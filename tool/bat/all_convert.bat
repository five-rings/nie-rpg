@echo off
rem �X�V���p�ɑS�R���o�[�g���������s����X�N���v�g

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
echo �S�R���o�[�g���������܂���
pause
