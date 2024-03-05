@echo off
rem リリースモードでゲームを起動するスクリプト


rem ##############################
rem # configure
rem #

setlocal

set HOME=%CD%
cd /d %~dp0
call config.bat


rem ##############################
rem # build & run
rem #

call bat\buildrun "-f release" "console"

rem # finishing
rem #

cd %HOME%
endlocal
