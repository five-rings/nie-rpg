@echo off
rem code\language\‚É‚ ‚éƒtƒ@ƒCƒ‹‚ð•ÏŠ·‚·‚é


rem ##############################
rem # configure
rem #

setlocal
set HOME=%CD%
cd /d %~dp0
call ..\config.bat


rem ##############################
rem # convert
rem #

set SRC=%CODE%\language
set DST=%BUILD%\Data\Language

if not exist %DST% mkdir %DST%

rem rvlangc
cd %RVLANGC%
echo convert %SRC% to %DST% >&2
call %RVLANGC_CMD% -s "%SRC%" -o "%DST%"

rem ##############################
rem # finishing
rem #

cd %HOME%
endlocal

