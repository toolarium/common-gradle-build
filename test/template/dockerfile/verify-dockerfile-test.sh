#!/usr/bin/env bash

#########################################################################
#
# verify-dockerfile-test.sh
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
# Meta-test: verifies that dockerfile-test.sh itself is correct.
#
# Two checks:
#
#   1. TOKEN COVERAGE
#      Extracts every @@PLACEHOLDER@@ from all Dockerfile templates and
#      confirms each one has a substitution in dockerfile-test.sh's
#      render_template function.  Catches the case where a new token is
#      added to a template but the test is not updated.
#
#   2. MUTATION TEST
#      Temporarily injects a fake @@MUTATION_TOKEN@@ into one template,
#      runs dockerfile-test.sh, and asserts it exits non-zero.
#      Then removes the injection and asserts the test exits 0.
#      Confirms the test actually catches unresolved placeholders.
#
# Usage:
#   bash test/template/dockerfile/verify-dockerfile-test.sh
#
#########################################################################

SCRIPT_DIR=$(cd -- "$(dirname "$0" 2>/dev/null)" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../../.." && pwd)
TEMPLATE_DIR="$REPO_DIR/gradle/template"
TEST_SCRIPT="$SCRIPT_DIR/dockerfile-test.sh"

PASSED=0
FAILED=0
TOTAL=0

#########################################################################
# Assertion helpers
#########################################################################
assert_exit_zero() {
    local name="$1" rc="$2"
    TOTAL=$((TOTAL + 1))
    if [ "$rc" -eq 0 ]; then
        printf "  PASS: %s\n" "$name"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (expected exit 0, got %s)\n" "$name" "$rc"
        FAILED=$((FAILED + 1))
    fi
}

assert_exit_nonzero() {
    local name="$1" rc="$2"
    TOTAL=$((TOTAL + 1))
    if [ "$rc" -ne 0 ]; then
        printf "  PASS: %s (exit %s, test correctly failed)\n" "$name" "$rc"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (expected non-zero exit, got 0 — test did NOT catch the regression)\n" "$name"
        FAILED=$((FAILED + 1))
    fi
}

assert_no_diff() {
    local name="$1" diff_output="$2"
    TOTAL=$((TOTAL + 1))
    if [ -z "$diff_output" ]; then
        printf "  PASS: %s\n" "$name"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s\n%s\n" "$name" "$diff_output"
        FAILED=$((FAILED + 1))
    fi
}

#########################################################################
# CHECK 1: TOKEN COVERAGE
# Every @@TOKEN@@ in Dockerfile templates must appear as a substitution
# in the render_template sed block of dockerfile-test.sh.
#########################################################################
printf "\n=== Check 1: Token coverage ===\n"

DOCKERFILES=(
    "$TEMPLATE_DIR/base/Dockerfile.template"
    "$TEMPLATE_DIR/docker/Dockerfile.template"
    "$TEMPLATE_DIR/kubernetes/Dockerfile.template"
    "$TEMPLATE_DIR/nodejs/Dockerfile.template"
    "$TEMPLATE_DIR/nodejs/Dockerfile-node.template"
    "$TEMPLATE_DIR/quarkus/Dockerfile.template"
    "$TEMPLATE_DIR/quarkus/Dockerfile-java-runner.template"
    "$TEMPLATE_DIR/quarkus/Dockerfile-java-runner-multistage.template"
)

# Extract tokens from templates — include ALL lines (Gradle replaces tokens
# everywhere in the file, even inside shell comments).
TEMPLATE_TOKENS=$(grep -oh '@@[A-Za-z_][A-Za-z_0-9]*@@' "${DOCKERFILES[@]}" \
    | sort -u)

# Extract tokens handled by render_template in the test script
# (only the sed -e lines, not assertion message strings)
TEST_TOKENS=$(sed -n '/^render_template()/,/^}/p' "$TEST_SCRIPT" \
    | grep -oh '@@[A-Za-z_][A-Za-z_0-9]*@@' \
    | sort -u)

# Tokens in templates but missing from test
MISSING=$(comm -23 \
    <(printf '%s\n' "$TEMPLATE_TOKENS") \
    <(printf '%s\n' "$TEST_TOKENS"))

assert_no_diff "all template tokens covered in render_template" \
    "$([ -n "$MISSING" ] && printf "  missing from test:\n%s\n" "$MISSING")"

# Tokens in test but not in any current template (stale substitutions — informational)
STALE=$(comm -13 \
    <(printf '%s\n' "$TEMPLATE_TOKENS") \
    <(printf '%s\n' "$TEST_TOKENS"))

if [ -n "$STALE" ]; then
    printf "  INFO: stale substitutions (in test but no longer in templates):\n"
    printf '%s\n' "$STALE" | while IFS= read -r token; do
        printf "        %s\n" "$token"
    done
fi

# Per-template report
printf "\n  Per-template token summary:\n"
for f in "${DOCKERFILES[@]}"; do
    name="${f#$TEMPLATE_DIR/}"
    count=$(grep -oh '@@[A-Za-z_][A-Za-z_0-9]*@@' "$f" 2>/dev/null | grep -v '^\s*#' | sort -u | wc -l | tr -d ' ')
    printf "    %-55s %s tokens\n" "$name" "$count"
done

#########################################################################
# CHECK 2: MUTATION TEST
# Inject @@MUTATION_TOKEN@@ into one template → test must fail.
# Remove it → test must pass.
#
# We use quarkus/Dockerfile.template as the mutation target since it
# covers the most substitution paths (JVM tuning ARGs, multistage, etc.)
#########################################################################
printf "\n=== Check 2: Mutation test ===\n"

MUTATION_TARGET="$TEMPLATE_DIR/quarkus/Dockerfile.template"
MUTATION_TOKEN="@@MUTATION_TOKEN@@"
MUTATION_MARKER="# mutation-test-injection"

# Safety: ensure no leftover mutation from a previous interrupted run
if grep -qF "$MUTATION_MARKER" "$MUTATION_TARGET" 2>/dev/null; then
    sed -i "/$MUTATION_MARKER/d" "$MUTATION_TARGET"
fi

#########################################################################
# 2a. Baseline: test must pass on clean templates
#########################################################################
output=$(bash "$TEST_SCRIPT" 2>&1)
rc=$?
assert_exit_zero "baseline: dockerfile-test.sh passes on clean templates" "$rc"

#########################################################################
# 2b. Inject mutation → test must fail
#########################################################################
printf "  Injecting %s into %s...\n" "$MUTATION_TOKEN" "${MUTATION_TARGET#$REPO_DIR/}"

# Append an ARG line with an unresolved placeholder after the FROM line
sed -i "s|^FROM @@dockerImage@@|FROM @@dockerImage@@\nARG INJECTED=\"${MUTATION_TOKEN}\" ${MUTATION_MARKER}|" \
    "$MUTATION_TARGET"

output=$(bash "$TEST_SCRIPT" 2>&1)
rc=$?
assert_exit_nonzero "with injected token: dockerfile-test.sh detects unresolved placeholder" "$rc"

# Show which assertion caught it (first FAIL line)
caught=$(printf '%s\n' "$output" | grep 'FAIL:' | head -3)
if [ -n "$caught" ]; then
    printf "  (caught by)\n"
    printf '%s\n' "$caught" | while IFS= read -r line; do
        printf "        %s\n" "$line"
    done
fi

#########################################################################
# 2c. Remove mutation → test must pass again
#########################################################################
sed -i "/$MUTATION_MARKER/d" "$MUTATION_TARGET"
printf "  Removed injection — restoring clean state...\n"

output=$(bash "$TEST_SCRIPT" 2>&1)
rc=$?
assert_exit_zero "after removal: dockerfile-test.sh passes again" "$rc"

# Confirm template is truly clean
if grep -qF "$MUTATION_TOKEN" "$MUTATION_TARGET" 2>/dev/null; then
    printf "  WARNING: mutation token still present in template — manual cleanup needed!\n"
fi

#########################################################################
# Summary
#########################################################################
printf "\n=== Summary ===\n"
printf "  Passed: %s / %s\n" "$PASSED" "$TOTAL"
printf "  Failed: %s / %s\n" "$FAILED" "$TOTAL"
if [ "$FAILED" -gt 0 ]; then
    # Emergency cleanup in case mutation is still injected
    sed -i "/$MUTATION_MARKER/d" "$MUTATION_TARGET" 2>/dev/null || true
    exit 1
fi
exit 0
