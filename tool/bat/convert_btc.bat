@echo off
rem code\behaviortree\‚É‚ ‚éƒtƒ@ƒCƒ‹‚ð•ÏŠ·‚·‚é


rem ##############################
rem # configure
rem #

setlocal
set HOME=%CD%
cd /d %~dp0
call ..\config.bat

set FLAG=%1

rem ##############################
rem # convertion
rem #

set BTC_RESOURCE=%CODE%\behaviortree
set BTC_DATA=%DATA%\Behavior

if not exist %BTC_DATA% mkdir %BTC_DATA%
cd %BTC%
echo btc %BTC_RESOURCE% to %BTC_DATA%
%BTC_CMD% -s "%BTC_RESOURCE%" -o "%BTC_DATA%" -e excludes -b %FLAG%

rem # finishing
rem #

cd %HOME%
endlocal

