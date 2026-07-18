# common-gradle-build

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.5.4] - 2026-07-18
### Fixed
- Build log output on kubernetes product and container based builds.

## [v1.5.3] - 2026-06-29
### Fixed
- Update Dokcefile.template for node based containers, support cache-control.
- Changelog parser dependency.

## [v1.5.2] - 2026-05-15
### Added
- Generated AsciiDoc files automatically included in AsciiDoctor HTML/PDF processing via staging copy into `src/doc/` during build
- Generated documentation (PDF and Markdown) included in kubernetes JAR under `docs/` folder (controlled by `enumConfigurationDocIncludeInJar`)
- Enum configuration documentation generator (`gradle/build-element/doc/enumconfiguration.gradle`): generates professional AsciiDoc and Markdown documentation from toolarium-enum-configuration JSON data with Overview, Mandatory Configurations, and Services chapters
- Configuration documentation split by marker interface: services with marker interfaces get separate files
- `mainClassName` property: sets `Main-Class` manifest attribute in JAR, making java-library projects executable via `java -jar`
- `mainClassPath` property: sets `Class-Path` manifest attribute; supports `auto` (resolves from `runtimeClasspath` dependencies) or explicit space/comma-separated list of JARs

### Changed
- AsciiDoctor theme templates updated: reduced font sizes for PDF (base 9pt, tables 8pt), compact table cell padding, professional admonition block styling with colored left borders, hidden default HTML footer via CSS

### Fixed
- Vulnerability scanner: trivy non-zero exit code without findings no longer fails the build (now logs a warning instead)
- Vulnerability scanner: blacklisted dependency checks are now evaluated even when trivy produces no output

## [v1.5.1] - 2026-04-26
### Fixed
- `github.gradle`: release download now prefers uploaded release assets (`.zip`) over GitHub's auto-generated zipball, which included `.github/`, `test/`, `CLAUDE.md` and other excluded files in the cached framework
- Shell script git permissions set to executable (`100755`)

## [v1.5.0] - 2026-04-18
### Added
- New `vulnerability-scanner.gradle` (510 lines): integrated [Trivy](https://trivy.dev/) scanning for dependencies (`trivy rootfs`) and container images (`trivy image`); severity levels DENY/CRIT/HIGH/MED/LOW; snapshot builds scan all severities without failing, release builds fail on DENY/CRIT/HIGH; dependency tree resolution showing which top-level `build.gradle` dependency to update; integrates with whitelist/blacklist properties files
- New `toolarium-java-runner.sh.template` (417 lines): replaces `java-runner.sh` — now a `.template` with placeholder support, JVM memory auto-tuning, GC configuration (`UseG1GC` default), native memory tracking, graceful startup, and configurable logging
- `toolarium-java-runner.sh.template`: `--port` parameter to set Quarkus HTTP port at runtime; `printWrapped` function for word-wrapping long output lines; `TESTCASE` env var support
- New `cb-meminfo.sh` (249 lines): memory monitoring script for container JVM diagnostics with configurable observation cycle
- New `Dockerfile-java-runner-multistage.template` (156 lines): multistage build Dockerfile — compiles with JDK image, runs on minimal Alpine runtime image; controlled by `dockerMultistageBuild` property (default: `true`)
- Container hardening across all Dockerfile templates: removal of setuid/setgid binaries, cron, unnecessary system accounts, docs/man pages, version information, and apk package manager
- Read-only filesystem support in containers: `dockerMakeFilesystemReadonly` (default: `true`), `dockerReadonlyFilesystemPath` (default: `/etc /usr /lib`), `dockerReadonlyFilesystemExcludePath` (Alpine CA certs, Java truststore)
- Non-essential binary removal in containers: `dockerRemoveNonEssentialBinaries` (default: `true`)
- `EXPOSE_PORT` environment variable now set consistently across all 8 Dockerfile templates; runtime-effective port changes via entrypoint scripts (nginx) and `-Dquarkus.http.port` (Quarkus)
- `dockerEntrypoint` property for configurable container entrypoints in `Dockerfile-node.template`
- New testing project type (`testing.gradle`): Playwright end-to-end testing with `src/main/ts/tests/` source layout, `build/` output, environment URL mapping (`ENV_NAME`: local/int/acpt/prod), `TESTCASE` env var, `BASE_URL` support, container-based test execution
- Testing project templates: `package.json.template`, `playwright.config.ts.template`, `tests/example.spec.ts.template`
- Git cleanup of disallowed tracked files: `cleanupDisallowedTrackedFiles()` and `removeFromGitCache()` functions in `git.gradle`; automatically removes `build/`, `.gradle/`, `.idea/`, `.vscode/`, `.settings/`, `.claude/`, `.classpath`, `.project` from git index on snapshot builds and appends them to `.gitignore`; controlled by `gitCleanupDisallowedFiles` property and `CB_DISABLE_GIT_CLEANUP` environment variable
- 256-color ANSI support in `constants.gradle`: `bg_dark_red`, `bg_dark_green`, `light_lavender`, `light_pink`, `bright_white` color entries; new `ERROR_LINE_LEVEL` (red foreground for separator lines) and `SUCCESS_HINT_LEVEL` (dark green background) color levels
- Dependency version expression support for colon-separated keys (`group:name`) in `getVersionExpression()` in `dependencies.gradle`
- Custom properties file parser in `file.gradle` `readPropertiesFile()`: only treats `=` as key-value separator (not `:`) to support `group:name` keys in whitelist/blacklist files
- Shell script test suites: `toolarium-java-runner-test.sh` (83 tests), `cb-meminfo-test.sh` (60 tests), `apply-subpath-test.sh` (89 tests)
- GitHub Actions CI workflows: `cgb-test.yml` (test pipeline) and `cgb-release.yml` (release pipeline)
- Sonatype Central Portal: `finalizeOssrhUpload()` function in `release.gradle` for OSSRH Staging API finalization POST; `mavenPublishFinalizeUrl` property
- Vulnerability scanner: `[container]` tag support in whitelist/blacklist properties for container image version matching (e.g. `[container]registry.k8s.io/ingress-nginx/controller = 1.15.1`)
- Vulnerability scanner: referenced container image scanning for kubernetes-product projects via `kubernetesDockerReferenceFile` with summary table output; optional `cb-container --scan --csv` optimization
- `kubernetesProductFailOnVulnerabilityDependencies` property (default: `false`) — controls whether referenced container image vulnerabilities fail the build
- `kubernetesDockerReferenceFile` property for configurable docker reference file path
- `kubernetesIngressNginxDeprecationWarning` property (default: `true`) — controls ingress-nginx deprecation warning visibility
- Comprehensive `README.md` rewrite with full configuration reference, architecture overview, and task dependency graph
- `docs/index.html` and `docs/templates.html`/`docs/templates.md` documentation pages

### Changed
- `defaultQuarkusPluginVersion` updated from `3.20.4` to `3.20.6`
- `dockerJavaRunner` default changed from `java-runner.sh` to `toolarium-java-runner.sh`
- `INFO_LEVEL` changed from `magenta` to `light_lavender` (256-color: `38;5;147`); `DEBUG_LEVEL` changed from `magenta` to `light_pink` (256-color: `38;5;183`); `ERROR_LEVEL` changed from `red` foreground to `bg_dark_red` (dark red background with bold bright white text)
- `MAX_LINELENGTH` increased from `88` to `120`; `LINE` and `STAR_LINE` constants extended to match; new `DOT_LINE` constant
- Error separator lines now use `ERROR_LINE_LEVEL` (red foreground) instead of `ERROR_LEVEL` (background color) across `base.gradle`, `signing.gradle`, `initialisation.gradle`, `git.gradle`
- Enum configuration dependency changed from `implementation` to `annotationProcessor` + `compileOnly` in both `java-library.gradle` and `quarkus.gradle`
- Sonatype publishing URLs migrated from `oss.sonatype.org` to `ossrh-staging-api.central.sonatype.com` (releases) and `central.sonatype.com` (snapshots); `mavenRepositoryUrl` changed to `repo1.maven.org/maven2`
- `signing.gradle`: signing `required` block simplified to pure boolean predicate for Gradle 8.13 compatibility; credential validation moved to `gradle.taskGraph.whenReady`
- `Dockerfile-node.template`: `ENTRYPOINT` now uses `@@dockerEntrypoint@@` placeholder instead of hardcoded `npm start`
- `project-types.properties`: testing project type updated for Playwright with `npx --yes create-playwright`
- Quarkus docker image logic moved after `defaults.gradle` is loaded to allow organization overrides of `dockerMultistageBuild`
- Version updates: `jacocoToolDefaultVersion` `0.8.9` → `0.8.14`, `sonarVersion` `4.4.1.3373` → `7.2.3.7755`, `checkstyleToolVersion` `10.3.3` → `13.4.0`, `snakeYamlVersion` `1.29` → `2.3`, `grgitCoreVersion` `4.1.1` → `5.3.2`, `commonGradleJacksonAnnotationVersion` `2.15.3` → `2.19.4`, `kubernetesIdmImageVersion` `23.0.3` → `26.6.1`, `defaultOpenapiPluginVersion` `7.2.0` → `7.12.0`, `testDependencyVersion` `5.7.2` → `5.12.2`, `esElasticsearchVersion` `8.8.2` → `9.3.3`, `kubernetesIngressNginxVersion` `1.9.5` → `1.15.1` (final release)
- `kubernetesIngressNginxVersion` updated from `1.9.5` to `1.15.1` (final release); template updated: `k8s.gcr.io` → `registry.k8s.io`, controller `v1.1.1` → `v1.15.1`, certgen `v1.1.1` → `v1.6.9`, enhanced security contexts, `coordination.k8s.io` and `discovery.k8s.io` RBAC rules
- `grgitCoreVersion` 4.x → 5.x: removed deprecated `Credentials` class usage from `git.gradle`; credentials now via `GRGIT_USER`/`GRGIT_PASS` environment variables only
- `sonar.gradle`: replaced deprecated `sonar.jacoco.reportPath` and `sonar.java.coveragePlugin` with `sonar.coverage.jacoco.xmlReportPaths`; updated `sonar.junit.reportPath` to `sonar.junit.reportPaths`
- `testcoverage.gradle`: JaCoCo XML report output location set explicitly for SonarQube integration
- Checkstyle template: added `HexLiteralCase`, `MissingOverrideOnRecordAccessor`, `NoWhitespaceBeforeCaseDefaultColon`, `ConstructorsDeclarationGrouping`, `InvalidJavadocPosition`, `RequireEmptyLineBeforeBlockTagGroup`, `LambdaParameterName`, `PatternVariableName`, `RecordComponentName`
- `kubernetesSupportIngressNginx` marked as deprecated (ingress-nginx archived March 2026); deprecation warning printed during build
- New Gateway API support: `kubernetesGatewayApiSupport` property, `kubernetes-gateway.template` and `kubernetes-httproute.template`, portable HTTPRoute routing rules for any Gateway API implementation (NGINX Gateway Fabric, Envoy Gateway, Istio, Contour, Traefik)
- `kubernetesConcat`: ingress-nginx webhook cleanup only when ingress-nginx is enabled; Gateway API files included in concatenated YAML and kustomize output

### Removed
- `java-runner.sh` (337 lines) — replaced by `toolarium-java-runner.sh.template`

## [v1.4.8] - 2026-02-26
### Changed
- Version bump from 1.4.6 to 1.4.8 (code changes were already in v1.4.7)

## [v1.4.7] - 2026-02-26
### Added
- `buildServiceProperties()` in `base.gradle` now supports a `servicesProperties` property: a comma-separated list of custom key=value entries appended to the service properties file as `service.<entry>`

## [v1.4.6] - 2026-02-24
### Added
- New `targetFatJar` task (type: `Tar`) in `webjar.gradle` for creating `.tgz` fat jar packages when `fatJarPackageType` is not `jar`; registers the tgz as a build artifact
- Kubernetes `startupProbe` sections added to three Kubernetes YAML templates (`kubernetes.yaml.template`, `nodejs/kubernetes.yaml.template`, `quarkus/kubernetes.yaml.template`) with placeholders for failure threshold, check path, port, scheme, initial delay, period, success threshold, and timeout

### Changed
- `publication.gradle`: when `createCustomJar` is true and `fatJarPackageType` is not `jar`, publishes the `targetFatJar` artifact instead of `customJar`
- `kubernetes-product.gradle`: moved `apply from: publication.gradle` after `webjar.gradle` to ensure `targetFatJar` task is defined before publication references it
- Log messages: "Created fat-jar package" changed to "Created app package", "Create java fat-jar" changed to "Create app"
- `java-base.gradle`: fixed comment header from `java-library.gradle` to `java-base.gradle`

## [v1.4.5] - 2025-12-09
### Fixed
- `defaults.gradle`: removed extra closing parenthesis on `kubernetesIdmStartupCheckPath` line that caused a syntax error

## [v1.4.4] - 2025-12-09
### Changed
- `defaultQuarkusPluginVersion` updated from `3.20.3` to `3.20.4`
- Kubernetes Quarkus probe defaults now use hardcoded values instead of inheriting from generic kubernetes properties (e.g. `kubernetesQuarkusStartupCheckPath` now uses `.../q/health/started`, failure threshold `60`, period `10s`)
- Kubernetes IDM health check paths changed from realm-based to health endpoints (`/health/ready`, `/health/live`, `/health/started`)
- `kubernetes.gradle`: application secret template is now always generated (removed conditional check for `kubernetesApplicationOIDCPublicKey`)
- `project-types.properties`: nuxtjs init command changed from `npx --yes nuxi init` to `npm --yes create nuxt`

## [v1.4.3] - 2025-11-18

### Added
- New `documentation` project type (`gradle/documentation.gradle`) with full AsciiDoctor HTML+PDF generation, `customJar` task packaging docs into a jar, and repository/signing/publication support
- New templates: `documentation/build.gradle.template`, `documentation.adoc.template`, `documentation/gradle.properties.template`
- `calculateDirectorySize()` function added to `file.gradle` for recursive directory size calculation
- New `fatJarPackageType` property (default: `jar`) in `defaults.gradle`

### Changed
- `buildFatJar()` in `base.gradle` now supports both `jar` and `tgz`/`jgz` output formats via `ant.tar` with gzip compression; shows file size in MB in log output
- `toolariumDependencyCheckVersion` updated from `12.0.1` to `12.1.8`
- `container.gradle`: `dockerBuildCmd` set to `build` (instead of `buildx build`) when nerdctl is detected; `--metadata-file` flag disabled

### Fixed
- Typo fix: "got to" changed to "go to" across 9 project type gradle files

## [v1.4.2] - 2025-10-20

### Fixed
- `apply-subpath.sh.template`: removed accidentally pasted Dockerfile content (`RUN chgrp -R root /deployment...`) that was concatenated to the nginx redirect block generation, breaking the shell script

## [v1.4.1] - 2025-09-30

### Changed
- `asciidoctor-support.gradle`: commented out many hardcoded Asciidoctor attributes so documents can define their own values; only `imagesdir`, `organization`, `copyright`, `encoding`, `stylesheet`/`pdf-theme` remain set
- Added `docdate`, `doctime`, and `revdate` attributes to both HTML and PDF tasks (formatted as `dd.MM.yyyy`)
- `asciidoctor-theme.css.template`: added `#footer` styling with gradient background, white text, border-radius
- `asciidoctor-theme.yml.template`: changed `extends` from `default` to `default-with-fallback-font`, changed page margins from inches to centimeters, removed explicit font families

## [v1.4.0] - 2025-09-29

### Added
- New `asciidoctor-theme.css.template` (507 lines): full HTML theme with CSS custom properties, gradient header, responsive design, print styles, admonition/TOC styling
- New `asciidoctor-theme.yml.template` (205 lines): full PDF theme with branded colors, typography, heading styles, table formatting, code block styling
- Auto-creation of `images/`, `themes/` directories and theme files from templates
- `kubernetesDocSupport` property (default: `true`) — when enabled, includes AsciiDoctor PDF output in Kubernetes jar
- `nuxtjs.gradle`: added `app`, `content`, `shared` to allowed main directories

### Changed
- AsciiDoctor support module renamed from `gradle/build-element/docs/` to `gradle/build-element/doc/`
- `asciidocDirectoryName` default changed from `asciidoc` to `doc`
- `asciidocSourceDirectory` changed from `${docsDirectory}/${asciidocDirectoryName}` to `${srcDirectory}/${asciidocDirectoryName}`
- `asciidocOutputDirectory` changed from `${reportsPath}/${asciidocDirectoryName}` to `${buildDir}/docs/asciidoc`
- `defaultQuarkusPluginVersion` updated from `3.20.0` to `3.20.3`
- `dockerAddAnnotation` default changed from `true` to `false`
- `README.md`: replaced `git.io/JfDQT` short URLs with full `raw.githubusercontent.com` URLs
- `project-types.properties`: Nuxt label changed from `Nuxt3.js` to `Nuxt`

## [v1.3.10] - 2025-08-04

### Added
- AsciiDoctor integration: new `gradle/build-element/docs/asciidoctor-support.gradle` (178 lines) with HTML and PDF generation tasks (`convertAsciidoctorHtml`, `convertAsciidoctorPdf`, `cleanAsciidoctorDocs`, `generateAsciidoctorArtefacts`) using `asciidoctor-gradle-jvm` v3.3.2, `asciidoctorj` v2.5.7, `asciidoctor-pdf` v2.3.4
- 18 new AsciiDoctor default properties in `defaults.gradle` (`supportAsciiDoctor`, `asciidocDirectoryName`, `asciiDoctorEncoding`, etc.)
- `apply-subpath.sh.template`: added nginx 302 redirect blocks for path hierarchy

## [v1.3.9] - 2025-07-31

### Added
- Docker container annotation support in `container.gradle`: builds `--annotation` flags for OCI metadata (maintainer, title, vendor, url, license, version, revision, created timestamp)
- Docker latest tag support: when `dockerSupportLatestTag` is true, adds `-t ${rootProject.name}:latest` to docker build
- Docker metadata file support: `--metadata-file` flag passed to docker build
- Four new defaults: `dockerBuildCmd` (`buildx build`), `dockerAddAnnotation` (`true`), `dockerSupportLatestTag` (`true`), `dockerMetadataFile`

### Changed
- Docker build command changed from hardcoded `build` to configurable `${containerCmd} ${dockerBuildCmd}`

## [v1.3.8] - 2025-07-30

### Added
- `propertyreplacement.gradle`: added `@@servicePropertiesName@@` placeholder replacement

### Changed
- `apply-subpath.sh.template`: properties file path changed from hardcoded `/opt/toolarium-service.properties` to configurable via `PROPERTIES_FILE` variable

## [v1.3.7] - 2025-07-30

### Changed
- `webjar.gradle` `replaceFilesInPathWithSlahes()`: quoted context replacements now use original `target` instead of `normalizedTarget` to preserve trailing slashes in quoted strings
- `webjar.gradle`: when `fatWebSubContextReplacement` is `/` (root), prepends `/` to `dockerSubPathAccess` for correct absolute path matching

### Fixed
- `Dockerfile.template` for Node.js: added `RUN chmod 755 /docker-entrypoint.d/05-apply-subpath.sh` to ensure the subpath script is executable

## [v1.3.6] - 2025-07-29

### Added
- `Dockerfile.template` for Node.js: added `apk --no-cache add file` to install the `file` command needed by `apply-subpath.sh` for binary file detection

### Fixed
- `apply-subpath.sh.template`: moved `NGINX_CONF_DIR` initialization before the readability check — previously the variable was unset when the check ran

## [v1.3.5] - 2025-07-29

### Added
- `replaceFilesInPathWithSlahes()` function in `webjar.gradle` (135 lines): comprehensive path replacement handling Unicode escape sequences (`\u002F`), URL encoding (`%2F`), JSON escaped slashes (`\/`), double-escaped slashes (`\\/`), and quoted contexts; includes binary file detection (skips files with >1% null bytes)
- `apply-subpath.sh.template`: expanded to handle the same encoding variations via sed, plus binary file detection with `file -b --mime-encoding`

### Changed
- `webjar.gradle` `buildFatWebJar`: replaced multi-step approach with single call to `replaceFilesInPathWithSlahes()`

## [v1.3.4] - 2025-07-29

### Changed
- `kubernetes-product.gradle`: Kubernetes Node health check paths set to `/index.json` instead of `/index.html` for static container products
- `Dockerfile.template` for Kubernetes: no longer creates empty `index.html` placeholder

## [v1.3.3] - 2025-07-24

### Changed
- `webjar.gradle` `buildFatWebJar`: path comparison now uses `trimSlahes()` for both `dockerSubPathAccess` and `fatWebSubContext` to normalize before comparing

## [v1.3.2] - 2025-07-24

### Added
- `webjar.gradle`: API call protection during path replacement — saves `api/${dockerSubPathAccess}` as `__PROTECTED__`, performs replacements, then restores

### Fixed
- `base.gradle`: added `project.hasProperty("kubernetesUrlPath")` guard before accessing `kubernetesUrlPath` in `dockerSubPathAccess` fallback logic to prevent `MissingPropertyException`

## [v1.3.1] - 2025-07-23

### Fixed
- `base.gradle`: added empty-string checks (`.isEmpty()`) to `kubernetesUrlPath` and `runtimeUrlPath` property handling, preventing empty paths from being normalized to just `/`
- `base.gradle`: added `project.hasProperty("runtimeUrlPath")` guard before accessing `runtimeUrlPath`
- `runtimeUrlPath` fallback to `$kubernetesUrlPath` now only happens when `kubernetesUrlPath` is not empty

## [v1.3.0] - 2025-07-21

### Added
- Path normalization system in `base.gradle`: `kubernetesUrlPath`, `runtimeUrlPath`, `dockerSubPathAccess`, and `fatWebSubContext` are automatically trimmed and normalized with proper leading/trailing slashes
- `trimSlahes()` and `trimCharacters()` utility functions in `util.gradle`
- `replaceFilesInPath()` function in `file.gradle` for regex-based search-and-replace across directory trees
- `@@dockerScriptPath@@` placeholder in `propertyreplacement.gradle`
- New `apply-subpath.sh.template` (85 lines) for Node.js containers: runtime subpath remapping via properties file, sed replacements in static resources, nginx config updates
- Updated `Dockerfile.template` for Node.js with `DEPLOYMENT_SCRIPT_PATH` ARG, `apply-subpath.sh` copy, and service properties copy
- `nodejs.gradle`: `dockerBuild` doFirst block generating `apply-subpath.sh` script and service properties; path validation/warnings in `projectValidation`
- `webjar.gradle` `buildFatWebJar`: when `dockerSubPathAccess` differs from `fatWebSubContext`, replaces paths in all files under dist and generates service properties

### Changed
- `mavenSnapshotPublishUrl` and `mavenSnapshotRepositoryUrl` defaults changed from `oss.sonatype.org` to `central.sonatype.com`

## [v1.2.6] - 2025-05-19

### Changed
- `commonGradleCacheDynamicDuration` now defaults to `0` for snapshot builds (was always `10*60`), disabling dynamic version caching during development
- `kubernetes-product.gradle`: added existence check before copying environment variable file, preventing build failure when file does not exist

## [v1.2.5] - 2025-05-01

### Added
- New `dependencies-json.gradle` with `exportRequestDepndency` and `exportDependency` tasks for exporting dependency trees as JSON
- `validateEnumConfiguration()` function in `enumconfiguration.gradle` for detecting duplicate keys across service files
- `dependenciesReport` property for text-format dependency output

### Changed
- `gradleWrapperDefaultVersion` updated from `8.5` to `8.13`
- `defaultQuarkusPluginVersion` updated from `3.6.9` to `3.20.0`
- `nodePluginVersion` updated from `2.2.4` to `7.1.0`
- Enum configuration mandatory file generation refactored to sort alphabetically and only emit entries for services with actual missing defaults
- `dependencyReport` and `htmlDependencyReport` tasks: added `outputFile` attribute for Gradle 8.13 compatibility

## [v1.2.4] - 2025-03-18

### Added
- `resolveParentResourceIfNotFound` property with placeholder replacement for jwebserver configuration

### Changed
- `webServerRunnerVersion` updated from `1.2.0` to `1.2.7`
- `commonGradleSlf4jApiVersion` updated from `2.0.13` to `2.0.17`
- `commonGradleLogbackVersion` updated from `1.5.6` to `1.5.17`
- Dependency-check imports: added `DependencyFilter.DIRECT` for filtering direct dependencies only

## [v1.2.3] - 2025-02-07

### Changed
- `toolariumDependencyCheckVersion` updated from `9.0.6` to `12.0.1`
- Fixed typo: `toolariumDependencyCeckUtilVersion` renamed to `toolariumDependencyCheckUtilVersion`, version updated from `1.0.0` to `1.0.2`
- `commonGradleJptoolsVersion` updated from `1.7.11` to `1.7.12`
- `commonGradleApachePoiVersion` updated from `3.9` to `5.4.0`
- Dependency-check hardcoded fallback version updated from `8.3.1` to `12.0.1`
- Added try/catch around vulnerability report processing; report now calls `addError()` only when results are non-empty

## [v1.2.2] - 2024-12-07

### Added
- `testEnableDynamicAgentLoading` property (default: `true`) — when enabled, adds `-XX:+EnableDynamicAgentLoading -Xshare:off` JVM arguments to test tasks, suppressing the "A Java agent has been loaded dynamically" warning in JDK 21+

## [v1.2.1] - 2024-11-04

### Added
- `splitAsListByLength()` utility function in `util.gradle` for splitting strings by max length
- `kubernetesProductConfigMapEnvironmentMaxLength` property (default: `150`) for controlling max line length in Kubernetes configmap YAML
- Long environment variable values in Kubernetes YAML are now split across multiple lines with backslash continuation

### Changed
- `toolariumEnumConfigurationVersion` updated to `1.2.0` in `enumconfiguration.gradle` buildscript
- Kubernetes template YAML indentation cleanup: `valueFrom`/`configMapKeyRef`/`secretKeyRef` changed from 4-space to 2-space nesting

## [v1.2.0] - 2024-10-13

### Added
- New `java-runner.sh` (337 lines): POSIX shell script for running Quarkus applications in containers with JVM memory options, Java agent configuration, and graceful startup
- New `Dockerfile-java-runner.template` (88 lines) using `eclipse-temurin:21-jre-alpine` with `java-runner.sh`
- Apache POI dependency (`commonGradleApachePoiVersion` = `3.9`) in `model-generator.gradle`
- `commitlint.config.ts` and `.vscode`/`.idea` directories added to allowed files/directories
- Kubernetes product README generation with externally accessible services and image versions

### Changed
- Default Docker base image for Quarkus changed from `adoptopenjdk/openjdk11:alpine-jre` to `eclipse-temurin:21-jre-alpine`
- `createServiceJavaAgent` default changed from `true` to `false`
- `toolariumEnumConfigurationVersion` updated from `1.1.8` to `1.2.0`
- `webServerRunnerVersion` updated from `1.1.5` to `1.2.0`
- `commonGradleConfigResourcebundleName` changed from `Resourcebundle.xls` to `Resourcebundle.xlsx`
- `commonGradleSlf4jApiVersion` updated from `2.0.10` to `2.0.13`
- `commonGradleLogbackVersion` updated from `1.4.14` to `1.5.6`
- Kubernetes YAML templates: fixed indentation for `valueFrom` keys from 4-space to 2-space

## [v1.1.3] - 2024-06-18

### Changed
- `toolariumEnumConfigurationVersion` reverted from `1.1.9` back to `1.1.8`

## [v1.1.2] - 2024-06-15

### Added
- `.env` file auto-creation in `react.gradle` with `BUILD_PATH` configuration; new `reactEnvFileName` property

### Changed
- `forceStaticTarget` default changed from `false` to `true`
- `enablePatchRunTimeDefaultsConfigSource` default changed from `true` to `false`
- `defaultQuarkusPluginVersion` updated from `3.5.3` to `3.6.9`
- React deployment source path changed from `build` to `dist`
- React `package.json` homepage now uses `dockerSubPathAccess` instead of `dockerDeploymentSourcePath`

## [v1.1.1] - 2024-06-15

### Fixed
- `react.gradle`: fixed `targetStatic` initialization that was calling `set` instead of `get` (`project.ext.set("forceStaticTarget")` changed to `project.hasProperty("forceStaticTarget")`)

### Changed
- `react.gradle`: resource bundle output path changed from `static/locales` to `public/locales`
- `react.gradle`: deployment source path changed from `dist` to `build`, build command from `run generate` to `run build`
- `react.gradle`: now adds `homepage` entry to `package.json` pointing to `/$dockerDeploymentSourcePath/`

## [v1.1.0] - 2024-06-15

### Added
- New React project type (`gradle/react.gradle`, 196 lines) with static/server build modes, nginx/node alpine Docker images, resource bundle JSON support, and `package.json` homepage manipulation
- `getNpmPackage()` utility function in `util.gradle` for downloading and extracting npm packages
- `parseNpmDependencyVersion()` function in `nodejs.gradle` for reading dependency versions from `package.json`
- Working directory support for exec commands: optional `workingPath` parameter in `execCommand()`, `execCommands()`, `execOSCommand()`, `execRawCommand()`
- Nuxt 3 awareness in `nuxtjs.gradle`: detects version via `parseNpmDependencyVersion` and uses `.output` directory for Nuxt 3+
- Additional allowed files in `nodejs.gradle`: `tsconfig.node.json`, `vite.config.ts`, `.env`

### Changed
- `toolariumEnumConfigurationVersion` updated from `1.1.8` to `1.1.9`
- `defaultQuarkusPluginVersion` updated from `3.2.9.Final` to `3.5.3`
- SonarQube documentation updated to use `127.0.0.1` instead of `localhost`

## [v1.0.5] - 2024-01-29

### Fixed
- Container image list JSON format flag: changed `--format 'json'` to `--format json` — the single quotes were being passed literally, causing parse failures

## [v1.0.4] - 2024-01-29

### Added
- `dockerExecuteAsScript`/`dockerExecuteNotAsAbsolutePath` flags in `container.gradle`: workaround for nerdctl v1.12 on Linux which had issues with absolute path references in Dockerfile `-f` argument
- `@@DOCKER_TAG_PREFIX@@` placeholder in `propertyreplacement.gradle`

### Changed
- Container image listing switched from text-based parsing to JSON-based parsing using `--format json` and `JsonSlurper`
- Container image size display reformatted with space before unit suffix (e.g. `123.4 MB`)

### Removed
- `dockerRemovePreviousVersionImages` and `dockerMaxNumberOfImages` properties and the entire previous version image cleanup logic

## [v1.0.3] - 2024-01-22

### Changed
- Kubernetes database kind property split: `kubernetesDatabaseKind` replaced by `kubernetesDatabaseKindKey` (configmap data key) and `kubernetesDatabaseKindEnvName` (environment variable name)
- Updated Kubernetes templates and property replacement for the new split properties

### Fixed
- `kubernetes-product.gradle`: added missing task dependencies (`build.dependsOn(customJar)`, `buildFatWebJar.dependsOn(kubernetesJar)`)

## [v1.0.2] - 2024-01-08

### Fixed
- Docker/container installation check crash in `container.gradle`: wrapped `execCommand("${containerCmd} --version")` and `execCommand("${containerCmd} info")` in try/catch — previously threw unhandled exception if no container tool was installed

### Changed
- Quarkus build template: added commented-out Oracle JDBC driver dependency

## [v1.0.1] - 2024-01-08

### Fixed
- Missing `$` in template variable (`openapi/build.gradle.template`): Jakarta WS RS API dependency was `{commonGradleJakartaWsRSApiVersion}` instead of `${commonGradleJakartaWsRSApiVersion}`

## [v1.0.0] - 2024-01-08

### Added
- SonarQube integration (`gradle/build-element/base/sonar.gradle`): new 113-line file with `sonarEnabled` (default: false) and `sonarVersion` (4.4.1.3373) defaults
- New container project type (`gradle/container.gradle`, 273 lines) separate from docker
- Dependency validation functions in `dependencies.gradle`: `getDependencyVersion()`, `validateDependencyVersion()`, `validateDependencyVersionByGroupAndName()`
- ANSI color library: `toolarium-ansi:0.8.0` for proper terminal color detection
- 20+ dependency-check report formatting properties (color settings, max text length, enable reason/URL)
- JUnit XML report configuration in `test.gradle` with `junitReportPath` default
- Test environment cleanup: `GRGIT_USER`/`GRGIT_PASS` removed from test environment

### Changed
- Default container command changed from `docker` to `nerdctl` with new `containerCmd` property
- Default Gradle wrapper version updated from `8.1.1` to `8.5`
- Major dependency updates: `toolariumEnumConfigurationVersion` 1.1.6→1.1.8, `toolariumChangelogParserVersion` 0.9.2→1.0.0, JUnit 5.7.1→5.7.2, JaCoCo 0.8.7→0.8.9, Quarkus 3.1.3.Final→3.2.9.Final, OpenAPI plugin 6.5.0→7.2.0, jwebserver 1.1.3→1.1.5, ingress-nginx 1.1.1→1.9.5, Keycloak 21.1.0→23.0.3, SLF4J 1.7.30→2.0.10, Logback 1.2.3→1.4.14
- Dependency-check overhauled: replaced raw JSON parsing with `toolarium-dependency-check-util:1.0.0`; property names changed (`dependencyAutoUpdate` → `dependencyCheckAutoUpdate`, etc.)
- `docker.gradle` reduced to a thin wrapper applying `container.gradle`
- All `build.gradle.template` files updated to use full GitHub raw URL instead of `git.io` short URL

### Removed
- `verifyDependencies2` task (experimental JSurfer-based verification)

## [v0.9.113] - 2023-12-28

### Added
- New `taskNameBeforeReleaseArtefacts` property (default: `build`) in `defaults.gradle` to control task ordering before release artefacts
- `nodejs.gradle` and `kubernetes-product.gradle` set `taskNameBeforeReleaseArtefacts='buildFatWebJar'`

### Changed
- `release.gradle`: `release.mustRunAfter` and `releaseVerification.mustRunAfter` now use the dynamic `taskNameBeforeReleaseArtefacts` instead of hardcoded `'build'`

## [v0.9.112] - 2023-12-20

### Added
- `release.gradle`: added `release.mustRunAfter('build')` and `releaseVerification.mustRunAfter('build')` to ensure correct task ordering

## [v0.9.111] - 2023-12-12

### Added
- New `testRuntimeOnlyPlatformLauncher` property set to `org.junit.platform:junit-platform-launcher` — conditionally included as `testRuntimeOnly` dependency

### Changed
- `kubernetesIdmImageVersion` updated from `12.0.2` to `21.1.0` (Keycloak)

## [v0.9.110] - 2023-09-15

### Added
- New `enablePatchRunTimeDefaultsConfigSource` property (default: `true`) in `defaults.gradle`
- `quarkus.gradle`: `runTimeDefaultsConfigSourceName` made configurable; RunTimeDefaultsConfigSource patching disabled for Quarkus <= 2.x

## [v0.9.109] - 2023-09-07

### Added
- `nodejs.gradle`: fat jar now copied into `gradleDistributionDirectory` after build

### Fixed
- `kubernetes.gradle` `replaceNamespace()`: fixed `StringIndexOutOfBoundsException` when namespace tag has no value (empty/whitespace-only line after `namespace:`)

## [v0.9.108] - 2023-07-17

### Fixed
- `quarkus.gradle`: changed `printInfo` to `logInfo` for RunTimeDefaultsConfigSource creation message (consistent logging level)

## [v0.9.107] - 2023-07-17

### Added
- `java-base.gradle`: added test source sets for generated sources (test Java and test resources directories)
- `quarkus.gradle`: added `RunTimeDefaultsConfigSource` Java class generation during `JavaCompile` tasks, with template support, fallback inline generation, and patching of `generated-bytecode.jar`

### Changed
- Quarkus v3 patch: suppress build environment warnings

## [v0.9.106] - 2023-07-14

### Added
- New `gradleDistributionDirectoryName` (default: `distributions`) and `gradleDistributionDirectory` properties in `defaults.gradle`

### Changed
- `kubernetes-product.gradle`: fat jar output path changed from `${gradleBuildDirectory}/libs/` to `${gradleDistributionDirectory}/`

## [v0.9.105] - 2023-07-13

### Changed
- `nodejs.gradle` and `docker.gradle`: custom jar log messages now use `prepareFilename()` for cleaner output
- `docker.gradle`: removed `archiveBaseName` override that stripped `-docker` suffix

## [v0.9.104] - 2023-07-11

### Added
- `propertyreplacement.gradle`: added three Jakarta template placeholders (`@@commonGradleJakartaAnnotationVersion@@`, `@@commonGradleJakartaValidtionVersion@@`, `@@commonGradleJakartaWsRSApiVersion@@`)

## [v0.9.103] - 2023-07-11

### Added
- `openapiUseJakartaEe` property (default: `true`) with `useJakartaEe` parameter passed to OpenAPI generator
- Jakarta dependency defaults: `commonGradleJakartaAnnotationVersion` (2.1.1), `commonGradleJakartaValidtionVersion` (3.0.2), `commonGradleJakartaWsRSApiVersion` (3.1.0)

### Changed
- `commonGradleJacksonAnnotationVersion` updated from `2.11.2` to `2.15.2`
- OpenAPI build template migrated from `javax` to `jakarta` dependencies

## [v0.9.102] - 2023-07-11

### Added
- Elasticsearch defaults: `esElasticsearchVersion` (8.8.2), `esElasticsearchClusterName` (elastic), `esElasticsearchReplicas`, `esElasticsearchStorageSize` (3Gi), `esElasticsearchStorageClassName` (standard)
- Five Elasticsearch template placeholders in `propertyreplacement.gradle`

### Changed
- `defaultOpenapiPluginVersion` downgraded from `6.6.0` to `6.5.0`
- `nuxtjs.gradle`: moved `.npmrc` from allowed directories to allowed files

## [v0.9.101] - 2023-07-10

### Added
- `nuxtjs.gradle`: support for `nuxt.config.ts` (TypeScript) with fallback from `.js`
- `nuxtjs.gradle`: added allowed directories `composables`, `public`, `server`, `.npmrc` and allowed file `nuxt.config.ts`

## [v0.9.100] - 2023-07-10

### Changed
- `quarkus.gradle`: `javax` to `jakarta` auto-migration now also scans test sources (previously only main sources)

## [v0.9.99] - 2023-07-10

### Changed
- `quarkus.gradle`: simplified `javax` to `jakarta` migration to use a single `replaceAll("javax.", "jakarta.")` instead of individual package replacements

## [v0.9.98] - 2023-07-10

### Changed
- `gradleWrapperDefaultVersion` updated from `7.5.1` to `8.1.1`
- `checkstyleToolVersion` updated from `8.42` to `10.3.3`
- `defaultQuarkusPluginVersion` updated from `2.6.2.Final` to `3.1.3.Final`
- `defaultOpenapiPluginVersion` updated from `6.5.0` to `6.6.0`
- `toolariumDependencyCheckVersion` updated from `6.5.2.1` to `8.3.1`

### Added
- `util.gradle`: added `prepareFilename()` helper function
- `quarkus.gradle`: added auto-version-update logic for `gradle.properties` and `javax` to `jakarta` auto-migration
- `openapi.gradle`: extended with additional config options (`bigDecimalAsString`, `booleanGetterPrefix`, etc.)

### Fixed
- `dependencies.gradle`: moved dependency resolution logic into `doFirst` block to avoid premature configuration resolution
- `file.gradle`: fixed typo `relacesearchContext` → `replacesearchContext` in `replaceFile()`

## [v0.9.97] - 2023-06-19

### Fixed
- `docker.gradle`: fixed variable scoping bug in `dockerPush` task — `tagName` was missing `def` keyword, causing it to reference an outer scope variable

## [v0.9.96] - 2023-06-16

### Changed
- `toolariumEnumConfigurationVersion` updated from `1.1.5` to `1.1.6`

## [v0.9.95] - 2023-06-16

### Added
- `java-library.gradle`: added `compileOnly` and `testImplementation` dependencies for `toolarium-enum-configuration`; added empty `kubernetesConfiguration` and `prepareApplicationConfiguration` tasks
- `kubernetes-product.gradle`: added enum configuration version conflict detection with `duplicatesStrategy = 'exclude'`
- `quarkus.gradle`: added `extractEnumConfiguration` task to extract `toolarium-enum-configuration.json` from runtime classpath jars
- `base.gradle`: added `validBuild` guard to `buildFatJar`; `docker.gradle` and `webjar.gradle` added `onlyIf { return validBuild }` guards
- `version.gradle`: added `parseNameWithVersion()` utility function

## [v0.9.94] - 2023-04-25

### Changed
- `webServerRunnerVersion` updated from `1.1.2` to `1.1.3`
- `jwebserver.properties.template`: added `supportedFileExtensions = .json`

## [v0.9.93] - 2023-04-25

### Changed
- Introduced `defaultOpenapiPluginVersion` property (set to `6.5.0`); `openapiPluginVersion` now defaults to it instead of hardcoded `5.1.1`

## [v0.9.92] - 2023-04-25

### Changed
- `gradleWrapperDefaultVersion` updated from `7.3.1` to `7.5.1`
- `jacocoXMLReport` default changed from `false` to `true`
- Added `.idea` directory to `allowedMainDirectories`

## [v0.9.91] - 2023-04-24

### Changed
- `webServerRunnerVersion` updated from `1.1.1` to `1.1.2`

## [v0.9.90] - 2023-02-16

### Changed
- `common.gradle`: major refactoring of custom config home resolution — extracted `readGitProjectUrl()` and `readCommonGradleBuildHomeBase()` as reusable functions; added URL-based routing via `.cb-custom-config` file matching git remote URL against patterns (longest match wins)
- `base.gradle`: `buildServiceProperties()` now takes `rootPathSourceFile` and `rootPathSourceProperty` as parameters; fixed leading/trailing `/` path comparison logic

## [v0.9.89] - 2022-12-29

### Added
- `gradle/template/kubernetes/gradle.properties.template`: new template for kubernetes-product projects

### Changed
- `webServerRunnerVersion` updated from `1.1.0` to `1.1.1`
- `project-types.properties`: removed `-app` suffix requirement from `java-application` project name

## [v0.9.88] - 2022-12-28

### Changed
- `nodejs.gradle`: reordered script — moved `createCustomJar` property and `customJar` task definition before `apply from` statements for repository/signing/publication

## [v0.9.87] - 2022-12-28

### Added
- `nodejs.gradle`: new `customJar` task (type: Jar) with proper manifest attributes
- `kubernetes-product.gradle`: added web jar fat-jar support with `buildFatWebJar` task and application-information copying

### Changed
- Renamed `jar-configuration.gradle` to `webjar.gradle`; renamed `configurations.jar` to `configurations.webJar`
- `jwebserver.properties.template` moved from `gradle/template/nodejs/` to `gradle/template/base/`; added `webserverName`, `resourcePath`, `ioThreads`, `workerThreads`, `welcomeFiles`
- `webServerRunnerVersion` updated from `1.0.1` to `1.1.0`

## [v0.9.86] - 2022-12-27

### Added
- `nodejs.gradle` and `kubernetes-product.gradle`: added `archives jar` artifact when `createFatJar` is true

## [v0.9.85] - 2022-12-23

### Added
- New `gradle/build-element/base/jar-configuration.gradle`: extracted fat web jar build logic from `nodejs.gradle` into a shared reusable script
- New Kubernetes properties: `kubernetesApplyCommand`, `kubernetesDeleteCommand`, `kubernetesInstallMessage`, IDM template filename properties

### Changed
- `nodejs.gradle`: removed inline fat web jar logic, now uses shared `jar-configuration.gradle`
- `kubernetes-product.gradle`: IDM template filenames now use configurable properties

## [v0.9.84] - 2022-12-22

### Added
- `base.gradle`: new `buildServiceProperties()` function creating `toolarium-service.properties` with service name, version, root-path, and resources path
- `base.gradle`: `buildFatJar()` now accepts `mergeManifest` parameter and properly merges MANIFEST.MF
- New `createServiceProperties` (default: `true`) and `servicePropertiesName` (default: `toolarium-service.properties`) properties

### Changed
- `nodejs.gradle` and `quarkus.gradle`: replaced inline service.properties generation with shared `buildServiceProperties()` and `buildFatJar()` calls

## [v0.9.83] - 2022-12-21

### Changed
- `webServerRunnerVersion` updated from `1.0.0` to `1.0.1`

## [v0.9.82] - 2022-12-21

### Added
- `nodejs.gradle`: added `service.properties` generation to fat web jar build with service name, version, root-path, and kubernetes URL path

## [v0.9.81] - 2022-12-21

### Added
- New `jwebserver.properties.template` in `gradle/template/nodejs/` for web server runner configuration
- `nodejs.gradle`: full fat web jar build pipeline — `configurations.jar` for web server runner dependency, `buildFatWebJar` task that packages static web content with `toolarium-jwebserver`, manifest merging, and template-based properties
- New web server runner defaults: `webServerRunnerPackage`, `webServerRunnerName`, `webServerRunnerVersion`, `webServerRunnerPropertiesName`
- New docker defaults: `dockerBuildLatestTag`, `dockerBuildLatestTagName`
- `@@DISTNAME@@` placeholder in `propertyreplacement.gradle`

## [v0.9.80] - 2022-11-23

### Added
- `docker.gradle`: new `customJar` task (type: Jar) for docker project type with manifest attributes; support for `createCustomJar`/`createFatJar` properties with repository, signing, and publication

## [v0.9.79] - 2022-11-23

### Added
- `docker.gradle`: repository/signing/publication support when `createCustomJar` is true and no kubernetes directory exists
- `vuejs.gradle`: added `vue.config.js` to allowed main files

## [v0.9.78] - 2022-10-28

### Changed
- `project-types.properties`: added `--yes` flag to `npx` commands for vuejs and nuxtjs init actions to auto-confirm prompts

## [v0.9.77] - 2022-10-28

### Added
- `docker.gradle`: added `service.properties` creation logic (commented-out)
- `dockerignore.template`: added `build/reports` exclusion
- `Dockerfile.template`: added `service.properties` creation commands (commented-out)

### Changed
- `project-types.properties`: updated nuxtjs to include "HTML" and `"template": "html"` in init action answers
- `quarkus.gradle`: changed `kubernetesUrlPath` default fallback to empty string; fixed `service.properties` header comment

## [v0.9.76] - 2022-07-08

### Changed
- `toolariumEnumConfigurationVersion` updated from `1.1.4` to `1.1.5`

## [v0.9.75] - 2022-06-23

### Changed
- `toolariumEnumConfigurationVersion` updated from `1.1.3` to `1.1.4`

## [v0.9.74] - 2022-06-20

### Changed
- `toolariumEnumConfigurationVersion` updated from `1.1.2` to `1.1.3`

## [v0.9.73] - 2022-06-02

### Added
- New Kubernetes product resource properties: `kubernetesProductMainResourcesPath`, `kubernetesProductMainResourcesIncludes`, `kubernetesProductResourcesPathname`, `kubernetesProductResourcesPath`
- `kubernetes-product.gradle`: new `createJsonIndexFile()` function that recursively creates `index.json` files listing directory contents
- `kubernetes-product.gradle`: new `copyAppResources` task copying application resources into kubernetes application-information structure

## [v0.9.72] - 2022-05-22

### Changed
- `toolariumEnumConfigurationVersion` updated from `1.0.0` to `1.1.2`

## [v0.9.71] - 2022-04-26

### Changed
- Version bump only (empty diff)

## [v0.9.70] - 2022-04-26

### Changed
- `toolariumEnumConfigurationVersion` updated from `0.9.12` to `1.0.0`

## [v0.9.69] - 2022-04-26

### Fixed
- `java.gradle`: `configurations.all` cache strategy now skips configurations containing `quarkusDependency` to avoid resolution conflicts with Quarkus > v2.8.1.Final
- `quarkus.gradle`: fixed `quarkusPluginVersion` replacement in `gradle.properties` to only match lines starting with `quarkusPluginVersion`

## [v0.9.68] - 2022-02-01

### Fixed
- `quarkus.gradle`: added `hasProperty` check before adding `'enforced-platform'` to `suppressedValidationErrors` in `GenerateModuleMetadata` task

## [v0.9.67] - 2022-01-27

### Added
- `kubernetesIngressProxyBufferSize` property (default: `8k`)
- `@@KUBERNETES_INGRESS_PROXY_BUFFER_SIZE@@` placeholder in `propertyreplacement.gradle`
- `kubernetes-ingress-controller-header.template`: added `nginx.ingress.kubernetes.io/proxy-buffer-size` annotation

## [v0.9.66] - 2022-01-27

### Changed
- `kubernetesControllerImage` updated from `networking.k8s.io/v1beta1` to `networking.k8s.io/v1`
- `kubernetesIngressNginxVersion` updated from `0.44.0` to `1.1.1`
- `kustomization.template`: updated `apiVersion` from `v1beta1` to `v1`

## [v0.9.65] - 2022-01-27

### Changed
- Full upgrade of ingress-nginx from `0.44.0` to `1.1.1`: updated container images, switched to `--controller-class`, added `IngressClass` resource, removed `extensions` API group references, added `allow-snippet-annotations`, added security context and node selector
- `kubernetes-product.gradle`: ingress controller content updated to `networking.k8s.io/v1` format with `pathType: Prefix`
- `kubernetes-ingress-controller-header.template`: added `ingressClassName: nginx` to spec

## [v0.9.64] - 2022-01-26

### Added
- `changelog.gradle`: new `readChangelog()` and `updateChangelog()` functions for programmatic changelog updates with specific change types
- New changelog properties: `changelogDefaultType`, `changelogDefaultComment`, `changelogReleaseUpdateType` (SECURITY), `changelogReleaseUpdateComment`
- `release.gradle`: major enhancement with `releaseUpdateVersion` task, release artefact validation (signature/hash), configurable release directory structure
- New release properties: `releaseAddComponentIdIntoReleasePath`, `commonGradleBuildValidateReleaseArtefact`, `copyReleaseArtefactInformation`, `releaseVersionFileExtension`

### Changed
- `toolariumChangelogParserVersion` updated from `0.9.1` to `0.9.2`
- Kubernetes defaults template: health check paths updated from `/health/ready` to `/q/health/ready`; added startup probe sections

## [v0.9.63] - 2022-01-11

### Changed
- `jacocoToolDefaultVersion` updated from `0.8.6` to `0.8.7`
- `defaultQuarkusPluginVersion` updated from `2.5.4.Final` to `2.6.2.Final`

## [v0.9.62] - 2022-01-11

### Added
- Kubernetes startup probe configuration sections in defaults template

### Changed
- `gradle.gradle`: added logging of expected vs actual gradle wrapper version; wrapper version check now allows empty/unset `gradleWrapperDefaultVersion`
- Kubernetes health check paths updated to Quarkus 2.x style (`/q/health/ready`)

## [v0.9.61] - 2022-01-11

### Fixed
- `quarkus.gradle`: moved `quarkusResourcePath` variable definition outside the `IS_NEW` block so it's accessible in both new and existing project paths
- `quarkus.gradle`: disabled auto-creation of `index.html` in `META-INF/resources` for new projects

## [v0.9.60] - 2022-01-09

### Added
- New `ansi-support.gradle`: terminal color detection system supporting NONE, ANSI16, ANSI256, and TRUECOLOR; detects IntelliJ, VS Code, Eclipse, iTerm, Apple Terminal, Hyper
- New `dependencies.gradle`: dependency whitelist/blacklist validation system with `validateDependency()`, `getVersionExpression()`, and configuration from properties files
- New `dependency-check.gradle`: OWASP dependency-check integration via `toolarium-dependency-check-gradle` plugin
- New `whitelist-dependencies.properties` and `blacklist-dependencies.properties` configuration files
- New `script.gradle` project type for script projects
- `version.gradle`: added `getVersionExpression()` and `isCompliantVersion()` using semver4j for semantic version matching

### Changed
- Major dependency updates: Gradle 7 support, `snakeYamlVersion` to 1.29, `grgitCoreVersion` to 4.1.1, `semver4jVersion` 3.1.0, `gradleWrapperDefaultVersion` to 7.3.1
- Duplicate strategy for jar support added
- Support of mavenCentral
- OpenAPI support for multiple spec files
- Detect ANSI support improved; changed to MaxMetaspaceSize
- JUnit dependency set to 5.7.1
- Checkstyle v8.42 support
- `README.md`: fixed license badge from MIT to GPL-3.0

## [v0.9.57] - 2021-10-22

### Changed
- `quarkus.gradle`: disabled auto-creation of `index.html` in new project setup; added cleanup of existing `index.html` in older projects on rebuild

## [v0.9.56] - 2021-10-22

### Changed
- `gradleWrapperDefaultVersion` updated from `6.7` to `7.2`
- `defaultQuarkusPluginVersion` updated from `1.11.7.Final` to `2.1.4.Final`
- `checkstyleToolVersion` hardcoded to `8.42`
- `dockerRepositoryHost` changed from `https://hub.docker.com/` to empty string
- Quarkus health check paths changed from `/health/ready` to `/q/health/ready` (Quarkus 2.x format)
- `docker.gradle`: added workaround for Docker Hub login on Windows

## [v0.9.55] - 2021-07-28

### Changed
- `quarkusAppJar` default changed from `quarkus-app.jar` to `quarkus-run.jar` (Quarkus renamed the jar)
- `Dockerfile.template` ENTRYPOINT updated accordingly

### Fixed
- `java-base.gradle` and `publication.gradle`: fixed `createCustomJar` property check to use `.toString().equalsIgnoreCase("true")` instead of direct boolean check
- `quarkus.gradle`: fixed `createFatJar` property check with same string comparison fix
- `kubernetes-product.gradle`: added `createCustomJar` property, moved applies after task definition, added `onlyIf` guard and `mustRunAfter`

## [v0.9.54] - 2021-07-19

### Changed
- `security.gradle`: `createMessageHash` now prefixes hash with algorithm name in braces (e.g. `{SHA-256}base64...`)
- `security.gradle`: `verifyMessageHash` now auto-detects hash algorithm from `{algorithm}` prefix

### Fixed
- `logger.gradle`: fixed two Kotlin-style `val` keywords that should have been Groovy `def` in `detectANSISupport`

## [v0.9.53] - 2021-07-08

### Changed
- `security.gradle`: renamed `signMessage` to `createMessageHash` and `verifyMessage` to `verifyMessageHash`
- `security.gradle`: fixed `createMessageHash` to return properly encoded Base64

## [v0.9.52] - 2021-07-07

### Added
- New `gradle/build-element/base/security.gradle` with cryptographic functions: `createPassword`, `createHash`, `readPublicKeyFromFile`, `readPrivateKeyFromFile`, `signMessage`, `verifyMessage`

## [v0.9.51] - 2021-07-06

### Added
- `kubernetesProductConfigMapEnvironmentVariableName` and corresponding filename property for ConfigMap environment variables
- `kubernetes-product.gradle`: support for ConfigMap environment variables via `secretKeyRef` in Kubernetes YAML

### Changed
- `toolariumEnumConfigurationVersion` updated from `0.9.10` to `0.9.12`
- `kubernetesProductEnvironmentVariableName` renamed from `environment-variables.properties` to `kubernetes-environment-variables.properties`
- Manifest reference fallback changed from `tmp/jarJar/MANIFEST.MF` to `tmp/customJar/MANIFEST.MF`
- Checkstyle template: removed deprecated `PackageHtml` module

## [v0.9.50] - 2021-06-30

### Fixed
- `kubernetes-product.gradle`: fixed typo `yamlIndentFiler` → `yamlIndentFilter`
- `kubernetes-product.gradle`: fixed YAML comment detection to use `line.trim().startsWith("#")` instead of `line.startsWith("#")`
- `kubernetes-product.gradle`: fixed section detection to skip comment lines and labels parsing to exclude indented lines

### Changed
- Added commented-out `productOrganisation` property in defaults template

## [v0.9.49] - 2021-06-28

### Changed
- `quarkusPluginVersion` updated from `1.11.7.Final` to `1.13.7.Final`
- `kubernetes-product.gradle`: added `productName`, `productOrganisation`, and `copyrightText` properties; product service info JSON now uses these instead of `rootProject.name`/`licenseOrganisation`

## [v0.9.48] - 2021-06-22

### Changed
- `kubernetes-product.gradle`: renamed `jarJar` task to `customJar`; added `createCustomJar` property flag and `Usage.JAVA_API` attribute

## [v0.9.47] - 2021-06-22

### Added
- `quarkus.gradle`: new `updateApplicationProperties` function that strips `%test`/`%dev` profiles and removes `%prod.` prefix
- `quarkus.gradle`: new `createServicePathProperties` generating `service-path.properties` in quarkus-app directory
- New properties: `quarkusAppSubPathName` (app), `createServicePathProperties` (true), `updateApplicationProperties` (true)

## [v0.9.46] - 2021-06-21

### Changed
- `base.gradle`: `buildFatJar` now includes `**/**.*` pattern instead of just `*.jar` and `lib/**.jar`
- `kubernetes-product.gradle`: added `Usage.JAVA_API` attribute to `configurations.jar`

## [v0.9.45] - 2021-06-21

### Added
- `base.gradle`: new `buildFatJar` function for creating fat/uber jars
- New `createFatJar` property (default: false)
- New Kubernetes environment variable properties (`kubernetesProductEnvironmentVariableName`, etc.)
- `kubernetes-product.gradle`: new `jarJar` task for packaging kubernetes configuration
- `processKubernetesDependencies` task

### Changed
- `toolariumEnumConfigurationVersion` updated from `0.9.8` to `0.9.10`
- `toolariumChangelogParserVersion` updated from `0.9.0` to `0.9.1`
- `checkstyleToolDefaultVersion` updated from `8.27` to `8.37`
- `jacocoToolDefaultVersion` updated from `0.8.5` to `0.8.6`
- `java-application.gradle`: replaced `shadowClassifier` with `javaApplicationShadowClassifier`, made classifier optional
- Test source directory auto-creation disabled (commented out) in `java-base.gradle` and `language-base.gradle`

## [v0.9.44] - 2021-06-11

### Changed
- `kubernetes-product.gradle`: kustomize file copy now processes namespace replacement instead of raw copy

## [v0.9.43] - 2021-06-10

### Added
- `dockerSupportProjectTemplateList` and `kubernetesSupportProjectTemplateList` properties for restricting which projects may have local templates
- `kubernetesFileAdditionalContent` property for appending to combined Kubernetes file
- Validation warnings when projects have local Dockerfiles/Kubernetes templates but are not in the allowed list

### Changed
- All Dockerfile templates simplified: removed `UID`, `GID`, `RUNTIMEGROUP` ARGs; simplified to `RUNTIMEUSER` with `adduser -D`; added `chmod -R g=u` for OpenShift compatibility
- `file.gradle`: `replaceFile` now uses temp files instead of in-memory string concatenation

## [v0.9.42] - 2021-06-09

### Added
- New `kubernetes-namespace.template` file extracted from individual config/secret templates

### Changed
- Namespace YAML now generated as a separate file and applied first
- Simplified kustomize path structure (removed `base/` nesting)
- Removed inline namespace definitions from config/secret/IDM templates

## [v0.9.41] - 2021-06-09

### Fixed
- Removed `@@PRODUCT_BUILD_ID@@` suffix from `kubernetesDatabaseAdminSecretName` default

## [v0.9.40] - 2021-06-08

### Fixed
- `release.gradle`: fixed `git.add` for OpenAPI spec files by normalizing path (stripping leading `./` prefix) to avoid git staging errors

## [v0.9.39] - 2021-06-08

### Fixed
- `release.gradle`: changed path format for OpenAPI spec file staging from `file.getPath()` to `"${srcMainApiSpecDirectory}/" + file.getName()`

## [v0.9.38] - 2021-06-08

### Fixed
- `release.gradle`: changed `"$file"` to `file.getPath()` for git staging of OpenAPI spec files after release

## [v0.9.37] - 2021-06-08

### Changed
- `openapiUpdateFileAfterRelease` default changed from `false` to `true`

### Added
- `kubernetes-product.gradle`: added kustomize directory creation in `kubernetesConcat` task

## [v0.9.36] - 2021-06-07

### Added
- `updateChangelog` function in `changelog.gradle` for adding version entries after release
- `replaceFile` function in `file.gradle` for search-and-replace within files by extension
- New `kustomization.template` for Kubernetes kustomize support
- `release.gradle`: auto-updates changelog and OpenAPI spec files after release version bump
- New properties: `changelogFailOnSnapshotBuild`, `changelogUpdateFileAfterRelease`, `changelogSupportEmptySection`
- Kustomize properties: `kustomizeSupport`, `kustomizeConfigurationPath`

### Changed
- Moved `changelog.gradle` from `scm/` to `base/` directory
- `toolariumChangelogParserVersion` updated from `0.8.3` to `0.9.0`
- Changelog validation now only fails on release builds (or when `changelogFailOnSnapshotBuild` is true)
- `docker.gradle`: `dockerPush` now only runs if `validBuild` is true
- Changed import sort order in checkstyle configuration

## [v0.9.35] - 2021-05-25

### Added
- Toolarium enum configuration support: new `enumconfiguration.gradle` build element (207 lines)
- `createJsonArray` JSON helper function
- Changelog and enum-configuration integration in kubernetes-product
- `includeApplicationInformation` property
- `kubernetesFileTemplateName` support
- Kubernetes application information and `app:`/`version:` labels in all kubernetes.yaml templates
- Nuxt projects distJar support
- Snapshot version preparation after release

### Changed
- Improved quarkus version handling
- Updated to openapi generator v5.1.1
- Refactored external tool version management
- Kubernetes Ingress/Nginx optimization, updated ingress-nginx to v0.44.0
- Introduced mandatory changelog validation with automated verification
- `initialisation.gradle`: changelog initial entry now says "Setup initial version."

## [v0.9.34] - 2021-03-07

### Changed
- Updated kubernetes templates with app/version labels

## [v0.9.33] - 2021-03-05

### Added
- `kubernetesIngressProxyBodySize` property (default: `10m`)
- Kubernetes ingress controller header: `proxy-body-size` annotation

### Changed
- `openapiPluginVersion` updated from `5.0.0-beta2` to `5.0.0`

### Fixed
- `docker.gradle`: refactored docker image listing to only compute age for non-current-version images, fixing parsing issues

## [v0.9.32] - 2021-02-24

### Added
- Install scripts: added `--help`, `--version`, `--replicas`, `--initialDelay`, `--period` options for overriding Kubernetes YAML values

### Changed
- `kubernetesReadinessInitialDelaySeconds` updated from `0` to `60`

## [v0.9.31] - 2021-02-16

### Changed
- Renamed `config-home.gradle` to `organization-config.gradle`
- `project-types.properties`: updated entry from `config-home` to `organization-config`
- `quarkusPluginVersion` updated from `1.8.1.Final` to `1.10.5.Final`

## [v0.9.30] - 2021-02-15

### Added
- New `enumconfiguration.gradle` build element (207 lines) for toolarium enum configuration
- `nodejs.gradle` aggregator build element (63 lines)
- Expanded JSON helper functions in `json.gradle`
- `kubernetes-ingress-controller-header.template`
- `isWindowsWSL` WSL detection support

### Changed
- License changed from MIT to GPL-3.0 across all source files
- ~95 lines of new Kubernetes defaults (IDM, database, ingress, application config, secret management)
- `docker.gradle`: enhanced with snapshot vs release repository handling
- `exec.gradle`: added timeout and output capture parameters
- Renamed `changelog.template` to `CHANGELOG.template`
- Improved dangling image cleanup; improved read image information

## [v0.9.28] - 2021-02-13

### Fixed
- `nodejs.gradle`: fixed `.node-config-initialized` file creation by ensuring parent directory exists via `mkdirs()`
- `nuxtjs.gradle` and `vuejs.gradle`: fixed license file handling during project initialization

## [v0.9.27] - 2021-02-05

### Added
- `kubernetes-product.gradle`: new file (~452 lines) for Kubernetes product assembly with service concatenation, ingress handling, install scripts
- New templates: kubernetes deployment templates, install scripts (bat/sh), INSTALL template
- `json.gradle`: added JSON helper functions (`startJsonElement`, `createJsonKeyValueElement`, etc.)
- `addCommonGradlePropertyList` for list-based properties
- ~190 lines of Kubernetes property replacements in `propertyreplacement.gradle`
- Kubernetes readiness/liveness probes enabled for quarkus
- shadowJar support; `configPackageArchiveClassifier` property
- JSON support module

### Changed
- ~87 lines of new Kubernetes defaults (namespace, labels, OIDC, database, IDM, ingress)
- Update from NodePort to ClusterIP in Kubernetes service templates
- Expanded kubernetes IDM template with health probes and volume mounts

## [v0.9.26] - 2021-01-21

### Changed
- `docker.gradle`: `execDocker` now accepts `failOnError` parameter (default: true) for non-fatal docker errors
- Standardized indentation and formatting in multiple templates

## [v0.9.25] - 2021-01-17

### Fixed
- `resourcebundle.gradle`: fixed modelgenerator logger config reference and logger class references
- Modelgenerator log output now goes to `./build/modelgenerator.log` instead of `logs/`

### Changed
- Defaults template: added `excelFileEncoding` option; reorganized resource bundle and quarkus sections

## [v0.9.24] - 2021-01-17

### Changed
- `version.gradle`: `readVersion` now returns a boolean indicating whether the VERSION file was updated
- `release.gradle`: during release prepare, if version file was changed, explicitly calls `updateVersion()` to persist

## [v0.9.23] - 2021-01-17

### Added
- `supported-repositories.gradle`: extracted repository configuration into a reusable file
- `custom.gradle.template`: new template for organization-specific build extensions
- `common.gradle`: support for applying `custom.gradle` from common-gradle-build home path
- `docker.gradle`: new `copyLibs` task to copy implementation dependencies to build/libs
- Testing memory support

### Changed
- `testMinHeapSize` (128m) and `testMaxHeapSize` (512m) properties added
- `commonGradleJptoolsModelGeneratorVersion` updated from `1.7.2` to `1.7.6`
- `resourcebundle.gradle`: added `referenceSheetName` and `referenceSheetHasNoSubFolder` support

## [v0.9.22] - 2021-01-12

### Fixed
- `file.gradle`: `createFileFromTemplatePath` now deletes existing output file when `overwrite` is true before writing

## [v0.9.21] - 2021-01-12

### Added
- New `propertyreplacement.gradle` (512 lines): extracted all template placeholder replacements from `file.gradle`
- API dependency support in `java-base.gradle`

### Changed
- `file.gradle`: removed ~500 lines of property replacement code (moved to new file)
- `.gitattributes`: added `*.yaml text eol=lf` and `*.sh text eol=lf` rules
- Kubernetes config/secret file encoding improvements

## [v0.9.20] - 2021-01-11

### Fixed
- `defaults.gradle`: fixed indentation in `kubernetesDatabaseIntitializationString` from tabs to 4 spaces for YAML consistency

## [v0.9.19] - 2021-01-11

### Fixed
- `defaults.gradle`: fixed `kubernetesDatabaseIntitializationString` to use `$IDM_SCHEMA` variable in `CREATE SCHEMA IF NOT EXISTS` for IDM user

## [v0.9.18] - 2021-01-11

### Added
- New properties: `kubernetesDatabaseAdminSecretName`, `kubernetesDatabaseAdminUsername`, `kubernetesDatabaseAdminPassword`
- `kubernetesDatabaseIntitializationString`: PostgreSQL init script for creating app and IDM users/schemas
- Database template: init-db ConfigMap and volume mount

### Changed
- `kubernetesDatabaseUsername` default changed from `serviceUser` to `appuser`
- `kubernetesIdmDatabaseUsername` default changed from `${kubernetesDatabaseUsername}` to `idmuser`

## [v0.9.17] - 2021-01-11

### Added
- New properties: `kubernetesIdmServiceName`, `kubernetesIdmDatabaseSchema`, `kubernetesIdmDatabaseSchemaKey`, `kubernetesIdmDatabaseSchemaEnvName`
- Kubernetes IDM config/template: database schema key/value entries and `DB_SCHEMA` environment variable
- Kubernetes database template: admin-secret, database-init ConfigMap, init script volume mount
- `file.gradle`: changed temp path from `cgb` to `cgb-<username>` for multi-user isolation

## [v0.9.16] - 2021-01-08

### Added
- Docker image name now includes tag prefix based on snapshot/release configuration
- `version.gradle`: handles adding/removing `SNAPSHOT` qualifier based on `isReleaseVersion`
- `quarkusRepository` support (JBoss Maven repository)
- `kubernetes-product.gradle`: docker image reference file generation

### Changed
- `commonGradleBuildCacheLastCheckTimeout` updated (half day instead of one day)
- `java-base.gradle`: `defaultTasks` simplified with `jar.dependsOn(createResourceBundle)`
- Application properties template: standardized spacing; added `quarkus.liquibase.migrate-at-start`
- `.gitattributes.template`: added `*.sh text eol=lf`

## [v0.9.15] - 2020-12-19

### Changed
- `commonGradleBuildReleaseBranchName` changed from `"master"` to `""` (no branch restriction by default)

### Fixed
- `docker.gradle`: fixed docker build command to not include empty `dockerBuildArgs`
- `docker.gradle`: fixed docker tag name construction (removed double slash)
- `docker.gradle`: downgraded docker image list read error from `printWarn` to `logInfo`

## [v0.9.14] - 2020-12-19

### Added
- `docker.gradle`: major expansion with docker image listing, dangling image cleanup, previous version image removal, snapshot vs release repository push
- New properties: `dockerRemoveDanglingImages` (true), `dockerRemovePreviousVersionImages` (true), `dockerMaxNumberOfImages` (2)
- New properties: `dockerRepositoryHost`, `dockerTagPrefix`, `dockerSnapshotRepositoryHost`, `dockerSnapshotTagPrefix`
- `dockerFileTemplate` property for template-based Dockerfiles
- `docker/gradle.properties.template`
- `file.gradle`: extracted `createFileFromTemplatePath` as public function

### Changed
- Docker build now uses temp files for Dockerfiles instead of modifying local files

## [v0.9.12] - 2020-12-11

### Added
- Create template without placeholder replacement support
- Allow forcing `isReleaseVersion` via `-PisReleaseVersion=true` parameter

### Changed
- `release.gradle`: major refactoring of release version handling with proper `isReleaseVersion`/`isSnapshotVersion` tracking
- Logback template: changed log file path from `logs/` to `build/`

### Fixed
- Kubernetes logback settings fixed
- Docker images with subpath (node-based projects) now supported

## [v0.9.11] - 2020-12-05

### Changed
- `kubernetes.gradle`: application secret only generated when `kubernetesApplicationOIDCPublicKey` is non-empty
- `docker.gradle`: sets `kubernetesDockerImage` property when kubernetes directory exists

## [v0.9.10] - 2020-12-05

### Added
- `base.gradle`: new `checkUpdateCommonGradleBuild` task for manual cache/home update
- OIDC auth server URL and token issuer properties
- `kubernetes.gradle`: expanded with template processing and file concatenation
- `docker.gradle`: restructured with kubernetes-aware docker support

### Changed
- `srcKubernetesDirectoryName` changed from `"docker"` to `"kubernetes"`
- Quarkus application properties: added `quarkus.http.root-path=/`, improved security/dev/test config

## [v0.9.9] - 2020-11-30

### Added
- `kubernetes-product.gradle`: new file for Kubernetes product assembly
- `kubernetes.gradle`: new build element for Kubernetes configuration support
- `docker.gradle` project type for standalone Docker projects
- 10+ Kubernetes config templates (application config/secret, database, IDM, ingress-nginx)
- Quarkus `kubernetes.yaml.template` with deployment/service and health probes

### Changed
- ~133 lines of new Kubernetes, Docker, and Nuxt.js defaults
- `common-gradle-build.gradle`: refactored remote version check to use temp file utilities
- `nodejs.gradle`: added node registry initialization and fund message suppression
- `createProjectIndividualDockerfie` default changed from `true` to `false`

## [v0.9.8] - 2020-11-23

### Added
- `release.gradle`: new `checkReleaseCredentials` task validating `GRGIT_USER`/`GRGIT_PASS` environment variables
- `release.gradle`: new `publishRelease` task
- `java.gradle`: configurable cache strategy with `cacheDynamicVersionsFor`/`cacheChangingModulesFor`
- Nuxtjs typescript version file generation support

### Changed
- `commonGradleBuildReleasePublish` default changed from `false` to `true`
- Added `commonGradleCacheDynamicDuration` (600s) and `commonGradleCacheChangingModulesDuration` (0s) properties

## [v0.9.7] - 2020-11-16

### Fixed
- `kubernetesIdmFrontendUrl` fixed from `http://app-${kubernetesLabelId}.local` to `http://${rootProject.name}.local`
- Kubernetes database template: PVC `apiVersion` fixed from `apps/v1` to `v1`
- Quarkus kubernetes template: OIDC secret references fixed from `configMapKeyRef` to `secretKeyRef`

### Changed
- `nuxtjs.gradle`: auto-inserts `target: 'static'` into `nuxt.config.js` for new projects when `forceStaticTarget` is true

## [v0.9.6] - 2020-11-15

### Added
- `kubernetes.gradle`: new build element (187 lines)
- `docker.gradle` project type (109 lines)
- Full set of Kubernetes config templates: application-config/secret, database-parameters/secret/deployment, IDM config/secret/deployment, ingress-nginx, ingress-controller-header
- Quarkus kubernetes.yaml.template and base kubernetes.yaml.template

### Changed
- ~143 lines of new Kubernetes properties (labels, namespaces, OIDC, database, IDM)
- OpenAPI default changed to return Response objects
- `nodejs.gradle`: added `nodeConfigInitFile`, `nodeFundMessage`, `nodeRegistry` properties

## [v0.9.5] - 2020-11-04

### Added
- `gradleWrapperDefaultVersion` property (default: `6.7`)
- `checkstyleEclipseConfigurationOverwrite` property (default: `true`)

### Changed
- `gradle.gradle`: wrapper version check now handles missing files gracefully
- `eclipse.gradle`: respects `checkstyleEclipseConfigurationOverwrite` property
- `openapi.gradle`: major reformatting of inline YAML generation

## [v0.9.4] - 2020-11-02

### Added
- `vuejs.gradle`: new Vue.js project type (64 lines)
- `openapi.gradle`: added `beans.xml` META-INF creation
- `java.gradle`: new `createMeateInfFiles` task for META-INF preparation

### Changed
- `openapiDateLibrary` changed from `java8` to `legacy`
- `project-types.properties`: updated with project name suffixes (-app, -ui, -config, -api-spec, -service)
- `initialisation.gradle`: fixed case-insensitive path comparison

## [v0.9.2] - 2020-11-01

### Fixed
- `common.gradle`: fixed port check from `homeURL.getPort()!=null` to `homeURL.getPort()!=null && homeURL.getPort()>0` to handle default port (-1)

## [v0.9.1] - 2020-11-01

### Added
- `release.gradle`: `getReleaseArtefactInfoFile` function with component ID-based release directory structure
- `copyReleaseArtefactInformation` and `releaseAddComponentIdIntoReleasePath` properties
- Prepared checkstyle for future version support

### Changed
- Home optimization: multiple improvements to CB home directory resolution
- `common-gradle-build.gradle`: fixed logging for existing version check
- `base.gradle`: git commit hash now set during project validation

### Fixed
- Node projects without groupId now handled correctly
- Setting scm version fixed

## [v0.9.0] - 2020-10-28

### Added
- `docker.gradle` build element (260 lines) for Docker image building, cleanup, and push
- `release.gradle` (315 lines): comprehensive release management with version handling, git tagging, snapshot/release workflows
- `java-application.gradle` project type with shadow jar support
- Docker templates: Dockerfile (base, nodejs, quarkus), dockerignore, Dockerfile-node
- `commonGradleBuildReleasePublish` property

### Changed
- `constants.gradle`: added `STYLER_NO_COLOR`/`STYLER_COLOR` maps; plain console mode now disables ANSI colors
- ~80 lines of Docker defaults (UID/GID, ports, timezone, build options, repository settings)
- `nuxtjs.gradle`: major expansion (~115 lines) with npm build integration, Docker support, static target validation

## [v0.8.9] - 2020-10-07

### Added
- Resource bundle support in `java-base.gradle`
- Quarkus test template: added `@QuarkusTestResource` annotation

### Fixed
- Nuxt init issues fixed
- Quarkus resource handling issue resolved

## [v0.8.8] - 2020-10-06

### Added
- `java-application.gradle` project type (67 lines) with shadow jar support
- `model-generator.gradle` and `resourcebundle.gradle`: new build elements for resource bundle generation
- `run.gradle`: new build element for running applications
- `jptools/modelgenerator.properties`: full model generator configuration (382 lines)

### Changed
- Quarkus template: renamed `applications.properties.template` to `application.properties.template`

## [v0.8.7] - 2020-09-21

### Changed
- `openapi.gradle`: improved API spec file handling with better Swagger/OpenAPI version detection

## [v0.8.6] - 2020-09-16

### Added
- OpenAPI configuration defaults (~23 lines) in `defaults.gradle`
- `util.gradle`: added `parseInteger` and `parseVersion` utility functions
- `openapi.gradle`: configurable code generation properties

## [v0.8.5] - 2020-09-10

### Fixed
- `eclipse.gradle`: removed duplicate classpath entries

## [v0.8.4] - 2020-09-10

### Added
- `commonGradleBuildReleaseVersion` support for controlling which framework version to use

### Changed
- `common-gradle-build.gradle`: major refactoring of version caching with GitHub release API support
- `common.gradle`: GitHub release-based home directory resolution (~90 lines)
- `openapi.gradle`: enhanced with configurable settings

## [v0.8.2] - 2020-09-09

### Fixed
- `common-gradle-build.gradle`: fixed version file path comparison
- `initialisation.gradle`: added null checks for IS_NEW property
- `eclipse.gradle`: fixed classpath generation

## [v0.8.1] - 2020-09-07

### Added
- `logger.gradle`: new ANSI-aware logging system (128 lines) with color support detection
- `openapi.gradle` project type (355 lines) for OpenAPI code generation with Quarkus/JAX-RS support
- OpenAPI templates: build.gradle, gradle.properties, sample YAML

### Changed
- Node.js defaults and repository settings added to `defaults.gradle`
- `java-base.gradle`: improved source directory handling

## [v0.8.0] - 2020-08-26

### Added
- `exec.gradle`: new command execution utility
- `testcoverage.gradle`: new JaCoCo test coverage support
- `nodejs.gradle` build element (185 lines) for Node.js projects
- `nuxtjs.gradle` project type (89 lines) for Nuxt.js projects
- `quarkus.gradle` project type (88 lines) for Quarkus projects
- `config-home.gradle` project type (81 lines) for organization config home
- Full template suites for Quarkus, Node.js, Checkstyle, Eclipse
- `conf/Resourcebundle.xls` and modelgenerator logger configuration
- Project logo/branding

### Changed
- `common.gradle`: added organization-specific config support via git remote URL-based routing
- `scm/git.gradle`: major expansion with clone, branch, commit, push, tag support
- ~40 lines of new defaults (changelog, node plugin, quarkus)
- Checkstyle and Eclipse templates moved to dedicated directories
- `gitignore.template`: expanded with Node.js, IDE, and OS-specific patterns

## [v0.7.7] - 2020-08-01

### Changed
- `publication.gradle`: added `publishToMavenLocal` task alongside remote publishing

## [v0.7.6] - 2020-07-31

### Added
- `scm/git.gradle`: git remote URL reading functions
- `gradlehome.properties.template`

### Changed
- `publication.gradle`: major refactoring with proper Maven POM generation and repository configuration
- `java/repository.gradle`: expanded with snapshot and staging repository support

## [v0.7.5] - 2020-07-30

### Fixed
- `initialisation.gradle`: removed redundant code block
- `publication.gradle`: fixed publication reference

## [v0.7.4] - 2020-07-29

### Added
- `java/eclipse.gradle`: new Eclipse project file generation (52 lines)
- `eclipse-build-settings.template`

### Changed
- `initialisation.gradle`: added project configuration validation (~26 lines)
- `conf/project-types.properties`: reformatted

## [v0.7.3] - 2020-07-25

### Added
- `config.gradle` project type with publication support
- `config/publication.gradle` (16 lines)
- `config/gradle.properties.template`

### Changed
- `base.gradle`: major reorganization (~86 lines)
- `defaults.gradle`: added configuration project defaults (~33 lines)
- `initialisation.gradle`: major expansion with project validation (~146 lines)

## [v0.7.2] - 2020-07-25

### Changed
- VERSION file format: changed from 3-field to 4-field format (added `qualifier`)
- `version.gradle`: added qualifier support
- `java-base.gradle`: refactored test configuration and source directory setup
- `java/checkstyle.gradle`: added checkstyle version configuration
- Moved config files to `conf/` folder
- Adapted checkstyle configuration

### Fixed
- Eclipse classpath bugfix

## [v0.7.0] - 2020-07-23

### Added
- Initial release of common-gradle-build framework
- Core build elements: base, constants, defaults, version, logger, init, util, file, gradle, properties, github
- Java build elements: java, javaversion, javadoc, checkstyle, test, publication, signing, repository, eclipse
- SCM integration via grgit
- Java library project type
- Template system with property replacement
- Auto-detection of project type from directory structure
- URL-based inclusion pattern (`apply from:`)
- Local caching in `~/.gradle/common-gradle-build/`
