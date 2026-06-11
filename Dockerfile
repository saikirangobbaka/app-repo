# File: Dockerfile (in root of app-repo)
# Multi-stage Docker build

# Stage 1: Build stage
FROM maven:3.8.1-openjdk-11 AS builder

WORKDIR /app

# Copy pom.xml first
COPY pom.xml .

# Download dependencies
RUN mvn dependency:resolve

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Stage 2: Runtime stage
FROM openjdk:11-jre-slim

WORKDIR /app

# Copy JAR from builder stage
COPY --from=builder /app/target/devops-app.jar .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD java -cp /app/devops-app.jar com.example.HelloWorld || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "devops-app.jar"]
