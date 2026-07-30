# Stage 1: Build
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY application/pom.xml .
RUN mvn dependency:go-offline -B
COPY application/src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: Run (non-root, minimal base)
FROM eclipse-temurin:17-jre-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=build /build/target/campus-app.jar app.jar
RUN chown appuser:appgroup /app/app.jar
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q --spider http://localhost:8080/health || exit 1
ENTRYPOINT ["java", "-jar", "app.jar"]
