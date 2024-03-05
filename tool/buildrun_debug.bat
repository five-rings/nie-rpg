@echo off
rem デバッグモードでゲームを起動するスクリプト


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

call bat\buildrun "-f debug" "console"

rem # finishing
rem #

cd %HOME%
endlocal
