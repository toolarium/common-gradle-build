# Security

## Reporting a vulnerability

If you discover a security vulnerability in common-gradle-build, please report it privately by opening a [GitHub Security Advisory](https://github.com/toolarium/common-gradle-build/security/advisories/new) rather than a public issue.

Alternatively, contact the maintainers via the email address listed on the [toolarium GitHub organization profile](https://github.com/toolarium).

## Scope

common-gradle-build is included by consumer projects via `apply from:` with a raw GitHub URL. It executes Gradle/Groovy scripts, generates files from templates, runs shell scripts inside containers, and integrates with external tools (Trivy, Docker/nerdctl, SonarQube). Vulnerabilities in any of these areas are in scope:

- Script injection via template placeholder tokens or property values
- Path traversal in template generation or file operations
- Dependency confusion or manipulation via whitelist/blacklist bypass
- Shell injection in `exec` or command-building utilities
- Unauthorized file modification during build or container startup
- Insecure defaults in generated Dockerfiles, nginx configs, or Kubernetes manifests

## Response

We will acknowledge reports within 7 days and aim to provide a fix or mitigation within 30 days, depending on severity.
