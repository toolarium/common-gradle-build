#!/usr/bin/env bash

#########################################################################
#
# run-all-tests.sh
#
# Master test runner — executes every test script under test/template/.
# Continues running all suites even when one fails, then reports a
# consolidated summary with timing per suite.
#
# Usage:
#   bash test/template/run-all-tests.sh [options]
#
# Options:
#   --skip-docker   Skip all tests that require Docker
#   --skip-build    Skip the expensive full docker-build matrix only
#                   (lint and signal tests still run)
#   --help          Show this help
#
# Without options: runs everything, including the full --build matrix.
#
# Exit code:
#   0  all suites passed
#   1  one or more suites failed
#
#########################################################################

SCRIPT_DIR=$(cd -- "$(dirname "$0" 2>/dev/null)" && pwd)

SKIP_DOCKER=0
SKIP_BUILD=0

for arg in "$@"; do
    case "$arg" in
        --skip-docker) SKIP_DOCKER=1 ;;
        --skip-build)  SKIP_BUILD=1 ;;
        --help|-h)
            sed -n '/^#/!q; s/^# \{0,1\}//p' "$0" | tail -n +2
            exit 0
            ;;
        *)
            printf "Unknown option: %s\n" "$arg" >&2
            exit 1
            ;;
    esac
done

#########################################################################
# Tracking
#########################################################################
SUITE_PASSED=0
SUITE_FAILED=0
SUITE_SKIPPED=0
FAILED_SUITES=""

#########################################################################
# run_suite <label> <command...>
# Runs a test command, prints a header/footer with timing, and tracks
# pass/fail. Continues on failure (does not abort).
#########################################################################
run_suite() {
    local label="$1"
    shift

    printf "\n"
    printf "########################################################################\n"
    printf "# %-68s #\n" "$label"
    printf "########################################################################\n"

    local start end elapsed
    start=$(date +%s)
    "$@"
    local rc=$?
    end=$(date +%s)
    elapsed=$(( end - start ))

    if [ $rc -eq 0 ]; then
        printf "\n  => PASSED  [%ss]\n" "$elapsed"
        SUITE_PASSED=$(( SUITE_PASSED + 1 ))
    else
        printf "\n  => FAILED  [%ss]  (exit %s)\n" "$elapsed" "$rc"
        SUITE_FAILED=$(( SUITE_FAILED + 1 ))
        FAILED_SUITES="${FAILED_SUITES}    - ${label}\n"
    fi
}

#########################################################################
# skip_suite <label> <reason>
#########################################################################
skip_suite() {
    local label="$1" reason="$2"
    printf "\n  SKIP: %s  (%s)\n" "$label" "$reason"
    SUITE_SKIPPED=$(( SUITE_SKIPPED + 1 ))
}

#########################################################################
# Check Docker availability once
#########################################################################
DOCKER_AVAILABLE=0
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    DOCKER_AVAILABLE=1
fi

if [ "$SKIP_DOCKER" -eq 1 ]; then
    printf "Docker tests: SKIPPED (--skip-docker)\n"
elif [ "$DOCKER_AVAILABLE" -eq 0 ]; then
    printf "Docker tests: SKIPPED (Docker not available or daemon not running)\n"
    SKIP_DOCKER=1
else
    DOCKER_VER=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    printf "Docker tests: ENABLED (Docker %s)\n" "$DOCKER_VER"
fi

TOTAL_START=$(date +%s)

#########################################################################
# 1. Quarkus shell script tests  (no Docker)
#########################################################################
run_suite "quarkus/toolarium-java-runner-test" \
    bash "$SCRIPT_DIR/quarkus/toolarium-java-runner-test.sh"

run_suite "quarkus/cb-meminfo-test" \
    bash "$SCRIPT_DIR/quarkus/cb-meminfo-test.sh"

#########################################################################
# 2. Node.js apply-subpath test  (no Docker)
#########################################################################
run_suite "nodejs/apply-subpath-test" \
    bash "$SCRIPT_DIR/nodejs/apply-subpath-test.sh"

#########################################################################
# 3. Dockerfile token coverage + mutation  (no Docker)
#########################################################################
run_suite "dockerfile/verify-dockerfile-test" \
    bash "$SCRIPT_DIR/dockerfile/verify-dockerfile-test.sh"

#########################################################################
# 4. Dockerfile placeholder substitution  (no Docker)
#########################################################################
run_suite "dockerfile/dockerfile-test (level 0 — placeholder check)" \
    bash "$SCRIPT_DIR/dockerfile/dockerfile-test.sh"

#########################################################################
# 5. Dockerfile lint  (Docker required)
#########################################################################
if [ "$SKIP_DOCKER" -eq 1 ]; then
    skip_suite "dockerfile/dockerfile-test --lint" "Docker not available"
else
    run_suite "dockerfile/dockerfile-test (level 1 — lint)" \
        bash "$SCRIPT_DIR/dockerfile/dockerfile-test.sh" --lint
fi

#########################################################################
# 6. Signal handling  (Docker required)
#########################################################################
if [ "$SKIP_DOCKER" -eq 1 ]; then
    skip_suite "dockerfile/signal-test" "Docker not available"
else
    run_suite "dockerfile/signal-test" \
        bash "$SCRIPT_DIR/dockerfile/signal-test.sh"
fi

#########################################################################
# 7. Full docker build matrix  (Docker required, expensive)
#########################################################################
if [ "$SKIP_DOCKER" -eq 1 ]; then
    skip_suite "dockerfile/dockerfile-test --build" "Docker not available"
elif [ "$SKIP_BUILD" -eq 1 ]; then
    skip_suite "dockerfile/dockerfile-test --build" "--skip-build"
else
    run_suite "dockerfile/dockerfile-test (level 2 — full build matrix)" \
        bash "$SCRIPT_DIR/dockerfile/dockerfile-test.sh" --build
fi

#########################################################################
# Summary
#########################################################################
TOTAL_END=$(date +%s)
TOTAL_ELAPSED=$(( TOTAL_END - TOTAL_START ))

printf "\n"
printf "########################################################################\n"
printf "# SUMMARY                                                              #\n"
printf "########################################################################\n"
printf "  Total time : %ss\n" "$TOTAL_ELAPSED"
printf "  Passed     : %s\n" "$SUITE_PASSED"
printf "  Failed     : %s\n" "$SUITE_FAILED"
printf "  Skipped    : %s\n" "$SUITE_SKIPPED"

if [ "$SUITE_FAILED" -gt 0 ]; then
    printf "\n  Failed suites:\n"
    printf '%b' "$FAILED_SUITES"
    exit 1
fi
exit 0
