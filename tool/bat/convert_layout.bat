@echo off
rem code\layout\‚É‚ ‚éƒtƒ@ƒCƒ‹‚ð•ÏŠ·‚·‚é


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

set SRC=%CODE%\layout
set DST=%BUILD%\Data\Layout
set EXD=%TOOL%\exclude\layout.txt

if not exist %DST% mkdir %DST%

rem rvdump
cd %RVDUMP%
echo convert %SRC% to %DST% >&2
call %RVDUMP_CMD% -s "%SRC%" -o "%DST%" -e "%EXD%"

rem ##############################
rem # finishing
rem #

cd %HOME%
endlocal

