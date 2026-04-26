# Contributing to common-gradle-build

Thank you for your interest in contributing to common-gradle-build! This document explains how to get started.


## Development setup

1. Clone the repository:
   ```bash
   git clone https://github.com/toolarium/common-gradle-build.git
   cd common-gradle-build
   ```

2. Run the tests to verify your setup:
   ```bash
   bash test/template/quarkus/toolarium-java-runner-test.sh
   bash test/template/quarkus/cb-meminfo-test.sh
   bash test/template/nodejs/apply-subpath-test.sh
   ```


## Project structure

- `gradle/common.gradle` — entry point; bootstraps logging, resolves paths, auto-detects project type
- `gradle/*.gradle` — project-type files (`java-library`, `quarkus`, `openapi`, `nodejs`, etc.)
- `gradle/build-element/` — modular, composable Gradle script fragments
  - `base/` — core utilities (logging, constants, properties, versioning, release, security, dependencies, vulnerability scanner, exec, file ops)
  - `java/` — Java-specific (compilation, test, Javadoc, Checkstyle, test coverage, signing, publication)
  - `scm/` — Git integration
  - `doc/` — Asciidoctor support
- `gradle/conf/` — configuration files (dependency whitelists/blacklists, project types)
- `gradle/template/` — scaffolding templates (~85 files) for new projects
- `test/` — shell script test suites
- `docs/` — documentation pages


## How to contribute

### Reporting bugs

Open an [issue](https://github.com/toolarium/common-gradle-build/issues) using the bug report template. Include:
- Operating system and version
- Gradle version
- Steps to reproduce
- Expected vs. actual behavior
- Console output (if applicable)

### Suggesting features

Open an [issue](https://github.com/toolarium/common-gradle-build/issues) using the feature request template.

### Submitting changes

1. Fork the repository and create a branch from `master`.
2. Make your changes following the coding conventions below.
3. Add or update tests for your changes (see below).
4. Update `CHANGELOG.md` under the `[Unreleased]` section.
5. Ensure all tests pass.
6. Submit a pull request.


## Coding conventions

### Gradle scripts

- All scripts use Groovy syntax within Gradle script files (`.gradle`).
- Properties are set via `setCommonGradleDefaultPropertyIfNull()` — check `defaults.gradle` for available defaults.
- Preserve the `apply from:` URL-based inclusion pattern.
- Do not introduce dependencies on Gradle plugins that would require a `buildscript` block in consumer projects — keep everything script-based.

### Shell scripts

- Use `#!/bin/sh` shebang and stick to POSIX-compatible syntax only — no bash-isms (`$BASH_COMMAND`, arrays, `[[ ]]`, `{a..z}`, process substitution `<()`).
- Scripts must run on both bash and Alpine images (BusyBox ash) inside containers.
- Use `grep -F` with `--` separator when matching patterns that may start with `-`.
- Always quote variable expansions: `"$var"` not `$var`.
- Prefer shell built-ins (`case`, parameter expansion) over spawning subprocesses (`sed`, `awk`, `grep`) where possible.
- Use `printf '%s\n'` (not `echo`) when writing content with backslashes to avoid shell-dependent escape interpretation.

### Templates

- Templates use `.template` extension and contain placeholder tokens (`@@tokenName@@`) for project-specific values.


## Versioning and compatibility

This project follows [Semantic Versioning](https://semver.org/):

| Version part | When to increment | Compatibility guarantee |
|---|---|---|
| **Patch** (1.0.**x**) | Bug fixes, documentation updates, internal refactoring | Fully backward compatible. No user-visible behavior changes. Existing consumer projects continue to work identically. |
| **Minor** (1.**x**.0) | New features, new project types, new build elements, new options | Backward compatible. All existing functionality continues to work. New features are additive only — no removal or change of existing behavior. |
| **Major** (**x**.0.0) | Breaking changes | May break backward compatibility. Examples: renamed/removed properties, changed default behavior, removed project types, changed environment variable semantics, restructured configuration files. |

When submitting a change, consider which category it falls into:

- **Patch**: fixing a bug in a build element, correcting a template, improving error handling without changing behavior.
- **Minor**: adding a new project type, adding a new build element, adding a new template, adding a new property.
- **Major**: renaming environment variables, changing the `common.gradle` bootstrapping behavior, removing support for a project type.

If your change introduces a breaking change, clearly document it in your pull request and the `CHANGELOG.md` entry.


## Testing

All changes should include tests where applicable. Test scripts live in `test/`:

- `test/template/quarkus/toolarium-java-runner-test.sh` — JVM runner script tests
- `test/template/quarkus/cb-meminfo-test.sh` — memory info script tests
- `test/template/nodejs/apply-subpath-test.sh` — Node.js subpath tests

**Key rules:**
- Tests use POSIX-compatible assertions (`assert_exit_code`, `assert_output_contains`, `assert_file_contains`, etc.)
- Tests must clean up after themselves (use `trap cleanup EXIT`)
- Use `printf '%s\n'` (not `echo`) when creating test files with backslashes
- Test scripts against both bash and ash (e.g. `docker run --rm alpine sh script.sh`)

Run the full suite:
```bash
bash test/template/quarkus/toolarium-java-runner-test.sh
bash test/template/quarkus/cb-meminfo-test.sh
bash test/template/nodejs/apply-subpath-test.sh
```

### Local testing of Gradle scripts

Test changes locally by setting the `COMMON_GRADLE_BUILD_URL` environment variable to a `file://` path pointing at the local `gradle/` directory:
```bash
export COMMON_GRADLE_BUILD_URL="file:///path/to/common-gradle-build/gradle"
```


## License

By contributing, you agree that your contributions will be licensed under the [GNU General Public License v3](LICENSE).
