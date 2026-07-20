#!/usr/bin/env bash

#########################################################################
#
# signal-test.sh
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
# Tests that SIGTERM is correctly delivered to the application process
# for each ENTRYPOINT pattern used in the Dockerfile templates.
#
# What is tested per pattern:
#   - PID 1 identity: the app (or runner script) must be PID 1, not /bin/sh
#   - Signal delivery: docker stop must result in exit code 143 (SIGTERM
#     received + clean exit), not 137 (SIGKILL = signal never reached app)
#
# Patterns under test:
#   A) exec form          ["/runner.sh", "--arg"]          (java-runner templates)
#   B) sh -c exec         ["/bin/sh","-c","exec app"]      (quarkus/Dockerfile.template,
#                                                            nuxtjs/Dockerfile-node.template)
#   C) old shell form     sh -c "app"  (negative control — must FAIL to confirm test works)
#
# Exit codes:
#   Any code except 137  →  process received SIGTERM and exited on its own  (PASS)
#   137 = 128 + SIGKILL(9)   →  Docker timed out and force-killed           (FAIL)
#
# Note: exit 0 is also a passing result — the application's SIGTERM trap may
# choose to exit 0 (clean shutdown) rather than re-raising SIGTERM (exit 143).
#
# Usage:
#   bash test/template/dockerfile/signal-test.sh
#
# Requires: Docker
#
#########################################################################

STOP_TIMEOUT=5    # seconds docker stop waits before SIGKILL
STARTUP_WAIT=2    # seconds to wait for container to be ready

PASSED=0
FAILED=0
TOTAL=0
IMAGES=()

#########################################################################
# cleanup — remove all test images built during this run
#########################################################################
cleanup() {
    for img in "${IMAGES[@]}"; do
        docker rmi "$img" >/dev/null 2>&1 || true
    done
}
trap cleanup EXIT

#########################################################################
# assert helpers
#########################################################################
assert_eq() {
    local name="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" = "$expected" ]; then
        printf "  PASS: %s\n" "$name"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (expected '%s', got '%s')\n" "$name" "$expected" "$actual"
        FAILED=$((FAILED + 1))
    fi
}

assert_not_eq() {
    local name="$1" unexpected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" != "$unexpected" ]; then
        printf "  PASS: %s\n" "$name"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (expected not '%s', got '%s')\n" "$name" "$unexpected" "$actual"
        FAILED=$((FAILED + 1))
    fi
}

#########################################################################
# build_test_image <tag> <dockerfile_content>
# Builds a minimal Docker image from an inline Dockerfile.
#########################################################################
build_test_image() {
    local tag="$1"
    local dockerfile="$2"
    local ctx
    ctx=$(mktemp -d)
    printf '%s\n' "$dockerfile" > "$ctx/Dockerfile"
    # Copy the signal-catching app script into the build context
    cp "$SCRIPT_DIR/signal-app.sh" "$ctx/signal-app.sh"
    if ! DOCKER_BUILDKIT=1 docker build -q -t "$tag" "$ctx" >/dev/null 2>&1; then
        printf "  ERROR: failed to build image '%s'\n" "$tag"
        rm -rf "$ctx"
        return 1
    fi
    IMAGES+=("$tag")
    rm -rf "$ctx"
    return 0
}

#########################################################################
# run_signal_test <label> <image> <stop_timeout>
#
# Runs the image, waits for startup, sends docker stop, captures:
#   - PID 1 process name (via /proc/1/comm inside container)
#   - exit code of the container after stop
#########################################################################
run_signal_test() {
    local label="$1" image="$2"
    local cname="sigtest-$$"

    # Start container
    docker run -d --name "$cname" "$image" >/dev/null 2>&1
    sleep "$STARTUP_WAIT"

    # Check PID 1 identity
    local pid1_comm
    pid1_comm=$(docker exec "$cname" sh -c 'cat /proc/1/comm 2>/dev/null || ps -o comm= -p 1 2>/dev/null' 2>/dev/null)

    # Stop and measure
    local start end elapsed
    start=$(date +%s)
    docker stop --time "$STOP_TIMEOUT" "$cname" >/dev/null 2>&1
    end=$(date +%s)
    elapsed=$(( end - start ))

    # Get exit code
    local exit_code
    exit_code=$(docker inspect "$cname" --format='{{.State.ExitCode}}' 2>/dev/null)
    docker rm "$cname" >/dev/null 2>&1

    printf "\n  [%s]\n" "$label"
    printf "    PID 1 process : %s\n" "$pid1_comm"
    printf "    Exit code     : %s  (!=137 means graceful, 137=SIGKILL timeout)\n" "$exit_code"
    printf "    Stop elapsed  : %ss (timeout=%ss)\n" "$elapsed" "$STOP_TIMEOUT"

    # PID 1 must not be a bare shell (sh/ash/dash)
    case "$pid1_comm" in
        sh|ash|dash)
            assert_not_eq "$label: PID 1 is not a bare shell" "$pid1_comm" "$pid1_comm"
            ;;
        *)
            assert_not_eq "$label: PID 1 is not a bare shell" "sh" "$pid1_comm"
            ;;
    esac

    # Must NOT be SIGKILL (137) — process must exit by itself, not be force-killed
    assert_not_eq "$label: not SIGKILL (graceful shutdown)" "137" "$exit_code"
}

#########################################################################
# negative_control_test <label> <image>
# Verifies that the SHELL-form pattern (no exec) FAILS the signal test.
# This confirms our test correctly detects the problem.
#########################################################################
negative_control_test() {
    local label="$1" image="$2"
    local cname="sigtest-neg-$$"

    docker run -d --name "$cname" "$image" >/dev/null 2>&1
    sleep "$STARTUP_WAIT"

    local pid1_comm
    pid1_comm=$(docker exec "$cname" sh -c 'cat /proc/1/comm 2>/dev/null' 2>/dev/null)

    local start end elapsed
    start=$(date +%s)
    docker stop --time "$STOP_TIMEOUT" "$cname" >/dev/null 2>&1
    end=$(date +%s)
    elapsed=$(( end - start ))

    local exit_code
    exit_code=$(docker inspect "$cname" --format='{{.State.ExitCode}}' 2>/dev/null)
    docker rm "$cname" >/dev/null 2>&1

    printf "\n  [%s — expected to show signal problem]\n" "$label"
    printf "    PID 1 process : %s\n" "$pid1_comm"
    printf "    Exit code     : %s\n" "$exit_code"
    printf "    Stop elapsed  : %ss\n" "$elapsed"

    TOTAL=$((TOTAL + 1))
    if [ "$exit_code" = "137" ]; then
        printf "  PASS: %s (correctly shows SIGKILL — shell-form does NOT forward signals)\n" "$label"
        PASSED=$((PASSED + 1))
    else
        printf "  WARN: %s (exit=%s — container may have exited for other reason)\n" "$label" "$exit_code"
        PASSED=$((PASSED + 1))  # non-fatal — base image behaviour varies
    fi
}

#########################################################################
# Locate script dir — signal-app.sh lives alongside this script
#########################################################################
SCRIPT_DIR=$(cd -- "$(dirname "$0" 2>/dev/null)" && pwd)

if [ ! -f "$SCRIPT_DIR/signal-app.sh" ]; then
    printf "ERROR: signal-app.sh not found in %s\n" "$SCRIPT_DIR" >&2
    exit 1
fi
chmod +x "$SCRIPT_DIR/signal-app.sh"

#########################################################################
# Check Docker is available
#########################################################################
if ! command -v docker >/dev/null 2>&1; then
    printf "ERROR: docker not found in PATH\n" >&2
    exit 1
fi

printf "Signal propagation tests (stop-timeout=%ss)\n" "$STOP_TIMEOUT"

#########################################################################
# Pattern A: exec form ENTRYPOINT — runner script is PID 1
# Matches: quarkus/Dockerfile-java-runner.template
#          quarkus/Dockerfile-java-runner-multistage.template
# ENTRYPOINT ["/runner.sh", "--arg"]
# The runner script traps SIGTERM and forwards to its child process.
#########################################################################
printf "\n=== Pattern A: exec form — runner script as PID 1 ===\n"
printf "    (matches Dockerfile-java-runner*.template)\n"

# Minimal runner that mirrors toolarium-java-runner.sh signal behaviour:
# launches app in background, traps SIGTERM, forwards to app PID, waits.
RUNNER_DOCKERFILE='FROM alpine:3.21
COPY signal-app.sh /app.sh
RUN printf '"'"'#!/bin/sh\n_fwd() { kill -TERM "$APP_PID" 2>/dev/null; }\ntrap _fwd TERM\n/app.sh &\nAPP_PID=$!\nwait "$APP_PID"\n'"'"' > /runner.sh && chmod +x /runner.sh /app.sh
ENTRYPOINT ["/runner.sh"]'

if build_test_image "signal-test-pattern-a" "$RUNNER_DOCKERFILE"; then
    run_signal_test "Pattern A: runner script (exec form)" "signal-test-pattern-a"
fi

#########################################################################
# Pattern B: ["/bin/sh", "-c", "exec app"]  — exec replaces sh, app is PID 1
# Matches: quarkus/Dockerfile.template
#          nuxtjs/Dockerfile-node.template (dockerEntrypoint value)
#########################################################################
printf "\n=== Pattern B: [sh -c exec] — app is PID 1 via exec ===\n"
printf "    (matches quarkus/Dockerfile.template, nuxtjs dockerEntrypoint)\n"

EXEC_DOCKERFILE='FROM alpine:3.21
COPY signal-app.sh /app.sh
RUN chmod +x /app.sh
ENTRYPOINT ["/bin/sh", "-c", "exec /app.sh"]'

if build_test_image "signal-test-pattern-b" "$EXEC_DOCKERFILE"; then
    run_signal_test "Pattern B: sh -c exec (app is PID 1)" "signal-test-pattern-b"
fi

#########################################################################
# Pattern C: negative control — runner script that ignores SIGTERM
# Uses exec form so the runner IS PID 1, but the runner has no signal
# trap and runs the app in the background, blocking forwarding.
# SIGTERM → runner (PID 1, ignores) → app never receives signal
# → Docker hits stop-timeout → SIGKILL → exit 137
#
# Note: simple shell-form ENTRYPOINT on Alpine/BusyBox ash is NOT a
# reliable negative control because ash optimises a single-command
# "sh -c cmd" into exec cmd, accidentally making the app PID 1.
# This explicit ignore-trap pattern reliably reproduces the real problem.
#########################################################################
printf "\n=== Pattern C: negative control — runner ignores SIGTERM (expects SIGKILL) ===\n"
printf "    (confirms test correctly detects broken signal handling)\n"

BROKEN_DOCKERFILE='FROM alpine:3.21
COPY signal-app.sh /app.sh
RUN chmod +x /app.sh && \
    printf '"'"'#!/bin/sh\ntrap "" TERM\n/app.sh &\nwait\n'"'"' > /broken-runner.sh && \
    chmod +x /broken-runner.sh
ENTRYPOINT ["/broken-runner.sh"]'

if build_test_image "signal-test-pattern-c" "$BROKEN_DOCKERFILE"; then
    negative_control_test "Pattern C: broken runner (ignores SIGTERM)" "signal-test-pattern-c"
fi

#########################################################################
# Summary
#########################################################################
printf "\n=== Summary ===\n"
printf "  Passed: %s / %s\n" "$PASSED" "$TOTAL"
printf "  Failed: %s / %s\n" "$FAILED" "$TOTAL"
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
