#!/usr/bin/env bash

#########################################################################
#
# dockerfile-test.sh
#
# Copyright by toolarium, all rights reserved.
#
# This file is part of the toolarium common-gradle-build.
#
# The common-gradle-build is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# The common-gradle-build is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Foobar. If not, see <http://www.gnu.org/licenses/>.
#
#########################################################################
#
# Tests Dockerfile templates by rendering @@placeholders@@ with test
# values and validating the results at three levels:
#
#   Level 0 (default, no Docker required):
#     - Renders each template with default + variant values
#     - Asserts no unresolved @@token@@ remains
#
#   Level 1 --lint (needs Docker 27+ with BuildKit):
#     - All Level 0 checks
#     - docker build --check (syntax / best-practice lint, no actual build)
#
#   Level 2 --build (needs Docker + internet access to pull base images):
#     - All Level 0 checks
#     - Full docker build for each boolean flag combination
#     - Tests all branches in REMOVE_NON_ESSENTIAL_BINARIES,
#       MAKE_FILESYSTEM_READONLY, REMOVE_PACKAGE_INSTALLATION_BINARIES,
#       ENABLE_ACCESS_LOG
#
# Usage:
#   bash test/template/dockerfile/dockerfile-test.sh
#   bash test/template/dockerfile/dockerfile-test.sh --lint
#   bash test/template/dockerfile/dockerfile-test.sh --build
#
# Boolean flag combinations tested per template (2^N matrix):
#   base, docker:        2 flags  -> 4 combinations
#   quarkus, nodejs:     3 flags  -> 8 combinations
#   kubernetes, node:    4 flags  -> 16 combinations
#
#########################################################################

SCRIPT_DIR=$(cd -- "$(dirname "$0" 2>/dev/null)" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../../.." && pwd)
TEMPLATE_DIR="$REPO_DIR/gradle/template"
TEST_DIR=$(mktemp -d)
LEVEL=0
PASSED=0
FAILED=0
TOTAL=0

case "$1" in
    --lint)  LEVEL=1 ;;
    --build) LEVEL=2 ;;
    --help|-h)
        printf "Usage: %s [--lint|--build]\n" "$0"
        printf "  (no flag)  placeholder substitution checks only\n"
        printf "  --lint     + docker build --check (needs Docker 27+)\n"
        printf "  --build    + full docker build per flag combination\n"
        exit 0
        ;;
esac

#########################################################################
# cleanup
#########################################################################
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

#########################################################################
# Assertion helpers (same pattern as toolarium-java-runner-test.sh)
#########################################################################
assert_file_not_contains() {
    local test_name="$1" pattern="$2" file="$3"
    TOTAL=$((TOTAL + 1))
    if grep -qF -- "$pattern" "$file" 2>/dev/null; then
        printf "  FAIL: %s (unexpected '%s' in %s)\n" "$test_name" "$pattern" "$file"
        grep -nF -- "$pattern" "$file" | head -5 | while IFS= read -r line; do
            printf "        %s\n" "$line"
        done
        FAILED=$((FAILED + 1))
    else
        printf "  PASS: %s\n" "$test_name"
        PASSED=$((PASSED + 1))
    fi
}

assert_file_contains() {
    local test_name="$1" pattern="$2" file="$3"
    TOTAL=$((TOTAL + 1))
    if grep -qF -- "$pattern" "$file" 2>/dev/null; then
        printf "  PASS: %s\n" "$test_name"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (expected '%s' in %s)\n" "$test_name" "$pattern" "$file"
        FAILED=$((FAILED + 1))
    fi
}

assert_exit_code() {
    local test_name="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" -eq "$expected" ]; then
        printf "  PASS: %s (exit %s)\n" "$test_name" "$actual"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (expected exit %s, got %s)\n" "$test_name" "$expected" "$actual"
        FAILED=$((FAILED + 1))
    fi
}

#########################################################################
# render_template <input> <output> [KEY=VALUE ...]
#
# Substitutes all @@placeholders@@ with test values.
# Overrides (optional, KEY=VALUE pairs):
#   RM_NON_ESSENTIAL   true|false   (dockerRemoveNonEssentialBinaries)
#   MAKE_READONLY      true|false   (dockerMakeFilesystemReadonly)
#   RM_PKG_BINARIES    true|false   (dockerRemovePackageInstallationBinaries)
#   ENABLE_ACCESS_LOG  true|false   (dockerEnableAccessLog)
#   SUBPATH            string       (dockerSubPathAccess)
#   DOCKER_IMAGE       image:tag    (dockerImage, first FROM)
#   DOCKER_RUNTIME_IMAGE image:tag  (dockerRuntimeImage, second FROM in multistage)
#   DOCKER_ENTRYPOINT  string       (dockerEntrypoint, raw value after ENTRYPOINT)
#########################################################################
render_template() {
    local input="$1" output="$2"
    shift 2

    # Defaults matching defaults.gradle values
    local rm_ne="true"
    local make_ro="true"
    local rm_pkg="true"
    local access_log="false"
    local subpath=""
    local docker_image="alpine:3.21"
    local docker_runtime_image="alpine:3.21"
    local docker_entrypoint='"node", "server.js"'

    for pair in "$@"; do
        local key="${pair%%=*}"
        local val="${pair#*=}"
        case "$key" in
            RM_NON_ESSENTIAL)    rm_ne="$val" ;;
            MAKE_READONLY)       make_ro="$val" ;;
            RM_PKG_BINARIES)     rm_pkg="$val" ;;
            ENABLE_ACCESS_LOG)   access_log="$val" ;;
            SUBPATH)             subpath="$val" ;;
            DOCKER_IMAGE)        docker_image="$val" ;;
            DOCKER_RUNTIME_IMAGE) docker_runtime_image="$val" ;;
            DOCKER_ENTRYPOINT)   docker_entrypoint="$val" ;;
        esac
    done

    # Use | as sed delimiter to avoid conflicts with / in paths
    sed \
        -e "s|@@LICENSE_ORGANISATION@@|Test-Org|g" \
        -e "s|@@LICENSE@@|GPL-3.0|g" \
        -e "s|@@GROUP_ID@@|com.example|g" \
        -e "s|@@COMPONENT_ID@@|test-app|g" \
        -e "s|@@DESCRIPTION@@|Test Application|g" \
        -e "s|@@URL@@|https://example.com|g" \
        -e "s|@@VERSION@@|1.0.0-SNAPSHOT|g" \
        -e "s|@@IS_RELEASE_VERSION@@|false|g" \
        -e "s|@@BUILD_TIMESTAMP_SHORT@@|2026-07-18|g" \
        -e "s|@@dockerImage@@|${docker_image}|g" \
        -e "s|@@dockerRuntimeImage@@|${docker_runtime_image}|g" \
        -e "s|@@dockerExposePort@@|8080|g" \
        -e "s|@@dockerUser@@|appuser|g" \
        -e "s|@@dockerTimezone@@|UTC|g" \
        -e "s|@@dockerDeploymentSourcePath@@|build/app|g" \
        -e "s|@@dockerDefaultEncoding@@|UTF-8|g" \
        -e "s|@@dockerDefaultLocale@@|en_US|g" \
        -e "s|@@dockerDefaultLanguage@@|en|g" \
        -e "s|@@dockerDefaultJavaOptions@@|-Djava.security.egd=file:/dev/./urandom|g" \
        -e "s|@@dockerJavaOptions@@|-Djava.security.egd=file:/dev/./urandom|g" \
        -e "s|@@dockerRemoveNonEssentialBinaries@@|${rm_ne}|g" \
        -e "s|@@dockerMakeFilesystemReadonly@@|${make_ro}|g" \
        -e "s|@@dockerReadonlyFilesystemPath@@|/etc /usr /lib|g" \
        -e "s|@@dockerReadonlyFilesystemExcludePath@@|/etc/ssl/certs|g" \
        -e "s|@@dockerRemovePackageInstallationBinaries@@|${rm_pkg}|g" \
        -e "s|@@dockerEnableAccessLog@@|${access_log}|g" \
        -e "s|@@dockerSubPathAccess@@|${subpath}|g" \
        -e "s|@@dockerScriptPath@@|build/scripts|g" \
        -e "s|@@dockerJavaRunner@@|toolarium-java-runner.sh|g" \
        -e "s|@@dockerMeminfo@@|cb-meminfo.sh|g" \
        -e "s|@@dockerOsPrettyName@@|Alpine Linux 3.21|g" \
        -e "s|@@dockerProxyHost@@||g" \
        -e "s|@@dockerProxyPort@@||g" \
        -e "s|@@dockerNoProxyHosts@@||g" \
        -e "s|@@dockerJavaAgent@@||g" \
        -e "s|@@dockerHttpAgent@@||g" \
        -e "s|@@dockerKeepAlive@@||g" \
        -e "s|@@dockerMaxConnections@@||g" \
        -e "s|@@dockerMaxRedirects@@||g" \
        -e "s|@@dockerLogLevel@@||g" \
        -e "s|@@dockerGc@@|UseG1GC|g" \
        -e "s|@@dockerGcLogging@@||g" \
        -e "s|@@dockerExitOnOutOfMemory@@|true|g" \
        -e "s|@@dockerNativeMemoryTracking@@|true|g" \
        -e "s|@@dockerObserveMemoryCycle@@|5|g" \
        -e "s|@@dockerEntrypoint@@|${docker_entrypoint}|g" \
        -e "s|@@PROJECT_NAME@@|test-app|g" \
        -e "s|@@dockerRemoveImageVersion@@|false|g" \
        -e "s|@@dockerRemovePackageVersions@@|false|g" \
        "$input" > "$output"
}

#########################################################################
# check_no_placeholders <label> <file>
# Asserts no @@token@@ remains after rendering.
#########################################################################
check_no_placeholders() {
    assert_file_not_contains "$1: no unresolved @@placeholders@@" "@@" "$2"
}

#########################################################################
# docker_lint <label> <dockerfile>
# Runs `docker build --check` (BuildKit lint, no actual build).
# Requires Docker 27+ (or docker buildx with recent BuildKit).
#
# Exit-code semantics from docker build --check:
#   0  = clean
#   1  = warnings or errors present
# We treat WARNING-only exits as non-failing (WARN) and only FAIL on
# actual ERROR-level issues, since some warnings are intentional (e.g.
# shell-form ENTRYPOINT to allow runtime variable expansion).
#########################################################################
docker_lint() {
    local label="$1" dockerfile="$2"
    local ctx="$TEST_DIR/empty-ctx"
    mkdir -p "$ctx"
    TOTAL=$((TOTAL + 1))
    local output rc
    output=$(DOCKER_BUILDKIT=1 docker build --check -f "$dockerfile" "$ctx" 2>&1)
    rc=$?
    if [ $rc -eq 0 ]; then
        printf "  PASS: %s (lint)\n" "$label"
        PASSED=$((PASSED + 1))
    elif printf '%s\n' "$output" | grep -qF 'ERROR:'; then
        # Actual errors (not just warnings) — real failure
        printf "  FAIL: %s (lint, exit %s)\n" "$label" "$rc"
        printf '%s\n' "$output" | grep -E 'ERROR:|WARNING:|Check complete' | while IFS= read -r line; do
            printf "        %s\n" "$line"
        done
        FAILED=$((FAILED + 1))
    else
        # Only warnings — non-fatal; print them so they are visible but pass
        printf "  WARN: %s (lint warnings, exit %s)\n" "$label" "$rc"
        printf '%s\n' "$output" | grep -E 'WARNING:|Check complete' | while IFS= read -r line; do
            printf "        %s\n" "$line"
        done
        PASSED=$((PASSED + 1))
    fi
}

#########################################################################
# docker_build_full <label> <dockerfile> <context_dir>
# Performs an actual `docker build` and cleans up the image afterwards.
#########################################################################
docker_build_full() {
    local label="$1" dockerfile="$2" ctx="$3"
    local tag
    tag="dockerfile-test-$(printf '%s' "$label" | tr ' =/' '---' | tr '[:upper:]' '[:lower:]')"
    TOTAL=$((TOTAL + 1))
    local output rc
    output=$(DOCKER_BUILDKIT=1 docker build --no-cache -f "$dockerfile" -t "$tag" "$ctx" 2>&1)
    rc=$?
    if [ $rc -eq 0 ]; then
        printf "  PASS: %s (full build)\n" "$label"
        PASSED=$((PASSED + 1))
        docker rmi "$tag" >/dev/null 2>&1 || true
    else
        printf "  FAIL: %s (full build, exit %s)\n" "$label" "$rc"
        printf "%s\n" "$output" | tail -30 | while IFS= read -r line; do
            printf "        %s\n" "$line"
        done
        FAILED=$((FAILED + 1))
    fi
}

#########################################################################
# Fixture helpers for level 2 builds
# Each returns the path to the build context directory via echo.
#########################################################################
setup_java_fixtures() {
    local dir="$TEST_DIR/ctx-java"
    mkdir -p "$dir/build/app"
    touch "$dir/build/app/app.jar"
    echo "$dir"
}

setup_quarkus_fixtures() {
    local dir="$TEST_DIR/ctx-quarkus"
    mkdir -p "$dir/build/quarkus-app/lib"
    printf '#!/bin/sh\nexec java "$@"\n' > "$dir/build/quarkus-app/toolarium-java-runner.sh"
    printf '#!/bin/sh\necho meminfo\n' > "$dir/build/quarkus-app/cb-meminfo.sh"
    touch "$dir/build/quarkus-app/quarkus-run.jar"
    echo "$dir"
}

setup_docker_fixtures() {
    local dir="$TEST_DIR/ctx-docker"
    mkdir -p "$dir/build/app"
    touch "$dir/build/app/index.html"
    echo "$dir"
}

setup_nodejs_fixtures() {
    local dir="$TEST_DIR/ctx-nodejs"
    mkdir -p "$dir/build/app"
    touch "$dir/build/app/index.js"
    # scripts required by Dockerfile-node.template
    mkdir -p "$dir/build/scripts"
    printf '#!/bin/sh\necho apply-subpath\n' > "$dir/build/scripts/apply-subpath.sh"
    touch "$dir/build/scripts/service.properties"
    echo "$dir"
}

setup_kubernetes_fixtures() {
    local dir="$TEST_DIR/ctx-kubernetes"
    mkdir -p "$dir/build/app"
    touch "$dir/build/app/index.html"
    echo "$dir"
}

#########################################################################
# Helper: render + check_no_placeholders in one step.
# render_check <unique_slug> <template> [overrides...]
# Returns the path to the rendered file in $RENDERED_FILE.
#########################################################################
render_check() {
    local slug="$1" tmpl="$2"
    shift 2
    RENDERED_FILE="$TEST_DIR/${slug}.Dockerfile"
    render_template "$tmpl" "$RENDERED_FILE" "$@"
    check_no_placeholders "$slug" "$RENDERED_FILE"
}

#########################################################################
# Check Docker availability for levels 1 and 2
#########################################################################
if [ "$LEVEL" -ge 1 ] && ! command -v docker >/dev/null 2>&1; then
    printf "ERROR: docker not found in PATH; --lint and --build require Docker.\n" >&2
    exit 1
fi

#########################################################################
#
# === base/Dockerfile.template ===
# Flags: MAKE_FILESYSTEM_READONLY, REMOVE_PACKAGE_INSTALLATION_BINARIES
#
#########################################################################
printf "\n=== base/Dockerfile.template ===\n"
TMPL="$TEMPLATE_DIR/base/Dockerfile.template"

render_check "base-defaults"   "$TMPL"
render_check "base-all-false"  "$TMPL" "MAKE_READONLY=false" "RM_PKG_BINARIES=false"
render_check "base-ro-only"    "$TMPL" "MAKE_READONLY=true"  "RM_PKG_BINARIES=false"
render_check "base-pkg-only"   "$TMPL" "MAKE_READONLY=false" "RM_PKG_BINARIES=true"

if [ "$LEVEL" -ge 1 ]; then
    render_template "$TMPL" "$TEST_DIR/base-lint.Dockerfile"
    docker_lint "base default" "$TEST_DIR/base-lint.Dockerfile"
fi

if [ "$LEVEL" -ge 2 ]; then
    CTX=$(setup_java_fixtures)
    for ro in true false; do
        for pkg in true false; do
            slug="base-${ro}-${pkg}"
            out="$TEST_DIR/${slug}.Dockerfile"
            render_template "$TMPL" "$out" "MAKE_READONLY=$ro" "RM_PKG_BINARIES=$pkg"
            docker_build_full "base ro=$ro pkg=$pkg" "$out" "$CTX"
        done
    done
fi

#########################################################################
#
# === docker/Dockerfile.template ===
# Flags: MAKE_FILESYSTEM_READONLY, REMOVE_PACKAGE_INSTALLATION_BINARIES
# Extra: @@dockerEntrypoint@@ used inside ENTRYPOINT [ ... ]
#
#########################################################################
printf "\n=== docker/Dockerfile.template ===\n"
TMPL="$TEMPLATE_DIR/docker/Dockerfile.template"

render_check "docker-defaults"  "$TMPL" 'DOCKER_ENTRYPOINT="sh", "-c", "echo hello"'
render_check "docker-all-false" "$TMPL" \
    "MAKE_READONLY=false" "RM_PKG_BINARIES=false" \
    'DOCKER_ENTRYPOINT="sh", "-c", "echo hello"'

if [ "$LEVEL" -ge 1 ]; then
    render_template "$TMPL" "$TEST_DIR/docker-lint.Dockerfile" 'DOCKER_ENTRYPOINT="sh", "-c", "echo hello"'
    docker_lint "docker default" "$TEST_DIR/docker-lint.Dockerfile"
fi

if [ "$LEVEL" -ge 2 ]; then
    CTX=$(setup_docker_fixtures)
    for ro in true false; do
        for pkg in true false; do
            slug="docker-${ro}-${pkg}"
            out="$TEST_DIR/${slug}.Dockerfile"
            render_template "$TMPL" "$out" \
                "MAKE_READONLY=$ro" "RM_PKG_BINARIES=$pkg" \
                'DOCKER_ENTRYPOINT="sh", "-c", "echo hello"'
            docker_build_full "docker ro=$ro pkg=$pkg" "$out" "$CTX"
        done
    done
fi

#########################################################################
#
# === kubernetes/Dockerfile.template ===
# Base: nginx:alpine
# Flags: REMOVE_NON_ESSENTIAL_BINARIES, MAKE_FILESYSTEM_READONLY,
#        REMOVE_PACKAGE_INSTALLATION_BINARIES, ENABLE_ACCESS_LOG
# Extra: SUBPATH variant
#
#########################################################################
printf "\n=== kubernetes/Dockerfile.template ===\n"
TMPL="$TEMPLATE_DIR/kubernetes/Dockerfile.template"

render_check "k8s-defaults"    "$TMPL" "DOCKER_IMAGE=nginx:alpine"
render_check "k8s-all-false"   "$TMPL" "DOCKER_IMAGE=nginx:alpine" \
    "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=false" "ENABLE_ACCESS_LOG=true"
render_check "k8s-subpath"     "$TMPL" "DOCKER_IMAGE=nginx:alpine" "SUBPATH=myapp/"
render_check "k8s-acclog-on"   "$TMPL" "DOCKER_IMAGE=nginx:alpine" "ENABLE_ACCESS_LOG=true"

if [ "$LEVEL" -ge 1 ]; then
    render_template "$TMPL" "$TEST_DIR/k8s-lint.Dockerfile" "DOCKER_IMAGE=nginx:alpine"
    docker_lint "kubernetes default" "$TEST_DIR/k8s-lint.Dockerfile"
fi

if [ "$LEVEL" -ge 2 ]; then
    CTX=$(setup_kubernetes_fixtures)
    for ne in true false; do
        for ro in true false; do
            for pkg in true false; do
                for al in true false; do
                    slug="k8s-${ne}-${ro}-${pkg}-${al}"
                    out="$TEST_DIR/${slug}.Dockerfile"
                    render_template "$TMPL" "$out" \
                        "DOCKER_IMAGE=nginx:alpine" \
                        "RM_NON_ESSENTIAL=$ne" "MAKE_READONLY=$ro" \
                        "RM_PKG_BINARIES=$pkg" "ENABLE_ACCESS_LOG=$al"
                    docker_build_full "k8s ne=$ne ro=$ro pkg=$pkg al=$al" "$out" "$CTX"
                done
            done
        done
    done
fi

#########################################################################
#
# === nodejs/Dockerfile.template ===
# Base: nginx:alpine  (nginx, apply-subpath.sh, no ENTRYPOINT placeholder)
# Flags: REMOVE_NON_ESSENTIAL_BINARIES, MAKE_FILESYSTEM_READONLY,
#        REMOVE_PACKAGE_INSTALLATION_BINARIES, ENABLE_ACCESS_LOG
# Extra: SUBPATH, DEPLOYMENT_SCRIPT_PATH (apply-subpath.sh + *.properties)
#
#########################################################################
printf "\n=== nodejs/Dockerfile.template ===\n"
TMPL="$TEMPLATE_DIR/nodejs/Dockerfile.template"

render_check "nodejs-defaults"  "$TMPL" "DOCKER_IMAGE=nginx:alpine"
render_check "nodejs-all-false" "$TMPL" "DOCKER_IMAGE=nginx:alpine" \
    "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=false" "ENABLE_ACCESS_LOG=true"
render_check "nodejs-subpath"   "$TMPL" "DOCKER_IMAGE=nginx:alpine" "SUBPATH=app/"
render_check "nodejs-acclog-on" "$TMPL" "DOCKER_IMAGE=nginx:alpine" "ENABLE_ACCESS_LOG=true"

if [ "$LEVEL" -ge 1 ]; then
    render_template "$TMPL" "$TEST_DIR/nodejs-lint.Dockerfile" "DOCKER_IMAGE=nginx:alpine"
    docker_lint "nodejs/Dockerfile.template default" "$TEST_DIR/nodejs-lint.Dockerfile"
fi

if [ "$LEVEL" -ge 2 ]; then
    CTX=$(setup_nodejs_fixtures)
    for ne in true false; do
        for ro in true false; do
            for pkg in true false; do
                for al in true false; do
                    slug="nodejs-${ne}-${ro}-${pkg}-${al}"
                    out="$TEST_DIR/${slug}.Dockerfile"
                    render_template "$TMPL" "$out" \
                        "DOCKER_IMAGE=nginx:alpine" \
                        "RM_NON_ESSENTIAL=$ne" "MAKE_READONLY=$ro" \
                        "RM_PKG_BINARIES=$pkg" "ENABLE_ACCESS_LOG=$al"
                    docker_build_full "Dockerfile ne=$ne ro=$ro pkg=$pkg al=$al" "$out" "$CTX"
                done
            done
        done
    done
fi

#########################################################################
#
# === nodejs/Dockerfile-node.template ===
# Base: node:22-alpine  (nuxt/node runtime, has @@dockerEntrypoint@@)
# Flags: REMOVE_NON_ESSENTIAL_BINARIES, MAKE_FILESYSTEM_READONLY,
#        REMOVE_PACKAGE_INSTALLATION_BINARIES
# Extra: @@dockerEntrypoint@@ — exec form via nuxtjs.gradle:
#        ["/bin/sh", "-c", "NUXT_PORT=${EXPOSE_PORT} exec npm start"]
#
#########################################################################
printf "\n=== nodejs/Dockerfile-node.template ===\n"
TMPL="$TEMPLATE_DIR/nodejs/Dockerfile-node.template"
# Match the exec-form value set by nuxtjs.gradle
NUXT_ENTRYPOINT='["/bin/sh", "-c", "NUXT_PORT=${EXPOSE_PORT} exec npm start"]'

render_check "node-defaults"    "$TMPL" \
    "DOCKER_IMAGE=node:22-alpine" "DOCKER_ENTRYPOINT=$NUXT_ENTRYPOINT"
render_check "node-all-false"   "$TMPL" \
    "DOCKER_IMAGE=node:22-alpine" "DOCKER_ENTRYPOINT=$NUXT_ENTRYPOINT" \
    "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=false"

if [ "$LEVEL" -ge 1 ]; then
    render_template "$TMPL" "$TEST_DIR/node-lint.Dockerfile" \
        "DOCKER_IMAGE=node:22-alpine" "DOCKER_ENTRYPOINT=$NUXT_ENTRYPOINT"
    docker_lint "nodejs/Dockerfile-node.template default" "$TEST_DIR/node-lint.Dockerfile"
fi

if [ "$LEVEL" -ge 2 ]; then
    CTX=$(setup_nodejs_fixtures)
    for ne in true false; do
        for ro in true false; do
            for pkg in true false; do
                slug="node-${ne}-${ro}-${pkg}"
                out="$TEST_DIR/${slug}.Dockerfile"
                render_template "$TMPL" "$out" \
                    "DOCKER_IMAGE=node:22-alpine" \
                    "DOCKER_ENTRYPOINT=$NUXT_ENTRYPOINT" \
                    "RM_NON_ESSENTIAL=$ne" "MAKE_READONLY=$ro" "RM_PKG_BINARIES=$pkg"
                docker_build_full "Dockerfile-node ne=$ne ro=$ro pkg=$pkg" "$out" "$CTX"
            done
        done
    done
fi

#########################################################################
#
# === quarkus/Dockerfile.template ===
# Base: eclipse-temurin:21-jre-alpine
# Flags: REMOVE_NON_ESSENTIAL_BINARIES, MAKE_FILESYSTEM_READONLY,
#        REMOVE_PACKAGE_INSTALLATION_BINARIES
#
#########################################################################
printf "\n=== quarkus/Dockerfile.template ===\n"
TMPL="$TEMPLATE_DIR/quarkus/Dockerfile.template"

render_check "quarkus-defaults"  "$TMPL" "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine"
render_check "quarkus-all-false" "$TMPL" "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine" \
    "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=false"

if [ "$LEVEL" -ge 1 ]; then
    render_template "$TMPL" "$TEST_DIR/quarkus-lint.Dockerfile" \
        "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine"
    docker_lint "quarkus default" "$TEST_DIR/quarkus-lint.Dockerfile"
fi

if [ "$LEVEL" -ge 2 ]; then
    CTX=$(setup_quarkus_fixtures)
    for ne in true false; do
        for ro in true false; do
            for pkg in true false; do
                slug="quarkus-${ne}-${ro}-${pkg}"
                out="$TEST_DIR/${slug}.Dockerfile"
                render_template "$TMPL" "$out" \
                    "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine" \
                    "RM_NON_ESSENTIAL=$ne" "MAKE_READONLY=$ro" "RM_PKG_BINARIES=$pkg"
                docker_build_full "quarkus ne=$ne ro=$ro pkg=$pkg" "$out" "$CTX"
            done
        done
    done
fi

#########################################################################
#
# === quarkus/Dockerfile-java-runner.template ===
# Base: eclipse-temurin:21-jre-alpine
# Flags: REMOVE_NON_ESSENTIAL_BINARIES, MAKE_FILESYSTEM_READONLY,
#        REMOVE_PACKAGE_INSTALLATION_BINARIES
# Extra: dockerJavaRunner, dockerMeminfo, dockerOsPrettyName,
#        all JVM tuning ARGs (proxy, gc, memory, etc.)
#
#########################################################################
printf "\n=== quarkus/Dockerfile-java-runner.template ===\n"
TMPL="$TEMPLATE_DIR/quarkus/Dockerfile-java-runner.template"

render_check "java-runner-defaults"  "$TMPL" "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine"
render_check "java-runner-all-false" "$TMPL" "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine" \
    "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=false"

if [ "$LEVEL" -ge 1 ]; then
    render_template "$TMPL" "$TEST_DIR/java-runner-lint.Dockerfile" \
        "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine"
    docker_lint "java-runner default" "$TEST_DIR/java-runner-lint.Dockerfile"
fi

if [ "$LEVEL" -ge 2 ]; then
    CTX=$(setup_quarkus_fixtures)
    for ne in true false; do
        for ro in true false; do
            for pkg in true false; do
                slug="java-runner-${ne}-${ro}-${pkg}"
                out="$TEST_DIR/${slug}.Dockerfile"
                render_template "$TMPL" "$out" \
                    "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine" \
                    "RM_NON_ESSENTIAL=$ne" "MAKE_READONLY=$ro" "RM_PKG_BINARIES=$pkg"
                docker_build_full "java-runner ne=$ne ro=$ro pkg=$pkg" "$out" "$CTX"
            done
        done
    done
fi

#########################################################################
#
# === quarkus/Dockerfile-java-runner-multistage.template ===
# Stage 1 (jdk): eclipse-temurin:21-alpine  (needs jlink)
# Stage 2 (runtime): alpine:3.21
# Flags: REMOVE_NON_ESSENTIAL_BINARIES, MAKE_FILESYSTEM_READONLY,
#        REMOVE_PACKAGE_INSTALLATION_BINARIES
#
#########################################################################
printf "\n=== quarkus/Dockerfile-java-runner-multistage.template ===\n"
TMPL="$TEMPLATE_DIR/quarkus/Dockerfile-java-runner-multistage.template"

render_check "multistage-defaults"  "$TMPL" \
    "DOCKER_IMAGE=eclipse-temurin:21-alpine" "DOCKER_RUNTIME_IMAGE=alpine:3.21"
render_check "multistage-all-false" "$TMPL" \
    "DOCKER_IMAGE=eclipse-temurin:21-alpine" "DOCKER_RUNTIME_IMAGE=alpine:3.21" \
    "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=false"

if [ "$LEVEL" -ge 1 ]; then
    render_template "$TMPL" "$TEST_DIR/multistage-lint.Dockerfile" \
        "DOCKER_IMAGE=eclipse-temurin:21-alpine" "DOCKER_RUNTIME_IMAGE=alpine:3.21"
    docker_lint "java-runner-multistage default" "$TEST_DIR/multistage-lint.Dockerfile"
fi

if [ "$LEVEL" -ge 2 ]; then
    CTX=$(setup_quarkus_fixtures)
    for ne in true false; do
        for ro in true false; do
            for pkg in true false; do
                slug="multistage-${ne}-${ro}-${pkg}"
                out="$TEST_DIR/${slug}.Dockerfile"
                render_template "$TMPL" "$out" \
                    "DOCKER_IMAGE=eclipse-temurin:21-alpine" \
                    "DOCKER_RUNTIME_IMAGE=alpine:3.21" \
                    "RM_NON_ESSENTIAL=$ne" "MAKE_READONLY=$ro" "RM_PKG_BINARIES=$pkg"
                docker_build_full "multistage ne=$ne ro=$ro pkg=$pkg" "$out" "$CTX"
            done
        done
    done
fi

#########################################################################
# Summary
#########################################################################
printf "\n=== Summary (level=%s) ===\n" "$LEVEL"
printf "  Passed: %s / %s\n" "$PASSED" "$TOTAL"
printf "  Failed: %s / %s\n" "$FAILED" "$TOTAL"
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
