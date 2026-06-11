// File: Jenkinsfile (in root of app-repo)
// Complete DevOps Pipeline - Declarative Syntax
// Copy this EXACTLY into Jenkins

pipeline {
    agent any

    // Environment variables for the pipeline
    environment {
        // Docker registry details (change these for your setup)
        DOCKER_REGISTRY = "docker.io"  // or "localhost:5000" for local registry
        DOCKER_USERNAME = credentials('docker-username')  // Jenkins secret
        DOCKER_PASSWORD = credentials('docker-password')  // Jenkins secret
        DOCKER_REPO = "saikiran0705"  // Your Docker Hub username or registry path
        IMAGE_NAME = "${DOCKER_REPO}/devops-app"
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        // SonarQube details
        SONARQUBE_SERVER = "http://localhost:9000"
        SONARQUBE_TOKEN = credentials('sonarqube-token')  // Jenkins secret
        SONARQUBE_PROJECT_KEY = "devops-app"
        
        // Git and ArgoCD details
        GIT_REPO_URL = "https://github.com/YOUR_USERNAME/app-repo.git"
        GITOPS_REPO_URL = "https://github.com/YOUR_USERNAME/gitops-repo.git"
        GITOPS_REPO_BRANCH = "main"
        GITOPS_REPO_PATH = "${WORKSPACE}/gitops-repo"
    }

    // Triggers
    triggers {
        // Webhook trigger from GitHub (Set up in GitHub settings)
        githubPush()
        
        // Poll SCM every 5 minutes (alternative if webhook doesn't work)
        pollSCM('H/5 * * * *')
    }

    // Pipeline options
    options {
        // Keep last 10 builds
        buildDiscarder(logRotator(numToKeepStr: '10'))
        
        // Add timestamps to console output
        timestamps()
        
        // Timeout after 1 hour
        timeout(time: 1, unit: 'HOURS')
    }

    stages {
        stage('1. Checkout') {
            steps {
                echo "========== STAGE 1: GIT CHECKOUT =========="
                
                // Checkout application repository
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[url: "${GIT_REPO_URL}"]],
                    poll: true
                ])
                
                echo "✓ Source code checked out successfully"
                sh 'echo "Workspace: ${WORKSPACE}"'
                sh 'ls -la'
            }
        }

        stage('2. Build & Package') {
            steps {
                echo "========== STAGE 2: MAVEN BUILD =========="
                
                // Use Maven to build the project
                sh '''
                    mvn clean compile package -DskipTests
                    echo "✓ Build successful"
                    ls -la target/
                '''
            }
        }

        stage('3. Run Unit Tests') {
            steps {
                echo "========== STAGE 3: UNIT TESTS =========="
                
                sh '''
                    mvn test
                    echo "✓ Tests completed"
                '''
            }
        }

        stage('4. Code Quality (SonarQube)') {
            steps {
                echo "========== STAGE 4: SONARQUBE SCAN =========="
                
                // Wait for SonarQube to be reachable
                sh '''
                    echo "Waiting for SonarQube to be ready..."
                    for i in {1..30}; do
                        if curl -f ${SONARQUBE_SERVER}/api/system/status > /dev/null 2>&1; then
                            echo "✓ SonarQube is ready"
                            break
                        fi
                        echo "Attempt $i: Waiting for SonarQube..."
                        sleep 2
                    done
                '''
                
                // Run SonarQube analysis
                sh '''
                    mvn sonar:sonar \
                        -Dsonar.projectKey=${SONARQUBE_PROJECT_KEY} \
                        -Dsonar.host.url=${SONARQUBE_SERVER} \
                        -Dsonar.login=${SONARQUBE_TOKEN}
                    echo "✓ SonarQube analysis completed"
                '''
                
                // Optional: Wait for SonarQube Quality Gate (takes ~10 seconds)
                sleep(time: 10, unit: 'SECONDS')
            }
        }

        stage('5. Build Docker Image') {
            steps {
                echo "========== STAGE 5: DOCKER BUILD =========="
                
                sh '''
                    echo "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                    echo "✓ Docker image built successfully"
                    docker images | grep ${DOCKER_REPO}
                '''
            }
        }

        stage('6. Push to Registry') {
            steps {
                echo "========== STAGE 6: DOCKER PUSH =========="
                
                sh '''
                    echo "Logging in to Docker Registry..."
                    echo "${DOCKER_PASSWORD}" | docker login -u ${DOCKER_USERNAME} --password-stdin
                    
                    echo "Pushing image: ${IMAGE_NAME}:${IMAGE_TAG}"
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
                    
                    echo "✓ Docker image pushed successfully"
                    docker logout
                '''
            }
        }

        stage('7. Update GitOps Repo') {
            steps {
                echo "========== STAGE 7: UPDATE GITOPS REPO =========="
                
                sh '''
                    # Clone GitOps repository
                    echo "Cloning GitOps repository..."
                    git clone -b ${GITOPS_REPO_BRANCH} ${GITOPS_REPO_URL} ${GITOPS_REPO_PATH}
                    cd ${GITOPS_REPO_PATH}
                    
                    # Update image tag in deployment.yaml
                    echo "Current deployment.yaml:"
                    cat k8s/deployment.yaml | grep "image:"
                    
                    # Use sed to update the image tag
                    sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" k8s/deployment.yaml
                    
                    echo "Updated deployment.yaml:"
                    cat k8s/deployment.yaml | grep "image:"
                    
                    # Configure git
                    git config user.email "jenkins@devops.local"
                    git config user.name "Jenkins Pipeline"
                    
                    # Commit and push changes
                    git add k8s/deployment.yaml
                    git commit -m "Update image tag to ${IMAGE_TAG} from Jenkins build #${BUILD_NUMBER}"
                    git push origin ${GITOPS_REPO_BRANCH}
                    
                    echo "✓ GitOps repository updated successfully"
                '''
            }
        }

        stage('8. ArgoCD Sync') {
            steps {
                echo "========== STAGE 8: ARGOCD SYNC =========="
                
                sh '''
                    # Install ArgoCD CLI if not present
                    if ! command -v argocd &> /dev/null; then
                        echo "Installing ArgoCD CLI..."
                        curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
                        chmod +x /usr/local/bin/argocd
                    fi
                    
                    # Login to ArgoCD (using kubectl port-forward)
                    argocd app sync devops-app --grpc-web
                    
                    echo "✓ ArgoCD sync triggered"
                '''
            }
        }
    }

    // Post build actions
    post {
        always {
            echo "========== PIPELINE EXECUTION SUMMARY =========="
            
            // Clean up workspace
            cleanWs(
                deleteDirs: true,
                patterns: [
                    [pattern: 'target/**', type: 'INCLUDE'],
                    [pattern: '.m2/**', type: 'INCLUDE']
                ]
            )
        }

        success {
            echo "✓✓✓ PIPELINE SUCCESSFUL ✓✓✓"
            echo "Docker Image: ${IMAGE_NAME}:${IMAGE_TAG}"
            echo "Application deployed to Minikube via ArgoCD"
        }

        failure {
            echo "✗✗✗ PIPELINE FAILED ✗✗✗"
            echo "Build Number: ${BUILD_NUMBER}"
            echo "Check Jenkins logs for details"
        }

        unstable {
            echo "⚠ PIPELINE UNSTABLE ⚠"
        }
    }
}

// ================================================================
// EXPLANATION OF EACH STAGE:
// ================================================================
// Stage 1: Checkout
//   - Pulls your source code from GitHub
//   - Uses the "main" branch by default
//
// Stage 2: Build & Package
//   - Runs: mvn clean compile package
//   - Creates JAR file in target/ directory
//
// Stage 3: Unit Tests
//   - Runs: mvn test
//   - Executes JUnit tests in src/test directory
//
// Stage 4: SonarQube
//   - Sends code to SonarQube for quality analysis
//   - Checks code smells, bugs, vulnerabilities
//   - Waits for SonarQube to be ready first
//
// Stage 5: Docker Build
//   - Creates Docker image from Dockerfile
//   - Tags with build number (${BUILD_NUMBER})
//   - Also tags as "latest"
//
// Stage 6: Docker Push
//   - Logs into Docker Hub using credentials
//   - Pushes image to registry
//   - Anyone can now pull this image
//
// Stage 7: Update GitOps Repo
//   - Clones your gitops-repo
//   - Updates deployment.yaml with new image tag
//   - Commits and pushes changes
//
// Stage 8: ArgoCD Sync
//   - Tells ArgoCD to sync the new manifest
//   - ArgoCD pulls from gitops-repo and deploys
//   - Updates running Minikube deployment
// ================================================================
