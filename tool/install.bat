@echo off
@rem ����ɕK�v�ȃZ�b�g�A�b�v���s���܂�

@echo �v���W�F�N�g�̏���ݒ���s���܂��B
@echo.

@set HOME=%CD%
cd /d %~dp0
cd ..
@set ROOT=%CD%

@set VERSION=1
@set INSTALLED=0
@if exist installed set /p INSTALLED=<installed

@if %INSTALLED% LSS %VERSION% goto install
@echo ���ɏ���̐ݒ�͍ς�ł��܂��B
@echo  installed ver. %VERSION%
goto abort


:install

@set TOOL=%ROOT%\tool
@set BUILD=%ROOT%\build
@set DATA=%BUILD%\Data

@echo rvp�̃C���X�g�[�����s���܂�
@echo   ������rvp���C���X�g�[���ς݂̏ꍇ�͎��s���Ă���肠��܂���B
@echo.
@cd %TOOL%\rvparasite\installer
@echo y| install_rvp.bat
@if "%ERRORLEVEL%"=="2" goto failed_rvp

@cd %ROOT%

@echo ..�K�v�ȃf�B���N�g�����쐬���܂��B
@mkdir %BUILD%\Data

@echo ..�f�[�^��ϊ����܂��B
@echo | %TOOL%\all_convert_debug.bat

@cd %ROOT%
>installed echo %VERSION%
goto exit


:failed_rvp
@echo.
@echo rvp�̃C���X�g�[���Ɏ��s���܂����B
@echo �G���[���O���m�F���Ainstall.bat�����s���Ȃ����Ă��������B
@pause
@cd %HOME%
exit /B 2

:abort
@echo.
@echo ����ݒ�𒆒f���܂����B
@pause
@cd %HOME%
exit /B 1

:exit
@echo.
@echo �C���X�g�[�����������܂����B
@echo  installed ver. %VERSION%
@pause
@cd %HOME%
exit /B 0

