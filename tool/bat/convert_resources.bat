@echo off
rem ���\�[�X�ނ�S�ăR���o�[�g����X�N���v�g

rem ##############################
rem # configuration
rem #

setlocal
set HOME=%CD%
cd /d %~dp0
call ..\config.bat

rem ##############################
rem # convert all of data
rem #

call convert_config
call convert_lang
call convert_text
call convert_layout
call convert_btc


rem ##############################
rem # finishing
rem #

cd %HOME%
endlocal

