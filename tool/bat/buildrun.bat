@echo off
rem IDE�Ńr���h���s���s�����߂̃X�N���v�g


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
