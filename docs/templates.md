# Template Reference

This document describes all scaffolding templates available in `gradle/template/`. Templates are used during project initialization and build-time code generation. Each template file uses the `.template` extension and contains placeholder tokens (e.g., `@@PROJECT_NAME@@`) that are replaced with project-specific values. Templates can be overridden via [Organization-Specific Overrides](index.html#org-overrides) — you only need to place the templates you want to override in your organization home directory. Any template not overridden falls back to the built-in default automatically.

## Placeholder Tokens

Common placeholders available in all templates:

| Token | Description |
|-------|-------------|
| `@@PROJECT_NAME@@` | Project name (e.g., `my-service`) |
| `@@GROUP_ID@@` | Maven group ID (e.g., `com.acme`) |
| `@@COMPONENT_ID@@` | Component identifier |
| `@@PACKAGE@@` | Java package name (e.g., `com.acme.myservice`) |
| `@@PARENT_PACKAGE@@` | Parent package name |
| `@@VERSION@@` | Project version |
| `@@YEAR@@` | Current year |
| `@@BUILD_TIMESTAMP@@` | Build timestamp |
| `@@DESCRIPTION@@` | Project description |
| `@@URL@@` | Project URL |
| `@@LICENSE@@` | License text |
| `@@SOURCE_MAIN@@` | Main source directory path |
| `@@SRC_TEST@@` | Test source directory path |
| `@@DISTNAME@@` | Distribution name |

## Templates by Category

### Base (`gradle/template/base/`)

Shared templates used across all project types.

| Template | Purpose |
|----------|---------|
| `build.gradle.template` | Default `build.gradle` with common-gradle-build `apply from:` |
| `settings.gradle.template` | Gradle `settings.gradle` with root project name |
| `gradle.properties.template` | Default `gradle.properties` with group ID, component ID, and description |
| `CHANGELOG.template` | Initial `CHANGELOG.md` in Keep a Changelog format |
| `LICENSE.template` | License file template |
| `README.template` | Project `README.md` with description and quick start |
| `editorconfig.template` | `.editorconfig` with encoding, indentation, and line ending rules |
| `Dockerfile.template` | Generic Dockerfile for container builds |
| `dockerignore.template` | `.dockerignore` excluding build artifacts, IDE files, and logs |
| `kubernetes.yaml.template` | Generic Kubernetes deployment and service manifest |
| `jwebserver.properties.template` | Configuration for embedded toolarium-jwebserver |
| `redirectIndexFile.template` | HTML redirect index file for subpath deployments |
| `robots.template` | `robots.txt` template |
| `defaults.gradle.template` | Organization `defaults.gradle` for organization-config projects |
| `custom.gradle.template` | Organization `custom.gradle` for organization-config projects |
| `gradlehome.properties.template` | Gradle home properties for custom configuration |

### Java (`gradle/template/java/`)

Templates for Java library projects.

| Template | Purpose |
|----------|---------|
| `build.gradle.template` | Java library `build.gradle` with dependencies and plugins |
| `javaFile.template` | Sample Java source file with package declaration |
| `javaLibrary.template` | Main library class stub |
| `javaLibraryTest.template` | JUnit test class stub |
| `JavaVersion.template` | Java version constants class |
| `logback.template` | Logback configuration (`logback-test.xml`) for test logging |

### Java Application (`gradle/template/java-application/`)

Templates for executable Java applications.

| Template | Purpose |
|----------|---------|
| `build.gradle.template` | Application `build.gradle` with shadow plugin |
| `gradle.properties.template` | Application properties with main class configuration |
| `javaLibrary.template` | Application main class with `public static void main` |

### Quarkus (`gradle/template/quarkus/`)

Templates for Quarkus REST services.

| Template | Purpose |
|----------|---------|
| `build.gradle.template` | Quarkus `build.gradle` with platform BOM and extensions |
| `gradle.properties.template` | Quarkus properties with plugin version, URL path, and database settings |
| `settings.gradle.template` | Quarkus `settings.gradle` with plugin management |
| `application.properties.template` | Quarkus `application.properties` with HTTP, datasource, OIDC, and logging config |
| `javaLibrary.template` | JAX-RS resource class stub |
| `javaLibraryTest.template` | Quarkus test class with `@QuarkusTest` |
| `javaLibraryNativeTest.template` | Native image test class |
| `index.html.template` | Welcome page for Quarkus dev UI |
| `Dockerfile.template` | Quarkus Dockerfile with JRE Alpine base image |
| `Dockerfile-java-runner.template` | Optimized Dockerfile using `toolarium-java-runner.sh` |
| `Dockerfile-java-runner-multistage.template` | Multistage build Dockerfile — compiles with JDK, runs on minimal Alpine image |
| `RunTimeDefaultsConfigSource.template` | MicroProfile Config source for runtime defaults |
| `kubernetes.yaml.template` | Kubernetes manifest with Quarkus health probes |
| `toolarium-java-runner.sh.template` | POSIX shell script for running Quarkus JARs in containers with JVM memory options, GC configuration, and graceful startup |
| `cb-meminfo.sh` | Memory monitoring script for container JVM diagnostics |

### OpenAPI (`gradle/template/openapi/`)

Templates for OpenAPI specification projects.

| Template | Purpose |
|----------|---------|
| `build.gradle.template` | OpenAPI `build.gradle` with generator plugin and Jakarta dependencies |
| `gradle.properties.template` | OpenAPI properties with generator settings |
| `openapi-sample.yaml.template` | Sample OpenAPI 3.0 specification YAML |

### Node.js (`gradle/template/nodejs/`)

Templates for Node.js-based projects (Nuxt.js, Vue.js, React).

| Template | Purpose |
|----------|---------|
| `build.gradle.template` | Node.js `build.gradle` with node plugin |
| `gradle.properties.template` | Node properties with version, registry, and build settings |
| `README.template` | Node.js project README |
| `Dockerfile.template` | Nginx Alpine Dockerfile for static web apps |
| `Dockerfile-node.template` | Node.js Alpine Dockerfile for server-side rendering |
| `kubernetes.yaml.template` | Kubernetes manifest for Node.js containers |
| `apply-subpath.sh.template` | Runtime subpath remapping script for dynamic context paths. See [full documentation](../README.md#runtime-subpath-remapping). |

### Kubernetes (`gradle/template/kubernetes/`)

Templates for Kubernetes product assembly.

| Template | Purpose |
|----------|---------|
| `build.gradle.template` | Kubernetes product `build.gradle` |
| `gradle.properties.template` | Kubernetes product properties |
| `kubernetes.yaml.template` | Service deployment manifest |
| `kubernetes-namespace.template` | Namespace definition |
| `kubernetes-application-config.template` | Application ConfigMap (OIDC, database settings) |
| `kubernetes-application-secret.template` | Application Secret (OIDC keys) |
| `kubernetes-database.template` | PostgreSQL StatefulSet with PVC and init scripts |
| `kubernetes-database-parameters.template` | Database connection parameters ConfigMap |
| `kubernetes-database-secret.template` | Database credentials Secret |
| `kubernetes-idm.template` | Keycloak/IDM Deployment with health probes |
| `kubernetes-idm-config.template` | IDM ConfigMap (database, realm settings) |
| `kubernetes-idm-secret.template` | IDM credentials Secret |
| `kubernetes-ingess-nginx.template` | Ingress-nginx controller deployment (deprecated — archived March 2026) |
| `kubernetes-ingress-controller-header.template` | Ingress resource with routing rules (deprecated) |
| `kubernetes-gateway.template` | Gateway API Gateway resource — installed once per cluster by platform admin |
| `kubernetes-httproute.template` | Gateway API HTTPRoute — portable routing rules for any Gateway API implementation |
| `kustomization.template` | Kustomize `kustomization.yaml` |
| `Dockerfile.template` | Container Dockerfile for Kubernetes products |
| `INSTALL.template` | Installation instructions |
| `install.sh.template` | Linux/Mac install script with `--replicas`, `--initialDelay`, `--period` |
| `install.bat.template` | Windows install script |

### Docker (`gradle/template/docker/`)

Templates for standalone container projects.

| Template | Purpose |
|----------|---------|
| `build.gradle.template` | Docker project `build.gradle` |
| `gradle.properties.template` | Docker project properties |
| `Dockerfile.template` | Standalone container Dockerfile |

### Documentation (`gradle/template/doc/`)

Templates for AsciiDoctor documentation projects.

| Template | Purpose |
|----------|---------|
| `asciidoctor-theme.css.template` | HTML theme with branded colors, responsive design, print styles |
| `asciidoctor-theme.yml.template` | PDF theme with typography, heading styles, code block formatting |

### Documentation Project (`gradle/template/documentation/`)

Templates for the `documentation` project type.

| Template | Purpose |
|----------|---------|
| `build.gradle.template` | Documentation project `build.gradle` |
| `gradle.properties.template` | Documentation project properties |
| `documentation.adoc.template` | Sample AsciiDoc document |

### Config (`gradle/template/config/`)

Templates for configuration package projects.

| Template | Purpose |
|----------|---------|
| `build.gradle.template` | Config project `build.gradle` |
| `gradle.properties.template` | Config project properties |

### Testing (`gradle/template/testing/`)

Templates for Playwright end-to-end testing projects.

| Template | Purpose |
|----------|---------|
| `package.json.template` | Node.js `package.json` with Playwright dependency and test scripts |
| `playwright.config.ts.template` | Playwright configuration with environment URL mapping, `TESTCASE` support, and `build/` output paths |
| `tests/example.spec.ts.template` | Sample Playwright test spec |

### Script (`gradle/template/script/`)

Templates for shell script projects.

| Template | Purpose |
|----------|---------|
| `build.gradle.template` | Script project `build.gradle` |
| `gradle.properties.template` | Script project properties |

### Checkstyle (`gradle/template/checkstyle/`)

Templates for code style checking configuration.

| Template | Purpose |
|----------|---------|
| `checkstyle.xml.template` | Checkstyle rules configuration |
| `checkstyle-suppressions.xml.template` | Checkstyle suppression rules |
| `checkstyle-file-header.txt.template` | Required file header text for license checks |

### Eclipse (`gradle/template/eclipse/`)

Templates for Eclipse IDE integration.

| Template | Purpose |
|----------|---------|
| `eclipse-project.template` | Eclipse `.project` file |
| `eclipse-classpath.template` | Eclipse `.classpath` file |
| `eclipse-checkstyle.template` | Eclipse Checkstyle plugin configuration |
| `eclipse-build-settings.template` | Eclipse build settings |

### SCM (`gradle/template/scm/`)

Templates for source control management.

| Template | Purpose |
|----------|---------|
| `gitignore.template` | `.gitignore` with IDE, build, OS, and Node.js patterns |
| `gitattributes.template` | `.gitattributes` with line ending rules for YAML, shell scripts |

### TypeScript (`gradle/template/typescript/`)

Templates for TypeScript configuration.

| Template | Purpose |
|----------|---------|
| `tsconfig.json.template` | TypeScript compiler configuration |
