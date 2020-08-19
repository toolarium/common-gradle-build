@ECHO OFF

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::
:: cgb-home-update.bat
::
:: Copyright by toolarium, all rights reserved.
:: MIT License: https://mit-license.org
::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


set PN=%~nx0
if .%1==.-h goto HELP
if .%1==.--help goto HELP
if .%1 == . echo. & echo .: ERROR: No url found. Please provide external git url & echo. & goto END
goto UPDATE


:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:HELP
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo %PN% - common-gradle-build-home update, to be used for first time git synchronization.
echo.
echo usage: %PN% GIT-CGB-URL
echo.
echo Overview of the available OPTIONs:
echo  -h, --help           Show this help message.
goto END


:UPDATE
set "commonGradleBuildHomeGitUrl=%1"
set "commonGradleBuildHomeUpdated=false"
set "commonGradleBuildHomeNotFound=false"
set "currentWorkingPath=%CD%"

set "commonGradleBuildHome=%USERPROFILE%\.gradle\common-gradle-build-home"
if not .%COMMON_GRADLE_BUILD_HOME% == . set "commonGradleBuildHome=%COMMON_GRADLE_BUILD_HOME%"

set "tempProjectName=common-gradle-build-home-update-%RANDOM%%RANDOM%"
mkdir "%TEMP%\%tempProjectName%"
cd /d "%TEMP%\%tempProjectName%"
echo apply from: "https://git.io/JfDQT" > build.gradle

if not defined GIT_CLIENT set "GIT_CLIENT=%CB_HOME%\current\git\bin\git"
%GIT_CLIENT% --version >nul 2>nul
if %ERRORLEVEL% NEQ 0 set "GIT_CLIENT=git"
%GIT_CLIENT% ls-remote %commonGradleBuildHomeGitUrl% >nul 2>nul
if %ERRORLEVEL% EQU 0 GOTO CALL_UPDATE
if %ERRORLEVEL% EQU 128 echo .: Inavlid credentials, please check with: control.exe keymgr.dll or rundll32.exe keymgr.dll,KRShowKeyMgr & GOTO END_WITH_ERROR
echo .: ERROR Could not access repository %commonGradleBuildHomeGitUrl%, give up.
GOTO END_WITH_ERROR

:CALL_UPDATE
::get credentials
echo ===================================================
call %CB_HOME%\bin\include\cb-credential --raw %commonGradleBuildHomeGitUrl%
set "GRGIT_USER=%GIT_USERNAME%"
set "GRGIT_PASS=%GIT_PASSWORD%"
echo .: Update %commonGradleBuildHomeGitUrl% in %commonGradleBuildHome%
call cb --silent -q --no-daemon -m "-PcommonGradleBuildHomeGitUrl=%commonGradleBuildHomeGitUrl%" > update.log
if %ERRORLEVEL% EQU 0 set "commonGradleBuildHomeUpdated=true"
type update.log 2>nul | findstr /C:"Could not read remote version" > nul
if %ERRORLEVEL% EQU 0 set "commonGradleBuildHomeUpdated=false" & set "commonGradleBuildHomeNotFound=true"
del /f /q /s *.* >nul
cd ..
rd /s /q "%tempProjectName%"
cd /d "%currentWorkingPath%"

::echo %commonGradleBuildHomeUpdated% %commonGradleBuildHomeNotFound%
dir %commonGradleBuildHome%\*.* /O-D/b 2>nul | findstr/n ^^ | findstr ^^1:> "%tempProjectName%"
for %%R in ("%tempProjectName%") do if %%~zR lss 1 echo .: Could not get %commonGradleBuildHomeGitUrl% & goto END_WITH_ERROR 
if .%commonGradleBuildHomeUpdated% == .true goto END

set "errorMsg=Could not update common-gradle-build-home from git repository"
if .%commonGradleBuildHomeNotFound% == .true set "errorMsg=%errorMsg% (not found)"
echo .: %errorMsg%:
echo    %commonGradleBuildHomeGitUrl% 
echo.
echo In case your credentials not match and you use the windows credential 
echo manager together with git you can manage it with the command:
echo rundll32.exe keymgr.dll,KRShowKeyMgr
echo.
echo You can retry this step by calling 
echo %0 %CB_PARAMETERS%
	

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:END_WITH_ERROR
exit /b 1
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:END
exit /b 0
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
