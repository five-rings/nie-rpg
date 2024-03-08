@echo off
@Setlocal
@rem rvp installer which is intended to use rvp in all projects.

@set HOME=%CD%

@echo rvp(rvparasite) �� �C���X�g�[�����܂��B
@echo.
@echo �S�Ẵv���W�F�N�g�� rvp ���g�p���邽�߂̐ݒ���s���܂��B
@echo  * �C���X�g�[���𑱂���ꍇ�� y �������Ă��������B
@echo  * ��߂�ꍇ�͂���ȊO�̃L�[�������ĉ������B
@echo ?

@set /p c=
@if "%c%"=="Y" goto do_install
@if "%c%"=="y" goto do_install
goto abort

:do_install
@echo rvp�̃C���X�g�[�����s���܂��B


:check_rvp
@cd /d %~dp0
@set RVP_INSTALLER=%CD%
@cd ..\
@set RVP=%CD%
@set RVP_DLL=%RVP%\scilexer.dll

@if exist %RVP_DLL% goto chech_rpg
@echo !Error: rvp ��������܂���B
@echo  %RVP_DLL% �����݂��܂���B
goto failed

:chech_rpg
@echo.
@echo ...RPG�c�N�[��VX Ace���C���X�g�[�������t�H���_��T���܂��B
@reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Enterbrain\RPGVXAce" /v ApplicationPath /reg:32 >NUL 2>&1
@if "%ERRORLEVEL%"=="0" goto get_rpg
@echo !Error: RPG�c�N�[��VX Ace��������܂���B
goto failed


:get_rpg
@for /f "TOKENS=1,2,*" %%A IN ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Enterbrain\RPGVXAce" /v ApplicationPath /reg:32') do (
	@if "%%A"=="ApplicationPath" set PATH_RPG=%%C
)
@if exist "%PATH_RPG%" (
	@echo RPG�c�N�[��VX Ace: "%PATH_RPG%"
	goto check_dll
)
@echo !Error: RPG�c�N�[��VX Ace��������܂���B
@echo  - ���W�X�g���ɐݒ肳��Ă���p�X "%PATH_RPG%" �͑��݂��܂���B
goto failed


:check_dll
@echo.
@echo ...SciLexer.dll��ޔ����܂��B
@if exist "%PATH_RPG%\SciLexer.dll" goto make_dll_dir
@echo !Error: RPG�c�N�[��VX Ace���C���X�g�[������Ă���t�H���_�� SciLexer.dll �����݂��܂���B
@echo  ����rvp���C���X�g�[������Ă���\��������܂��B
goto abort


:make_dll_dir
@if not exist "%PATH_RPG%\SciLexer" goto move_dll
@echo !Error: RPG�c�N�[��VX Ace���C���X�g�[������Ă���t�H���_�Ɋ��� SciLexer �����݂��܂��B
@echo  ����rvp���C���X�g�[������Ă���\��������܂��B
goto abort


:move_dll
@mkdir "%PATH_RPG%\SciLexer"
@if not "%ERRORLEVEL%"=="0" goto required_admin_authorship
@move "%PATH_RPG%\SciLexer.dll" "%PATH_RPG%\SciLexer"
@if not "%ERRORLEVEL%"=="0" goto required_admin_authorship

:move_rvp
@echo.
@echo ...rvp���R�s�[���܂��B
@copy /B "%RVP_DLL%" "%PATH_RPG%"
@if not "%ERRORLEVEL%"=="0" goto required_admin_authorship

goto exit


:required_admin_authorship
@echo.
@echo rvp ���C���X�g�[�����邽�߂ɊǗ��Ҍ������K�v�ȉ\��������܂��B
@echo �C���X�g�[���p�̃o�b�`�t�@�C�����u�Ǘ��҂Ƃ��Ď��s�v���Ă��������B
goto failed


:abort
@echo.
@echo rvp �̃C���X�g�[���𒆒f���܂����B
@pause

@cd %HOME%
@exit /B 1

:failed
@echo.
@echo rvp �̃C���X�g�[���Ɏ��s���܂����B
@pause

@cd %HOME%
@exit /B 2

:exit
@echo rvp �̃C���X�g�[�����������܂����B
@pause

@cd %HOME%
@exit /B 0
