@echo off
rem resources\�ɂ���json�t�@�C����rvdata2�ɕϊ�����
rem �ϊ������t�@�C���̓o�b�N�A�b�v(resources\_backup)��build\Data\�ɓW�J�����


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

set CONVERTED=%RESOURCE_CONVERTED%
set BACKUP=%RESOURCE_BACKUP%
set EXCLUDE=%TOOL%\bat\rv2daexcludes.txt

echo %BACKUP%
if not exist %CONVERTED% mkdir %CONVERTED%
if not exist %BACKUP% mkdir %BACKUP%

rem clear past converted
echo y | del %CONVERTED% >NUL

rem back up
copy /B /Y %DATA% %BACKUP% >NUL 2>&1

rem rv2da
cd %RV2DA%
echo compose %RESOURCE% to %DATA%
call %RV2DA_CMD% -c %RESOURCE% -o %CONVERTED% -e %EXCLUDE%

cd %CONVERTED%
copy /B /Y . %DATA%


rem ##############################
rem # finishing
rem #

cd %HOME%
endlocal

