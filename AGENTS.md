# AGENTS.md - %serviceSlug%

Java 25 LTS + Spring Boot 4.1 (Spring MVC) backend service, built with Maven, packaged as a Docker image.

## Layout

- `pom.xml`: Spring Boot parent, `spring-boot-starter-webmvc`, `spring-boot-starter-actuator`, `springdoc-openapi-starter-webmvc-ui`.
- `src/main/java/dev/mfeorchestrator/service/ServiceApplication.java`: entry point and the `@OpenAPIDefinition` (title, version).
- `src/main/java/dev/mfeorchestrator/service/HelloController.java`: example `GET /api/hello`.
- `src/main/resources/application.properties`: port, graceful shutdown, actuator exposure, springdoc paths.
- `src/test/java/...`: `@SpringBootTest` + MockMvc tests.
- `Dockerfile`: multi-stage, layered jar, non-root user `10001`, healthcheck on `/actuator/health/liveness`.
- `mvnw`, `.mvn/wrapper/`: Maven Wrapper. Always use `./mvnw`, never a system `mvn`.

## Endpoints the platform relies on

- `GET /actuator/health/liveness` and `GET /actuator/health/readiness`: Kubernetes probes.
- `GET /swagger-ui/index.html` (Swagger UI, `/swagger-ui.html` redirects there) and `GET /v3/api-docs` (OpenAPI spec). Both public, no auth.

## Add an endpoint

Create a `@RestController` in `dev.mfeorchestrator.service` (or a sub-package), under `/api`. Document it for the OpenAPI spec with `@Tag` on the class and `@Operation(summary = ...)` on each method; return a record or DTO so springdoc can derive the response schema, and add `@ApiResponse` for non-200 statuses. Add a MockMvc test in `src/test/java` that calls it, and assert in a test that `/v3/api-docs` contains its path if the documentation matters.

## Add a health check

Implement `HealthIndicator` as a `@Component` (e.g. `DatabaseHealthIndicator`, its name in the health tree is `database`). To make it gate readiness, add it to the readiness group in `application.properties`:

```properties
management.endpoint.health.group.readiness.include=readinessState,database
```

Never add dependency checks to the liveness group: a failing liveness probe restarts the pod.

## Commands

- `./mvnw verify` (tests + jar), `./mvnw spring-boot:run`, `./mvnw test -Dtest=ServiceApplicationTests`

## Conventions

- Configuration comes from environment variables only (`${ENV_VAR:default}` placeholders in `application.properties`). Never hardcode secrets or URLs.
- Keep the probes, the Swagger UI and `/v3/api-docs` working and unauthenticated. If you add Spring Security, permit `/actuator/health/**`, `/swagger-ui/**`, `/swagger-ui.html` and `/v3/api-docs/**`.
- Expose only `health` and `info` actuator endpoints over HTTP. Never expose `env`, `heapdump`, `beans`, `configprops` or `*`.
- Listen on `PORT` (default 8080). Keep `server.shutdown=graceful`.
- Every new endpoint needs a test. Run `./mvnw verify` before finishing.
- Never edit CI files (`.github/`, `.gitlab-ci.yml`, `azure-pipelines.yml`) or Dockerfile base images unless explicitly asked.
- Dependencies are kept current by Dependabot (`.github/dependabot.yml`, weekly, minor/patch grouped). Add new dependencies at their latest stable version; do not pin old versions without a reason.
