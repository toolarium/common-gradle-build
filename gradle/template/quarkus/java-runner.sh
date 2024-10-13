#!/bin/sh

#########################################################################
#
# toolarium-java-runner
#
# Copyright by toolarium, all rights reserved.
#
# This file is part of the toolarium common-gradle-build.
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

CB_LINE="----------------------------------------------------------------------------------------"
CB_LINEHEADER=".: "
ABS_PROG_PATH=$(cd -- "`dirname "$0" 2>/dev/null`" && pwd)
PN=$(basename "$0" 2>/dev/null)
PN_BASE="${PN%*.sh}"
PID_FILE="$PWD/$PN_BASE.pid"
TIMEZONE=$(date +"%Z %z")
exitCode=0
printEndedMessage="false"


#########################################################################
# printUsage
#########################################################################
printUsage() {
    echo "$PN - start a java process"
    echo "usage: $PN [OPTION] [ARGUMENTS]"
    echo ""
    echo "The arguments are passed as java arguements."
	echo ""
    echo "Overview of the available OPTIONs:"
    echo " -h, --help                    Show this help message."
    echo " --version                     Print the version information."
    echo " --verbose                     Enablesv verbose mode."
    echo " --nocolor                     Disable colored output. This is the same behavior as when TERM variable is set to a non xterm."
    echo " --colorPalette                Set the color palette, default 1 (dark 2)."
	echo " --executable                  Defines the executable, e.g. java."
    echo " --proxyHost <hostname>        Defines the proxy host for the process, e.g. myhost.com."
    echo "                               If the hostname is missing, it will be ignored."
    echo " --proxyPort <port>            Defines the proxy port for the process, e.g. 8080."
    echo "                               If the port is missing, it will be ignored."
    echo " --nonProxyHosts <list>        Defines the a list of non proxy hosts (separated by comma character):"
    echo "                               e.g. localhost,.cluster.local,*.acpt.app.com"
    echo "                               In case of an empty list, it will be ignored."
    echo " --javaAgent <jarpath>         Defines the path to the java agent jar, e.g. my-agent.jar."
    echo " --httpAgent <http agent name> Defines the http agent name, e.g. Java."
    echo " --keepAlive <true or false>   Defines the http keep alive, e.g. true."
    echo " --maxConnections <number>     Defines the number of http max connections, e.g. 5."
    echo " --maxRedirects <number>       Defines the number of http max redirects, e.g. 20."
    echo " --logLevel LEVEL[,package]    The log level. Defines the log level. Multiple entries with packages are possible:"
    echo "                               e.g. --logLevel INFO --logLevel WARN,my.package.name"
    echo "                               In case of an empty level, it will be ignored."
    echo " --javaOptions <options>       Defines additional java options, e.g. --javaOptions \"-Xms2m -Xmx10m\""
    echo ""
    echo "Instead of the listed parameters above they can be set as well as environment variable with"
    echo "same name like the parameter, e.g. proxyPort=9898 or logLevel=\"INFO\" WARN,my.package.name"
    echo ""
}


#########################################################################
# colorIt
#########################################################################
[ -z "$CB_LINE_NOCOLOR" ] && CB_LINE_NOCOLOR="$CB_LINE"
[ -z "$CB_LINEHEADER_NOCOLOR" ] && CB_LINEHEADER_NOCOLOR="$CB_LINEHEADER"

colorIt() {
    if [ -z "$TERM" ] || [ $(echo $TERM | grep -e '^xterm' | wc -l) -eq 0 ] || [ "$COLOR_PALETTE" = "no" ]; then
        BALCK="";RED="";GREEN="";YELLOW="";BLUE="";MAGENTA="";CYAN="";WHITE="";NO_COLOR=""
        INFO_LEVEL="";WARN_LEVEL="";ERROR_LEVEL="";TITLE_LEVEL="";HIGHLITE_LEVEL="";SUCCESS_LEVEL=""
        CB_LINE="$CB_LINE_NOCOLOR";CB_LINEHEADER="$CB_LINEHEADER_NOCOLOR"
    else
        escapeSign='\033['
        [ -z "$COLOR_PALETTE" ] && COLOR_PALETTE="0"
        [ -z "$INFO_LEVEL" ] && ESCAPE_STRING="${escapeSign}${COLOR_PALETTE};"
        [ -z "$BALCK" ] && BALCK="${ESCAPE_STRING}30m"
        [ -z "$RED" ] && RED="${ESCAPE_STRING}31m"
        [ -z "$GREEN" ] && GREEN="${ESCAPE_STRING}32m"
        [ -z "$YELLOW" ] && YELLOW="${ESCAPE_STRING}33m"
        [ -z "$BLUE" ] && BLUE="${ESCAPE_STRING}34m"
        [ -z "$MAGENTA" ] && MAGENTA="${ESCAPE_STRING}35m"
        [ -z "$CYAN" ] && CYAN="${ESCAPE_STRING}36m"
        [ -z "$WHITE" ] && WHITE="${ESCAPE_STRING}37m"
        [ -z "$NO_COLOR" ] && NO_COLOR="${escapeSign}0m"
        [ -z "$INFO_LEVEL" ] && INFO_LEVEL="$CYAN"
        [ -z "$WARN_LEVEL" ] && WARN_LEVEL="$YELLOW"
        [ -z "$ERROR_LEVEL" ] && ERROR_LEVEL="$RED"
        [ -z "$TITLE_LEVEL" ] && TITLE_LEVEL="$YELLOW"
        [ -z "$HIGHLITE_LEVEL" ] && HIGHLITE_LEVEL="$CYAN"
        [ -z "$SUCCESS_LEVEL" ] && SUCCESS_LEVEL="$GREEN"
        CB_LINE="${HIGHLITE_LEVEL}$CB_LINE_NOCOLOR${NO_COLOR}"
        CB_LINEHEADER="${HIGHLITE_LEVEL}$CB_LINEHEADER_NOCOLOR"
    fi
}
colorIt


#########################################################################
# parameterFailed
#########################################################################
parameterFailed() {
    printf "${CB_LINEHEADER}Parameter faild: $1.${NO_COLOR}\n\n"
    printUsage
}


#########################################################################
# error handler
#########################################################################
errorhandler() {
    [ -n "$DEBUG" ] && printf "${CB_LINEHEADER}ERROR on line #$LINENO, last command: $BASH_COMMAND${NO_COLOR}\n"
    exithandler
}


#########################################################################
# exit handler
#########################################################################
exithandler() {
    exitCode=$?

    [ -n "$DEBUG" ] && printf "${CB_LINEHEADER}ENDED${NO_COLOR}"

    if [ -r "$PID_FILE" ]; then
        pid=$(cat $PID_FILE 2> /dev/null)
        wait $pid
        rm -f "$PID_FILE" > /dev/null 2>&1
    fi

    if [ "$printEndedMessage" = "true" ]; then
        CB_END_TIMESTAMP=$(getTimestamp)
        CB_DUATION=$(eval "expr $(echo $CB_END_TIMESTAMP | sed 's/[ |.|:|-]*//g') - $(echo $CB_START_TIMESTAMP | sed 's/[ |.|:|-]*//g')")
        CB_DUATION=$(printf %.3f "${CB_DUATION}e-3")
        printf "%s$CB_LINE\n"
        printf "   ${INFO_LEVEL}ENDED${NO_COLOR} ${TITLE_LEVEL}${CB_END_TIMESTAMP} $TIMEZONE${NO_COLOR}, duration ${TITLE_LEVEL}${CB_DUATION} sec${NO_COLOR}, exit: ${TITLE_LEVEL}$exitCode${NO_COLOR}\n"
        printf "%s$CB_LINE\n"
        printEndedMessage="false"
    fi
    [ -n "$exitCode" ] && exit $exitCode
}


#########################################################################
# getTimestamp
#########################################################################
getTimestamp() {
    date '+%Y-%m-%d %H:%M:%S.%N' | cut -b1-23
}


#########################################################################
# check if the binary exists
#########################################################################
existBinary() {
    if ! [ "${1#*/}" = "$1" ]; then
       ! [ -x "$1" ] && return 1
	fi

    eval whereis whereis >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        result=$(whereis -b "$1" 2>/dev/null | awk '{print $2}')
        [ "$2" = "true" ] || result="${result##*.exe}"
        [ -n "$result" ] && echo "$result"
        [ -n "$result" ] && return 0 || return 1
    else
        which which >/dev/null 2>&1
        if  ! [ $? -eq 0 ]; then
            printf "${CB_LINEHEADER}Can not find which nor whereis command!${NO_COLOR}\n"
            return 1
        fi

        result=$(which "$1" 2>/dev/null)
        [ "$2" = "true" ] || result="${result##*.exe}"
        [ -n "$result" ] && echo "$result"
        [ $? -eq 0 ] && return 0 || return 1
    fi
}


#########################################################################
# Add the log level
#########################################################################
addLogLevel() {
    ! [ -n "$1" ] && return 1
    packageLevel=$(echo $1|cut -d '=' -f1|cut -d ',' -f1)
    packageName=$(echo $1|cut -d '=' -f2|cut -d ',' -f2)

    # "-Dquarkus.log.level=DEBUG"
    # "-Dquarkus.log.category.\"org.hibernate\".level=TRACE"
    [ "$packageLevel" = "$packageName" ] && packageName="" || packageName="category.\"$packageName\"."
    logLevel="${logLevel} -Dquarkus.log.${packageName}level=${packageLevel}"
    logLevel="${logLevel# }"
	return 0
}


#########################################################################
# Read version
#########################################################################
readVersion() {
    [ -n "$SCRIPT_VERSION_NUMBER" ] && versionNumber="${SCRIPT_VERSION_NUMBER}" || versionNumber="1.0.0"
    [ -r "${ABS_PROG_PATH}/VERSION" ] && VERSIONPATH="${ABS_PROG_PATH}/VERSION"
    [ -r "${ABS_PROG_PATH}/../VERSION" ] && VERSIONPATH="${ABS_PROG_PATH}/../VERSION"

    if [ -r "${VERSIONPATH}" ]; then
        majorNumber=$(cat "${VERSIONPATH}" | tr -d '\r' | grep major.number | awk '{print $3}')
        minorNumber=$(cat "${VERSIONPATH}" | tr -d '\r' | grep minor.number | awk '{print $3}')
        revisionNumber=$(cat "${VERSIONPATH}" | tr -d '\r' | grep revision.number | awk '{print $3}')
        qualifier=$(cat "${VERSIONPATH}" | tr -d '\r' | grep qualifier | awk '{print $3}')
        versionNumber=$majorNumber.$minorNumber.$revisionNumber
    fi

    echo "$versionNumber"
}


#########################################################################
# main
#########################################################################
trap 'exithandler $?; exit' 0
trap 'errorhandler $?; exit' 1 2 3 15

EXECUTABLE="";JARFILE="";JAVAAGENT="";JAVA_OPTIONS="";PARAMTERS="";inputLogLevel=""
#proxyHost="";proxyPort="";nonProxyHosts="";httpAgent="";keepAlive="";maxConnections="";maxRedirects="";logLevel=""; javaOptions=""

[ -n "$verbose" ] && CB_VERBOSE="$verbose"
[ -n "$nocolor" ] && COLOR_PALETTE="no" && colorIt
[ -n "$colorPalette" ] && COLOR_PALETTE="no" && colorIt && COLOR_PALETTE="$colorPalette"; colorIt
[ -n "$logLevel" ] && inputLogLevel="$logLevel"

logLevel=
[ -n "$inputLogLevel" ] && for i in $inputLogLevel; do addLogLevel $i; done

CB_START_TIMESTAMP=$(getTimestamp)
while [ $# -gt 0 ]; do
    case "$1" in
    -h)              printUsage; exit 0;;
    --help)          printUsage; exit 0;;
    --version)       echo "toolarium java runner $(readVersion)" && exit 0;;
    --verbose)       CB_VERBOSE="true";;
    --nocolor)       COLOR_PALETTE="no" && colorIt;;
    --colorPalette)  [ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && COLOR_PALETTE="no" && colorIt && COLOR_PALETTE="$2"; colorIt && shift;;
    --executable)    [ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && EXECUTABLE="$2" && shift;;
    --jar)           [ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && JARFILE="$2" && shift;;
    --javaAgent)     [ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && JAVAAGENT="-javaAgent:$2" && shift;;
    --proxyHost)     [ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && proxyHost="$2" && shift;;
    --proxyPort)     [ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && proxyPort="$2" && shift;;
    --nonProxyHosts) [ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && nonProxyHosts=$(echo $2| cut -d '=' -f2|sed 's/,/\|/g') && shift;;
    --httpAgent)     [ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && httpAgent="$2" && shift;;
    --keepAlive)     [ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && keepAlive="$2" && shift;;
    --maxConnections)[ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && maxConnections="$2" && shift;;
    --maxRedirects)  [ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && maxRedirects="$2" && shift;;
    --logLevel)      [ -n "$2" ] && ! [ -z $(echo "$2"|grep -e "^--" -v) ] && addLogLevel "$2" && shift;;
    --javaOptions)   [ -n "$2" ] && ! [ -z $(echo "$2") ] && javaOptions="$2" && shift;;
    -*)              parameterFailed "Invalid parameter $1"; exit 1;;
    *)               PARAMTERS="${PARAMTERS} $1";;
    esac
    shift
done
printEndedMessage="true"

# default values, see https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/net/doc-files/net-properties.html
[ "$CB_VERBOSE" = "true" ] && printf "${CB_LINEHEADER}Prepare parameters...${NO_COLOR}\n"
[ -z "$EXECUTABLE" ] && EXECUTABLE="java"
#[ -z "$httpAgent" ] && httpAgent="${EXECUTABLE#*/}"
[ "$CB_VERBOSE" = "true" ] && printf "${CB_LINEHEADER}Set java executable [${NO_COLOR}$EXECUTABLE${HIGHLITE_LEVEL}]${NO_COLOR}\n"

JAVAAGENT="${JAVAAGENT# }"
[ "$CB_VERBOSE" = "true" ] && printf "${CB_LINEHEADER}Set java agent      [${NO_COLOR}$JAVAAGENT${HIGHLITE_LEVEL}]${NO_COLOR}\n"

! [ -n "$JARFILE" ] && JARFILE="app.jar" # prepare jar file
[ -n "$proxyHost" ] && JAVA_OPTIONS="${JAVA_OPTIONS} -Dhttp.proxyHost=$proxyHost -Dhttps.proxyHost=$proxyHost" # proxyHost, e.g. "-Dhttp.proxyHost=192.168.1.1"
[ -n "$proxyPort" ] && JAVA_OPTIONS="${JAVA_OPTIONS} -Dhttp.proxyPort=$proxyPort -Dhttps.proxyPort=$proxyPort" # proxyPort, e.g. "-Dhttps.proxyPort=8080"
[ -n "$nonProxyHosts" ] && JAVA_OPTIONS="${JAVA_OPTIONS} -Dhttp.nonProxyHosts=\"$nonProxyHosts\"" # nonProxyHosts e.g. "-Dhttp.nonProxyHosts=localhost|.cluster.local|*.acpt.app.com"
[ -n "$httpAgent" ] && JAVA_OPTIONS="${JAVA_OPTIONS} -Dhttp.agent=$httpAgent" # e.g. "-Dhttp.agent=java"
[ -n "$keepAlive" ] && JAVA_OPTIONS="${JAVA_OPTIONS} -Dhttp.keepAlive=$keepAlive" # e.g. "-Dhttp.keepAlive=true"
[ -n "$maxConnections" ] && JAVA_OPTIONS="${JAVA_OPTIONS} -Dhttp.maxConnections=$maxConnections" # e.g. "-Dhttp.maxConnections=5"
[ -n "$maxRedirects" ] && JAVA_OPTIONS="${JAVA_OPTIONS} -Dhttp.maxRedirects=$maxRedirects" # e.g. "-Dhttp.maxRedirects=20"
[ -n "$logLevel" ] && JAVA_OPTIONS="${JAVA_OPTIONS} $logLevel"
[ -n "$javaOptions" ] && JAVA_OPTIONS="${JAVA_OPTIONS} $javaOptions"
JAVA_OPTIONS="${JAVA_OPTIONS# }"

[ "$CB_VERBOSE" = "true" ] && printf "${CB_LINEHEADER}Set java options    [${NO_COLOR}$JAVA_OPTIONS${HIGHLITE_LEVEL}]${NO_COLOR}\n"

PARAMTERS="${PARAMTERS# }"
[ "$CB_VERBOSE" = "true" ] && printf "${CB_LINEHEADER}Set java arguments  [${NO_COLOR}$PARAMTERS${HIGHLITE_LEVEL}]${NO_COLOR}\n"

linuxVersion=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -f2 -d'"')
linuxInstallDate=$(ls -lact --full-time /etc | awk 'END {print $6}')

printf "%s${CB_LINE}\n"
printf "   ${INFO_LEVEL}START${NO_COLOR} ${TITLE_LEVEL}$CB_START_TIMESTAMP $TIMEZONE${NO_COLOR}, toolarium java runner $(readVersion)\n"
printf "   ${INFO_LEVEL}OS${NO_COLOR}    ${TITLE_LEVEL}${linuxVersion}${NO_COLOR}, ${linuxInstallDate} on $(hostname)\n"
environment=$(env | egrep "LANG|LC"| xargs | sed 's/ /, /g')

if ! [ -n "$(existBinary $EXECUTABLE)" ]; then
    [ -n "$environment" ] && printf "   ${INFO_LEVEL}ENV${NO_COLOR}   $environment\n"
    printf "%s$CB_LINE\n"
    printf "${CB_LINEHEADER}Missing package ${WARN_LEVEL}${EXECUTABLE}${NO_COLOR}${HIGHLITE_LEVEL}, please install it before you continue.${NO_COLOR}\n"
    exitCode="1"
elif ! [ -r "$JARFILE" ]; then
    javaVersion=$($EXECUTABLE -version 2>&1 | tail -1)
    printf "   ${INFO_LEVEL}JAVA${NO_COLOR}  ${javaVersion}\n"
    [ -n "$environment" ] && printf "   ${INFO_LEVEL}ENV${NO_COLOR}   $environment\n"
    printf "%s$CB_LINE\n"
    printf "${CB_LINEHEADER}Missing jar file ${WARN_LEVEL}${JARFILE}${HIGHLITE_LEVEL}.${NO_COLOR}\n"
    exitCode="1"
else
    javaVersion=$($EXECUTABLE -version 2>&1 | tail -1)
    printf "   ${INFO_LEVEL}JAVA${NO_COLOR}  ${javaVersion}\n"
    [ -n "$environment" ] && printf "   ${INFO_LEVEL}ENV${NO_COLOR}   $environment\n"

    START_COMMAND="$EXECUTABLE \$JAVAAGENT \$JAVA_OPTIONS -jar \$JARFILE \$PARAMTERS"
    printf "%s$CB_LINE\n"
	touch $PID_FILE
    eval "$START_COMMAND" && echo "$!" > $PID_FILE
fi


#########################################################################
#  EOF
#########################################################################