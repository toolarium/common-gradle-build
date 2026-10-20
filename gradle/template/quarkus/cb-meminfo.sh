#!/bin/sh

#########################################################################
#
# cb-meminfo
#
# Copyright by toolarium, all rights reserved.
#
# This file is part of the toolarium common-build.
#
# The common-build is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# The common-build is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Foobar. If not, see <http://www.gnu.org/licenses/>.
#
#########################################################################


#########################################################################
# printUsage
#########################################################################
printUsage() {
    cat <<'USAGE'
meminfo.sh - Evaluate the memory usage.
usage: meminfo.sh [OPTION]

Overview of the available OPTIONs:
 -h, --help           Show this help message.
 -q                   Suppress header
 -ts                  Add timestamp as first column
 -jvm                 Show JVM memory details (requires -pid, NativeMemoryTracking enabled)
 -b                   Format in bytes
 -k                   Format in kilo bytes
 -m                   Format in mega bytes
 -g                   Format in giga bytes
 -t                   Format in tera bytes
 -p                   Format in peta bytes
 -pid <pid>           Filter a specific process
USAGE
}


#########################################################################
# validate_number
#########################################################################
validate_number() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}


#########################################################################
# run_timeout: run a command with a timeout when the 'timeout' binary is
# available (BusyBox / GNU coreutils). Falls back to a direct call when
# 'timeout' is absent (e.g. macOS without coreutils, Solaris).
# Override the deadline via _CB_JVM_TIMEOUT (default: 5 seconds).
# Used to guard jcmd/jstat which use the JVM Dynamic Attach mechanism
# and can block indefinitely in a container when the attach listener
# has not yet started.
#########################################################################
run_timeout() {
    if command -v timeout >/dev/null 2>&1; then
        timeout "${_CB_JVM_TIMEOUT:-5}" "$@"
    else
        "$@"
    fi
}


#########################################################################
# Format bytes and print as a 15-char column. No subshells.
# Usage: printColumn <bytes> <divideFactor>
#   divideFactor: -1=auto, 0=bytes, 1=K, 2=M, 3=G, 4=T, 5=P
#########################################################################
printColumn() {
    _v="${1:-0}"
    _i=0
    _df="${2:--1}"

    if [ "$_df" -lt 0 ] 2>/dev/null; then
        while [ "$_v" -gt 1024 ] 2>/dev/null; do
            _i=$((_i + 1))
            _v=$((_v / 1024))
        done
    else
        while [ "$_i" -lt "$_df" ] 2>/dev/null; do
            _i=$((_i + 1))
            _v=$((_v / 1024))
        done
    fi

    case "$_i" in
        0) printf '%-15s' "$_v  " ;;
        1) printf '%-15s' "$_v K" ;;
        2) printf '%-15s' "$_v M" ;;
        3) printf '%-15s' "$_v G" ;;
        4) printf '%-15s' "$_v T" ;;
        5) printf '%-15s' "$_v P" ;;
        6) printf '%-15s' "$_v E" ;;
        7) printf '%-15s' "$_v Z" ;;
        8) printf '%-15s' "$_v Y" ;;
        *) printf '%-15s' "$_v ?" ;;
    esac
}


#########################################################################
# main
#########################################################################
divideFactor=-1
quiet="true"
showTimestamp=""
showJvm=""
pidId=""
while [ $# -gt 0 ]; do
    case "$1" in
        -q)         quiet="";;
        -ts)        showTimestamp="true";;
        -jvm)       showJvm="true";;
        -h|--help)  printUsage; exit 0;;
        -b)         divideFactor=0;;
        -k)         divideFactor=1;;
        -m)         divideFactor=2;;
        -g)         divideFactor=3;;
        -t)         divideFactor=4;;
        -p)         divideFactor=5;;
        -pid)       shift; validate_number "$1" && pidId="$1" || { echo "Invalid pid: $1"; printUsage; exit 1; };;
        -*)         echo "Invalid parameter: $1"; echo ""; printUsage; exit 1;;
        *)          ;;
    esac
    shift
done


#########################################################################
# Collect OS memory
# - /proc/meminfo: direct file read, no process spawn (Linux/Alpine)
# - /proc/<pid>/status: per-PID RSS without ps (works on BusyBox + GNU)
# - ps -e -o rss=: sum all RSS (BusyBox + GNU compatible)
# - free(1): fallback for totalMemory if /proc/meminfo unavailable
#########################################################################
processMemory=0
case "$(uname -s)" in
    SunOS)
        _memtotal=$(/usr/sbin/prtconf 2>/dev/null | awk '/Memory/{print $3}')
        totalMemory=$((1024 * 1024 * ${_memtotal:-0}))
        _usedrss=$(ps -elfy 2>/dev/null | awk '{s+=$8}END{print s+0}')
        usedMemory=$((1024 * ${_usedrss:-0}))
        if [ -n "$pidId" ]; then
            _pidrss=$(ps -lyp "$pidId" 2>/dev/null | awk '{s+=$8}END{print s+0}')
            processMemory=$((1024 * ${_pidrss:-0}))
        fi
        ;;
    Darwin)
        # macOS: use sysctl for total memory, ps for used/per-PID
        totalMemory=$(sysctl -n hw.memsize 2>/dev/null)
        [ -z "$totalMemory" ] && totalMemory=0

        # Used: sum RSS of all processes (ps reports in KB on macOS)
        _usedrss=$(ps -A -o rss= 2>/dev/null | awk '{s+=$1}END{print s+0}')
        usedMemory=$((1024 * ${_usedrss:-0}))

        # Per-PID
        if [ -n "$pidId" ]; then
            _pidrss=$(ps -p "$pidId" -o rss= 2>/dev/null | awk '{print $1+0}')
            processMemory=$((${_pidrss:-0} * 1024))
        fi
        ;;
    *)
        # Linux/other: single awk pass on /proc/meminfo (no fork beyond awk)
        eval "$(awk '
            /^MemTotal:/     { t=$2 }
            /^MemAvailable:/ { a=$2 }
            /^MemFree:/      { f=$2 }
            /^Buffers:/      { b=$2 }
            /^Cached:/       { c=$2 }
            END {
                if (a=="") a=f+b+c
                printf "_memtotal=%d _memavail=%d\n", t+0, a+0
            }
        ' /proc/meminfo 2>/dev/null)"
        # Fallback to free(1) if /proc/meminfo is unavailable
        if [ "${_memtotal:-0}" -eq 0 ] 2>/dev/null; then
            eval "$(free 2>/dev/null | awk 'NR==2{printf "_memtotal=%d _memavail=%d\n",$2,$7?$7:$4}')"
        fi
        totalMemory=$((${_memtotal:-0} * 1024))
        usedMemory=$(( (${_memtotal:-0} - ${_memavail:-0}) * 1024 ))

        # Per-PID: read /proc directly (zero forks); fall back to ps filter
        if [ -n "$pidId" ]; then
            _pidrss=$(awk '/^VmRSS:/{print $2; exit}' "/proc/$pidId/status" 2>/dev/null)
            if [ -z "$_pidrss" ]; then
                _pidrss=$(ps -o pid,rss 2>/dev/null | awk "\$1==$pidId{print \$2; exit}")
            fi
            processMemory=$((${_pidrss:-0} * 1024))
        fi

        # Override with cgroup memory limit when running in a container.
        # _CGROUP_ROOT can be overridden for testing (default: /sys/fs/cgroup).
        _cgroot="${_CGROUP_ROOT:-/sys/fs/cgroup}"
        if [ -r "${_cgroot}/memory.max" ]; then
            # cgroup v2
            _cgmax=$(cat "${_cgroot}/memory.max" 2>/dev/null)
            if [ -n "$_cgmax" ] && [ "$_cgmax" != "max" ]; then
                totalMemory=$_cgmax
                _cgcurrent=$(cat "${_cgroot}/memory.current" 2>/dev/null)
                usedMemory=${_cgcurrent:-0}
            fi
        elif [ -r "${_cgroot}/memory/memory.limit_in_bytes" ]; then
            # cgroup v1: unlimited sentinel is 9223372036854771712 (2^63 - 4096).
            # Use awk (floating-point) instead of [ -lt ] to avoid 32-bit integer overflow
            # in POSIX sh implementations (e.g. dash) on the sentinel value.
            # Any real container limit is under 10 TB (10000000000000).
            _cgmax=$(cat "${_cgroot}/memory/memory.limit_in_bytes" 2>/dev/null)
            if awk -v v="${_cgmax:-0}" 'BEGIN{exit !(v > 0 && v < 10000000000000)}' 2>/dev/null; then
                totalMemory=$_cgmax
                _cgusage=$(cat "${_cgroot}/memory/memory.usage_in_bytes" 2>/dev/null)
                _cgcache=$(awk '/^cache /{print $2; exit}' "${_cgroot}/memory/memory.stat" 2>/dev/null)
                usedMemory=$(( ${_cgusage:-0} - ${_cgcache:-0} ))
            fi
        fi
        ;;
esac
freeMemory=$((totalMemory - usedMemory))


#########################################################################
# Collect JVM NativeMemoryTracking data (single jcmd + single awk)
#########################################################################
jvmAvailable=""
jvmTotal=0; jvmHeap=0; jvmNonHeap=0; jvmThread=0; jvmGc=0; jvmJit=0;jvmUsedAvailable="";jvmHeapUsed=0; jvmNonHeapUsed=0
if [ "$showJvm" = "true" ] && [ -n "$pidId" ]; then
    # Locate jcmd
    jcmdBin=""
    for _p in jcmd "${JAVA_HOME:+$JAVA_HOME/bin/jcmd}"; do
        [ -n "$_p" ] && command -v "$_p" >/dev/null 2>&1 && jcmdBin="$_p" && break
    done

    if [ -n "$jcmdBin" ]; then
        nmtOutput=$(run_timeout "$jcmdBin" "$pidId" VM.native_memory summary 2>&1)
        case "$nmtOutput" in
            *"Native Memory Tracking"*)
                jvmAvailable="true"
                # Single awk pass: detect unit + parse all 6 categories
                # Uses here-doc to avoid echo subshell
                eval "$(awk '
                    BEGIN { mul=1 }
                    /committed=.*KB/ && !ms { mul=1024; ms=1 }
                    function cv() { match($0,/committed=[0-9]+/); return substr($0,RSTART+10,RLENGTH-10) }
                    /^Total:/           { printf "jvmTotal=%d\n",  cv()*mul }
                    /Java Heap/,/\)$/   { if(/committed=/) printf "jvmHeap=%d\n",    cv()*mul }
                    /^-.*Class/,/\)$/   { if(/committed=/) printf "jvmNonHeap=%d\n", cv()*mul }
                    /^-.*Thread/,/\)$/  { if(/committed=/) printf "jvmThread=%d\n",  cv()*mul }
                    /^-.*GC/,/\)$/      { if(/committed=/) printf "jvmGc=%d\n",      cv()*mul }
                    /^-.*Code/,/\)$/    { if(/committed=/) printf "jvmJit=%d\n",     cv()*mul }
                ' <<EOF
$nmtOutput
EOF
                )"
            ;;
        esac
    fi
fi


#########################################################################
# Collect JVM used heap/non-heap via jstat -gc (reads hsperfdata; no attach needed)
# jstat -gc columns (KB): S0U S1U EU OU = used heap; MU = used non-heap (Metaspace)
#########################################################################
if [ "$showJvm" = "true" ] && [ -n "$pidId" ]; then
    jstatBin=""
    for _p in jstat "${JAVA_HOME:+$JAVA_HOME/bin/jstat}"; do
        [ -n "$_p" ] && command -v "$_p" >/dev/null 2>&1 && jstatBin="$_p" && break
    done

    if [ -n "$jstatBin" ]; then
        eval "$(run_timeout "$jstatBin" -gc "$pidId" 2>/dev/null | awk '
            NR==1 { for (i=1; i<=NF; i++) col[$i]=i; next }
            NR==2 {
                s0u = col["S0U"] ? $col["S0U"]+0 : 0
                s1u = col["S1U"] ? $col["S1U"]+0 : 0
                eu  = col["EU"]  ? $col["EU"]+0  : 0
                ou  = col["OU"]  ? $col["OU"]+0  : 0
                mu  = col["MU"]  ? $col["MU"]+0  : 0
                printf "jvmHeapUsed=%d jvmNonHeapUsed=%d jvmUsedAvailable=true\n", int((s0u+s1u+eu+ou)*1024), int(mu*1024)
            }
        ')"
    fi
fi


#########################################################################
# Output header
#########################################################################
if [ "$quiet" = "true" ]; then
    [ "$showTimestamp" = "true" ] && printf '%-24s' "Timestamp"
    printf '%-15s%-15s%-15s' "Total" "Used" "Free"
    [ -n "$pidId" ] && printf '%-15s' "Process[$pidId]"
    [ "$jvmAvailable" = "true" ] && printf '%-15s%-15s%-15s' "JVM-Total" "Heap" "Non-Heap"
    [ "$jvmUsedAvailable" = "true" ] && printf '%-15s%-15s' "Heap-Used" "Non-Heap-Used"
    [ "$jvmAvailable" = "true" ] && printf '%-15s%-15s%-15s' "Thread" "GC" "JIT"
    printf '\n'
fi


#########################################################################
# Output data — zero subshells (all formatting inline via printColumn)
#########################################################################
[ "$showTimestamp" = "true" ] && printf '%-24s' "$(date '+%Y-%m-%d %H:%M:%S')"
printColumn "$totalMemory" "$divideFactor"
printColumn "$usedMemory" "$divideFactor"
printColumn "$freeMemory" "$divideFactor"
[ -n "$pidId" ] && printColumn "$processMemory" "$divideFactor"
if [ "$jvmAvailable" = "true" ]; then
    printColumn "$jvmTotal" "$divideFactor"
    printColumn "$jvmHeap" "$divideFactor"
    printColumn "$jvmNonHeap" "$divideFactor"
fi
if [ "$jvmUsedAvailable" = "true" ]; then
    printColumn "$jvmHeapUsed" "$divideFactor"
    printColumn "$jvmNonHeapUsed" "$divideFactor"
fi
if [ "$jvmAvailable" = "true" ]; then
    printColumn "$jvmThread" "$divideFactor"
    printColumn "$jvmGc" "$divideFactor"
    printColumn "$jvmJit" "$divideFactor"
fi
printf '\n'


#########################################################################
# EOF
#########################################################################
