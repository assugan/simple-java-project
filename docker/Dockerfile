# ---------- build ----------
FROM maven:3.9.9-eclipse-temurin-21 AS builder
WORKDIR /app

# Copy pom.xml and download dependencies (cached)
COPY app/pom.xml .
RUN mvn dependency:go-offline -B

# Copy the sources and build jar file
COPY app/src ./src
RUN mvn package -DskipTests

# ---------- run ----------
FROM openjdk:21-jdk-slim
WORKDIR /app

# Copy jar file
COPY --from=builder /app/target/*.jar app.jar

# Run app
ENTRYPOINT ["java", "-jar", "app.jar"]