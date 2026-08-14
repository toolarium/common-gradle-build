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
#   --cert (needs Docker, openssl + internet access, combinable with the
#   levels above):
#     - Builds our image, adds the customer certificate overlay on top and
#       verifies in the running container that the certificate is trusted
#     - Every template x hardening combination must work
#
# Usage:
#   bash test/template/dockerfile/dockerfile-test.sh
#   bash test/template/dockerfile/dockerfile-test.sh --lint
#   bash test/template/dockerfile/dockerfile-test.sh --build
#   bash test/template/dockerfile/dockerfile-test.sh --cert
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
CERT_TEST=0
PASSED=0
FAILED=0
TOTAL=0

for arg in "$@"; do
    case "$arg" in
        --lint)  LEVEL=1 ;;
        --build) LEVEL=2 ;;
        --cert)  CERT_TEST=1 ;;
        --help|-h)
            printf "Usage: %s [--lint|--build] [--cert]\n" "$0"
            printf "  (no flag)  placeholder substitution checks only\n"
            printf "  --lint     + docker build --check (needs Docker 27+)\n"
            printf "  --build    + full docker build per flag combination\n"
            printf "  --cert     + customer certificate overlay test (needs Docker, openssl, network)\n"
            exit 0
            ;;
        *)
            printf "ERROR: unknown option '%s' (see --help).\n" "$arg" >&2
            exit 1
            ;;
    esac
done

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
#   ADDITIONAL_PACKAGES string      (dockerAdditionalPackages, extra apk packages)
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
    local additional_packages=""
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
            ADDITIONAL_PACKAGES) additional_packages="$val" ;;
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
        -e "s|@@dockerAdditionalPackages@@|${additional_packages}|g" \
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
        -e "s|@@dockerJlinkModules@@|java.base,java.compiler,java.logging,java.naming,java.sql,java.transaction.xa,java.management,java.net.http,java.security.jgss,java.security.sasl,java.xml,java.xml.crypto,java.prefs,java.desktop,jdk.management,jdk.management.agent,jdk.unsupported,jdk.crypto.ec,jdk.crypto.cryptoki,jdk.zipfs,jdk.net,jdk.jcmd,jdk.naming.dns|g" \
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
# check_update_ca_certificates_preserved <slug>
# Asserts that the full CA-update chain is saved/restored through the wipe:
#   update-ca-certificates, c_rehash, openssl (run-parts/readlink are busybox applets).
#########################################################################
check_update_ca_certificates_preserved() {
    local file="$TEST_DIR/${1}.Dockerfile"
    assert_file_contains "$1: update-ca-certificates saved before wipe" \
        "update-ca-certificates ] && /tmp/busybox cp /usr/sbin/update-ca-certificates /tmp/update-ca-certificates" "$file"
    assert_file_contains "$1: update-ca-certificates restored after wipe" \
        "update-ca-certificates ] && /bin/cp /tmp/update-ca-certificates /usr/sbin/update-ca-certificates" "$file"
    assert_file_contains "$1: c_rehash saved before wipe" \
        "c_rehash ] && /tmp/busybox cp /usr/bin/c_rehash /tmp/c_rehash" "$file"
    assert_file_contains "$1: c_rehash restored after wipe" \
        "c_rehash ] && /bin/cp /tmp/c_rehash /usr/bin/c_rehash" "$file"
    assert_file_contains "$1: openssl saved before wipe" \
        "openssl ] && /tmp/busybox cp /usr/bin/openssl /tmp/openssl" "$file"
    assert_file_contains "$1: openssl restored after wipe" \
        "openssl ] && /bin/cp /tmp/openssl /usr/bin/openssl" "$file"
    assert_file_contains "$1: readlink and run-parts in busybox symlinks" \
        "readlink run-parts" "$file"
}

#########################################################################
# setup_test_cert <ctx_dir>
# Generates a self-signed test CA cert in <ctx_dir>/cacerts/ using openssl.
# Returns 0 on success, 1 if openssl is not available or generation fails.
#########################################################################
setup_test_cert() {
    local ctx="$1"
    command -v openssl >/dev/null 2>&1 || return 1
    mkdir -p "$ctx/cacerts"
    openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
        -keyout "$ctx/cacerts/test-ca.key" \
        -out    "$ctx/cacerts/test-ca.crt" \
        -subj   "/CN=Test-CA" 2>/dev/null || return 1
    rm -f "$ctx/cacerts/test-ca.key"
    return 0
}

#########################################################################
# docker_build_enhancement <label> <enhancement_dockerfile> <ctx>
# Builds a Dockerfile that extends a hardened image with cert installation.
# Cleans up only the enhancement image; the caller owns the base tag.
#########################################################################
docker_build_enhancement() {
    local label="$1" enh_df="$2" ctx="$3"
    local tag
    tag="dockerfile-test-enh-$(printf '%s' "$label" | tr ' =/' '---' | tr '[:upper:]' '[:lower:]')"
    TOTAL=$((TOTAL + 1))
    local output rc
    output=$(DOCKER_BUILDKIT=1 docker build --no-cache -f "$enh_df" -t "$tag" "$ctx" 2>&1)
    rc=$?
    if [ $rc -eq 0 ]; then
        printf "  PASS: %s (cert enhancement build)\n" "$label"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (cert enhancement build, exit %s)\n" "$label" "$rc"
        printf "%s\n" "$output" | tail -20 | while IFS= read -r line; do
            printf "        %s\n" "$line"
        done
        FAILED=$((FAILED + 1))
    fi
    docker rmi "$tag" >/dev/null 2>&1 || true
}

#########################################################################
# check_tini_preserved <slug>
# Asserts that /sbin/tini is saved before the busybox wipe and restored
# after (quarkus templates only).
#########################################################################
check_tini_preserved() {
    local file="$TEST_DIR/${1}.Dockerfile"
    assert_file_contains "$1: tini saved before wipe" \
        "tini ] && /tmp/busybox cp /sbin/tini /tmp/tini" "$file"
    assert_file_contains "$1: tini restored after wipe" \
        "tini ] && /bin/cp /tmp/tini /sbin/tini" "$file"
}

#########################################################################
# check_nginx_preserved <slug>
# Asserts that nginx, envsubst and the extended symlink set are
# saved/restored through the wipe (kubernetes and nodejs templates).
#########################################################################
check_nginx_preserved() {
    local file="$TEST_DIR/${1}.Dockerfile"
    assert_file_contains "$1: nginx saved before wipe" \
        "/usr/sbin/nginx\" ] && /tmp/busybox cp /usr/sbin/nginx /tmp/nginx" "$file"
    assert_file_contains "$1: nginx restored after wipe" \
        "/tmp/nginx\" ] && /bin/cp /tmp/nginx /usr/sbin/nginx" "$file"
    assert_file_contains "$1: envsubst saved/restored in loop" \
        "envsubst" "$file"
    assert_file_contains "$1: extended symlink set (cut find md5sum)" \
        "find grep head md5sum" "$file"
}



#########################################################################
# check_nginx_compression <slug>
# Asserts that response compression is enabled for the static assets of a
# single page application (nodejs template). nginx ships gzip disabled, so
# without this the bundled js/css is served uncompressed.
#########################################################################
check_nginx_compression() {
    local file="$TEST_DIR/${1}.Dockerfile"
    assert_file_contains "$1: gzip enabled" \
        "gzip on;" "$file"
    assert_file_contains "$1: Vary Accept-Encoding emitted (needed with immutable caching)" \
        "gzip_vary on;" "$file"
    assert_file_contains "$1: compression applies behind a reverse proxy" \
        "gzip_proxied any;" "$file"
    assert_file_contains "$1: javascript is compressed" \
        "gzip_types application/javascript" "$file"
    assert_file_contains "$1: written to its own conf.d file" \
        "/etc/nginx/conf.d/00-compression.conf" "$file"
    # text/html is compressed unconditionally by nginx; listing it logs a
    # "duplicate MIME type" warning on every start
    assert_file_not_contains "$1: text/html not listed in gzip_types" \
        "gzip_types text/html" "$file"
    # "expires" emits its own Cache-Control, which would duplicate the header
    assert_file_not_contains "$1: no duplicate Cache-Control from expires" \
        "expires 1y;" "$file"
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
#
# Customer certificate overlay support (--cert)
#
# Customers use our images as base image and add their own (internal) CA
# certificates on top. Two patterns are in use — reproduced below verbatim:
#
#   services (quarkus; image contains keytool):
#     COPY cacerts/* /usr/local/share/ca-certificates/
#     RUN update-ca-certificates && for crtFile ... keytool -importcert -cacerts ...
#
#   ui (nuxtjs; image without keytool):
#     SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
#     COPY cacerts/* /usr/local/share/ca-certificates/
#     RUN cat ...crt >> /etc/ssl/certs/ca-certificates.crt && <apk repository swap>
#         && apk add --no-cache ca-certificates && update-ca-certificates
#     RUN chgrp -R root /deployment && chmod -R g=u /deployment [&& chmod -R g=u /etc/nginx/conf.d]
#
# Pattern selection follows the customer rule: keytool present -> services,
# otherwise ui (auto-detected from the built image, see cert_probe).
#
#########################################################################
CERT_RUNTIME_USER="appuser"
CERT_ALIAS="customer-internal-ca"
CERT_FILE_NAME="customer-internal-ca.crt"
CERT_STOREPASS="changeit"
CERT_CTX=""
CERT_HASH=""
CERT_MARKER=""
CERT_RESULT_TABLE=""

# The customer swaps in an internal apk mirror, overridable for builds behind a proxy/mirror.
CERT_APK_REPOSITORIES="${CERT_TEST_APK_REPOSITORIES:-https://dl-cdn.alpinelinux.org/alpine/latest-stable/main
https://dl-cdn.alpinelinux.org/alpine/latest-stable/community}"

#########################################################################
# cert_setup
# Creates the overlay build context: a self-signed test CA in cacerts/
# (named customer-internal-*.crt so the ui pattern glob matches) plus the
# simulated custom apk repository file.
# Sets CERT_CTX, CERT_HASH (subject hash used for the /etc/ssl/certs
# symlink) and CERT_MARKER (unique PEM line used to grep the CA bundle).
#########################################################################
cert_setup() {
    CERT_CTX="$TEST_DIR/cert-ctx"
    mkdir -p "$CERT_CTX/cacerts"

    if ! openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
            -subj "/CN=Customer Internal Root CA/O=Dockerfile Template Test" \
            -addext "basicConstraints=critical,CA:TRUE" \
            -keyout "$TEST_DIR/cert-test-ca.key" \
            -out "$CERT_CTX/cacerts/$CERT_FILE_NAME" >/dev/null 2>&1; then
        printf "ERROR: could not generate the test certificate with openssl.\n" >&2
        return 1
    fi

    CERT_HASH=$(openssl x509 -hash -noout -in "$CERT_CTX/cacerts/$CERT_FILE_NAME" 2>/dev/null)
    CERT_MARKER=$(sed -n '3p' "$CERT_CTX/cacerts/$CERT_FILE_NAME")
    printf '%s\n' "$CERT_APK_REPOSITORIES" > "$CERT_CTX/custom-repositories"

    if [ -z "$CERT_HASH" ] || [ -z "$CERT_MARKER" ]; then
        printf "ERROR: could not determine hash/marker of the test certificate.\n" >&2
        return 1
    fi
    return 0
}

#########################################################################
# cert_probe <image>
# Echoes "<mode> <has_update_ca> <has_nginx> <has_bundle> <has_apk>":
#   mode           services (keytool present) | ui
#   has_update_ca  true|false  (update-ca-certificates binary present)
#   has_nginx      true|false  (/etc/nginx/conf.d present)
#   has_bundle     true|false  (/etc/ssl/certs/ca-certificates.crt present)
#   has_apk        true|false  (/etc/apk/repositories present)
#########################################################################
cert_probe() {
    local image="$1"
    docker run --rm --entrypoint sh "$image" -c '
        if command -v keytool >/dev/null 2>&1; then mode=services; else mode=ui; fi
        if command -v update-ca-certificates >/dev/null 2>&1; then uca=true; else uca=false; fi
        if [ -d /etc/nginx/conf.d ]; then ngx=true; else ngx=false; fi
        if [ -f /etc/ssl/certs/ca-certificates.crt ]; then bundle=true; else bundle=false; fi
        if [ -f /etc/apk/repositories ]; then apk=true; else apk=false; fi
        echo "$mode $uca $ngx $bundle $apk"
    ' 2>/dev/null
}

#########################################################################
# cert_write_overlay <mode> <base_image> <out> <as_root> <has_nginx> <has_apk>
# Writes the customer overlay Dockerfile (their pattern, verbatim).
# as_root=true wraps the pattern in USER root ... USER <runtime user>,
# which is what a customer has to do because our images end with USER.
#########################################################################
cert_write_overlay() {
    local mode="$1" base_image="$2" out="$3" as_root="$4" has_nginx="$5" has_apk="$6"

    printf 'FROM %s\n\n' "$base_image" > "$out"
    if [ "$as_root" = "true" ]; then
        printf 'USER root\n\n' >> "$out"
    fi

    if [ "$mode" = "ui-hardened" ]; then
        # image without apk (dockerRemovePackageInstallationBinaries): the ui pattern
        # without the apk repository swap — ca-certificates is already installed
        cat >> "$out" <<'CERT_PATTERN_UI_HARDENED'
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
COPY cacerts/* /usr/local/share/ca-certificates/
RUN cat /usr/local/share/ca-certificates/customer-internal*.crt >> /etc/ssl/certs/ca-certificates.crt \
&& update-ca-certificates
CERT_PATTERN_UI_HARDENED
        if [ "$has_nginx" = "true" ]; then
            cat >> "$out" <<'CERT_PATTERN_UI_HARDENED_NGINX'

RUN chgrp -R root /deployment \
    && chmod -R g=u /deployment \
    && chmod -R g=u /etc/nginx/conf.d
CERT_PATTERN_UI_HARDENED_NGINX
        else
            cat >> "$out" <<'CERT_PATTERN_UI_HARDENED_PLAIN'

RUN chgrp -R root /deployment \
    && chmod -R g=u /deployment
CERT_PATTERN_UI_HARDENED_PLAIN
        fi
    elif [ "$mode" = "services" ]; then
        cat >> "$out" <<'CERT_PATTERN_SERVICES'
COPY cacerts/* /usr/local/share/ca-certificates/
RUN update-ca-certificates \
 && for crtFile in /usr/local/share/ca-certificates/*; \
    do \
      keytool -importcert -cacerts -storepass changeit -file ${crtFile} -alias $(basename ${crtFile} .crt) -noprompt; \
    done
CERT_PATTERN_SERVICES
    else
        # customer provides the internal apk mirror as /custom/repositories — simulated here
        printf 'COPY custom-repositories /custom/repositories\n' >> "$out"
        cat >> "$out" <<'CERT_PATTERN_UI'
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
COPY cacerts/* /usr/local/share/ca-certificates/
RUN cat /usr/local/share/ca-certificates/customer-internal*.crt >> /etc/ssl/certs/ca-certificates.crt \
&& mv /etc/apk/repositories /etc/apk/repositories.original \
&& mv /custom/repositories /etc/apk/repositories \
&& apk add --no-cache ca-certificates \
&& mv /etc/apk/repositories.original /etc/apk/repositories \
&& update-ca-certificates
CERT_PATTERN_UI
        if [ "$has_nginx" = "true" ]; then
            cat >> "$out" <<'CERT_PATTERN_UI_NGINX'

RUN chgrp -R root /deployment \
    && chmod -R g=u /deployment \
    && chmod -R g=u /etc/nginx/conf.d
CERT_PATTERN_UI_NGINX
        else
            # same pattern without the nginx part (image has no /etc/nginx/conf.d)
            cat >> "$out" <<'CERT_PATTERN_UI_PLAIN'

RUN chgrp -R root /deployment \
    && chmod -R g=u /deployment
CERT_PATTERN_UI_PLAIN
        fi
    fi

    if [ "$as_root" = "true" ]; then
        printf '\nUSER %s\n' "$CERT_RUNTIME_USER" >> "$out"
    fi
}

#########################################################################
# cert_verify <image> <mode>
# Checks in the running container that the certificate is really trusted:
#   - the PEM is part of /etc/ssl/certs/ca-certificates.crt
#   - update-ca-certificates created the /etc/ssl/certs/<hash>.0 symlink
#   - services only: the certificate is in the JVM truststore (keytool)
# Echoes the failure reason, returns non-zero on failure.
#########################################################################
cert_verify() {
    local image="$1" mode="$2"
    docker run --rm \
        -e "CERT_MARKER=$CERT_MARKER" \
        -e "CERT_HASH=$CERT_HASH" \
        -e "CERT_ALIAS=$CERT_ALIAS" \
        -e "CERT_STOREPASS=$CERT_STOREPASS" \
        -e "CERT_MODE=$mode" \
        --entrypoint sh "$image" -c '
            if ! grep -q "$CERT_MARKER" /etc/ssl/certs/ca-certificates.crt 2>/dev/null; then
                echo "certificate is not part of /etc/ssl/certs/ca-certificates.crt"; exit 1;
            fi
            if [ ! -e "/etc/ssl/certs/$CERT_HASH.0" ]; then
                echo "missing symlink /etc/ssl/certs/$CERT_HASH.0 (update-ca-certificates did not run)"; exit 1;
            fi
            if [ "$CERT_MODE" = "services" ]; then
                if ! keytool -list -cacerts -storepass "$CERT_STOREPASS" -alias "$CERT_ALIAS" >/dev/null 2>&1; then
                    echo "certificate is not in the JVM truststore (keytool -list -cacerts -alias $CERT_ALIAS)"; exit 1;
                fi
            fi
            echo "trusted"
        ' 2>&1
}

#########################################################################
# cert_failure_cause <build_output> <verify_output>
# Condenses a failed overlay into one actionable cause.
#########################################################################
cert_failure_cause() {
    local output="$1" verify_output="$2"

    if printf '%s' "$output" | grep -qE "/etc/ssl/certs.*(nonexistent directory|No such file)"; then
        # apk del apk-tools also purges ca-certificates-bundle, ssl_client, libssl3, libcrypto3
        echo "/etc/ssl/certs removed — the image has no CA trust store at all"
    elif printf '%s' "$output" | grep -q 'update-ca-certificates: not found'; then
        echo "update-ca-certificates is missing in the image"
    elif printf '%s' "$output" | grep -qE "/etc/apk/repositories.*(No such file|can't rename)|apk: not found|ash: not found"; then
        echo "apk / /etc/apk removed — the ui pattern cannot install ca-certificates"
    elif printf '%s' "$output" | grep -q 'keytool: not found'; then
        echo "keytool is missing in the image"
    elif printf '%s' "$output" | grep -q 'Permission denied'; then
        echo "permission denied — a path needed by the pattern is not writable"
    elif [ "$verify_output" = "overlay build failed" ]; then
        echo "the customer overlay does not build on this image"
    else
        printf '%s\n' "$verify_output"
    fi
}

#########################################################################
# cert_case <label> <template> <context> [overrides...]
# Builds our image from the template, detects the customer pattern,
# builds the customer overlay on top of it and verifies the certificate.
#
# Every case must work: if the customer cannot add their certificates to
# an image built from one of our templates, that is a defect of the
# template (or of a hardening option), never an accepted limitation.
#########################################################################
cert_case() {
    local label="$1" tmpl="$2" ctx="$3"
    shift 3

    local as_root="true"
    local slug base_tag overlay_tag base_file overlay_file
    slug=$(printf '%s' "$label" | tr ' =/' '---' | tr '[:upper:]' '[:lower:]')
    base_tag="dockerfile-cert-base-$slug"
    overlay_tag="dockerfile-cert-overlay-$slug"
    base_file="$TEST_DIR/cert-$slug-base.Dockerfile"
    overlay_file="$TEST_DIR/cert-$slug-overlay.Dockerfile"

    # 1. our image
    render_template "$tmpl" "$base_file" "$@"
    TOTAL=$((TOTAL + 1))
    local output rc
    output=$(DOCKER_BUILDKIT=1 docker build -f "$base_file" -t "$base_tag" "$ctx" 2>&1)
    rc=$?
    if [ $rc -ne 0 ]; then
        printf "  FAIL: %s (base image build failed, exit %s)\n" "$label" "$rc"
        printf '%s\n' "$output" | tail -15 | while IFS= read -r line; do
            printf "        %s\n" "$line"
        done
        FAILED=$((FAILED + 1))
        return 1
    fi
    PASSED=$((PASSED + 1))
    printf "  PASS: %s (base image build)\n" "$label"

    # 2. customer pattern detection (keytool -> services, otherwise ui)
    local probe mode has_update_ca has_nginx has_bundle has_apk
    probe=$(cert_probe "$base_tag")
    mode=$(printf '%s' "$probe" | cut -d' ' -f1)
    has_update_ca=$(printf '%s' "$probe" | cut -d' ' -f2)
    has_nginx=$(printf '%s' "$probe" | cut -d' ' -f3)
    has_bundle=$(printf '%s' "$probe" | cut -d' ' -f4)
    has_apk=$(printf '%s' "$probe" | cut -d' ' -f5)
    if [ -z "$mode" ]; then
        # busybox-reduced images can still be probed; an empty result is a real problem
        mode="ui"
        has_update_ca="false"
        has_nginx="false"
        has_bundle="false"
        has_apk="false"
        printf "  INFO: %s — image could not be probed, assuming ui pattern\n" "$label"
    fi

    # images without apk get the ui pattern without the apk repository swap
    if [ "$mode" = "ui" ] && [ "$has_apk" != "true" ]; then
        mode="ui-hardened"
    fi

    # both patterns rely on update-ca-certificates and on an existing CA bundle;
    # report the missing precondition directly, the build error alone is hard to read
    if [ "$has_bundle" != "true" ]; then
        printf "  INFO: %s — image has no /etc/ssl/certs/ca-certificates.crt\n" "$label"
    fi
    if [ "$has_update_ca" != "true" ]; then
        printf "  INFO: %s — update-ca-certificates is not available in the image\n" "$label"
    fi

    # 3. customer overlay
    cert_write_overlay "$mode" "$base_tag" "$overlay_file" "$as_root" "$has_nginx" "$has_apk"
    output=$(DOCKER_BUILDKIT=1 docker build -f "$overlay_file" -t "$overlay_tag" "$CERT_CTX" 2>&1)
    rc=$?

    # 4. certificate verification (only meaningful if the overlay was built)
    local verify_output="overlay build failed"
    if [ $rc -eq 0 ]; then
        verify_output=$(cert_verify "$overlay_tag" "$mode")
        if [ "$verify_output" != "trusted" ]; then
            rc=1
        fi
    fi

    TOTAL=$((TOTAL + 1))
    if [ $rc -eq 0 ]; then
        printf "  PASS: %s [%s pattern] — certificate trusted\n" "$label" "$mode"
        PASSED=$((PASSED + 1))
        CERT_RESULT_TABLE="${CERT_RESULT_TABLE}${label}|${mode}|OK|
"
    else
        local cause
        cause=$(cert_failure_cause "$output" "$verify_output")
        printf "  FAIL: %s [%s pattern] — certificate cannot be added: %s\n" "$label" "$mode" "$cause"
        printf '%s\n' "$output" | grep -E ": not found|Permission denied|can't |cannot |No such file" \
            | sed -e 's|^#[0-9]* *||' -e 's|^\([0-9.]*\) ||' | sort -u | head -3 | cut -c1-150 \
            | while IFS= read -r line; do
                printf "        %s\n" "$line"
            done
        FAILED=$((FAILED + 1))
        CERT_RESULT_TABLE="${CERT_RESULT_TABLE}${label}|${mode}|FAILED|${cause}
"
    fi

    docker rmi "$overlay_tag" >/dev/null 2>&1 || true
    docker rmi "$base_tag" >/dev/null 2>&1 || true
    return 0
}

#########################################################################
# cert_negative_control <template> <context>
# Sanity check of the verification itself: our image WITHOUT the customer
# overlay must be reported as "not trusted". Guards against a vacuous
# cert_verify (e.g. a certificate that is trusted by the base image).
#########################################################################
cert_negative_control() {
    local tmpl="$1" ctx="$2"
    local base_file="$TEST_DIR/cert-negative-base.Dockerfile"
    local base_tag="dockerfile-cert-negative"

    render_template "$tmpl" "$base_file" "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=false" \
        "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine"
    TOTAL=$((TOTAL + 1))
    if ! DOCKER_BUILDKIT=1 docker build -f "$base_file" -t "$base_tag" "$ctx" >/dev/null 2>&1; then
        printf "  FAIL: negative control (base image build failed)\n"
        FAILED=$((FAILED + 1))
        return 1
    fi

    local verify_output
    verify_output=$(cert_verify "$base_tag" "services")
    if [ "$verify_output" = "trusted" ]; then
        printf "  FAIL: negative control — image without the overlay reported as trusted (verification is vacuous)\n"
        FAILED=$((FAILED + 1))
    else
        printf "  PASS: negative control — image without the overlay is not trusted (%s)\n" "$verify_output"
        PASSED=$((PASSED + 1))
    fi
    docker rmi "$base_tag" >/dev/null 2>&1 || true
    return 0
}

#########################################################################
# Check Docker availability for levels 1 and 2 and for --cert
#########################################################################
if { [ "$LEVEL" -ge 1 ] || [ "$CERT_TEST" -eq 1 ]; } && ! command -v docker >/dev/null 2>&1; then
    printf "ERROR: docker not found in PATH; --lint, --build and --cert require Docker.\n" >&2
    exit 1
fi

if [ "$CERT_TEST" -eq 1 ] && ! command -v openssl >/dev/null 2>&1; then
    printf "ERROR: openssl not found in PATH; --cert requires openssl to create the test certificate.\n" >&2
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
check_update_ca_certificates_preserved "base-defaults"

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
check_update_ca_certificates_preserved "docker-defaults"

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
check_update_ca_certificates_preserved "k8s-defaults"
check_nginx_preserved "k8s-defaults"

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

if [ "$LEVEL" -ge 2 ] && command -v openssl >/dev/null 2>&1; then
    enh_ctx="$TEST_DIR/k8s-cert-ctx"
    if setup_test_cert "$enh_ctx"; then
        enh_base_df="$TEST_DIR/k8s-cert-base.Dockerfile"
        render_template "$TMPL" "$enh_base_df" "DOCKER_IMAGE=nginx:alpine" \
            "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=false" "ENABLE_ACCESS_LOG=false"
        base_tag="dockerfile-test-k8s-cert-base"
        TOTAL=$((TOTAL + 1))
        build_out=$(DOCKER_BUILDKIT=1 docker build --no-cache -f "$enh_base_df" -t "$base_tag" "$CTX" 2>&1)
        if [ $? -eq 0 ]; then
            PASSED=$((PASSED + 1))
            printf "  PASS: k8s cert base build\n"
            enh_df="$TEST_DIR/k8s-cert-enh.Dockerfile"
            {
                printf 'FROM %s\nUSER root\n' "$base_tag"
                printf 'SHELL ["/bin/ash", "-eo", "pipefail", "-c"]\n'
                printf 'COPY cacerts/* /usr/local/share/ca-certificates/\n'
                printf 'RUN cat /usr/local/share/ca-certificates/test-ca.crt >> /etc/ssl/certs/ca-certificates.crt \\\n'
                printf '    && update-ca-certificates\n'
                printf 'USER %s\n' "$CERT_RUNTIME_USER"
            } > "$enh_df"
            docker_build_enhancement "k8s cert enhancement" "$enh_df" "$enh_ctx"
            docker rmi "$base_tag" >/dev/null 2>&1 || true
        else
            FAILED=$((FAILED + 1))
            printf "  FAIL: k8s cert base build\n"
            printf '%s\n' "$build_out" | tail -10 | while IFS= read -r line; do printf "        %s\n" "$line"; done
        fi
    fi
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
check_update_ca_certificates_preserved "nodejs-defaults"
check_nginx_preserved "nodejs-defaults"

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
check_update_ca_certificates_preserved "node-defaults"

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
check_update_ca_certificates_preserved "quarkus-defaults"
check_tini_preserved "quarkus-defaults"

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
check_update_ca_certificates_preserved "java-runner-defaults"
check_tini_preserved "java-runner-defaults"

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

if [ "$LEVEL" -ge 2 ] && command -v openssl >/dev/null 2>&1; then
    enh_ctx="$TEST_DIR/java-runner-cert-ctx"
    if setup_test_cert "$enh_ctx"; then
        enh_base_df="$TEST_DIR/java-runner-cert-base.Dockerfile"
        render_template "$TMPL" "$enh_base_df" "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine" \
            "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=false"
        base_tag="dockerfile-test-java-runner-cert-base"
        TOTAL=$((TOTAL + 1))
        build_out=$(DOCKER_BUILDKIT=1 docker build --no-cache -f "$enh_base_df" -t "$base_tag" "$CTX" 2>&1)
        if [ $? -eq 0 ]; then
            PASSED=$((PASSED + 1))
            printf "  PASS: java-runner cert base build\n"
            enh_df="$TEST_DIR/java-runner-cert-enh.Dockerfile"
            {
                printf 'FROM %s\nUSER root\n' "$base_tag"
                printf 'COPY cacerts/* /usr/local/share/ca-certificates/\n'
                printf 'RUN update-ca-certificates \\\n'
                printf ' && for crtFile in /usr/local/share/ca-certificates/*; \\\n'
                printf '    do \\\n'
                printf '      keytool -importcert -cacerts -storepass changeit -file ${crtFile} -alias $(basename ${crtFile} .crt) -noprompt; \\\n'
                printf '    done\n'
                printf 'USER %s\n' "$CERT_RUNTIME_USER"
            } > "$enh_df"
            docker_build_enhancement "java-runner cert enhancement" "$enh_df" "$enh_ctx"
            docker rmi "$base_tag" >/dev/null 2>&1 || true
        else
            FAILED=$((FAILED + 1))
            printf "  FAIL: java-runner cert base build\n"
            printf '%s\n' "$build_out" | tail -10 | while IFS= read -r line; do printf "        %s\n" "$line"; done
        fi
    fi
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
check_update_ca_certificates_preserved "multistage-defaults"
check_tini_preserved "multistage-defaults"

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

if [ "$LEVEL" -ge 2 ] && command -v openssl >/dev/null 2>&1; then
    enh_ctx="$TEST_DIR/multistage-cert-ctx"
    if setup_test_cert "$enh_ctx"; then
        enh_base_df="$TEST_DIR/multistage-cert-base.Dockerfile"
        render_template "$TMPL" "$enh_base_df" \
            "DOCKER_IMAGE=eclipse-temurin:21-alpine" "DOCKER_RUNTIME_IMAGE=alpine:3.21" \
            "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=false"
        base_tag="dockerfile-test-multistage-cert-base"
        TOTAL=$((TOTAL + 1))
        build_out=$(DOCKER_BUILDKIT=1 docker build --no-cache -f "$enh_base_df" -t "$base_tag" "$CTX" 2>&1)
        if [ $? -eq 0 ]; then
            PASSED=$((PASSED + 1))
            printf "  PASS: multistage cert base build\n"
            enh_df="$TEST_DIR/multistage-cert-enh.Dockerfile"
            {
                printf 'FROM %s\nUSER root\n' "$base_tag"
                printf 'COPY cacerts/* /usr/local/share/ca-certificates/\n'
                printf 'RUN update-ca-certificates \\\n'
                printf ' && for crtFile in /usr/local/share/ca-certificates/*; \\\n'
                printf '    do \\\n'
                printf '      keytool -importcert -cacerts -storepass changeit -file ${crtFile} -alias $(basename ${crtFile} .crt) -noprompt; \\\n'
                printf '    done\n'
                printf 'USER %s\n' "$CERT_RUNTIME_USER"
            } > "$enh_df"
            docker_build_enhancement "multistage cert enhancement" "$enh_df" "$enh_ctx"
            docker rmi "$base_tag" >/dev/null 2>&1 || true
        else
            FAILED=$((FAILED + 1))
            printf "  FAIL: multistage cert base build\n"
            printf '%s\n' "$build_out" | tail -10 | while IFS= read -r line; do printf "        %s\n" "$line"; done
        fi
    fi
fi

#########################################################################
#
# === customer certificate overlay (--cert) ===
#
# Customers use our images as base image and add their own (internal) CA
# certificates on top. This section proves that this works for every
# template and every hardening combination. For each case:
#
#   1. our image is built from the template
#   2. the customer pattern is detected (keytool -> services, else ui)
#   3. the customer overlay is built on top of our image
#   4. the certificate is verified inside the container (CA bundle,
#      /etc/ssl/certs hash symlink and, for services, the JVM truststore)
#
# Every case must pass. A failure means a customer cannot bring in their
# certificates with an image built from that template — a defect to fix,
# not an accepted limitation.
#
# Flag combinations per template (the hardening options that touch the
# binaries and paths the certificate patterns rely on):
#   default   all hardening off (defaults.gradle)
#   readonly  MAKE_FILESYSTEM_READONLY=true
#   no-apk    REMOVE_PACKAGE_INSTALLATION_BINARIES=true
#   minimal   REMOVE_NON_ESSENTIAL_BINARIES=true
#   hardened  all three on
#
#########################################################################
if [ "$CERT_TEST" -eq 1 ]; then
    printf "\n=== customer certificate overlay ===\n"

    if ! cert_setup; then
        printf "  FAIL: could not prepare the certificate test context\n"
        FAILED=$((FAILED + 1))
        TOTAL=$((TOTAL + 1))
    else
        #################################################################
        # cert_matrix <label> <template> <context> [overrides...]
        # Runs the customer certificate overlay for all hardening
        # combinations of one template.
        #################################################################
        cert_matrix() {
            local label="$1" tmpl="$2" ctx="$3"
            shift 3
            cert_case "$label default"  "$tmpl" "$ctx" \
                "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=false" "$@"
            cert_case "$label readonly" "$tmpl" "$ctx" \
                "RM_NON_ESSENTIAL=false" "MAKE_READONLY=true"  "RM_PKG_BINARIES=false" "$@"
            cert_case "$label no-apk"   "$tmpl" "$ctx" \
                "RM_NON_ESSENTIAL=false" "MAKE_READONLY=false" "RM_PKG_BINARIES=true"  "$@"
            cert_case "$label minimal"  "$tmpl" "$ctx" \
                "RM_NON_ESSENTIAL=true"  "MAKE_READONLY=false" "RM_PKG_BINARIES=false" "$@"
            cert_case "$label hardened" "$tmpl" "$ctx" \
                "RM_NON_ESSENTIAL=true"  "MAKE_READONLY=true"  "RM_PKG_BINARIES=true"  "$@"
        }

        printf "\n  --- base/Dockerfile.template ---\n"
        CTX=$(setup_java_fixtures)
        cert_matrix "base" "$TEMPLATE_DIR/base/Dockerfile.template" "$CTX"

        printf "\n  --- docker/Dockerfile.template ---\n"
        CTX=$(setup_docker_fixtures)
        cert_matrix "docker" "$TEMPLATE_DIR/docker/Dockerfile.template" "$CTX" \
            'DOCKER_ENTRYPOINT="sh", "-c", "echo hello"'

        printf "\n  --- kubernetes/Dockerfile.template ---\n"
        CTX=$(setup_kubernetes_fixtures)
        cert_matrix "k8s" "$TEMPLATE_DIR/kubernetes/Dockerfile.template" "$CTX" \
            "DOCKER_IMAGE=nginx:alpine"

        printf "\n  --- nodejs/Dockerfile.template ---\n"
        CTX=$(setup_nodejs_fixtures)
        cert_matrix "nodejs" "$TEMPLATE_DIR/nodejs/Dockerfile.template" "$CTX" \
            "DOCKER_IMAGE=nginx:alpine"

        printf "\n  --- nodejs/Dockerfile-node.template ---\n"
        cert_matrix "node" "$TEMPLATE_DIR/nodejs/Dockerfile-node.template" "$CTX" \
            "DOCKER_IMAGE=node:22-alpine" \
            "DOCKER_ENTRYPOINT=[\"/bin/sh\", \"-c\", \"NUXT_PORT=\${EXPOSE_PORT} exec npm start\"]"

        printf "\n  --- quarkus/Dockerfile.template ---\n"
        CTX=$(setup_quarkus_fixtures)
        cert_matrix "quarkus" "$TEMPLATE_DIR/quarkus/Dockerfile.template" "$CTX" \
            "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine"

        printf "\n  --- quarkus/Dockerfile-java-runner.template ---\n"
        cert_matrix "java-runner" "$TEMPLATE_DIR/quarkus/Dockerfile-java-runner.template" "$CTX" \
            "DOCKER_IMAGE=eclipse-temurin:21-jre-alpine"

        printf "\n  --- quarkus/Dockerfile-java-runner-multistage.template ---\n"
        cert_matrix "multistage" "$TEMPLATE_DIR/quarkus/Dockerfile-java-runner-multistage.template" "$CTX" \
            "DOCKER_IMAGE=eclipse-temurin:21-jdk-alpine" "DOCKER_RUNTIME_IMAGE=alpine:3.21"

        # --- sanity check of the verification itself ---
        printf "\n  --- negative control ---\n"
        cert_negative_control "$TEMPLATE_DIR/quarkus/Dockerfile.template" "$CTX"

        # --- compatibility overview ---
        printf "\n  --- customer certificate compatibility ---\n"
        printf "    %-24s %-10s %-8s %s\n" "case" "pattern" "result" "cause"
        printf '%s' "$CERT_RESULT_TABLE" | while IFS='|' read -r c_label c_mode c_result c_cause; do
            [ -z "$c_label" ] && continue
            printf "    %-24s %-10s %-8s %s\n" "$c_label" "$c_mode" "$c_result" "$c_cause"
        done
    fi
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
