# %serviceSlug%

Backend service (Java 25 LTS, Spring Boot 4.1, Maven) managed by MFE Orchestrator.

## Endpoints

Port `8080` (override with `PORT`). Docs and probes need no auth.

| Purpose      | Method | Path                         |
| ------------ | ------ | ---------------------------- |
| Liveness     | GET    | `/actuator/health/liveness`  |
| Readiness    | GET    | `/actuator/health/readiness` |
| Docs UI      | GET    | `/swagger-ui/index.html`     |
| OpenAPI spec | GET    | `/v3/api-docs`               |
| Hello        | GET    | `/api/hello`                 |

`/swagger-ui.html` redirects (`302`) to `/swagger-ui/index.html`. Probes answer `{"status":"UP"}`; readiness answers `503` with `OUT_OF_SERVICE` once the application refuses traffic. Only the `health` and `info` actuator endpoints are exposed over HTTP.

## Run locally

Requires JDK 25. The Maven Wrapper downloads Maven on first use.

```bash
./mvnw spring-boot:run          # http://localhost:8080
curl localhost:8080/actuator/health/liveness
open http://localhost:8080/swagger-ui/index.html
```

## Configuration

Environment variables only (Spring relaxed binding also maps any property, e.g. `SERVER_PORT`):

| Variable           | Default | Description                                                     |
| ------------------ | ------- | --------------------------------------------------------------- |
| `PORT`             | `8080`  | HTTP port                                                       |
| `SHUTDOWN_TIMEOUT` | `20s`   | How long graceful shutdown waits for in-flight requests         |
| `JAVA_TOOL_OPTIONS`| `-XX:MaxRAMPercentage=75` (image) | JVM flags; the heap follows the container memory limit |

## Test and build

```bash
./mvnw verify                   # tests + target/service.jar
java -jar target/service.jar
```

## Docker

```bash
docker build -t %serviceSlug% .
docker run --rm -p 8080:8080 %serviceSlug%
```

Multi-stage build: `eclipse-temurin:25-jdk-alpine` builds a layered jar, `eclipse-temurin:25-jre-alpine` runs it as the non-root user `10001`. The `HEALTHCHECK` calls `/actuator/health/liveness` with the BusyBox `wget` of the alpine base (no curl in the image).

On SIGTERM Spring Boot switches readiness to `REFUSING_TRAFFIC`, stops accepting connections and waits up to `SHUTDOWN_TIMEOUT` for in-flight requests (`server.shutdown=graceful`). Kubernetes probes, with a short `preStop` sleep so the pod leaves the Service endpoints before the server stops accepting connections:

```yaml
livenessProbe:
  httpGet: { path: /actuator/health/liveness, port: 8080 }
readinessProbe:
  httpGet: { path: /actuator/health/readiness, port: 8080 }
lifecycle:
  preStop:
    sleep: { seconds: 5 }   # Kubernetes 1.30+; otherwise exec: ["sleep", "5"] (BusyBox sleep is in the image)
```

## Dependency updates

`.github/dependabot.yml` opens weekly pull requests for the Maven dependencies and plugins, the Docker base images and the GitHub Actions, with minor and patch updates grouped into one PR per ecosystem. Majors of the `eclipse-temurin` base images are ignored: move to the next Java LTS on purpose (Dockerfile, CI `java-version`, `java.version` in `pom.xml` together). GitLab and Azure DevOps do not read this file: use Renovate there if you need the same.

## Releases

1. Create a new version of the service in the MFE Orchestrator console (this creates a git tag on the repository).
2. The tag triggers CI: tests (`./mvnw -B verify`), image build and push to the container registry, then the image is registered on the console (`POST /api/services/by-slug/%serviceSlug%/versions/<tag>` with `api-key`).
3. The version shows up in the console with its image reference and digest.

The deploy secret `MICROFRONTEND_ORCHESTRATOR_API_KEY` is injected in the repository by the console.

- GitHub Actions: `.github/workflows/release.yml` pushes to `ghcr.io/<owner>/<repo>` using `GITHUB_TOKEN`. Optional repo variable `MICROFRONTEND_ORCHESTRATOR_DOMAIN` overrides the console URL.
- GitLab CI: `.gitlab-ci.yml` pushes to the project's container registry.
- Azure DevOps: `azure-pipelines.yml` needs two pipeline variables:
  - `MFE_ORCHESTRATOR_REGISTRY_CONNECTION`: name of the Docker registry service connection;
  - `MFE_ORCHESTRATOR_IMAGE_REPOSITORY`: repository path in the registry (e.g. `my-org/%serviceSlug%`).
  Optionally `MFE_ORCHESTRATOR_REGISTRY_HOST` (e.g. `myregistry.azurecr.io`) so the registered image reference is fully qualified, and `MICROFRONTEND_ORCHESTRATOR_DOMAIN` to override the console URL. The secret comes from the variable group `MFE_ORCHESTRATOR_SECRETS`. The digest is not sent from Azure (optional field).
