# DevOps CI/CD Project - Source Code

Simple Java application with complete CI/CD pipeline.

## Build Locally
mvn clean package

## Build Docker Image
docker build -t devops-app:latest .

## Run
docker run -it devops-app:latest
