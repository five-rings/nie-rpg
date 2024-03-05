@echo off
rem IDEでビルド実行を行うためのスクリプト


rem ##############################
rem # configure
rem #

setlocal
set FLAG=%1
set CONSOLE=%2

set HOME=%CD%
cd /d %~dp0
call ..\config.bat


rem ##############################
rem # build & run
rem #

call compose_scripts.bat %FLAG%

cd %BUILD%
_Game.exe test %CONSOLE%

rem # finishing
rem #

cd %HOME%
endlocal
