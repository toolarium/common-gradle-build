#!/usr/bin/env bash

#########################################################################
#
# apply-subpath-test.sh
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
# Test script for apply-subpath.sh
# Validates subpath detection, file replacements, security guards,
# nginx configuration, and edge cases.
#
#########################################################################

SCRIPT_DIR=$(cd -- "$(dirname "$0" 2>/dev/null)" && pwd)
SCRIPT="$SCRIPT_DIR/../../../gradle/template/nodejs/apply-subpath.sh.template"
TEST_DIR=$(mktemp -d)
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
# assert_file_contains - check that a file contains a pattern
#########################################################################
assert_file_contains() {
    test_name="$1"
    pattern="$2"
    file_path="$3"
    TOTAL=$((TOTAL + 1))

    if [ ! -f "$file_path" ]; then
        printf "  FAIL: %s (file '%s' does not exist)\n" "$test_name" "$file_path"
        FAILED=$((FAILED + 1))
    elif grep -qF -- "$pattern" "$file_path"; then
        printf "  PASS: %s (file contains '%s')\n" "$test_name" "$pattern"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (expected '%s' in file '%s')\n" "$test_name" "$pattern" "$file_path"
        printf "        content: %s\n" "$(cat "$file_path")"
        FAILED=$((FAILED + 1))
    fi
}

#########################################################################
# assert_file_not_contains - check that a file does not contain a pattern
#########################################################################
assert_file_not_contains() {
    test_name="$1"
    pattern="$2"
    file_path="$3"
    TOTAL=$((TOTAL + 1))

    if [ ! -f "$file_path" ]; then
        printf "  FAIL: %s (file '%s' does not exist)\n" "$test_name" "$file_path"
        FAILED=$((FAILED + 1))
    elif grep -qF -- "$pattern" "$file_path"; then
        printf "  FAIL: %s (unexpected '%s' in file '%s')\n" "$test_name" "$pattern" "$file_path"
        printf "        content: %s\n" "$(cat "$file_path")"
        FAILED=$((FAILED + 1))
    else
        printf "  PASS: %s (file does not contain '%s')\n" "$test_name" "$pattern"
        PASSED=$((PASSED + 1))
    fi
}

#########################################################################
# assert_file_exists
#########################################################################
assert_file_exists() {
    test_name="$1"
    file_path="$2"
    TOTAL=$((TOTAL + 1))

    if [ -e "$file_path" ]; then
        printf "  PASS: %s (exists '%s')\n" "$test_name" "$file_path"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (expected '%s' to exist)\n" "$test_name" "$file_path"
        FAILED=$((FAILED + 1))
    fi
}

#########################################################################
# assert_file_not_exists
#########################################################################
assert_file_not_exists() {
    test_name="$1"
    file_path="$2"
    TOTAL=$((TOTAL + 1))

    if [ ! -e "$file_path" ]; then
        printf "  PASS: %s (does not exist '%s')\n" "$test_name" "$file_path"
        PASSED=$((PASSED + 1))
    else
        printf "  FAIL: %s (expected '%s' not to exist)\n" "$test_name" "$file_path"
        FAILED=$((FAILED + 1))
    fi
}

#########################################################################
# setup_deployment - create a deployment directory with a subdir and files
#   $1 = base dir
#   $2 = subdir name
#########################################################################
setup_deployment() {
    base="$1"
    subdir="$2"
    rm -rf "$base"
    mkdir -p "$base/$subdir"
}

#########################################################################
# create_text_file - create a text file with given content
#   $1 = file path
#   $2 = content
#########################################################################
create_text_file() {
    printf '%s\n' "$2" > "$1"
}

#########################################################################
# create_nginx_conf - create a mock nginx default.conf
#   $1 = nginx conf dir
#   $2 = subdir name for try_files
#########################################################################
create_nginx_conf() {
    conf_dir="$1"
    subdir="$2"
    mkdir -p "$conf_dir"
    cat > "$conf_dir/default.conf" <<CONFEOF
server {
  listen 8080;
  root /deployment;
  index index.html;
  location / {
    try_files \$uri ${subdir}/index.html /${subdir}/index.html =404;
  }
}
CONFEOF
}

#########################################################################
# run_script - run apply-subpath.sh with given env vars
#   Sets DEPLOYMENT_DIR, SUBPATH, PROPERTIES_FILE, NGINX_CONF_DIR,
#   REPLACE_WHITESPACE_VARIATIONS, REPLACE_CASE_VARIATIONS
#   Returns: output in $LAST_OUTPUT, exit code in $LAST_EXIT
#########################################################################
run_script() {
    deploy_dir="${1:-}"
    subpath="${2:-}"
    props_file="${3:-/dev/null}"
    nginx_dir="${4:-$TEST_DIR/nonexistent-nginx}"
    whitespace="${5:-false}"
    case_var="${6:-false}"

    LAST_OUTPUT=$(DEPLOYMENT_DIR="$deploy_dir" \
        SUBPATH="$subpath" \
        PROPERTIES_FILE="$props_file" \
        NGINX_CONF_DIR="$nginx_dir" \
        REPLACE_WHITESPACE_VARIATIONS="$whitespace" \
        REPLACE_CASE_VARIATIONS="$case_var" \
        sh "$SCRIPT" 2>&1)
    LAST_EXIT=$?
}


printf "=========================================================================\n"
printf " apply-subpath.sh test suite\n"
printf "=========================================================================\n\n"

# Path logic reference (no properties file, SUBPATH set):
#   sourceSubdir = <dirname found in DEPLOYMENT_DIR>
#   runtimeUrlPath = sourceSubdir (default when no properties)
#   targetSubpath = SUBPATH (stripped)
#   replaceTo = targetSubpath/runtimeUrlPath
#   files end up at: DEPLOYMENT_DIR/targetSubpath/sourceSubdir/...
#   content: sourceSubdir -> replaceTo


#########################################################################
echo "=== Early exit: no deployment directory ==="
#########################################################################
run_script "$TEST_DIR/nonexistent" "" "" ""
assert_exit_code "exit 0 when deployment dir missing" 0 "$LAST_EXIT"
assert_output_contains "skip message" "Skip apply subpath, no" "$LAST_OUTPUT"

#########################################################################
echo ""
echo "=== Early exit: empty deployment directory (no subdirs) ==="
#########################################################################
deploy="$TEST_DIR/empty-deploy"
mkdir -p "$deploy"
run_script "$deploy" "" "" ""
assert_exit_code "exit 0 when no subdirs" 0 "$LAST_EXIT"
assert_output_contains "no subdir message" "no source subdirectory found" "$LAST_OUTPUT"

#########################################################################
echo ""
echo "=== Early exit: source equals target (no-op) ==="
#########################################################################
deploy="$TEST_DIR/noop-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/index.html" "hello myapp"
run_script "$deploy" "" "" ""
assert_exit_code "exit 0 when source equals target" 0 "$LAST_EXIT"
# no SUBPATH, no properties -> targetSubpath=myapp=sourceSubdir -> early exit, no changes
assert_file_contains "file untouched" "hello myapp" "$deploy/myapp/index.html"

#########################################################################
echo ""
echo "=== Security: SUBPATH with path traversal (..) ==="
#########################################################################
deploy="$TEST_DIR/traversal-deploy"
setup_deployment "$deploy" "myapp"
run_script "$deploy" "../../etc" "" ""
assert_exit_code "reject path traversal" 1 "$LAST_EXIT"
assert_output_contains "traversal error" "SUBPATH contains '..'" "$LAST_OUTPUT"

#########################################################################
echo ""
echo "=== Security: SUBPATH with unsafe characters ==="
#########################################################################
deploy="$TEST_DIR/unsafe-subpath-deploy"
setup_deployment "$deploy" "myapp"
run_script "$deploy" 'my;app' "" ""
assert_exit_code "reject semicolon in SUBPATH" 1 "$LAST_EXIT"
assert_output_contains "unsafe char error" "unsafe characters" "$LAST_OUTPUT"

deploy="$TEST_DIR/unsafe-subpath-deploy2"
setup_deployment "$deploy" "myapp"
run_script "$deploy" 'my$app' "" ""
assert_exit_code "reject dollar in SUBPATH" 1 "$LAST_EXIT"
assert_output_contains "unsafe char error dollar" "unsafe characters" "$LAST_OUTPUT"

deploy="$TEST_DIR/unsafe-subpath-deploy3"
setup_deployment "$deploy" "myapp"
run_script "$deploy" 'my app' "" ""
assert_exit_code "reject space in SUBPATH" 1 "$LAST_EXIT"
assert_output_contains "unsafe char error space" "unsafe characters" "$LAST_OUTPUT"

#########################################################################
echo ""
echo "=== Security: subdirectory with unsafe characters ==="
#########################################################################
deploy="$TEST_DIR/unsafe-subdir-deploy"
setup_deployment "$deploy" 'my;app'
run_script "$deploy" "target" "" ""
assert_exit_code "reject unsafe subdir name" 1 "$LAST_EXIT"
assert_output_contains "unsafe subdir error" "unsafe characters" "$LAST_OUTPUT"

#########################################################################
echo ""
echo "=== Security: SUBPATH with allowed special chars (dot, hyphen, slash) ==="
#########################################################################
deploy="$TEST_DIR/allowed-chars-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/index.html" "path: myapp"
run_script "$deploy" "org/my-app.v2" "" ""
assert_exit_code "accept dot, hyphen, slash in SUBPATH" 0 "$LAST_EXIT"

#########################################################################
echo ""
echo "=== Multiple subdirectories: uses first, warns ==="
#########################################################################
deploy="$TEST_DIR/multi-deploy"
mkdir -p "$deploy/aaa" "$deploy/bbb"
create_text_file "$deploy/aaa/index.html" "hello aaa"
run_script "$deploy" "target" "" ""
assert_exit_code "exit 0 with multiple subdirs" 0 "$LAST_EXIT"
assert_output_contains "multi subdir warning" "WARNING: multiple subdirectories" "$LAST_OUTPUT"

#########################################################################
echo ""
echo "=== Basic replacement: with properties file and SUBPATH ==="
#########################################################################
deploy="$TEST_DIR/basic-deploy"
setup_deployment "$deploy" "__myapp__"
create_text_file "$deploy/__myapp__/index.html" 'href="__myapp__/style.css"'
create_text_file "$deploy/__myapp__/app.js" 'const base = "__myapp__";'
# properties file that maps runtime path
props="$TEST_DIR/basic.properties"
cat > "$props" <<'EOF'
service.root-path = /myapp
service.resources = /myapp
EOF
# sourceSubdir=__myapp__, runtimeUrlPath=myapp, targetSubpath=ui, replaceTo=ui/myapp
# mv __myapp__ -> myapp (rename), then mv myapp into ui -> ui/myapp
run_script "$deploy" "ui" "$props" ""
assert_exit_code "basic replacement exit 0" 0 "$LAST_EXIT"
assert_file_contains "html replaced" 'href="ui/myapp/style.css"' "$deploy/ui/myapp/index.html"
assert_file_contains "js replaced" 'const base = "ui/myapp";' "$deploy/ui/myapp/app.js"

#########################################################################
echo ""
echo "=== Replacement: API paths are protected ==="
#########################################################################
deploy="$TEST_DIR/api-protect-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/index.js" 'fetch("api/myapp/users"); load("myapp/page");'
# sourceSubdir=myapp, runtimeUrlPath=myapp, targetSubpath=newpath, replaceTo=newpath/myapp
# mv myapp into newpath -> newpath/myapp
run_script "$deploy" "newpath" "" ""
assert_exit_code "api protection exit 0" 0 "$LAST_EXIT"
assert_file_contains "api path preserved" "api/myapp/users" "$deploy/newpath/myapp/index.js"
assert_file_contains "non-api path replaced" "newpath/myapp/page" "$deploy/newpath/myapp/index.js"

#########################################################################
echo ""
echo "=== Replacement: URL encoding (%2F) ==="
#########################################################################
deploy="$TEST_DIR/urlenc-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/config.js" 'path: "myapp%2Fstyle"'
# replaceTo=newpath/myapp, "myapp%2F" -> "newpath/myapp/"
run_script "$deploy" "newpath" "" ""
assert_exit_code "url encoding exit 0" 0 "$LAST_EXIT"
assert_file_contains "url encoded replaced" "newpath/myapp/" "$deploy/newpath/myapp/config.js"

#########################################################################
echo ""
echo "=== Replacement: Unicode escape (\u002F) ==="
#########################################################################
deploy="$TEST_DIR/unicode-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/config.js" 'path: "myapp\u002Fstyle"'
# replaceTo=newpath/myapp, "myapp\u002F" -> "newpath/myapp/"
run_script "$deploy" "newpath" "" ""
assert_exit_code "unicode escape exit 0" 0 "$LAST_EXIT"
assert_file_contains "unicode escaped replaced" "newpath/myapp/" "$deploy/newpath/myapp/config.js"

#########################################################################
echo ""
echo "=== Replacement: JSON escaped slash (\/) ==="
#########################################################################
deploy="$TEST_DIR/jsonesc-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/data.json" '"url": "myapp\\/detail"'
# replaceTo=newpath/myapp, "myapp\/" -> "newpath/myapp/"
run_script "$deploy" "newpath" "" ""
assert_exit_code "json escaped exit 0" 0 "$LAST_EXIT"
assert_file_contains "json escaped replaced" "newpath/myapp/" "$deploy/newpath/myapp/data.json"

#########################################################################
echo ""
echo "=== Replacement: double escaped slash (\\\\/) ==="
#########################################################################
deploy="$TEST_DIR/dblesc-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/data.json" '"url": "myapp\\/detail"'
# replaceTo=newpath/myapp, "myapp\\/" -> "newpath/myapp/"
run_script "$deploy" "newpath" "" ""
assert_exit_code "double escaped exit 0" 0 "$LAST_EXIT"
assert_file_contains "double escaped replaced" "newpath/myapp/" "$deploy/newpath/myapp/data.json"

#########################################################################
echo ""
echo "=== Replacement: quoted contexts (double, single, backtick) ==="
#########################################################################
deploy="$TEST_DIR/quoted-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/config.js" "double: \"myapp\" single: 'myapp' backtick: \`myapp\`"
# replaceTo=newpath/myapp
run_script "$deploy" "newpath" "" ""
assert_exit_code "quoted contexts exit 0" 0 "$LAST_EXIT"
assert_file_contains "double quote replaced" '"newpath/myapp"' "$deploy/newpath/myapp/config.js"
assert_file_contains "single quote replaced" "'newpath/myapp'" "$deploy/newpath/myapp/config.js"
assert_file_contains "backtick replaced" '`newpath/myapp`' "$deploy/newpath/myapp/config.js"

#########################################################################
echo ""
echo "=== Binary file skipping: known extensions ==="
#########################################################################
deploy="$TEST_DIR/binary-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/index.html" "path: myapp"
create_text_file "$deploy/myapp/logo.png" "myapp should not be replaced"
create_text_file "$deploy/myapp/font.woff2" "myapp should not be replaced"
create_text_file "$deploy/myapp/bundle.wasm" "myapp should not be replaced"
# replaceTo=newpath/myapp, files at newpath/myapp/...
run_script "$deploy" "newpath" "" ""
assert_exit_code "binary skip exit 0" 0 "$LAST_EXIT"
assert_file_contains "html was replaced" "path: newpath/myapp" "$deploy/newpath/myapp/index.html"
assert_file_contains "png skipped" "myapp should not be replaced" "$deploy/newpath/myapp/logo.png"
assert_file_contains "woff2 skipped" "myapp should not be replaced" "$deploy/newpath/myapp/font.woff2"
assert_file_contains "wasm skipped" "myapp should not be replaced" "$deploy/newpath/myapp/bundle.wasm"

#########################################################################
echo ""
echo "=== Locales directory skipped ==="
#########################################################################
deploy="$TEST_DIR/locales-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/index.html" "path: myapp"
mkdir -p "$deploy/myapp/locales"
create_text_file "$deploy/myapp/locales/en.json" '{"path": "myapp"}'
# replaceTo=newpath/myapp, files at newpath/myapp/...
run_script "$deploy" "newpath" "" ""
assert_exit_code "locales skip exit 0" 0 "$LAST_EXIT"
assert_file_contains "html replaced" "path: newpath/myapp" "$deploy/newpath/myapp/index.html"
assert_file_contains "locales untouched" "myapp" "$deploy/newpath/myapp/locales/en.json"

#########################################################################
echo ""
echo "=== Properties file: runtime and kubernetes paths ==="
#########################################################################
deploy="$TEST_DIR/props-deploy"
setup_deployment "$deploy" "__ui__"
create_text_file "$deploy/__ui__/index.html" "ref: __ui__"
props="$TEST_DIR/props.properties"
cat > "$props" <<'EOF'
service.root-path = /dashboard
service.resources = /dashboard
EOF
# sourceSubdir=__ui__, runtimeUrlPath=dashboard, no SUBPATH -> targetSubpath=dashboard
# __ui__ != dashboard, so mv __ui__ -> dashboard
run_script "$deploy" "" "$props" ""
assert_exit_code "properties path exit 0" 0 "$LAST_EXIT"
assert_file_exists "moved to runtimeUrlPath" "$deploy/dashboard/index.html"
assert_file_contains "content replaced" "ref: dashboard" "$deploy/dashboard/index.html"

#########################################################################
echo ""
echo "=== Properties file with SUBPATH: nested path ==="
#########################################################################
deploy="$TEST_DIR/props-sub-deploy"
setup_deployment "$deploy" "__ui__"
create_text_file "$deploy/__ui__/index.html" "ref: __ui__"
props="$TEST_DIR/props-sub.properties"
cat > "$props" <<'EOF'
service.root-path = /app
service.resources = /myui
EOF
# sourceSubdir=__ui__, runtimeUrlPath=myui, targetSubpath=portal, replaceTo=portal/myui
# mv __ui__ -> myui (rename), then mv myui into portal -> portal/myui
run_script "$deploy" "portal" "$props" ""
assert_exit_code "props + SUBPATH exit 0" 0 "$LAST_EXIT"
assert_file_exists "nested path created" "$deploy/portal/myui/index.html"
assert_file_contains "content has replaceTo" "ref: portal/myui" "$deploy/portal/myui/index.html"

#########################################################################
echo ""
echo "=== Nginx conf: basic replacement ==="
#########################################################################
deploy="$TEST_DIR/nginx-basic-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/index.html" "myapp"
nginx_dir="$TEST_DIR/nginx-basic"
create_nginx_conf "$nginx_dir" "myapp"
# sourceSubdir=myapp, runtimeUrlPath=myapp, targetSubpath=newpath, replaceTo=newpath/myapp
# nginx sed replaces "myapp" with "newpath/myapp" in default.conf
run_script "$deploy" "newpath" "" "$nginx_dir"
assert_exit_code "nginx basic exit 0" 0 "$LAST_EXIT"
assert_file_contains "nginx subdir replaced" "newpath/myapp/index.html" "$nginx_dir/default.conf"

#########################################################################
echo ""
echo "=== Nginx conf: hierarchical 302 redirects ==="
#########################################################################
deploy="$TEST_DIR/nginx-redir-deploy"
setup_deployment "$deploy" "myui"
create_text_file "$deploy/myui/index.html" "myui"
nginx_dir="$TEST_DIR/nginx-redir"
create_nginx_conf "$nginx_dir" "myui"
# sourceSubdir=myui, runtimeUrlPath=myui, targetSubpath=org/team, replaceTo=org/team/myui
# targetSubpath(org/team) != runtimeUrlPath(myui) -> generates redirect blocks
run_script "$deploy" "org/team" "" "$nginx_dir"
assert_exit_code "nginx redirect exit 0" 0 "$LAST_EXIT"
assert_output_contains "redirect applied" "hierarchical 302 redirects" "$LAST_OUTPUT"
assert_file_contains "redirect for org" "location ~ ^/org/?$" "$nginx_dir/default.conf"
assert_file_contains "redirect for org/team" "location ~ ^/org/team/?$" "$nginx_dir/default.conf"
assert_file_contains "redirect target" "return 302 /org/team/myui/" "$nginx_dir/default.conf"

#########################################################################
echo ""
echo "=== Nginx conf: __mypage__ with SUBPATH generates 302 redirect ==="
#########################################################################
deploy="$TEST_DIR/nginx-dunder-deploy"
setup_deployment "$deploy" "__mypage__"
create_text_file "$deploy/__mypage__/index.html" "__mypage__"
nginx_dir="$TEST_DIR/nginx-dunder"
create_nginx_conf "$nginx_dir" "__mypage__"
props="$TEST_DIR/nginx-dunder.properties"
printf '%s\n' 'service.root-path = /mypage' 'service.resources = /mypage' > "$props"
# sourceSubdir=__mypage__, runtimeUrlPath=mypage, targetSubpath=ppp, replaceTo=ppp/mypage
# targetSubpath(ppp) != runtimeUrlPath(mypage) -> generates redirect for /ppp
run_script "$deploy" "ppp" "$props" "$nginx_dir"
assert_exit_code "__mypage__+SUBPATH exit 0" 0 "$LAST_EXIT"
assert_output_contains "__mypage__+SUBPATH redirect applied" "hierarchical 302 redirects" "$LAST_OUTPUT"
assert_file_contains "__mypage__+SUBPATH redirect for ppp" "location ~ ^/ppp/?$" "$nginx_dir/default.conf"
assert_file_contains "__mypage__+SUBPATH redirect target" "return 302 /ppp/mypage/" "$nginx_dir/default.conf"

#########################################################################
echo ""
echo "=== Nginx conf: no redirects when targetSubpath equals runtimeUrlPath ==="
#########################################################################
deploy="$TEST_DIR/nginx-noredir-deploy"
setup_deployment "$deploy" "__myui__"
create_text_file "$deploy/__myui__/index.html" "__myui__"
nginx_dir="$TEST_DIR/nginx-noredir"
props="$TEST_DIR/nginx-noredir.properties"
cat > "$props" <<'EOF'
service.root-path = /newui
service.resources = /newui
EOF
create_nginx_conf "$nginx_dir" "__myui__"
# sourceSubdir=__myui__, runtimeUrlPath=newui, no SUBPATH -> targetSubpath=newui
# targetSubpath(newui) == runtimeUrlPath(newui) -> no redirect blocks
run_script "$deploy" "" "$props" "$nginx_dir"
assert_exit_code "nginx no redirect exit 0" 0 "$LAST_EXIT"
assert_output_not_contains "no redirect output" "hierarchical 302 redirects" "$LAST_OUTPUT"

#########################################################################
echo ""
echo "=== Option 7: whitespace variations (disabled by default) ==="
#########################################################################
deploy="$TEST_DIR/whitespace-off-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/config.txt" "key =  myapp  value"
# replaceTo=newpath/myapp, standard sed replaces "myapp" -> "newpath/myapp" regardless
run_script "$deploy" "newpath" "" "" "false"
assert_exit_code "whitespace off exit 0" 0 "$LAST_EXIT"
# standard replacement already handles "myapp", so check it was replaced
assert_file_contains "standard replaced" "newpath/myapp" "$deploy/newpath/myapp/config.txt"

#########################################################################
echo ""
echo "=== Option 7: whitespace variations (enabled) ==="
#########################################################################
deploy="$TEST_DIR/whitespace-on-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/config.txt" "key = myapp  value"
run_script "$deploy" "newpath" "" "" "true"
assert_exit_code "whitespace on exit 0" 0 "$LAST_EXIT"
assert_file_contains "whitespace variation replaced" "newpath/myapp" "$deploy/newpath/myapp/config.txt"

#########################################################################
echo ""
echo "=== Option 8: case variations (disabled by default) ==="
#########################################################################
deploy="$TEST_DIR/case-off-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/config.txt" "lower: myapp upper: MYAPP"
# replaceTo=newpath/myapp; standard sed replaces "myapp" but NOT "MYAPP"
run_script "$deploy" "newpath" "" "" "false" "false"
assert_exit_code "case off exit 0" 0 "$LAST_EXIT"
assert_file_contains "upper case not replaced" "MYAPP" "$deploy/newpath/myapp/config.txt"

#########################################################################
echo ""
echo "=== Option 8: case variations (enabled) ==="
#########################################################################
deploy="$TEST_DIR/case-on-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/config.txt" "lower: myapp upper: MYAPP"
run_script "$deploy" "newpath" "" "" "false" "true"
assert_exit_code "case on exit 0" 0 "$LAST_EXIT"
assert_file_not_contains "upper case replaced" "MYAPP" "$deploy/newpath/myapp/config.txt"
assert_file_contains "replaced with target" "newpath/myapp" "$deploy/newpath/myapp/config.txt"

#########################################################################
echo ""
echo "=== Move: __subdir__ renamed to runtimeUrlPath ==="
#########################################################################
deploy="$TEST_DIR/rename-deploy"
setup_deployment "$deploy" "__portal__"
create_text_file "$deploy/__portal__/index.html" "ref: __portal__"
props="$TEST_DIR/rename.properties"
cat > "$props" <<'EOF'
service.root-path = /portal
service.resources = /portal
EOF
# sourceSubdir=__portal__, runtimeUrlPath=portal, targetSubpath=app, replaceTo=app/portal
# mv __portal__ -> portal (rename), then mv portal into app -> app/portal
run_script "$deploy" "app" "$props" ""
assert_exit_code "rename move exit 0" 0 "$LAST_EXIT"
assert_file_not_exists "old dir removed" "$deploy/__portal__"
assert_file_exists "target dir exists" "$deploy/app/portal/index.html"
assert_file_contains "content replaced" "ref: app/portal" "$deploy/app/portal/index.html"

#########################################################################
echo ""
echo "=== No SUBPATH: default to runtimeUrlPath ==="
#########################################################################
deploy="$TEST_DIR/default-path-deploy"
setup_deployment "$deploy" "__ui__"
create_text_file "$deploy/__ui__/app.js" "base: __ui__"
props="$TEST_DIR/default-path.properties"
cat > "$props" <<'EOF'
service.root-path = /myui
service.resources = /myui
EOF
# sourceSubdir=__ui__, runtimeUrlPath=myui, no SUBPATH -> targetSubpath=myui, replaceTo=myui
# mv __ui__ -> myui
run_script "$deploy" "" "$props" ""
assert_exit_code "default path exit 0" 0 "$LAST_EXIT"
assert_output_contains "default message" "No specific subpath defined" "$LAST_OUTPUT"
assert_file_exists "moved to runtimeUrlPath" "$deploy/myui/app.js"
assert_file_contains "content replaced" "base: myui" "$deploy/myui/app.js"

#########################################################################
echo ""
echo "=== SUBPATH leading/trailing slashes stripped ==="
#########################################################################
deploy="$TEST_DIR/slash-strip-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/index.html" "myapp"
# SUBPATH="///newpath///" -> targetSubpath="newpath", replaceTo=newpath/myapp
# files at newpath/myapp/...
run_script "$deploy" "///newpath///" "" ""
assert_exit_code "slash strip exit 0" 0 "$LAST_EXIT"
assert_file_exists "path without slashes" "$deploy/newpath/myapp/index.html"

#########################################################################
echo ""
echo "=== Sentinel: __PROTECTED_API__ not left in files ==="
#########################################################################
deploy="$TEST_DIR/sentinel-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/index.js" 'fetch("api/myapp/v1"); load("myapp/page");'
# replaceTo=newpath/myapp, files at newpath/myapp/...
run_script "$deploy" "newpath" "" ""
assert_exit_code "sentinel cleanup exit 0" 0 "$LAST_EXIT"
assert_file_not_contains "no sentinel left" "__PROTECTED_API__" "$deploy/newpath/myapp/index.js"

#########################################################################
echo ""
echo "=== Multiple files in nested directories ==="
#########################################################################
deploy="$TEST_DIR/nested-deploy"
setup_deployment "$deploy" "myapp"
mkdir -p "$deploy/myapp/sub1/sub2"
create_text_file "$deploy/myapp/index.html" "root: myapp"
create_text_file "$deploy/myapp/sub1/page.html" "sub1: myapp"
create_text_file "$deploy/myapp/sub1/sub2/deep.js" "deep: myapp"
# replaceTo=newpath/myapp, files at newpath/myapp/...
run_script "$deploy" "newpath" "" ""
assert_exit_code "nested dirs exit 0" 0 "$LAST_EXIT"
assert_file_contains "root replaced" "root: newpath/myapp" "$deploy/newpath/myapp/index.html"
assert_file_contains "sub1 replaced" "sub1: newpath/myapp" "$deploy/newpath/myapp/sub1/page.html"
assert_file_contains "sub2 replaced" "deep: newpath/myapp" "$deploy/newpath/myapp/sub1/sub2/deep.js"

#########################################################################
echo ""
echo "=== Empty deployment subdir (no files) ==="
#########################################################################
deploy="$TEST_DIR/empty-subdir-deploy"
setup_deployment "$deploy" "myapp"
# replaceTo=newpath/myapp, mv myapp into newpath -> newpath/myapp
run_script "$deploy" "newpath" "" ""
assert_exit_code "empty subdir exit 0" 0 "$LAST_EXIT"
assert_file_exists "dir moved" "$deploy/newpath/myapp"

#########################################################################
echo ""
echo "=== Nginx conf: no nginx dir (skipped gracefully) ==="
#########################################################################
deploy="$TEST_DIR/no-nginx-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/index.html" "myapp"
run_script "$deploy" "newpath" "" "$TEST_DIR/nonexistent-nginx-dir"
assert_exit_code "no nginx exit 0" 0 "$LAST_EXIT"
assert_output_not_contains "no nginx replacement" "Apply nginx replacement" "$LAST_OUTPUT"


#########################################################################
echo ""
echo "=== Known text extensions processed without file command ==="
#########################################################################
deploy="$TEST_DIR/text-ext-deploy"
setup_deployment "$deploy" "myapp"
create_text_file "$deploy/myapp/index.html" "path: myapp"
create_text_file "$deploy/myapp/app.js" "path: myapp"
create_text_file "$deploy/myapp/style.css" "path: myapp"
create_text_file "$deploy/myapp/data.json" "path: myapp"
create_text_file "$deploy/myapp/config.yaml" "path: myapp"
create_text_file "$deploy/myapp/config.yml" "path: myapp"
create_text_file "$deploy/myapp/readme.md" "path: myapp"
create_text_file "$deploy/myapp/data.xml" "path: myapp"
create_text_file "$deploy/myapp/notes.txt" "path: myapp"
create_text_file "$deploy/myapp/run.sh" "path: myapp"
create_text_file "$deploy/myapp/config.toml" "path: myapp"
create_text_file "$deploy/myapp/settings.ini" "path: myapp"
create_text_file "$deploy/myapp/data.csv" "path: myapp"
create_text_file "$deploy/myapp/module.mjs" "path: myapp"
create_text_file "$deploy/myapp/component.tsx" "path: myapp"
create_text_file "$deploy/myapp/theme.scss" "path: myapp"
run_script "$deploy" "newpath" "" ""
assert_exit_code "known text extensions exit 0" 0 "$LAST_EXIT"
assert_file_contains "html replaced" "path: newpath/myapp" "$deploy/newpath/myapp/index.html"
assert_file_contains "js replaced" "path: newpath/myapp" "$deploy/newpath/myapp/app.js"
assert_file_contains "css replaced" "path: newpath/myapp" "$deploy/newpath/myapp/style.css"
assert_file_contains "json replaced" "path: newpath/myapp" "$deploy/newpath/myapp/data.json"
assert_file_contains "yaml replaced" "path: newpath/myapp" "$deploy/newpath/myapp/config.yaml"
assert_file_contains "yml replaced" "path: newpath/myapp" "$deploy/newpath/myapp/config.yml"
assert_file_contains "md replaced" "path: newpath/myapp" "$deploy/newpath/myapp/readme.md"
assert_file_contains "xml replaced" "path: newpath/myapp" "$deploy/newpath/myapp/data.xml"
assert_file_contains "txt replaced" "path: newpath/myapp" "$deploy/newpath/myapp/notes.txt"
assert_file_contains "sh replaced" "path: newpath/myapp" "$deploy/newpath/myapp/run.sh"
assert_file_contains "toml replaced" "path: newpath/myapp" "$deploy/newpath/myapp/config.toml"
assert_file_contains "ini replaced" "path: newpath/myapp" "$deploy/newpath/myapp/settings.ini"
assert_file_contains "csv replaced" "path: newpath/myapp" "$deploy/newpath/myapp/data.csv"
assert_file_contains "mjs replaced" "path: newpath/myapp" "$deploy/newpath/myapp/module.mjs"
assert_file_contains "tsx replaced" "path: newpath/myapp" "$deploy/newpath/myapp/component.tsx"
assert_file_contains "scss replaced" "path: newpath/myapp" "$deploy/newpath/myapp/theme.scss"

#########################################################################
# Summary
#########################################################################
printf "\n=========================================================================\n"
printf " Results: %s passed, %s failed, %s total\n" "$PASSED" "$FAILED" "$TOTAL"
printf "=========================================================================\n"

[ "$FAILED" -gt 0 ] && exit 1
exit 0
