@echo off
rem �X�V���p�ɑS�R���o�[�g���������s����X�N���v�g(�f�o�b�O�p)


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
