@echo off
rem Data\scripts���p�b�P�[�W�����t�@�C����Data\scripts�ɐ�������
rem ������Game.exe���ǂݍ���Script.rvdata2�ɂ��R�s�[����


rem ##############################
rem # configuration
rem #

setlocal
set FLAG="%1"

set HOME=%CD%
cd /d %~dp0
call ..\config.bat


rem ##############################
rem # convert
rem #

set TARGET=%CODE%\Scripts.rvdata2
set LINKORDER=%CODE_SCRIPTS%\Scripts.conf.rb
set ORIGINAL=%DATA%\Scripts.rvdata2

cd %TOOL%
echo compose %TARGET% from %CODE_SCRIPTS%
%RV2SA_CMD% -c "%LINKORDER%" -o "%TARGET%" %FLAG%
copy /B "%TARGET%" "%ORIGINAL%"
echo compose_script.bat finished


rem # finishing
rem #

cd %HOME%
endlocal

