@echo off
rem �f�o�b�O���[�h�ŃQ�[�����N������X�N���v�g


rem ##############################
rem # configure
rem #

setlocal

set HOME=%CD%
cd /d %~dp0
call config.bat


rem ##############################
rem # build & run
rem #

call bat\buildrun "-f debug" "console"

rem # finishing
rem #

cd %HOME%
endlocal
