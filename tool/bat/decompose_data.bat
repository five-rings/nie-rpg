@echo off
rem rvdata2をjsonファイルとしてresources\に展開する


rem ##############################
rem # configuration
rem #

setlocal
set HOME=%CD%
cd /d %~dp0
call ..\config.bat


call setup_rv2da.bat

rem ##############################
rem # convert
rem #

set BACKUP=%RESOURCE_BACKUP%

if not exist %BACKUP% mkdir %BACKUP%
rem back up
copy /B /Y %RESOURCE% %BACKUP% >NUL 2>&1

rem rv2da
cd %RV2DA%
echo decompose %DATA% to %RESOURCE%
call %RV2DA_CMD% -d %DATA% -o %RESOURCE% -e excludes
echo decompose_data.bat finished

rem ##############################
rem # finishing
rem #

cd %HOME%
endlocal

