# common-gradle-build

[![License](https://img.shields.io/github/license/toolarium/common-gradle-build)](https://opensource.org/licenses/GPL-3.0)

<img align="right" height="110" src="docs/logo/common-gradle-build-small.png">

A shared, script-based Gradle build framework that provides a complete build lifecycle for multiple project types. Consumer projects integrate with a single line — no plugins, no `buildscript` blocks, just one `apply from:` statement.

> Works hand in hand with its sister project [**common-build**](https://github.com/toolarium/common-build).

## Quick Start

### Using common-build (recommended)

The [**common-build**](https://github.com/toolarium/common-build) project wizard creates new projects interactively and installs Gradle for you — no manual setup required:

```bash
cb --new
```

See the [common-build documentation](https://github.com/toolarium/common-build) for installation and usage.

### Manual setup

1. Install [Gradle](https://gradle.org/install/) and ensure `gradle` is available on your command line.
2. Create a project directory, e.g. `mkdir my-java-lib && cd my-java-lib`
3. Create a `build.gradle` with this content and run `gradle`:

   ```groovy
   apply from: "https://raw.githubusercontent.com/toolarium/common-gradle-build/master/gradle/common.gradle"
   ```

   One-liner for the shell:
   - **Windows:** `echo apply from: "https://raw.githubusercontent.com/toolarium/common-gradle-build/master/gradle/common.gradle" > build.gradle & gradle`
   - **Linux/Mac:** `echo apply from: \"https://raw.githubusercontent.com/toolarium/common-gradle-build/master/gradle/common.gradle\" > build.gradle && gradle`

The framework auto-detects your project type from the directory structure and applies the full build lifecycle automatically.

## Supported Project Types

| Type | Description | Name Suffix |
|------|-------------|-------------|
| **config** | Configuration package projects (properties, YAML) | `-config` |
| **container** | Container image building with Docker/nerdctl | `-container` |
| **documentation** | AsciiDoctor documentation rendering to HTML and PDF | `-documentation` |
| **java-application** | Executable Java application with shadow/fat jar and container support | `-app` |
| **java-library** | Standard Java library with compilation, testing, publication, and signing | — |
| **kubernetes-product** | Kubernetes deployments with manifest generation and product assembly | `-app` |
| **nuxtjs** | Nuxt.js with TypeScript support and localization | `-ui` |
| **openapi** | OpenAPI spec generation using the openapi-generator plugin | `-service-api-spec` |
| **organization-config** | Organization-level configuration and policy management | `-config` |
| **quarkus** | Quarkus REST service with optimized JVM options and Alpine container support | `-service` |
| **react** | React single-page application projects | `-ui` |
| **script** | Shell/bash script projects with distribution archives | `-bin` |
| **testing** | End-to-end testing with Playwright, container-based test execution | `-testing` |
| **vuejs** | Vue.js single-page application projects | `-ui` |

## Versioning & Release Management

Semantic versioning based on a `VERSION` file with four fields:

```
major.number        = 1
minor.number        = 4
revision.number     = 8
qualifier           =
```

**Snapshot vs. release detection:** The build is a **snapshot** when the `qualifier` contains `SNAPSHOT` (the default for new projects). It is a **release** when the qualifier is empty. This controls behavior across the entire framework — snapshot builds skip strict validation, allow mutable artifacts, and disable version caching; release builds enforce changelog validation, sign artifacts, and fail on vulnerability issues.

**Releasing:**

```bash
gradle release
```

If the qualifier is `SNAPSHOT`, this creates a full release — removes the qualifier, builds and publishes artifacts, creates a git tag, then increments the revision number and re-adds SNAPSHOT for the next development cycle. If the qualifier is already empty, it creates a snapshot build.

To force a release build regardless of the current qualifier (e.g., for CI), the SNAPSHOT qualifier will be removed automatically:

```bash
gradle -PisReleaseVersion=true release
```

With [**common-build**](https://github.com/toolarium/common-build):

```bash
cb release                            # release based on qualifier (full release or snapshot)
cb -PisReleaseVersion=true release    # force a release, SNAPSHOT qualifier removed automatically
```

## Features

### Changelog Management

Follows the [Keep a Changelog](https://keepachangelog.com) format:
- Automatic changelog file creation for new projects
- Mandatory validation on release builds (configurable)
- Auto-adds version entries after release with configurable change type and comment
- Unreleased section support, bracket-style versions, release links
- Configurable header and item separators

### Dependency Management

A whitelist/blacklist system controls which dependency versions are allowed or forbidden.

- **`gradle/conf/whitelist-dependencies.properties`** — approved dependency versions
- **`gradle/conf/blacklist-dependencies.properties`** — forbidden dependency versions

Version expressions support flexible matching (e.g., `1.2.*`, `>=1.0.2 <2.1.2`). Entries can be scoped to specific configurations like `[implementation]` or `[testRuntimeOnly]`. The system maps resolved configuration names (`compileClasspath`) back to declared names (`implementation`).

### Vulnerability Scanning

Integrated [Trivy](https://trivy.dev/) scanning for dependencies and container images. **Disabled by default** — enable via property or environment variable:

```properties
# gradle.properties
vulnerabilityScannerEnabled=true
```

```sh
# or via environment variable (overrides property)
CB_VULNERABILITY_SCANNER_ENABLED=true ./gradlew build
```

- Scans dependencies via `trivy rootfs` and container images via `trivy image` (only if `dockerBuild` succeeded)
- Severity levels: **DENY** (blacklisted), **CRIT**, **HIGH**, **MED**, **LOW** — aligned to 5 chars
- Snapshot builds scan all severities but don't fail; release builds fail on DENY, CRIT, or HIGH
- Vulnerabilities without a fix available are reported with `[no fix available]` but don't fail the build (configurable via `vulnerabilityScannerFailWithoutFix`)
- Set `vulnerabilityScannerAbortEnabled=false` (or `CB_VULNERABILITY_SCANNER_ABORT=false`) to report findings as warnings without failing the build
- Dependency tree resolution shows which top-level `build.gradle` dependency to update (with configuration like `implementation`, `transitive`)
- Whitelist bypass for known/accepted vulnerabilities using the same properties files
- Container image whitelist/blacklist via `[container]` tag (e.g. `[container]registry.k8s.io/ingress-nginx/controller = 1.15.1`)
- Kubernetes-product: referenced container images scanned with summary table; configurable build failure via `kubernetesProductFailOnVulnerabilityDependencies`
- Fine-tune scanning via `trivy.yaml` in the project root (see below)

#### Trivy Configuration (`trivy.yaml`)

Trivy natively picks up a `trivy.yaml` file from the **project root** (the working directory during build) or from `~/.config/trivy/trivy.yaml`. The scanner does not pass a `--config` flag — discovery is handled by Trivy itself.

A starter template is available in [`gradle/experimental/conf/trivy.yaml`](gradle/experimental/conf/trivy.yaml). The settings that are actually useful to configure here are `skip-dirs` and `skip-files` — everything else is controlled (and overridden) by Gradle properties:

```yaml
# trivy.yaml — place in the project root

# skip-dirs is additive: .gradle is always skipped by the scanner via --skip-dirs
skip-dirs:
  - node_modules
  - .git

# skip-files has no Gradle property equivalent — configure it here
skip-files:
  - "**/*.test.js"
  - "**/test/**"

# Do NOT set these here — they are always overridden by Gradle properties passed as CLI flags:
#   severity      → overridden by vulnerabilityScannerSeverity (--severity)
#   scan.scanners → overridden by vulnerabilityScannerScanners (--scanners)
#   format        → hardcoded to json by the scanner (--format json)
#   exit-code     → controlled by vulnerabilityScannerExitCode (--exit-code)
```

#### Console Output Example

A scan with findings (colors stripped):

```
> Dependency scan: 3 issues found (CRIT: 1, HIGH: 1, LOW: 1). (1 no fix available)
  CRIT CVE-2024-29025: io.netty:netty-codec-http 4.1.107.Final -> 4.1.108.Final
       -> io.quarkus:quarkus-resteasy-reactive:3.8.1 (implementation, transitive)
  HIGH CVE-2024-12797: org.bouncycastle:bcprov-jdk18on 1.77 [no fix available]
       -> io.quarkus:quarkus-smallrye-jwt:3.8.1 (implementation, transitive)
  LOW  CVE-2023-52428: com.nimbusds:nimbus-jose-jwt 9.37.3 -> 9.40
       -> io.quarkus:quarkus-smallrye-jwt:3.8.1 (implementation, transitive)
```

When no vulnerabilities are found:

```
> Dependency scan: no vulnerabilities (CRITICAL,HIGH) found.
```

Each finding line shows:
- **Severity label** (`DENY`/`CRIT`/`HIGH`/`MED`/`LOW`) padded to 5 characters
- **CVE ID** and affected package `name version`
- **Fix version** (`-> x.y.z`) or `[no fix available]` when no fix exists
- **Top-level `build.gradle` dependency** that pulls in the vulnerable package, with its declared Gradle configuration (`implementation`, `testImplementation`, etc.) and whether it is a direct or `transitive` dependency

### OWASP Dependency-Check

Optional OWASP dependency-check integration via `toolarium-dependency-check-util`. Generates HTML and JSON reports with colored console output showing artifacts, CVEs, severity, confidence, and included-by chains.

### Code Quality

**Checkstyle** — integrated style checking with HTML/XML reports, configurable warning thresholds, and auto-created configuration from templates. Supports per-project or organization-wide checkstyle rules with custom stylesheets for HTML reports.

**JaCoCo** — code coverage with XML, CSV, and HTML reports. Automatically runs after tests and integrates with SonarQube for dashboard reporting.

**SonarQube** — code analysis for smells, bugs, and security issues with coverage, dependency-check, and test report integration. Enable with:

```groovy
sonarEnabled = true
sonarHostUrl = "https://your-sonar-server.com"
sonarToken   = "your-token"
```

### Java Build Features

- **Compilation:** Source/target auto-detected from current JDK, `-Xlint:unchecked`, `-parameters`, deprecation warnings enabled, optional fork with custom JDK
- **Testing:** JUnit 5 by default (JUnit 4 auto-detected), configurable heap sizes, dynamic agent loading support for JDK 21+, JUnit XML reports, git credentials cleaned from test environment
- **Javadoc:** Automatic Javadoc JAR generation
- **Publication:** Maven publication with full POM metadata (developer, license, SCM), auto-detected Git remote URL, separate snapshot/release/staging repositories
- **Signing:** GPG artifact signing for release builds (requires `signing.keyId`, `signing.password`, `signing.secretKeyRingFile` in `~/.gradle/gradle.properties`)
- **Fat JARs:** Shadow plugin for java-application, fat web jars with embedded `toolarium-jwebserver` for Node.js projects, configurable package type (jar, tgz)
- **Executable JARs:** Any java-library can be made executable via `java -jar` by setting `mainClassName`

**Example: Make a java-library executable**

Set the main class in `gradle.properties`:

```properties
mainClassName=com.acme.mylib.Main
```

Optionally add a classpath — use `auto` to include all runtime dependencies, or list JARs explicitly:

```properties
mainClassPath=auto
```

Then run:

```bash
gradle build
java -jar build/libs/my-library-1.0.0.jar
```

### Container & Kubernetes

**Container support:**
- Auto-detects Docker or nerdctl (falls back to Docker if nerdctl unavailable)
- Dockerfile generation from `.template` files with placeholder replacement
- Default base images: `eclipse-temurin:21-jre-alpine` (Java), `nginx:alpine` (web), `node:alpine` (Node.js)
- OCI annotation support (maintainer, title, vendor, license, version, revision, created)
- Latest tag support, metadata file output, dangling image cleanup
- Separate snapshot/release registries with login support
- Image building, tagging, pushing, and post-build cleanup
- Vulnerability scanning of built images via Trivy

**Kubernetes support:**
- Manifest generation with YAML templating and namespace replacement
- Namespace, Service, Deployment, Ingress creation from templates
- Readiness, liveness, and startup probe configuration with configurable thresholds
- ConfigMap and Secret management with base64 encoding
- OIDC authentication support (auth server URL, token issuer, client ID, public key)
- Database configuration (PostgreSQL by default) with admin/app user separation and init scripts
- IDM/Keycloak integration with realm, database, and secret configuration
- Kustomize support with base/services/config/controller structure
- Install scripts (bat/sh) with `--help`, `--replicas`, `--initialDelay`, `--period` options
- Ingress-nginx controller with configurable proxy buffer/body size (**deprecated** — archived March 2026)
- [Gateway API](https://gateway-api.sigs.k8s.io/) support with HTTPRoute and Gateway resource templates — portable across NGINX Gateway Fabric, Envoy Gateway, Istio, Contour, Traefik, etc.
- Product assembly: service concatenation, README generation, application-information packaging

### AsciiDoctor Documentation

HTML and PDF document generation from AsciiDoc sources:
- Auto-created theme files (CSS for HTML, YAML for PDF) from templates with branded colors, responsive design, print styles
- Custom fonts support, configurable source highlighter (highlight.js for HTML, rouge for PDF)
- TOC, icons, section anchors, and encoding configuration
- Documents included in Kubernetes JAR when `kubernetesDocSupport` is enabled
- `documentation` project type for standalone documentation projects

### Template & Scaffolding System

85+ templates in `gradle/template/` for bootstrapping new projects: build files, Dockerfiles, Kubernetes manifests, Java source stubs, Checkstyle configs, Eclipse settings, Git configs, and more. See the full [Template Reference](docs/TEMPLATES.md) for details.

Templates use placeholder tokens (e.g., `@@PROJECT_NAME@@`, `@@GROUP_ID@@`, `@@VERSION@@`, `@@PACKAGE@@`, `@@YEAR@@`, `@@BUILD_TIMESTAMP@@`) that are replaced during project initialization.

### JavaScript / Node.js Support

For Node.js-based project types (nuxtjs, vuejs, react):
- gradle-node-plugin integration with configurable Node.js, npm, and yarn versions
- npm registry configuration, fund message suppression
- npm build, test, dev, and lint tasks
- Nuxt 3 auto-detection (uses `.output` directory, generates nitro config)
- React `.env` file management with `BUILD_PATH` configuration
- Fat web JAR creation with embedded `toolarium-jwebserver` for containerized deployment
- Runtime subpath remapping via `apply-subpath.sh` for dynamic context paths in containers
- Multi-encoding path replacement (Unicode `\u002F`, URL `%2F`, JSON `\/`, double-escaped `\\/`)

#### Runtime Subpath Remapping

When a Node.js application is deployed under a different URL subpath than it was built with, the container automatically rewrites all path references at startup. For example, an app built as `myui` can be served under `/org/team/myui` without rebuilding.

**Example: Deploy under a custom subpath**

Set the `SUBPATH` environment variable when running the container:

```sh
# App built with subdir "myui", now served under /portal/myui
docker run -e SUBPATH=portal myimage

# Nested subpath: served under /org/team/myui
docker run -e SUBPATH=org/team myimage
```

**Example: Configure via service properties**

Instead of `SUBPATH`, you can define the paths in `toolarium-service.properties`:

```properties
service.root-path = /org/team/myui
service.resources = /myui
```

**Example: Kubernetes deployment**

```yaml
env:
  - name: SUBPATH
    value: "org/team"
```

**What happens at container startup:**
1. Detects the source subdirectory in the deployment directory
2. Reads target paths from the service properties file if available
3. Moves files to the target subpath structure
4. Replaces all occurrences of the source path in text files, handling multiple encodings (Unicode `\u002F`, URL-encoded `%2F`, JSON-escaped `\/`, double-escaped `\\/`, and quoted contexts)
5. Updates the nginx configuration and generates 302 redirect blocks for intermediate path segments

Binary files (images, fonts, wasm, archives) and `locales/` directories are automatically skipped.

**Environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `SUBPATH` | *(empty)* | Override target subpath (e.g., `org/team`) |
| `REPLACE_WHITESPACE_VARIATIONS` | `false` | Also replace paths surrounded by whitespace, e.g. `key = myui  value` -> `key = portal/myui  value`. Useful for config files with loose formatting. |
| `REPLACE_CASE_VARIATIONS` | `false` | Also replace UPPERCASE and Title Case variants, e.g. `MYUI` -> `portal/myui` and `Myui` -> `portal/myui`. Requires GNU sed (not available on Alpine by default). |

**Allowed characters:**
- `SUBPATH` must only contain `[a-zA-Z0-9._/-]` — no spaces, semicolons, dollar signs, or other special characters
- `SUBPATH` must not contain `..` (path traversal is rejected)
- API paths (`api/<subdir>/...`) are automatically protected from rewriting

### Testing (Playwright)

End-to-end testing project type using [Playwright](https://playwright.dev/). Test sources live under `src/main/ts/tests/`, output goes to `build/`. Supports local execution, container-based execution, and environment-based URL targeting.

**Project structure:**

```
my-project-testing/
├── src/main/ts/
│   └── tests/              # Playwright test specs
│       └── example.spec.ts
├── playwright.config.ts     # Playwright configuration
├── package.json
├── build/
│   ├── test-results/        # test output
│   └── playwright-report/   # HTML report
└── build.gradle
```

**Build and test commands:**

```sh
cb                          # install dependencies
cb test                     # run all tests
ENV_NAME=int cb test        # run against a specific environment
BASE_URL=https://url cb test  # run against an explicit URL
```

**Container-based testing:**

```sh
cb dockerBuild              # build test container

# using cb-container
cb-container                                       # run all tests
cb-container -e ENV_NAME=acpt                      # target environment
cb-container -e TESTCASE="has title"               # specific test case
cb-container -e ENV_NAME=int -e TESTCASE="has title"  # combine both
# report available at: build/reports/testing/index.html

# using docker run
docker run --rm my-project-testing:0.0.1-SNAPSHOT
docker run --rm -e ENV_NAME=acpt my-project-testing:0.0.1-SNAPSHOT
docker run --rm -e TESTCASE="has title" my-project-testing:0.0.1-SNAPSHOT
docker run --rm -v ./build/reports/testing:/deployment/build/playwright-report my-project-testing:0.0.1-SNAPSHOT
```

**Environment variables:**

| Variable | Description |
|----------|-------------|
| `BASE_URL` | Explicit target URL (highest priority) |
| `ENV_NAME` | Environment name mapped in `playwright.config.ts` (`local`, `int`, `acpt`, `prod`) |
| `TESTCASE` | Run only test cases matching this name |

URL resolution order: `BASE_URL` > `ENV_NAME` > default (`http://localhost:8080`).

### Enum Configuration

Toolarium enum configuration processor integration:
- Type-safe configuration generation from JSON
- Duplicate key validation across services (fails on release builds)
- Mandatory configuration with missing default value detection
- Index and initialization file generation for Kubernetes product assembly
- **Documentation generation** — automatic AsciiDoc (`.adoc`) and Markdown (`.md`) documentation from enum configuration JSON data:
  - Overview with service summary table, Mandatory Configurations chapter, detailed Services chapter with all configuration keys
  - Flag system: **M** (Mandatory), S (Secure), U (Unique), **C** (Customer-responsible), P (Provisioned)
  - Split by marker interface into separate documents (e.g. `configuration-ienumconfiguration.adoc`)
  - Generated docs included in AsciiDoctor PDF/HTML processing and in the Kubernetes JAR (`docs/` folder)
  - Configurable via `enumConfigurationDocAsciidoc`, `enumConfigurationDocMarkdown`, `enumConfigurationDocKeyLowercase`, `enumConfigurationDocGroupLowercase`, `enumConfigurationDocProductLabel`, `enumConfigurationDocIncludeInJar`, `enumConfigurationDocCustomerKeys`, `enumConfigurationDocProvisionedKeys`

### Resource Bundles & Localization

Excel-based localization workflow: define translations in `Resourcebundle.xlsx`, generate JSON and properties output files for multi-language projects. Supports reference sheets and configurable encoding.

### Security Utilities

Cryptographic helper functions available in all project types:
- `createPassword(length)` — random password with special characters
- `createHash(length)` — random alphanumeric hash
- `readPublicKeyFromFile(filename)` / `readPrivateKeyFromFile(filename)` — PEM key extraction
- `createMessageHash(keyFile, message, algorithm)` — RSA-signed message digest with `{ALGORITHM}base64` format
- `verifyMessageHash(keyFile, message, hash)` — RSA signature verification with auto-detected algorithm

### SCM Integration

Git operations via grgit library:
- Repository initialization, clone, branch, commit, push, tag
- Release branch creation and merge-back workflow
- Credentials manager support (`GRGIT_USER`, `GRGIT_PASS`)
- Auto-detected Git remote URL for POM SCM metadata
- Commit hash tracking during project validation

### Git Cleanup of Disallowed Tracked Files

The framework automatically detects and removes files from the git index that should not be checked in (e.g., `build/`, `.gradle/`, `.idea/`, `.vscode/`, `.settings/`, `.claude/`, `.classpath`, `.project`). On snapshot builds, if any of these directories or files are tracked, they are removed from the git cache (`git rm --cached`) and appended to `.gitignore` so they stay untracked going forward.

This prevents accidental commits of IDE settings, build output, and other local-only files.

**Configuration:**

| Property | Default | Description |
|----------|---------|-------------|
| `gitCleanupDisallowedFiles` | `true` | Enable automatic cleanup of disallowed tracked files |
| `disallowedCheckedInFiles` | `build, .claude, .gradle, .classpath, .project, .settings, .idea, .vscode` | Comma-separated list of files/directories to remove from git index |

Set `CB_DISABLE_GIT_CLEANUP=true` as an environment variable to disable this feature without changing project properties.

---

## Configuration Reference

All properties below can be set in two places:

- **`defaults.gradle`** (via [Organization-Specific Overrides](#organization-specific-overrides)) — recommended for **general settings** that apply across all projects in your organization.
- **`gradle.properties`** (per project, or via `-P` on the command line) — for **project-specific settings** only.

Framework defaults are defined in [`gradle/build-element/base/defaults.gradle`](gradle/build-element/base/defaults.gradle).

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `COMMON_GRADLE_BUILD_URL` | Override framework location (`file://` for local testing, `https://` for custom fork) |
| `COMMON_GRADLE_BUILD_CACHE` | Override local cache directory (default: `~/.gradle/common-gradle-build/`) |
| `COMMON_GRADLE_BUILD_HOME` | Override configuration home directory (see [Organization-Specific Overrides](#organization-specific-overrides)) |
| `CB_CUSTOM_CONFIG_VERSION` | Pin custom configuration version |
| `GRGIT_USER` | Git username for release operations |
| `GRGIT_PASS` | Git password/token for release operations |
| `CB_DISABLE_GIT_CLEANUP` | Set to `true` to disable automatic cleanup of disallowed tracked files (see [Git Cleanup](#git-cleanup-of-disallowed-tracked-files)) |
| `CB_VULNERABILITY_SCANNER_ENABLED` | Set to `true`/`false` to enable or disable vulnerability scanning (overrides `vulnerabilityScannerEnabled` property) |
| `CB_VULNERABILITY_SCANNER_ABORT` | Set to `false` to report vulnerability findings as warnings without failing the build (overrides `vulnerabilityScannerAbortEnabled` property) |

---

### Most Relevant Settings

These are the properties you are most likely to customize. Set general/organization-wide values in `defaults.gradle` (via [Organization-Specific Overrides](#organization-specific-overrides)); set project-specific values in `gradle.properties`:

#### Build Artifacts

| Property | Default | Description |
|----------|---------|-------------|
| `createJar` | `true` | Create main JAR artifact |
| `createSourceJar` | `true` | Create sources JAR artifact |
| `createJavadocJar` | `true` | Create Javadoc JAR artifact |
| `createFatJar` | `false` | Create fat/uber JAR with all dependencies |
| `createCustomJar` | `false` | Create custom JAR (used by kubernetes-product, docker, nodejs) |
| `fatJarPackageType` | `jar` | Fat JAR output format: `jar`, `tgz`, or `jgz` |

#### Compilation

| Property | Default | Description |
|----------|---------|-------------|
| `sourceCompatibility` | *(current JDK)* | Java source compatibility version |
| `targetCompatibility` | *(current JDK)* | Java bytecode target version |
| `fileEncoding` | `UTF-8` | Source file encoding |
| `compileJavaFork` | `false` | Fork a separate JVM for compilation |
| `compileJavaHome` | `""` | Custom JDK home for compilation (requires `compileJavaFork=true`) |
| `mainClassName` | `""` | Fully qualified main class for executable JAR (`Main-Class` manifest attribute) |
| `mainClassPath` | `""` | `Class-Path` manifest attribute for executable JAR. Use `auto` to resolve from runtime dependencies, or a space/comma-separated list of JARs |

#### Testing

| Property | Default | Description |
|----------|---------|-------------|
| `useJUnit` | `true` | Enable JUnit testing |
| `testDependencyVersion` | `5.7.2` | JUnit version (auto-detects JUnit 4 vs 5) |
| `testMinHeapSize` | `128m` | Minimum heap for test JVM |
| `testMaxHeapSize` | `512m` | Maximum heap for test JVM |
| `testEnableDynamicAgentLoading` | `true` | Add `-XX:+EnableDynamicAgentLoading` for JDK 21+ |
| `showStandardStreams` | `false` | Display test stdout/stderr in console |

#### Changelog

| Property | Default | Description |
|----------|---------|-------------|
| `createChangelogFile` | `true` | Auto-create CHANGELOG.md for new projects |
| `validateChangelogFile` | `true` | Validate changelog format on build |
| `changelogUpdateFileAfterRelease` | `true` | Auto-add version entry after release |
| `changelogFailOnSnapshotBuild` | `false` | Fail validation on snapshot builds (normally release-only) |
| `changelogSupportUnreleased` | `true` | Allow `[Unreleased]` section |

#### Code Quality

| Property | Default | Description |
|----------|---------|-------------|
| `checkstyleToolVersion` | `10.3.3` | Checkstyle version |
| `checkstyleMaxWarnings` | `0` | Maximum allowed checkstyle warnings before failure |
| `checkstyleHTMLReport` | `true` | Generate HTML checkstyle report |
| `checkstyleXMLReport` | `false` | Generate XML checkstyle report |
| `projectIndividualCheckstyleConfiguration` | `true` | Use project-local checkstyle config (vs. organization-wide) |
| `jacocoToolDefaultVersion` | `0.8.14` | JaCoCo version |
| `jacocoXMLReport` | `true` | Generate XML coverage report (needed for SonarQube) |
| `jacocoHTMLReport` | `true` | Generate HTML coverage report |
| `jacocoCSVReport` | `false` | Generate CSV coverage report |
| `sonarEnabled` | `false` | Enable SonarQube analysis |
| `sonarVersion` | `7.2.3.7755` | SonarQube Gradle plugin version |

#### Container

| Property | Default | Description |
|----------|---------|-------------|
| `containerCmd` | `nerdctl` | Container tool command (`nerdctl` or `docker`) |
| `dockerImage` | *(per project type)* | Base container image |
| `dockerDefaultPort` | `8080` | Container exposed port |
| `dockerSubPathAccess` | `""` | URL subpath for container deployment |
| `buildAlwaysDockerImage` | `false` | Build container image on every build |
| `dockerRemoveDanglingImages` | `true` | Clean up dangling images after build |
| `dockerRemoveNonEssentialBinaries` | `false` | Remove non-essential binaries from container (Alpine only; keeps only what entrypoint scripts need) |
| `dockerMakeFilesystemReadonly` | `false` | Make `/etc`, `/usr`, `/lib` read-only in container |
| `dockerReadonlyFilesystemPath` | `"/etc /usr /lib"` | Space-separated paths to make read-only |
| `dockerReadonlyFilesystemExcludePath` | `"/etc/ssl/certs /usr/local/share/ca-certificates $JAVA_HOME/lib/security"` | Space-separated paths to keep writable within read-only dirs (Alpine CA certs, Java truststore) |
| `dockerRemoveImageVersion` | `false` | Remove OS version info files (`/etc/alpine-release`, `/etc/os-release`, `/etc/issue`) from container image |
| `dockerRemovePackageVersions` | `false` | Remove package version information from container image (e.g. `package.json`, dependency list files) |
| `dockerRemovePackageInstallationBinaries` | `true` | Remove package manager binaries (`apk`) from container image |
| `dockerSupportLatestTag` | `true` | Add `:latest` tag to built image |
| `dockerAddAnnotation` | `false` | Add OCI metadata annotations |
| `dockerCleanupAfterBuild` | `false` | Remove image after successful build |
| `dockerCleanupAfterPublish` | `true` | Remove local image after push |

#### Vulnerability Scanner

| Property | Default | Description |
|----------|---------|-------------|
| `vulnerabilityScannerEnabled` | `false` | Enable Trivy vulnerability scanning (also overridable via `CB_VULNERABILITY_SCANNER_ENABLED` env var) |
| `vulnerabilityScannerAbortEnabled` | `true` | When `false`, findings are reported as warnings without failing the build (also overridable via `CB_VULNERABILITY_SCANNER_ABORT` env var) |
| `vulnerabilityScannerCmd` | `trivy` | Vulnerability scanner command |
| `vulnerabilityScannerScanners` | `vuln` | Scanner types to run |
| `vulnerabilityScannerSeverity` | `CRITICAL,HIGH` | Severity levels to scan (release builds) |
| `vulnerabilityScannerExitCode` | `0` | Exit code handling for scanner |
| `vulnerabilityScannerFailWithoutFix` | `false` | When `true`, unfixable vulnerabilities also fail the build |

#### Publishing & Repository

| Property | Default | Description |
|----------|---------|-------------|
| `mavenPublishUrl` | `https://ossrh-staging-api.central.sonatype.com/.../maven2` | Release repository URL |
| `mavenSnapshotPublishUrl` | `https://central.sonatype.com/.../maven-snapshots` | Snapshot repository URL |
| `mavenUsername` | — | Maven repository username (see [Sensitive Settings](#sensitive-settings)) |
| `mavenPassword` | — | Maven repository password (see [Sensitive Settings](#sensitive-settings)) |
| `allowMavenCentralRepository` | `true` | Use Maven Central for dependency resolution |
| `allowMavenSnapshotRepository` | `true` | Use snapshot repository for dependency resolution |

---

### All Settings by Category

> This section documents the most commonly used settings. For the complete list of all 700+ properties including Kubernetes OIDC, database init scripts, IDM/Keycloak configuration, Docker advanced tuning, dependency-check report colors, and more, see [`gradle/build-element/base/defaults.gradle`](gradle/build-element/base/defaults.gradle).

#### Framework & Cache

| Property | Default | Description |
|----------|---------|-------------|
| `gradleWrapperDefaultVersion` | `8.13` | Default Gradle wrapper version for new projects |
| `commonGradleBuildCache` | `~/.gradle/common-gradle-build` | Local cache directory |
| `commonGradleBuildCacheLastCheckTimeout` | `43200000` (12h) | Cache freshness timeout in ms |
| `commonGradleBuildReleaseVersion` | `""` | Pin framework to specific version |
| `commonGradleBuildReleasesPreRelease` | `false` | Include pre-release versions |
| `commonGradleBuildCustomConfigName` | `Custom Config` | Display name for custom config |
| `commonGradleBuildHomeGitUrl` | `""` | Git URL for organization config home |
| `commonGradleCacheDynamicDuration` | `600` (release) / `0` (snapshot) | Dynamic version cache duration in seconds |
| `commonGradleCacheChangingModulesDuration` | `0` | Changing modules cache duration in seconds |
| `mainTaskProtectExclusion` | `tasks, help, wrapper, clean, ...` | Tasks excluded from main task protection |
| `duplicatesStrategy` | `exclude` | Gradle duplicate file strategy |
| `onlineCheckConnectionUrl` | `www.google.com` | URL for online connectivity check |
| `onlineCheckConnectionUrlTimeout` | `1500` | Connectivity check timeout in ms |

#### Gradle JVM

| Property | Default | Description |
|----------|---------|-------------|
| `gradlePropertiesJvmArgs` | `-Xmx1g -XX:MaxHeapSize=1g -XX:MaxMetaspaceSize=256m ...` | JVM arguments for Gradle |
| `gradlePropertiesLogLevel` | `quiet` | Gradle log level |
| `gradlePropertiesConsole` | `rich` | Console output mode |
| `gradlePropertiesWarningMode` | `all` | Deprecation warning mode |

#### Project Structure

| Property | Default | Description |
|----------|---------|-------------|
| `projectType` | `java-library` | Explicit project type (normally auto-detected) |
| `licenseOrganisation` | `${rootProject.name}` | Organization name in license/metadata |
| `licenseText` | `MIT License: https://mit-license.org` | License description |
| `licenseUrl` | `https://mit-license.org` | License URL |
| `projectUrl` | `""` | Project homepage URL |
| `configDirectoryName` | `conf` | Configuration directory name |
| `srcDirectoryName` | `src` | Source root directory name |
| `srcMainDirectoryName` | `main` | Main source directory name |
| `srcTestDirectoryName` | `test` | Test source directory name |
| `docsDirectoryName` | `docs` | Documentation directory name |
| `supportMultipleResourceFolder` | `true` | Support multiple resource folders |

#### Project Files

| Property | Default | Description |
|----------|---------|-------------|
| `versionFilename` | `VERSION` | Version file name |
| `readmeFilename` | `README.md` | README file name |
| `licenseFilename` | `LICENSE` | License file name |
| `changelogFilename` | `CHANGELOG.md` | Changelog file name |
| `includeReadmeFile` | `false` | Include README in JAR META-INF |
| `includeLicenseFile` | `true` | Include LICENSE in JAR META-INF |
| `includeVersionFile` | `true` | Include VERSION in JAR META-INF |
| `includeChangelogFile` | `true` | Include CHANGELOG in JAR META-INF |
| `includeGeneratedMetaInfFiles` | `true` | Include generated META-INF files |

#### Project Validation

| Property | Default | Description |
|----------|---------|-------------|
| `projectNameRegularExpressionPattern` | `^[a-zA-Z0-9\-]+$` | Regex for valid project names |
| `projectGroupIdRegularExpressionPattern` | `^[a-zA-Z0-9\.]+$` | Regex for valid group IDs |
| `projectComponentIdIsPartOfProjectName` | `true` | Component ID must be part of project name |
| `projectComponentIdSeparator` | `-` | Separator between name parts |
| `validateRootFiles` | `true` | Warn about unexpected files in project root |
| `validateRootDirectories` | `false` | Warn about unexpected directories in project root |
| `validateProjectNameAndFolder` | `false` | Validate project name matches folder name |
| `projectNameTypeRegularExpressionPattern` | `""` | Additional project-type-specific name validation |
| `allowMultipleSourceFiles` | `true` | Allow multiple source files (false for single-file projects) |

#### Build Initialization Display

| Property | Default | Description |
|----------|---------|-------------|
| `initShowJava` | `true` | Show Java version at build start |
| `initShowGroovy` | `false` | Show Groovy version |
| `initShowRuntime` | `false` | Show runtime info |
| `initShowPath` | `true` | Show project paths |
| `initShowScm` | `true` | Show SCM info |
| `initShowGradle` | `true` | Show Gradle info |
| `initCheckstyle` | `true` | Initialize checkstyle |
| `initEclipse` | `true` | Initialize Eclipse settings |
| `initScmForNewProjects` | `true` | Initialize git for new projects |
| `installGradleWrapper` | `true` | Install Gradle wrapper |
| `showCreatedArtefacts` | `true` | Display artifact info after build |

#### Build Artifacts

| Property | Default | Description |
|----------|---------|-------------|
| `createJar` | `true` | Create main JAR artifact |
| `createSourceJar` | `true` | Create sources JAR artifact |
| `createJavadocJar` | `true` | Create Javadoc JAR artifact |
| `createFatJar` | `false` | Create fat/uber JAR with all dependencies |
| `createCustomJar` | `false` | Create custom JAR (used by kubernetes-product, docker, nodejs) |
| `fatJarPackageType` | `jar` | Fat JAR output format: `jar`, `tgz`, or `jgz` |

#### Compilation

| Property | Default | Description |
|----------|---------|-------------|
| `sourceCompatibility` | *(current JDK)* | Java source compatibility version |
| `targetCompatibility` | *(current JDK)* | Java bytecode target version |
| `fileEncoding` | `UTF-8` | Source file encoding |
| `excelFileEncoding` | `UTF-8` | Excel file encoding for resource bundles |
| `compileJavaFork` | `false` | Fork a separate JVM for compilation |
| `compileJavaHome` | `""` | Custom JDK home for compilation (requires `compileJavaFork=true`) |
| `mainClassName` | `""` | Fully qualified main class for executable JAR (`Main-Class` manifest attribute). Set this to make a java-library JAR executable via `java -jar` |
| `mainClassPath` | `""` | `Class-Path` manifest attribute for executable JAR. Use `auto` to resolve from runtime dependencies, or a space/comma-separated list of JARs (e.g. `lib/foo.jar lib/bar.jar`) |

#### Testing

| Property | Default | Description |
|----------|---------|-------------|
| `initTesting` | `true` | Enable testing initialization |
| `useJUnit` | `true` | Enable JUnit testing |
| `testDependencyVersion` | `5.7.2` | JUnit version (auto-detects JUnit 4 vs 5) |
| `testMinHeapSize` | `128m` | Minimum heap for test JVM |
| `testMaxHeapSize` | `512m` | Maximum heap for test JVM |
| `testEnableDynamicAgentLoading` | `true` | Add `-XX:+EnableDynamicAgentLoading` for JDK 21+ |
| `showStandardStreams` | `false` | Display test stdout/stderr in console |

#### Code Quality

| Property | Default | Description |
|----------|---------|-------------|
| `checkstyleToolVersion` | `10.3.3` | Checkstyle version |
| `checkstyleMaxWarnings` | `0` | Maximum allowed checkstyle warnings before failure |
| `checkstyleHTMLReport` | `true` | Generate HTML checkstyle report |
| `checkstyleXMLReport` | `false` | Generate XML checkstyle report |
| `checkstyleConfigurationFilename` | `checkstyle.xml` | Checkstyle config filename |
| `projectIndividualCheckstyleConfiguration` | `true` | Use project-local checkstyle config (vs. organization-wide) |
| `checkstyleEclipseConfigurationOverwrite` | `true` | Overwrite Eclipse checkstyle config |
| `jacocoToolDefaultVersion` | `0.8.14` | JaCoCo version |
| `jacocoXMLReport` | `true` | Generate XML coverage report (needed for SonarQube) |
| `jacocoHTMLReport` | `true` | Generate HTML coverage report |
| `jacocoCSVReport` | `false` | Generate CSV coverage report |
| `sonarEnabled` | `false` | Enable SonarQube analysis |
| `sonarVersion` | `7.2.3.7755` | SonarQube Gradle plugin version |

#### Dependency Reports

| Property | Default | Description |
|----------|---------|-------------|
| `dependencyTextReport` | `true` | Generate text dependency report |
| `dependencyHTMLReport` | `true` | Generate HTML dependency report |
| `dependenciesReport` | `build/reports/dependencies/dependencies.txt` | Text report output path |
| `dependenciesFile` | `build/reports/dependencies/dependencies.json` | JSON report output path |

#### Release & Versioning

| Property | Default | Description |
|----------|---------|-------------|
| `isReleaseVersion` | `false` | Mark build as release (removes SNAPSHOT qualifier) |
| `tagReleaseVersion` | `true` | Create git tag on release |
| `isReleaseUpdateVersion` | `false` | Version-only update release (e.g., security patches) |
| `tagReleaseUpdateVersion` | `true` | Create git tag on release update |
| `tagIgnoreReleaseUpdateVersionIfNoFilesChanged` | `true` | Skip tag if no files changed |
| `commonGradleBuildSupportSnapshotHandling` | `true` | Enable SNAPSHOT version workflow |
| `commonGradleBuildReleasePublish` | `true` | Publish artifacts during release |
| `commonGradleBuildReleaseBranchName` | `""` | Required branch for release (empty = any branch) |
| `commonGradleBuildValidateReleaseArtefact` | `true` | Validate artifacts before release |
| `copyReleaseArtefactInformation` | `true` | Copy build artifacts to release directory |
| `releaseAddComponentIdIntoReleasePath` | `true` | Include component ID in release path |
| `taskNameBeforeReleaseArtefacts` | `build` | Task that must run before release artifacts |

#### Changelog

| Property | Default | Description |
|----------|---------|-------------|
| `createChangelogFile` | `true` | Auto-create CHANGELOG.md for new projects |
| `validateChangelogFile` | `true` | Validate changelog format on build |
| `changelogUpdateFileAfterRelease` | `true` | Auto-add version entry after release |
| `changelogFailOnSnapshotBuild` | `false` | Fail validation on snapshot builds |
| `changelogSupportUnreleased` | `true` | Allow `[Unreleased]` section |
| `changelogHeaderSeparator` | `-` | Separator character for headers |
| `changelogItemSeparator` | `-` | Separator character for items |
| `changelogSupportBracketsAroundVersion` | `true` | Support `[version]` format |
| `changelogSupportReleaseLink` | `true` | Support release links |
| `changelogSupportReleaseInfo` | `true` | Support release metadata |
| `changelogSupportLinkInDescription` | `true` | Allow links in descriptions |
| `changelogSupportEmptySection` | `false` | Allow empty changelog sections |
| `changelogDefaultType` | `""` | Default change type (e.g., FIXED) |
| `changelogDefaultComment` | `Small bug fixes.` | Default changelog comment |
| `changelogReleaseUpdateType` | `SECURITY` | Change type for release updates |
| `changelogReleaseUpdateComment` | `Security updates.` | Comment for release updates |

#### Publishing & Repository

| Property | Default | Description |
|----------|---------|-------------|
| `mavenPublishUrl` | `https://ossrh-staging-api.central.sonatype.com/.../maven2` | Release repository URL |
| `mavenSnapshotPublishUrl` | `https://central.sonatype.com/.../maven-snapshots` | Snapshot repository URL |
| `mavenUsername` | — | Maven repository username (see [Sensitive Settings](#sensitive-settings)) |
| `mavenPassword` | — | Maven repository password (see [Sensitive Settings](#sensitive-settings)) |
| `allowMavenCentralRepository` | `true` | Use Maven Central |
| `allowGoogleRepository` | `true` | Use Google repository |
| `allowJCenterRepository` | `false` | Use JCenter (Gradle <7 only) |
| `allowMavenRepository` | `false` | Use custom Maven repository |
| `allowMavenStagingRepository` | `false` | Use staging repository |
| `allowMavenSnapshotRepository` | `true` | Use snapshot repository |
| `mavenRepositoryUrl` | `https://oss.sonatype.org/.../public` | Maven repository URL |
| `mavenStagingPublishUrl` | `https://oss.sonatype.org/.../maven2` | Staging publish URL |
| `mavenSnapshotRepositoryUrl` | `https://central.sonatype.com/.../maven-snapshots` | Snapshot repository URL |

#### Container

| Property | Default | Description |
|----------|---------|-------------|
| `containerCmd` | `nerdctl` | Container tool command (`nerdctl` or `docker`) |
| `dockerImage` | *(per project type)* | Base container image |
| `dockerBuildCmd` | `buildx build` | Container build command |
| `dockerBuildPull` | `""` | Pull base image flags (docker: `--pull --force-rm`) |
| `dockerBuildCompress` | `""` | Compress layers flag (docker: `--compress`) |
| `dockerBuildArgs` | `""` | Additional `--build-arg` arguments |
| `dockerName` | `""` | Custom image name (default: `rootProject:version`) |
| `dockerDefaultPort` | `8080` | Default exposed port |
| `dockerUID` | `3000` | Container user ID |
| `dockerGID` | `${dockerUID}` | Container group ID |
| `dockerUser` | `appuser` | Container username |
| `dockerTimezone` | *(system default)* | Container timezone |
| `dockerDefaultEncoding` | `${fileEncoding}` | Container encoding |
| `dockerDefaultLanguage` | `en` | Container language |
| `dockerJavaOptions` | `-Djava.security.egd=file:/dev/./urandom` | JVM options in container |
| `dockerJavaAgent` | `""` | Java agent JAR path |
| `dockerProxyHost` | `""` | HTTP proxy host |
| `dockerProxyPort` | `""` | HTTP proxy port |
| `dockerGc` | `UseG1GC` | JVM garbage collector |
| `dockerExitOnOutOfMemory` | `true` | Exit JVM on OOM |
| `dockerNativeMemoryTracking` | `""` | Native memory tracking mode |
| `dockerObserveMemoryCycle` | `5` | Memory monitoring interval (seconds) |
| `dockerLogLevel` | `""` | Application log level in container |
| `dockerEnableAccessLog` | `false` | Enable HTTP access logging |
| `dockerSupportLatestTag` | `true` | Add `:latest` tag to built image |
| `dockerAddAnnotation` | `false` | Add OCI metadata annotations |
| `dockerMetadataFile` | `build/container-metadata.json` | Build metadata output file |
| `dockerRemoveDanglingImages` | `true` | Clean up dangling images after build |
| `dockerMultistageBuild` | `true` | Use jlink multistage build to create a minimal JRE in the container |
| `dockerJlinkModules` | *(full module list)* | Comma-separated Java modules for `jlink --add-modules`; spaces/tabs stripped automatically |
| `dockerRemoveNonEssentialBinaries` | `false` | Remove non-essential binaries from container (Alpine only; keeps only what entrypoint scripts need) |
| `dockerMakeFilesystemReadonly` | `false` | Make `/etc`, `/usr`, `/lib` read-only in container |
| `dockerReadonlyFilesystemPath` | `"/etc /usr /lib"` | Space-separated paths to make read-only |
| `dockerReadonlyFilesystemExcludePath` | `"/etc/ssl/certs /usr/local/share/ca-certificates $JAVA_HOME/lib/security"` | Paths to keep writable within read-only dirs (Alpine CA certs, Java truststore) |
| `dockerRemoveImageVersion` | `false` | Remove OS version info files from container image |
| `dockerRemovePackageVersions` | `false` | Remove package version information from container image |
| `dockerRemovePackageInstallationBinaries` | `true` | Remove package manager binaries (`apk`) from container image |
| `dockerCleanupAfterBuild` | `false` | Remove image after successful build |
| `dockerCleanupAfterPublish` | `true` | Remove local image after push |
| `buildAlwaysDockerImage` | `false` | Build container image on every build |
| `dockerSubPathAccess` | `""` | URL subpath for container deployment |
| `dockerRepositoryHost` | `""` | Release registry URL |
| `dockerTagPrefix` | `hub.docker.com` | Release image tag prefix |
| `dockerSnapshotRepositoryHost` | `""` | Snapshot registry URL |
| `dockerSnapshotTagPrefix` | `""` | Snapshot image tag prefix |
| `dockerRepositoryUser` | `""` | Registry login username (see [Sensitive Settings](#sensitive-settings)) |
| `dockerRepositoryPassword` | `""` | Registry login password (see [Sensitive Settings](#sensitive-settings)) |
| `dockerSupportProjectTemplateList` | `false` | Restrict which projects can have custom Dockerfiles |
| `createServiceProperties` | `true` | Generate `toolarium-service.properties` |
| `servicePropertiesName` | `toolarium-service.properties` | Service properties filename |

#### Kubernetes

| Property | Default | Description |
|----------|---------|-------------|
| `kubernetesSupport` | `false` | Enable Kubernetes support |
| `kubernetesReplicas` | `2` | Default replica count |
| `kubernetesNamespace` | *(from groupId)* | Kubernetes namespace |
| `kubernetesLabelId` | *(from groupId)* | Label identifier |
| `kubernetesApplicationHost` | `${rootProject.name}.local` | Application hostname |
| `kubernetesUrlPath` | `/api/${rootProject.name}` | Service URL path |
| `kubernetesDocSupport` | `true` | Include AsciiDoctor docs in Kubernetes JAR |
| `kubernetesInstallSupport` | `true` | Generate install scripts |
| `kubernetesProductInformationSupport` | `true` | Generate product information |
| `kubernetesProductFailOnVulnerabilityDependencies` | `false` | When `true`, referenced container image vulnerabilities fail the build |
| `kustomizeSupport` | `true` | Enable kustomize output |
| `kubernetesSupportIngressNginx` | `true` | **Deprecated** — include ingress-nginx controller (archived March 2026, no security updates) |
| `kubernetesIngressNginxVersion` | `1.9.5` | Ingress-nginx version (archived) |
| `kubernetesIngressProxyBufferSize` | `8k` | Nginx proxy buffer size |
| `kubernetesIngressProxyBodySize` | `10m` | Nginx max request body size |
| `kubernetesGatewayApiSupport` | `false` | Enable [Gateway API](https://gateway-api.sigs.k8s.io/) support (modern replacement for Ingress) |
| `kubernetesGatewayClassName` | `nginx` | Gateway class name (`nginx`, `istio`, `envoy`, etc.) |
| `kubernetesGatewayListenerPort` | `80` | Gateway listener port |
| `kubernetesGatewayListenerProtocol` | `HTTP` | Gateway listener protocol |
| `kubernetesSupportDatabase` | `true` | Include database configuration |
| `kubernetesDatabaseHost` | `database` | Database service hostname |
| `kubernetesDatabasePort` | `5432` | Database port |
| `kubernetesDatabaseImage` | `postgres:latest` | Database container image |
| `kubernetesDatabaseStorage` | `100Mi` | Database PVC size |
| `kubernetesDatabaseUsername` | `appuser` | Application database user |
| `kubernetesDatabaseAdminUsername` | `dbadmin` | Database admin user |
| `kubernetesProductConfigMapEnvironmentMaxLength` | `150` | Max env var line length in YAML |

#### Kubernetes Health Probes

Health probe settings follow the pattern `kubernetes{Service}{Probe}{Setting}` for each combination of service type and probe type:

**Service types:** *(no prefix)* (generic), `Quarkus`, `Node`, `Idm`
**Probe types:** `Readiness`, `Liveness`, `Startup`

| Setting suffix | Default (generic) | Description |
|----------------|-------------------|-------------|
| `CheckPath` | *(per service/probe)* | Health check URL path |
| `FailureThreshold` | `3` | Failures before giving up |
| `InitialDelaySeconds` | `0` | Delay before first check |
| `PeriodSeconds` | `10` | Check interval |
| `SuccessThreshold` | `1` | Successes needed to pass |
| `TimeoutSeconds` | `5` | Check timeout |
| `Scheme` | `HTTP` | HTTP or HTTPS |

Example: `kubernetesQuarkusReadinessCheckPath`, `kubernetesNodeLivenessFailureThreshold`, `kubernetesIdmStartupInitialDelaySeconds`

> For the complete list of all Kubernetes health probe properties, see [`gradle/build-element/base/defaults.gradle`](gradle/build-element/base/defaults.gradle).

---

#### Third-Party / Project-Type Specific

#### AsciiDoctor — [asciidoctor.org](https://asciidoctor.org/)

| Property | Default | Description |
|----------|---------|-------------|
| `supportAsciiDoctor` | `true` | Enable AsciiDoctor support (activates when source dir exists) |
| `asciidocDirectoryName` | `doc` | AsciiDoc source directory name under `src/` |
| `asciiDoctorEncoding` | `utf-8` | Document encoding |
| `asciiDoctorPdfTheme` | `theme.yml` | PDF theme filename |
| `asciiDoctorHtmlTheme` | `theme.css` | HTML theme filename |
| `asciiDoctorSourceHighlighter` | `highlight.js` | HTML source highlighter |
| `asciiDoctorPDFSourceHighlighter` | `rouge` | PDF source highlighter |
| `asciiDoctorHighlightJsTheme` | `github` | Highlight.js theme |
| `asciiDoctorRougeStyle` | `github` | Rouge style for PDF |
| `asciiDoctorToc` | `left` | Table of contents position |
| `asciiDoctorTocLevel` | `3` | TOC depth level |
| `asciiDoctorIcons` | `font` | Icon mode |

#### Dependency Check (OWASP) — [owasp.org](https://owasp.org/www-project-dependency-check/)

| Property | Default | Description |
|----------|---------|-------------|
| `dependencyCheckEnabled` | `false` | Enable OWASP dependency-check |
| `toolariumDependencyCheckVersion` | `12.1.8` | Dependency-check plugin version |
| `dependencyCheckFailBuildOnCVSS` | `11` | CVSS score threshold for build failure (7 = standard) |
| `dependencyCheckAutoUpdate` | `true` | Auto-update NVD database |
| `dependencyCheckCveValidForHours` | `12` | CVE database freshness in hours |
| `dependencyCheckFailOnError` | `true` | Fail build on check errors |
| `dependencyCheckReportMaxTextLen` | `72` | Max text length in console report |
| `dependencyCheckReportFilter` | `api, implementation, runtimeOnly, runtimeClasspath` | Configurations to check |

#### Elasticsearch (Kubernetes) — [elastic.co](https://www.elastic.co/elasticsearch)

| Property | Default | Description |
|----------|---------|-------------|
| `esElasticsearchVersion` | `8.8.2` | Elasticsearch version |
| `esElasticsearchClusterName` | `elastic` | Cluster name |
| `esElasticsearchReplicas` | `""` | Replica count |
| `esElasticsearchStorageSize` | `3Gi` | Storage size |
| `esElasticsearchStorageClassName` | `standard` | Storage class |

#### Enum Configuration — [github.com/toolarium](https://github.com/toolarium/toolarium-enum-configuration)

| Property | Default | Description |
|----------|---------|-------------|
| `hasToolariumEnumConfiguration` | `true` | Enable enum configuration support |
| `toolariumEnumConfigurationVersion` | `1.2.0` | Enum configuration library version |
| `enumConfigurationDocAsciidoc` | `true` | Generate AsciiDoc documentation |
| `enumConfigurationDocMarkdown` | `true` | Generate Markdown documentation |
| `enumConfigurationDocOutputPath` | `build/generated/sources/doc` | Documentation output directory |
| `enumConfigurationDocKeyLowercase` | `false` | Convert configuration key names to lowercase in output |
| `enumConfigurationDocGroupLowercase` | `false` | Convert group/class names to lowercase in output |
| `enumConfigurationDocProductLabel` | `${rootProject.name}` | Label shown in HTML sidebar and PDF header |
| `enumConfigurationDocIncludeInJar` | `true` | Include generated docs (PDF, Markdown) in kubernetes JAR |
| `enumConfigurationDocCustomerKeys` | `""` | Comma-separated `configName#KEY` entries flagged as customer-responsible (C) |
| `enumConfigurationDocProvisionedKeys` | `""` | Comma-separated `configName#KEY` entries flagged as provisioned (P) |

#### Java Application (Shadow JAR) — [github.com/GradleUp/shadow](https://github.com/GradleUp/shadow)

| Property | Default | Description |
|----------|---------|-------------|
| `javaApplicationShadowClassifier` | `""` | Shadow JAR classifier (empty = replace main JAR) |

#### Node.js — [nodejs.org](https://nodejs.org/)

| Property | Default | Description |
|----------|---------|-------------|
| `nodePluginVersion` | `7.1.0` | gradle-node-plugin version |
| `nodeFundMessage` | `false` | Show npm fund messages |
| `nodeRegistry` | `https://registry.npmjs.org/` | NPM registry URL |
| `webServerRunnerVersion` | `1.2.7` | Embedded toolarium-jwebserver version |
| `webServerRunnerPropertiesName` | `jwebserver.properties` | Web server config filename |
| `resolveParentResourceIfNotFound` | `""` | Resolve parent resource when not found (SPA routing) |

#### OpenAPI — [openapi-generator.tech](https://openapi-generator.tech/)

| Property | Default | Description |
|----------|---------|-------------|
| `openapiPluginVersion` | `7.2.0` | OpenAPI Generator plugin version |
| `openapiGeneratorName` | `jaxrs-spec` | Generator type |
| `openapiLibrary` | `quarkus` | Target library |
| `openapiUseJakartaEe` | `true` | Use Jakarta EE instead of javax |
| `openapiInterfaceOnly` | `true` | Generate interfaces only (no implementation) |
| `openapiReturnResponse` | `true` | Return Response objects |
| `openapiUseBeanValidation` | `false` | Enable bean validation annotations |
| `openapiDocs` | `true` | Generate API documentation |
| `openapiTests` | `true` | Generate test stubs |
| `openapiDateLibrary` | `java8` | Date library (`java8` or `legacy`) |
| `openapiSerializableModel` | `true` | Make models serializable |
| `openapiUpdateFileAfterRelease` | `true` | Update spec version after release |

#### Quarkus — [quarkus.io](https://quarkus.io/)

| Property | Default | Description |
|----------|---------|-------------|
| `defaultQuarkusPluginVersion` | `3.20.6` | Quarkus plugin version (controls auto-update) |
| `quarkusPluginVersion` | `${defaultQuarkusPluginVersion}` | Actual Quarkus version used |
| `quarkusReleaseUpdateVersion` | `true` | Auto-update Quarkus version on release |
| `quarkusPlatformGroupId` | `io.quarkus` | Quarkus BOM group ID |
| `quarkusAppJar` | `quarkus-run.jar` | Quarkus application JAR name |
| `quarkusAppSubPathName` | `app` | Sub-path for Quarkus app |
| `updateApplicationProperties` | `true` | Strip test/dev profiles from app properties |
| `createServiceJavaRunner` | `true` | Generate toolarium-java-runner.sh for container |
| `createServiceJavaAgent` | `false` | Include Java agent in container |
| `enablePatchRunTimeDefaultsConfigSource` | `false` | Patch RunTimeDefaultsConfigSource class |

#### Vulnerability Scanner (Trivy) — [trivy.dev](https://trivy.dev/)

| Property | Default | Description |
|----------|---------|-------------|
| `vulnerabilityScannerEnabled` | `false` | Enable Trivy vulnerability scanning (also overridable via `CB_VULNERABILITY_SCANNER_ENABLED` env var) |
| `vulnerabilityScannerAbortEnabled` | `true` | When `false`, findings are reported as warnings without failing the build (also overridable via `CB_VULNERABILITY_SCANNER_ABORT` env var) |
| `vulnerabilityScannerCmd` | `trivy` | Vulnerability scanner command |
| `vulnerabilityScannerScanners` | `vuln` | Scanner types to run |
| `vulnerabilityScannerSeverity` | `CRITICAL,HIGH` | Severity levels to scan (release builds) |
| `vulnerabilityScannerExitCode` | `0` | Exit code handling for scanner |
| `vulnerabilityScannerFailWithoutFix` | `false` | When `true`, vulnerabilities without a fix also fail the build. When `false` (default), unfixable findings are reported but don't fail |

---

## Architecture

### Entry Point

`gradle/common.gradle` bootstraps the framework: initializes logging with ANSI color support, reads the git project URL, resolves cache/home paths with URL-based organization routing, auto-detects the project type from directory structure, and applies the matching build script.

### Build Elements

Modular, composable Gradle script fragments in `gradle/build-element/`:

- **base/** — core utilities: logging (`logger.gradle`), ANSI colors (`ansi-support.gradle`, `constants.gradle`), properties (`defaults.gradle`, `properties.gradle`), versioning (`version.gradle`), release (`release.gradle`), security (`security.gradle`), dependencies (`dependencies.gradle`, `dependency-check.gradle`, `dependencies-json.gradle`), vulnerability scanning (`vulnerability-scanner.gradle`), SonarQube (`sonar.gradle`), exec (`exec.gradle`), file operations (`file.gradle`, `propertyreplacement.gradle`), JSON (`json.gradle`), changelog (`changelog.gradle`), Kubernetes (`kubernetes.gradle`), container (`container.gradle`), enum configuration (`enumconfiguration.gradle`), webjar (`webjar.gradle`), init (`init.gradle`, `initialisation.gradle`), scripts (`scripts.gradle`)
- **java/** — compilation (`java.gradle`, `javaversion.gradle`), testing (`test.gradle`), coverage (`testcoverage.gradle`), Javadoc (`javadoc.gradle`), Checkstyle (`checkstyle.gradle`), Eclipse (`eclipse.gradle`), repository (`repository.gradle`, `supported-repositories.gradle`), publication (`publication.gradle`), signing (`signing.gradle`)
- **scm/** — Git integration (`git.gradle`) via grgit
- **doc/** — AsciiDoctor (`asciidoctor-support.gradle`), enum configuration documentation (`enumconfiguration.gradle`)
- **config/** — Configuration publication (`publication.gradle`)
- Aggregators: `base.gradle`, `java-base.gradle`, `language-base.gradle`, `nodejs.gradle`

### Templates

`gradle/template/` contains 85+ scaffolding templates organized by project type (base, java, java-application, quarkus, openapi, nodejs, kubernetes, docker, documentation, scm, checkstyle, eclipse).

### Local Data

The framework stores data under the Gradle home directory (overridable via [Environment Variables](#environment-variables)):

| Directory | Override | Purpose |
|-----------|----------|---------|
| `~/.gradle/common-gradle-build/` | `COMMON_GRADLE_BUILD_CACHE` | Cached framework scripts, version tracking (`lastCheck.properties`) |
| `~/.gradle/common-gradle-build-releases/` | `COMMON_GRADLE_BUILD_HOME` | Release build artifacts and information (only for non-snapshot releases) |
| `~/.gradle/dependency-check-data/` | — | OWASP dependency-check NVD database (when `dependencyCheckEnabled=true`) |

On Windows, `~` corresponds to `%USERPROFILE%` (e.g. `C:\Users\<name>\.gradle\...`).

## Sensitive Settings

The following properties contain credentials or secrets and **must not** be placed in your project's `gradle.properties` (which is typically committed to version control). Define them in your user-level Gradle properties file instead:

- **Linux/Mac:** `~/.gradle/gradle.properties`
- **Windows:** `%USERPROFILE%\.gradle\gradle.properties`

```properties
# Maven / Sonatype publishing credentials
sonatypeUsername=your-username
sonatypePassword=your-password
# or directly:
mavenUsername=your-username
mavenPassword=your-password

# GPG signing
signing.keyId=AABBCCDD
signing.password=your-gpg-passphrase
signing.secretKeyRingFile=/path/to/secring.gpg

# Docker / container registry
dockerRepositoryUser=your-registry-user
dockerRepositoryPassword=your-registry-password

# SonarQube
sonarHostUrl=https://your-sonar-server.com
sonarToken=sqa_your-token
```

| Property | Purpose |
|----------|---------|
| `sonatypeUsername` / `mavenUsername` | Maven repository username |
| `sonatypePassword` / `mavenPassword` | Maven repository password |
| `signing.keyId` | GPG key ID for artifact signing |
| `signing.password` | GPG private key passphrase |
| `signing.secretKeyRingFile` | Path to GPG secret key ring file |
| `dockerRepositoryUser` | Container registry username |
| `dockerRepositoryPassword` | Container registry password |
| `sonarHostUrl` | SonarQube server URL |
| `sonarToken` | SonarQube authentication token |

> **Note:** Git credentials (`GRGIT_USER`, `GRGIT_PASS`) are passed as environment variables, not Gradle properties — see the [Environment Variables](#environment-variables) table.

## Organization-Specific Overrides

Organization-specific overrides allow different teams or companies to share the same common-gradle-build framework with their own default settings, custom tasks, and configuration files.

### How It Works

On every build, the framework resolves an organization-specific **home directory** that can contain override files. The resolution follows this priority:

1. **Environment variable `COMMON_GRADLE_BUILD_HOME`** — if set, used directly (skips all routing)
2. **URL-based routing via `.cb-custom-config`** — matches the project's git remote URL to select the right config
3. **Default fallback** — `~/.gradle/common-gradle-build-home/`

### Setting Up `.cb-custom-config`

Create the routing file at:
- **Linux/Mac:** `~/.common-build/conf/.cb-custom-config`
- **Windows:** `%USERPROFILE%\.common-build\conf\.cb-custom-config`

The file contains `KEY=URL-PATTERN` entries. The framework reads the current project's git remote URL and matches it against the patterns using **prefix matching** (longest match wins):

```properties
# ~/.common-build/conf/.cb-custom-config
acme-corp=https://github.com/acme-corp/
xyz-ltd=https://github.com/xyz-ltd/
```

When building a project with remote `https://github.com/acme-corp/my-service.git`, the `acme-corp` entry matches. The framework then resolves the home directory from the URL:

```
Host:  github.com
Port:  443 (HTTPS default)
Path:  /acme-corp/ → _acme-corp

Result: ~/.common-build/conf/github.com@443_acme-corp/
```

### Home Directory Structure

Once the home directory is resolved, the framework looks for these files:

```
~/.common-build/conf/github.com@443_acme-corp/
├── gradle/
│   ├── defaults.gradle               # Override framework default properties
│   ├── dependency-management.gradle  # Override dependency resolution strategies
│   └── custom.gradle                 # Add custom tasks and build extensions
├── conf/                      # Configuration files (checkstyle, security keys, etc.)
└── lastCheck.properties       # Auto-generated version tracking
```

**`gradle/defaults.gradle`** — loaded **before** framework defaults, so properties set here take precedence. Use `setCommonGradleProperty()` to override any setting from the [Configuration Reference](#configuration-reference):

```groovy
// Organization-wide defaults
setCommonGradleProperty("licenseOrganisation", "ACME Corporation")
setCommonGradleProperty("sourceCompatibility", JavaVersion.VERSION_21)
setCommonGradleProperty("targetCompatibility", JavaVersion.VERSION_21)
setCommonGradleProperty("mavenPublishUrl", "https://nexus.acme.internal/repository/releases/")
setCommonGradleProperty("dockerTagPrefix", "registry.acme.internal")
```

**`gradle/dependency-management.gradle`** — loaded **after** `defaults.gradle`, applied before the rest of the build. Use this to define organization-wide dependency resolution rules such as forced versions, resolution strategies, and BOM imports:

```groovy
// Pin a transitive dependency to a known-safe version
configurations.all {
    resolutionStrategy {
        force 'com.example:my-library:1.2.3'
    }
}

// Import an organization BOM
dependencies {
    implementation platform('com.acme:acme-bom:2.0.0')
}
```

**`gradle/custom.gradle`** — loaded **after** the project type is applied. Use this for custom tasks or build extensions:

```groovy
// Organization-specific custom tasks
task complianceReport {
    doLast {
        println "Running ACME compliance checks..."
    }
}
```

### Remote Configuration via Git

Instead of manually setting up the home directory, you can host your organization configuration in a Git repository and have it automatically downloaded and cached:

| Property | Default | Description |
|----------|---------|-------------|
| `commonGradleBuildHomeGitUrl` | `""` | Git repository URL containing organization config |
| `commonGradleBuildHomeVersionFileUrl` | `""` | URL to VERSION file for version tracking (auto-derived from git URL if empty) |
| `commonGradleBuildCustomConfigName` | `Custom Config` | Display name for logging |

The framework caches each version in a separate subdirectory under the home base path and re-checks for updates based on `commonGradleBuildCacheLastCheckTimeout` (default: 12 hours). Pin a specific version with the `CB_CUSTOM_CONFIG_VERSION` environment variable.

### Creating an Organization Config Project

Use the `organization-config` project type to scaffold a new configuration repository:

```groovy
// build.gradle
projectType = 'organization-config'
apply from: "https://raw.githubusercontent.com/toolarium/common-gradle-build/master/gradle/common.gradle"
```

This generates the directory structure with template `defaults.gradle`, `dependency-management.gradle`, and `custom.gradle` files ready to customize.

### Overriding Templates

Templates can also be overridden by placing custom versions in the home directory's `gradle/template/` folder. The framework checks the home directory first before falling back to the built-in templates. See the full [Template Reference](docs/TEMPLATES.md) for all available templates.

For example, to override the Dockerfile template for Quarkus projects across your organization:

```
~/.common-build/conf/github.com@443_acme-corp/
└── gradle/
    └── template/
        └── quarkus/
            └── Dockerfile.template    # Your custom Dockerfile
```

### Property Override Priority

```
Highest:  gradle.properties / -P command line (project-specific)
          ↓
          Home gradle/defaults.gradle (organization-wide via setCommonGradleProperty)
          ↓
          Framework defaults.gradle (via setCommonGradleDefaultPropertyIfNull)
Lowest:   Built-in framework defaults
```

> **Dependency resolution** follows a separate but analogous order: the built-in `dependency-management.gradle` runs first, then the home `gradle/dependency-management.gradle` (if present) is applied on top, allowing organizations to add or override forced versions, resolution strategies, and BOM imports.

## Local Development

To test framework changes locally, point a consumer project at your local checkout:

```bash
export COMMON_GRADLE_BUILD_URL="file:///path/to/common-gradle-build/gradle"
cd /path/to/consumer-project
gradle build
```

### Logging Functions

The framework provides these logging functions for use in gradle scripts:

| Function | Visibility | Color | Use Case |
|----------|-----------|-------|----------|
| `logDebug(message)` | Only with `-d` flag | Light pink | Detailed diagnostic information |
| `logInfo(message)` | Gradle info level | Light lavender | Informational messages in build logs |
| `printInfo(message)` | Always visible | Plain text | User-visible status messages |
| `printWarn(message)` | Always visible | Yellow | Warnings that don't fail the build |
| `printLine(color, force)` | Conditional | Configurable | Visual separator lines (120 chars) |

### Error Handling & Build Failure

The framework uses a **deferred error collection** pattern — errors are accumulated during the build and reported at the end:

```groovy
// Add an error (does NOT throw immediately)
addError("Dependency version mismatch: expected 1.2.x, found 1.3.0")

// Multiple errors can be accumulated
addError("Changelog validation failed")
addError("Blacklisted dependency found: log4j:1.2.17")
```

`addError()` sets `validBuild = false` and appends the message to `validBuildMessage`. At build completion, the `gradle.buildFinished` hook checks `validBuild` — if false, it prints all accumulated errors in a formatted error box and throws a `GradleException` to fail the build.

Many tasks guard execution with `onlyIf { return validBuild }` so they skip gracefully after an error is recorded.

### Property Setter Pattern

| Function | Overwrites existing? | Use Case |
|----------|---------------------|----------|
| `setCommonGradleDefaultPropertyIfNull(name, value)` | No — skips if property already exists | Framework defaults in `defaults.gradle` |
| `setCommonGradleProperty(name, value)` | Yes — always sets | Organization overrides, runtime updates |
| `addCommonGradlePropertyList(name, value)` | Appends with `, ` separator | Accumulating lists (allowed files, errors) |

### Task Dependency Graph

The diagram below shows the major task flow and conditional branches:

```
                          gradle build (default)
                          ══════════════════════
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
                 clean    projectValidation    build
                             │                   │
                  ┌──────────┤              ┌────┼────────────────────┐
                  ▼          ▼              ▼    ▼                    ▼
             initScm   validateProject     jar  test            createResourceBundle
                       (name, groupId,      │    │
                        root files)         │    ▼
                                            │  jacocoTestReport
                                            │    │
                                    ┌───────┼────┼───────┐
                                    ▼       ▼    ▼       ▼
                              sourcesJar javadocJar checkstyleMain
                                                         │
                             ┌───────────────────────────┘
                             ▼
                      verifyDependencies
                      dependencyReport

                    ═══ Conditional Tasks ═══

         if buildAlwaysDockerImage
           build ──finalizedBy──▶ dockerBuild

         if vulnerabilityScannerEnabled
           build ──finalizedBy──▶ vulnerabilityScanner

         if sonarEnabled
           build ──▶ sonar

         if supportAsciiDoctor && src/doc/ exists
           build ──▶ convertAsciidoctorHtml/Pdf


                       dockerBuild
                       ═══════════
                   [onlyIf: validBuild]
                             │
                      ┌──────┴──────┐
                      ▼             ▼
                 dockerRun     dockerPush
                           (login, tag, push)
                                    │
                                    ▼
                          vulnerabilityScanner
                          (trivy image scan)

                       gradle release
                       ══════════════
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
    checkReleaseCredentials  │  checkValidReleaseEnvironment
              │              │              │
              └──────────────┼──────────────┘
                             ▼
                      releasePrepare
                      (set version, validate artifacts)
                             │
                             ▼
                           build
                   (full build with release version)
                             │
                             ▼
                    releaseVerification
                    [onlyIf: validBuild]
                    (git branch, tag, merge, push)
                             │
                             ▼
                      publishRelease
                      (Maven publish)
```

## Shell Script Compatibility

All shell scripts in this framework are POSIX-compatible and run on both bash and Alpine/BusyBox ash:
- `#!/bin/sh` shebang with POSIX-only syntax
- No bash-isms (`[[ ]]`, arrays, process substitution)
- Quoted variable expansions to prevent word splitting
- `grep -F` with `--` separator for patterns starting with `-`

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
