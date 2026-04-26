#!/usr/bin/env bash

#########################################################################
#
# toolarium-java-runner-test.sh
#
# Test script for toolarium-java-runner.sh
# Validates parameter parsing, option assembly, and edge cases.
#
#########################################################################

SCRIPT_DIR=$(cd -- "$(dirname "$0" 2>/dev/null)" && pwd)
RUNNER_TEMPLATE="$SCRIPT_DIR/../../../gradle/template/quarkus/toolarium-java-runner.sh.template"
TEST_DIR=$(mktemp -d)
# resolve @@placeholders@@ with test defaults (simulates Gradle build-time replacement)
RUNNER="$TEST_DIR/toolarium-java-runner.sh"
sed -e 's/@@dockerOsVersion@@/test/g' \
    -e 's/@@toolariumJavaRunnerLogPackage@@/toolarium.java.runner/g' \
    -e 's/@@toolariumJavaRunnerLogCategoryWidth@@/80/g' \
    -e 's/@@toolariumJavaRunnerLogCategoryMax@@/79/g' \
    -e 's/@@toolariumJavaRunnerLogInfoWidth@@/15/g' \
    -e 's/@@toolariumJavaRunnerLogInfoMax@@/15/g' \
    "$RUNNER_TEMPLATE" > "$RUNNER"
chmod +x "$RUNNER"
PASSED=0
FAILED=0
TOTAL=0

#########################################################################
# cleanup
#########################################################################
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

#########################################################################
# assert_exit_code
#########################################################################
assert_exit_code() {
    test_name="$1"
    expected="$2"
    actual="$3"
    TOTAL=$((TOTAL + 1))

    if [ "$actual" -eq "$expected" ]; then
        printf "  PASS: %s (exit code %s)\n" "$test_name" "$actual"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (expected exit %s, got %s)\n" "$test_name" "$expected" "$actual"
        FAILED=$((FAILED + 1))
    fi
}

#########################################################################
# assert_output_contains
#########################################################################
assert_output_contains() {
    test_name="$1"
    pattern="$2"
    output="$3"
    TOTAL=$((TOTAL + 1))

    if echo "$output" | grep -qF -- "$pattern"; then
        printf "  PASS: %s (contains '%s')\n" "$test_name" "$pattern"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (expected '%s' in output)\n" "$test_name" "$pattern"
        printf "        output: %s\n" "$output"
        FAILED=$((FAILED + 1))
    fi
}

#########################################################################
# assert_output_not_contains
#########################################################################
assert_output_not_contains() {
    test_name="$1"
    pattern="$2"
    output="$3"
    TOTAL=$((TOTAL + 1))

    if echo "$output" | grep -qF -- "$pattern"; then
        printf "  FAIL: %s (unexpected '%s' in output)\n" "$test_name" "$pattern"
        printf "        output: %s\n" "$output"
        FAILED=$((FAILED + 1))
    else
        printf "  PASS: %s (does not contain '%s')\n" "$test_name" "$pattern"
        PASSED=$((PASSED + 1))
    fi
}

#########################################################################
# create_mock_java - creates a fake java executable for testing
#########################################################################
create_mock_java() {
    mock_java="$TEST_DIR/mock-java"
    cat > "$mock_java" <<'MOCKEOF'
#!/bin/sh
if [ "$1" = "-version" ]; then
    echo "mock java version \"17.0.1\" 2024-01-01" >&2
    echo "MockJVM (build 17.0.1+0)" >&2
    echo "MockJVM 64-Bit Server VM (build 17.0.1+0, mixed mode)" >&2
    exit 0
fi
# Print received arguments for verification, then exit
echo "MOCK_JAVA_ARGS: $*"
exit 0
MOCKEOF
    chmod +x "$mock_java"
    echo "$mock_java"
}

#########################################################################
# create_mock_jar - creates a dummy jar file
#########################################################################
create_mock_jar() {
    jar_path="$TEST_DIR/app.jar"
    touch "$jar_path"
    echo "$jar_path"
}


printf "=========================================================================\n"
printf " toolarium-java-runner.sh test suite\n"
printf "=========================================================================\n\n"


#########################################################################
# Test 1: --help flag
#########################################################################
printf "[Test Group 1] Help and version flags\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --help 2>&1)
rc=$?
assert_exit_code "--help exits with 0" 0 "$rc"
assert_output_contains "--help shows usage" "start a java process" "$output"
assert_output_contains "--help shows options" "Overview of the available OPTIONs" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" -h 2>&1)
rc=$?
assert_exit_code "-h exits with 0" 0 "$rc"
assert_output_contains "-h shows usage" "start a java process" "$output"

echo ""


#########################################################################
# Test 2: --version flag
#########################################################################
printf "[Test Group 2] Version output\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --version 2>&1)
rc=$?
assert_exit_code "--version exits with 0" 0 "$rc"
assert_output_contains "--version shows toolarium" "toolarium java runner" "$output"

echo ""


#########################################################################
# Test 3: Missing executable
#########################################################################
printf "[Test Group 3] Missing executable\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --executable nonexistent_binary_xyz 2>&1)
rc=$?
assert_output_contains "missing executable message" "Missing package" "$output"
assert_output_contains "missing executable name" "nonexistent_binary_xyz" "$output"

echo ""


#########################################################################
# Test 4: Missing jar file
#########################################################################
printf "[Test Group 4] Missing jar file\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --jar nonexistent.jar 2>&1)
rc=$?
assert_output_contains "missing jar message" "Missing jar file" "$output"
assert_output_contains "missing jar name" "nonexistent.jar" "$output"

echo ""


#########################################################################
# Test 5: Invalid parameter
#########################################################################
printf "[Test Group 5] Invalid parameter\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --invalidParam 2>&1)
rc=$?
assert_exit_code "invalid param exits with 1" 1 "$rc"
assert_output_contains "invalid param message" "Invalid parameter" "$output"

echo ""


#########################################################################
# Test 6: Verbose mode shows assembled parameters
#########################################################################
printf "[Test Group 6] Verbose parameter assembly\n"

mock_java=$(create_mock_java)
mock_jar=$(create_mock_jar)

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --proxyHost myproxy.com \
    --proxyPort 8080 \
    --httpAgent TestAgent \
    --keepAlive true \
    --maxConnections 10 \
    --maxRedirects 5 2>&1)
rc=$?

assert_output_contains "verbose shows executable" "Set java executable" "$output"
assert_output_contains "verbose shows options" "Set java options" "$output"
assert_output_contains "proxyHost in options" "proxyHost=myproxy.com" "$output"
assert_output_contains "proxyPort in options" "proxyPort=8080" "$output"
assert_output_contains "httpAgent in options" "http.agent=TestAgent" "$output"
assert_output_contains "keepAlive in options" "keepAlive=true" "$output"
assert_output_contains "maxConnections in options" "maxConnections=10" "$output"
assert_output_contains "maxRedirects in options" "maxRedirects=5" "$output"

echo ""


#########################################################################
# Test 7: Log level parsing
#########################################################################
printf "[Test Group 7] Log level parsing\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --logLevel INFO \
    --logLevel "WARN,my.package.name" 2>&1)

assert_output_contains "global log level" "quarkus.log.level=INFO" "$output"
assert_output_contains "package log level" "quarkus.log.category" "$output"
assert_output_contains "package name in log" "my.package.name" "$output"
assert_output_contains "package warn level" "level=WARN" "$output"

echo ""


#########################################################################
# Test 8: nonProxyHosts comma-to-pipe conversion
#########################################################################
printf "[Test Group 8] nonProxyHosts conversion\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --nonProxyHosts "localhost,.cluster.local,*.acpt.app.com" 2>&1)

assert_output_contains "nonProxyHosts pipe-separated" "localhost|.cluster.local" "$output"

echo ""


#########################################################################
# Test 9: Java options passthrough
#########################################################################
printf "[Test Group 9] Java options passthrough\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --javaOptions "-Xms2m -Xmx10m" 2>&1)

assert_output_contains "javaOptions in output" "-Xms2m -Xmx10m" "$output"

echo ""


#########################################################################
# Test 10: --nocolor disables colors
#########################################################################
printf "[Test Group 10] No-color mode\n"

output=$(cd "$TEST_DIR" && TERM="xterm-256color" sh "$RUNNER" --nocolor --help 2>&1)
rc=$?
assert_exit_code "--nocolor --help exits 0" 0 "$rc"
# ANSI escape codes should not appear
assert_output_not_contains "no ANSI escapes in nocolor" "\\033\[" "$output"

echo ""


#########################################################################
# Test 11: Default jar file is app.jar
#########################################################################
printf "[Test Group 11] Default values\n"

clean_dir="$TEST_DIR/clean_default"
mkdir -p "$clean_dir"
output=$(cd "$clean_dir" && TERM="" sh "$RUNNER" --nocolor --verbose 2>&1)

assert_output_contains "default executable is java" "Set java executable" "$output"
assert_output_contains "missing default jar app.jar" "Missing jar file" "$output"

echo ""


#########################################################################
# Test 12: Environment variable support
#########################################################################
printf "[Test Group 12] Environment variable input\n"

output=$(cd "$TEST_DIR" && TERM="" proxyHost=envproxy.com proxyPort=3128 \
    sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)

assert_output_contains "env proxyHost" "proxyHost=envproxy.com" "$output"
assert_output_contains "env proxyPort" "proxyPort=3128" "$output"

echo ""


#########################################################################
# Test 13: Paths with spaces
#########################################################################
printf "[Test Group 13] Paths with spaces\n"

space_dir="$TEST_DIR/path with spaces"
mkdir -p "$space_dir"
space_jar="$space_dir/my app.jar"
touch "$space_jar"

space_java="$space_dir/mock-java"
cp "$mock_java" "$space_java"
chmod +x "$space_java"

output=$(cd "$space_dir" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$space_java" \
    --jar "$space_jar" 2>&1)

assert_output_contains "spaces: shows executable" "Set java executable" "$output"
assert_output_not_contains "spaces: no missing package error" "Missing package" "$output"

echo ""


#########################################################################
# Test 14: Mock java execution with jar
#########################################################################
printf "[Test Group 14] Successful execution with mock java\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)
rc=$?

assert_exit_code "mock java execution exits 0" 0 "$rc"
assert_output_contains "shows START banner" "START" "$output"
assert_output_contains "shows ENDED banner" "ENDED" "$output"
assert_output_contains "mock java received -jar" "MOCK_JAVA_ARGS: -jar" "$output"

echo ""


#########################################################################
# Test 15: Extra arguments passed through
#########################################################################
printf "[Test Group 15] Extra arguments passthrough\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    extraArg1 extraArg2 2>&1)

assert_output_contains "extra args in verbose" "Set java arguments" "$output"
assert_output_contains "extraArg1 passed" "extraArg1" "$output"
assert_output_contains "extraArg2 passed" "extraArg2" "$output"

echo ""


#########################################################################
# Test 16: logLevel via environment variable
#########################################################################
printf "[Test Group 16] Log level via environment variable\n"

output=$(cd "$TEST_DIR" && TERM="" logLevel="DEBUG" \
    sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)

assert_output_contains "env logLevel DEBUG" "quarkus.log.level=DEBUG" "$output"

echo ""


#########################################################################
# Test 17: Numeric validation rejects non-numeric values
#########################################################################
printf "[Test Group 17] Numeric parameter validation\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor \
    --proxyPort abc 2>&1)
assert_output_contains "proxyPort rejects non-numeric" "requires a number" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor \
    --maxConnections xyz 2>&1)
assert_output_contains "maxConnections rejects non-numeric" "requires a number" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor \
    --maxRedirects foo 2>&1)
assert_output_contains "maxRedirects rejects non-numeric" "requires a number" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --proxyPort 8080 \
    --maxConnections 10 \
    --maxRedirects 5 2>&1)
assert_output_not_contains "valid numbers accepted without error" "requires a number" "$output"
assert_output_contains "valid proxyPort in options" "proxyPort=8080" "$output"
assert_output_contains "valid maxConnections in options" "maxConnections=10" "$output"
assert_output_contains "valid maxRedirects in options" "maxRedirects=5" "$output"

echo ""


#########################################################################
# Test 18: Garbage collector parameter
#########################################################################
printf "[Test Group 18] Garbage collector parameter\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --gc UseG1GC 2>&1)
assert_output_contains "gc adds +UseG1GC" "-XX:+UseG1GC" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --gc +UseZGC 2>&1)
assert_output_contains "gc preserves leading +" "-XX:+UseZGC" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --gc UseSerialGC 2>&1)
assert_output_contains "gc UseSerialGC" "-XX:+UseSerialGC" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --gc -UseG1GC 2>&1)
assert_output_contains "gc preserves leading -" "-XX:-UseG1GC" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)
assert_output_not_contains "no gc without flag" "-XX:+Use" "$output"

echo ""


#########################################################################
# Test 19: GC logging parameter
#########################################################################
printf "[Test Group 19] GC logging parameter\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --gcLogging 2>&1)
assert_output_contains "gcLogging sets Xlog" "-Xlog:gc*=info" "$output"
assert_output_contains "gcLogging sets PrintFlagsFinal" "-XX:+PrintFlagsFinal" "$output"

echo ""


#########################################################################
# Test 20: Exit on out of memory parameter
#########################################################################
printf "[Test Group 20] Exit on out of memory parameter\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --exitOnOutOfMemory 2>&1)
assert_output_contains "exitOnOutOfMemory flag" "-XX:+ExitOnOutOfMemoryError" "$output"

echo ""


#########################################################################
# Test 21: Native memory tracking parameter
#########################################################################
printf "[Test Group 21] Native memory tracking parameter\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --nativeMemoryTracking 2>&1)
assert_output_contains "nativeMemoryTracking flag" "-XX:NativeMemoryTracking=summary" "$output"

echo ""


#########################################################################
# Test 22: JVM parameters via environment variables
#########################################################################
printf "[Test Group 22] JVM parameters via environment variables\n"

output=$(cd "$TEST_DIR" && TERM="" gc="UseZGC" gcLogging="true" \
    exitOnOutOfMemory="true" nativeMemoryTracking="true" \
    sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)
assert_output_contains "env gc" "-XX:+UseZGC" "$output"
assert_output_contains "env gcLogging" "-Xlog:gc*=info" "$output"
assert_output_contains "env exitOnOutOfMemory" "-XX:+ExitOnOutOfMemoryError" "$output"
assert_output_contains "env nativeMemoryTracking" "-XX:NativeMemoryTracking=summary" "$output"

echo ""


#########################################################################
# Test 23: All new JVM params combined via CLI
#########################################################################
printf "[Test Group 23] All new JVM params combined\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --gc UseZGC \
    --gcLogging \
    --exitOnOutOfMemory \
    --nativeMemoryTracking 2>&1)
assert_output_contains "combined: gc" "-XX:+UseZGC" "$output"
assert_output_contains "combined: gcLogging Xlog" "-Xlog:gc*=info" "$output"
assert_output_contains "combined: gcLogging PrintFlags" "-XX:+PrintFlagsFinal" "$output"
assert_output_contains "combined: exitOnOutOfMemory" "-XX:+ExitOnOutOfMemoryError" "$output"
assert_output_contains "combined: nativeMemoryTracking" "-XX:NativeMemoryTracking=summary" "$output"

echo ""


#########################################################################
# Test 24: Flags not set when not requested
#########################################################################
printf "[Test Group 24] Flags not set when not requested\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)
assert_output_not_contains "no gcLogging by default" "Xlog:gc" "$output"
assert_output_not_contains "no ExitOnOutOfMemory by default" "ExitOnOutOfMemoryError" "$output"
assert_output_not_contains "no NativeMemoryTracking by default" "NativeMemoryTracking" "$output"
assert_output_not_contains "no PrintFlagsFinal by default" "PrintFlagsFinal" "$output"

echo ""


#########################################################################
# Test 25: --gc with missing value is skipped
#########################################################################
printf "[Test Group 25] Parameter edge cases\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --gc --verbose 2>&1)
assert_output_not_contains "gc skipped when followed by --" "-XX:" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --gc 2>&1)
assert_output_not_contains "gc skipped when no value" "-XX:" "$output"

echo ""


#########################################################################
# Test 26: --observeMemoryCycle parameter parsing
#########################################################################
printf "[Test Group 26] observeMemoryCycle parameter parsing\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --help 2>&1)
assert_output_contains "help shows observeMemoryCycle" "observeMemoryCycle" "$output"
assert_output_contains "help shows /dev/shm" "/dev/shm/meminfo.out" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor \
    --observeMemoryCycle abc 2>&1)
assert_output_contains "observeMemoryCycle rejects non-numeric" "requires a number" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --observeMemoryCycle 2>&1)
assert_output_not_contains "observeMemoryCycle without value accepted" "requires a number" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --observeMemoryCycle 10 2>&1)
assert_output_not_contains "observeMemoryCycle 10 accepted" "requires a number" "$output"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor --verbose \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --observeMemoryCycle --verbose 2>&1)
assert_output_not_contains "observeMemoryCycle followed by -- uses default" "requires a number" "$output"

echo ""


#########################################################################
# Test 27: --observeMemoryCycle warns when cb-meminfo.sh not found
#########################################################################
printf "[Test Group 27] observeMemoryCycle missing meminfo.sh\n"

# Create a copy of toolarium-java-runner.sh in an isolated dir where cb-meminfo.sh does not exist
isolated_dir="$TEST_DIR/isolated"
mkdir -p "$isolated_dir"
cp "$RUNNER" "$isolated_dir/toolarium-java-runner.sh"
isolated_runner="$isolated_dir/toolarium-java-runner.sh"

output=$(cd "$TEST_DIR" && TERM="" sh "$isolated_runner" --nocolor \
    --executable "$mock_java" \
    --jar "$mock_jar" \
    --observeMemoryCycle 2>&1)
assert_output_contains "warns when cb-meminfo.sh missing" "not available" "$output"

echo ""


#########################################################################
# Test 28: --observeMemoryCycle via environment variable
#########################################################################
printf "[Test Group 28] observeMemoryCycle via environment variable\n"

output=$(cd "$TEST_DIR" && TERM="" observeMemoryCycle="10" \
    sh "$isolated_runner" --nocolor \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)
assert_output_contains "env observeMemoryCycle warns no cb-meminfo" "not available" "$output"

output=$(cd "$TEST_DIR" && TERM="" observeMemoryCycle="" \
    sh "$RUNNER" --nocolor \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)
assert_output_not_contains "empty env observeMemoryCycle no warning" "not available" "$output"

echo ""


#########################################################################
# Test 29: Java-style log messages on startup and shutdown
#########################################################################
printf "[Test Group 29] Java-style log messages (printLogMessage)\n"

mock_java=$(create_mock_java)
mock_jar=$(create_mock_jar)

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)
# startup log line
assert_output_contains "startup log line has package" "toolarium.java.runner" "$output"
assert_output_contains "startup log line has level I" " - I - " "$output"
assert_output_contains "startup log line has Starting" "Starting" "$output"
# shutdown log line
assert_output_contains "shutdown log line has Stopped" "Stopped" "$output"
assert_output_contains "shutdown log line has duration" "duration:" "$output"
assert_output_contains "shutdown log line has exit" "exit: 0" "$output"
# format: timestamp with comma millis, host|pid|thread
assert_output_contains "log format has pipe-separated context" "|1]" "$output"

echo ""


#########################################################################
# Test 30: Log messages on error (missing jar)
#########################################################################
printf "[Test Group 30] Java-style log messages on error\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor \
    --executable "$mock_java" \
    --jar "nonexistent.jar" 2>&1)
assert_output_contains "error log has level E" " - E - " "$output"
assert_output_contains "error log has Missing jar" "Missing jar file: nonexistent.jar" "$output"

echo ""


#########################################################################
# Test 31: Log messages on missing executable
#########################################################################
printf "[Test Group 31] Java-style log messages on missing executable\n"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor \
    --executable "nonexistent_binary_xyz" 2>&1)
assert_output_contains "missing exec log has level E" " - E - " "$output"
assert_output_contains "missing exec log has package" "toolarium.java.runner" "$output"
assert_output_contains "missing exec log message" "Missing package: nonexistent_binary_xyz" "$output"

echo ""


#########################################################################
# Test 32: Log format without logInformation column (dev format)
#########################################################################
printf "[Test Group 32] Log format without logInformation (dev-style)\n"

# create a runner with no logInfo dimensions (simulates %-50c{49} | %m%n)
RUNNER_NO_INFO="$TEST_DIR/toolarium-java-runner-noinfo.sh"
sed -e 's/@@dockerOsVersion@@/test/g' \
    -e 's/@@toolariumJavaRunnerLogPackage@@/toolarium.java.runner/g' \
    -e 's/@@toolariumJavaRunnerLogCategoryWidth@@/50/g' \
    -e 's/@@toolariumJavaRunnerLogCategoryMax@@/49/g' \
    -e 's/@@toolariumJavaRunnerLogInfoWidth@@//g' \
    -e 's/@@toolariumJavaRunnerLogInfoMax@@//g' \
    "$RUNNER_TEMPLATE" > "$RUNNER_NO_INFO"
chmod +x "$RUNNER_NO_INFO"

mock_java=$(create_mock_java)
mock_jar=$(create_mock_jar)
output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER_NO_INFO" --nocolor \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)
assert_exit_code "no-info format exits 0" 0 "$?"
assert_output_contains "no-info has package" "toolarium.java.runner" "$output"
assert_output_contains "no-info has Starting" "Starting" "$output"
# should NOT have the double " - " separator before the pipe (logInfo column absent)
# with logInfo:    "...runner    - <info>          | Starting..."
# without logInfo: "...runner    | Starting..."
# verify the message directly follows category + " | "
assert_output_contains "no-info pipe after category" "| Starting" "$output"

echo ""


#########################################################################
# Test 33: Log format with custom category width
#########################################################################
printf "[Test Group 33] Log format with custom category width\n"

# create a runner with narrower category (40.39) and logInfo (10.10)
RUNNER_CUSTOM="$TEST_DIR/toolarium-java-runner-custom.sh"
sed -e 's/@@dockerOsVersion@@/test/g' \
    -e 's/@@toolariumJavaRunnerLogPackage@@/com.example.myapp/g' \
    -e 's/@@toolariumJavaRunnerLogCategoryWidth@@/40/g' \
    -e 's/@@toolariumJavaRunnerLogCategoryMax@@/39/g' \
    -e 's/@@toolariumJavaRunnerLogInfoWidth@@/10/g' \
    -e 's/@@toolariumJavaRunnerLogInfoMax@@/10/g' \
    "$RUNNER_TEMPLATE" > "$RUNNER_CUSTOM"
chmod +x "$RUNNER_CUSTOM"

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER_CUSTOM" --nocolor \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)
assert_exit_code "custom width exits 0" 0 "$?"
assert_output_contains "custom width has custom package" "com.example.myapp" "$output"
assert_output_not_contains "custom width no default package" "toolarium.java.runner" "$output"
assert_output_contains "custom width has Starting" "Starting" "$output"

echo ""


#########################################################################
# Test 34: On error exit, MEMINFO_FILE content is printed
#########################################################################
printf "[Test Group 34] Meminfo dump on error exit\n"

# create a mock java that fails
mock_java_fail="$TEST_DIR/mock-java-fail"
cat > "$mock_java_fail" <<'MOCKEOF'
#!/bin/sh
if [ "$1" = "-version" ]; then
    echo "mock java version \"17.0.1\" 2024-01-01" >&2
    echo "MockJVM (build 17.0.1+0)" >&2
    echo "MockJVM 64-Bit Server VM (build 17.0.1+0, mixed mode)" >&2
    exit 0
fi
exit 137
MOCKEOF
chmod +x "$mock_java_fail"
mock_jar=$(create_mock_jar)

# create a fake meminfo file at the expected path
MEMINFO_TEST="/dev/shm/cb-meminfo.out"
printf '%s\n' "MEM: rss=256MB heap=128MB" > "$MEMINFO_TEST" 2>/dev/null

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor \
    --executable "$mock_java_fail" \
    --jar "$mock_jar" 2>&1)
if [ -w "/dev/shm" ]; then
    assert_output_contains "meminfo printed on error" "MEM: rss=256MB heap=128MB" "$output"
    assert_output_contains "error log on failed exit" " - E - " "$output"
else
    # /dev/shm not available (e.g. some CI), skip gracefully
    printf "  SKIP: /dev/shm not writable, skipping meminfo dump test\n"
fi

echo ""


#########################################################################
# Test 35: On success exit, MEMINFO_FILE is NOT printed
#########################################################################
printf "[Test Group 35] No meminfo dump on success exit\n"

mock_java=$(create_mock_java)
mock_jar=$(create_mock_jar)

# create a fake meminfo file
printf '%s\n' "MEM: should-not-appear" > "$MEMINFO_TEST" 2>/dev/null

output=$(cd "$TEST_DIR" && TERM="" sh "$RUNNER" --nocolor \
    --executable "$mock_java" \
    --jar "$mock_jar" 2>&1)
if [ -w "/dev/shm" ]; then
    assert_output_not_contains "meminfo not printed on success" "should-not-appear" "$output"
fi
rm -f "$MEMINFO_TEST" 2>/dev/null

echo ""


#########################################################################
# Summary
#########################################################################
printf "=========================================================================\n"
printf " Results: %s/%s passed, %s failed\n" "$PASSED" "$TOTAL" "$FAILED"
printf "=========================================================================\n"

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
