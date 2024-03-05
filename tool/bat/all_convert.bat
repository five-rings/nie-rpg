@echo off
rem 更新時用に全コンバート処理を実行するスクリプト

rem ##############################
rem # configuration
rem #

setlocal
set FLAG=%1
set HOME=%CD%
cd /d %~dp0
call ..\config.bat

rem ##############################
rem # convert all of data
rem #

call convert_resources
@rem call data_deploy
call compose_scripts %FLAG%
call compose_data


rem ##############################
rem # finishing
rem #

cd %HOME%
endlocal

echo.
echo 全コンバートが完了しました
pause
