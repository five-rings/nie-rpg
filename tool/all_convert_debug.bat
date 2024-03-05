@echo off
rem 更新時用に全コンバート処理を実行するスクリプト(デバッグ用)


rem ##############################
rem # configure
rem #

setlocal

set HOME=%CD%
cd /d %~dp0
call config.bat


rem ##############################
rem # convert
rem #

call bat\all_convert "-f debug"

rem # finishing
rem #

cd %HOME%
endlocal
