@echo off
rem �X�V���p�ɑS�R���o�[�g���������s����X�N���v�g(�����[�X�p)


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

call bat\all_convert ""

rem # finishing
rem #

cd %HOME%
endlocal
