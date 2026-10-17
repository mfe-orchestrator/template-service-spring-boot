FROM eclipse-temurin:25-jdk-alpine AS build
WORKDIR /app
COPY --chmod=0755 mvnw ./
COPY .mvn ./.mvn
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -q dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -q package -DskipTests \
  && java -Djarmode=tools -jar target/service.jar extract --layers --launcher --destination target/extracted

FROM eclipse-temurin:25-jre-alpine
LABEL org.opencontainers.image.title="%serviceSlug%"
RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app app
ENV PORT=8080 JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75"
WORKDIR /app
COPY --from=build /app/target/extracted/dependencies/ ./
COPY --from=build /app/target/extracted/spring-boot-loader/ ./
COPY --from=build /app/target/extracted/snapshot-dependencies/ ./
COPY --from=build /app/target/extracted/application/ ./
USER 10001:10001
EXPOSE 8080
# busybox wget ships with the alpine base, no curl needed
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget -q -O /dev/null "http://127.0.0.1:${PORT}/actuator/health/liveness" || exit 1
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
