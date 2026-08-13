# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**common-gradle-build** is a shared, script-based Gradle build framework (GPL-3.0) distributed via GitHub raw URLs. Consumer projects include it with a single line in their `build.gradle`:

```groovy
apply from: "https://raw.githubusercontent.com/toolarium/common-gradle-build/master/gradle/common.gradle"
```

There is no build process — this project is purely script-based (Gradle/Groovy). Do not attempt to compile or run `gradle build`.

## Architecture

### Entry Point

`gradle/common.gradle` — bootstraps logging, resolves cache/home paths, auto-detects the project type from directory structure, and applies the matching project-type gradle file.

### Project Types (`gradle/*.gradle`)

Top-level gradle files for each supported project type: `java-library`, `java-application`, `quarkus`, `openapi`, `config`, `docker`, `container`, `kubernetes-product`, `nuxtjs`, `vuejs`, `react`, `script`, `documentation`, `testing`, `organization-config`.

### Build Elements (`gradle/build-element/`)

Modular, composable Gradle script fragments:

- **base/** — core utilities (logging, ANSI, constants, properties, versioning, release, security, dependencies, vulnerability-scanner, SonarQube, exec, file ops, JSON, changelog, Kubernetes, container)
- **java/** — Java-specific (compilation, test, Javadoc, Checkstyle, test coverage, Eclipse, repository, publication, signing)
- **scm/** — Git integration (grgit 5.x, credentials via `GRGIT_USER`/`GRGIT_PASS` env vars)
- **doc/** — Asciidoctor support
- **config/** — Publication config
- Aggregators: `base.gradle`, `java-base.gradle`, `language-base.gradle`, `nodejs.gradle`

### Templates (`gradle/template/`)

Scaffolding templates (~90 files) for new projects: build files, Dockerfiles, Kubernetes manifests, Gateway API resources, Java stubs, Playwright test specs, checkstyle configs, Eclipse settings, git configs, READMEs, etc.

## Key Conventions

- All scripts use Groovy syntax within Gradle script files (`.gradle`).
- Properties are set via `setCommonGradleDefaultPropertyIfNull()` — check `defaults.gradle` for available defaults.
- Environment variable overrides: `COMMON_GRADLE_BUILD_CACHE`, `COMMON_GRADLE_BUILD_URL`, `COMMON_GRADLE_BUILD_HOME`, `CB_CUSTOM_CONFIG_VERSION`.
- Organization-specific overrides live in `~/.common-build/conf/` with URL-based routing per git remote.
- Local caching is in `~/.gradle/common-gradle-build/`.
- Templates use `.template` extension and contain placeholder tokens for project-specific values.
- Property replacement uses `String.replace()` (not `replaceAll()`) to avoid regex interpretation of `$` in values.

## Working with This Codebase

- When editing gradle scripts, preserve the `apply from:` URL-based inclusion pattern.
- The `VERSION` file contains the version (`major.number`, `minor.number`, `revision.number`, `qualifier`).
- Do not introduce dependencies on Gradle plugins that would require a `buildscript` block in consumer projects — keep everything script-based.
- Test changes locally by setting `COMMON_GRADLE_BUILD_URL` to a `file://` path pointing at the local `gradle/` directory.
- **Dockerfile templates:** Never split `case` patterns across multiple lines with `\` continuation — Docker flattens continuations and preserves indentation whitespace, breaking pattern matching. Keep all `case` alternatives on a single line.
- **Non-essential binary removal in Dockerfiles:** Use the copy-wipe-restore pattern (`/tmp/bb`) — copy busybox to `/tmp`, wipe `/bin/*` etc., restore busybox and create symlinks. Handles Alpine usr-merge (`/bin` → `/usr/bin`).
- **Shell script compatibility:** All shell scripts must run properly on both bash and Alpine images (BusyBox ash) inside containers. This means:
  - Use `#!/bin/sh` and stick to POSIX-compatible syntax only — no bash-isms (`$BASH_COMMAND`, arrays, `[[ ]]`, `{a..z}`, process substitution `<()`).
  - Use `grep -F` with `--` separator when matching patterns that may start with `-`.
  - Always quote variable expansions (`"$var"`) to prevent word splitting and glob expansion.
  - Prefer shell built-ins (`case`, parameter expansion) over spawning subprocesses (`sed`, `awk`, `grep`) where possible.
  - Test scripts against both bash and ash (e.g. `docker run --rm alpine sh script.sh`).
  - Use Unix line endings (`\n`) for shell script templates — pass `NELINE` as the newLine parameter to `createFileFromTemplate`.

## Vulnerability Scanner

- `vulnerability-scanner.gradle` uses Trivy as an external binary (not a Gradle plugin), following the same pattern as `container.gradle` uses docker/nerdctl.
- Scans dependencies with `trivy rootfs` and container images with `trivy image` (only if `dockerBuild` task executed successfully and no `kubernetesDockerReferenceFile` exists).
- For kubernetes-product projects: scans all referenced container images from `kubernetesDockerReferenceFile` with a summary table (one line per image). Optionally uses `cb-container --scan --csv` for faster cached scanning, falls back to individual `trivy image` calls.
- Integrates with `whitelist-dependencies.properties` and `blacklist-dependencies.properties` — same format, same `getVersionExpression`/`isCompliantVersion` functions.
- Properties files use declared config names (`[implementation]`, `[testRuntimeOnly]`) not resolved names (`compileClasspath`, `runtimeClasspath`).
- Container image whitelist/blacklist uses `[container]` tag (e.g. `[container]registry.k8s.io/ingress-nginx/controller = 1.15.1`). Image names are parsed: `name:vX.Y.Z@sha256:...` → name + version (leading `v` stripped).
- Severity labels: `DENY` (blacklisted), `CRIT` (critical), `HIGH`, `MED` (medium), `LOW` — aligned to 5 chars.
- Snapshot builds scan all severity levels but do not fail the build. Release builds only fail on DENY, CRIT, or HIGH.
- Vulnerabilities without a fix available show `[no fix available]` and don't fail the build (controlled by `vulnerabilityScannerFailWithoutFix`).
- Referenced container image issues don't fail the build by default (controlled by `kubernetesProductFailOnVulnerabilityDependencies`).
- JSON parse errors write raw output to `trivy-scan-error.json` (not dumped to console).
- Output includes dependency tree resolution showing which top-level `build.gradle` dependency to update (with configuration like `implementation`, `transitive`).
- Scanner task timing: wired via `projectValidation.finalizedBy("vulnerabilityScanner")` + `mustRunAfter("build")`. Project types add their own `mustRunAfter` for specific tasks (`customJar` for documentation, `configJar` for config/script). Container projects add `mustRunAfter("dockerBuild")` in `container.gradle`.

## Executable JAR (Main-Class / Class-Path)

- `mainClassName` property sets the `Main-Class` manifest attribute in the JAR, making it executable via `java -jar`.
- `mainClassPath` property sets the `Class-Path` manifest attribute. Use `auto` to resolve from `runtimeClasspath` dependencies, or a space/comma-separated list of JARs.
- Both properties default to empty string (disabled). Defined in `defaults.gradle`, applied conditionally in `java.gradle` jar manifest block.
- Input normalization: commas replaced with spaces, multiple spaces collapsed to single space.

## Sonatype Publishing

- Release publishing uses the OSSRH Staging API: `ossrh-staging-api.central.sonatype.com`
- Snapshot publishing goes to `central.sonatype.com/repository/maven-snapshots/`
- After release upload, `finalizeOssrhUpload()` POSTs to `mavenPublishFinalizeUrl` to make deployment visible in Central Portal (only when publish URL domain matches finalize URL domain).
- Credentials: Central Portal user tokens in `~/.gradle/gradle.properties` as `sonatypeUsername`/`sonatypePassword`.

## Kubernetes & Gateway API

- `kubernetesSupportIngressNginx` is deprecated (ingress-nginx archived March 2026). Template updated to v1.15.1 (final release) with `registry.k8s.io`.
- `kubernetesGatewayApiSupport` enables Gateway API with `kubernetes-httproute.template` and `kubernetes-gateway.template`. When enabled, `kubernetesSupportIngressNginx` is automatically set to `false`.
- Deprecation warning controlled by `kubernetesIngressNginxDeprecationWarning` (default: `true`).

## Color System

- Colors defined in `constants.gradle` via STYLER maps. Supports standard 8-color ANSI and 256-color codes.
- `ERROR_LEVEL` and `SUCCESS_HINT_LEVEL` use background colors with bold bright white foreground (`1;97`) for readability.
- `INFO_LEVEL` uses light lavender (256-color: `38;5;147`), `DEBUG_LEVEL` uses light pink (`38;5;183`).
- `SUCCESS_LEVEL` remains foreground green; `SUCCESS_HINT_LEVEL` is dark green background.
- Plain console mode (`org.gradle.console=plain`) disables all colors via `STYLER_NO_COLOR`.

## Testing

- Shell script tests live in `test/template/quarkus/` — `toolarium-java-runner-test.sh` (83 tests) and `cb-meminfo-test.sh` (60 tests).
- Node.js subpath tests live in `test/template/nodejs/` — `apply-subpath-test.sh` (89 tests).
- Tests use POSIX-compatible assertions (`assert_exit_code`, `assert_output_contains`, `assert_output_not_contains`, `assert_file_contains`, `assert_file_not_contains`, `assert_file_exists`, `assert_file_not_exists`).
- Use `grep -qF --` for pattern matching to handle patterns starting with `-`.
- Use `printf '%s\n'` (not `echo`) when creating test files with backslashes to avoid shell-dependent escape interpretation.
- Run with: `bash test/template/quarkus/toolarium-java-runner-test.sh`, `bash test/template/quarkus/cb-meminfo-test.sh`, and `bash test/template/nodejs/apply-subpath-test.sh`.

## Testing Project Type (Playwright)

- `testing.gradle` — Playwright end-to-end testing with `src/main/ts/tests/` source layout.
- `npmBuild` disabled — tests run only via `cb test` (Gradle `test` task).
- `playwrightInstall` task (Exec type) installs Chromium only if not already present (platform-aware path detection).
- Container entrypoint: `["npx", "playwright", "test"]` (exec form, allows appending args).
- Environment variables: `BASE_URL`, `ENV_NAME` (local/int/acpt/prod), `TESTCASE` (grep filter).
- `dockerFileTemplateName` set to `Dockerfile-node.template`, `dockerEntrypoint` set to exec form.
