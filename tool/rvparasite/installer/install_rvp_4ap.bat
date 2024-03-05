@echo off
@Setlocal
@rem rvp installer which is intended to use rvp in all projects.

@set HOME=%CD%

@echo rvp(rvparasite) を インストールします。
@echo.
@echo 全てのプロジェクトで rvp を使用するための設定を行います。
@echo  * インストールを続ける場合は y を押してください。
@echo  * やめる場合はそれ以外のキーを押して下さい。
@echo ?

@set /p c=
@if "%c%"=="Y" goto do_install
@if "%c%"=="y" goto do_install
goto abort

:do_install
@echo rvpのインストールを行います。


:check_rvp
@cd /d %~dp0
@set RVP_INSTALLER=%CD%
@cd ..\
@set RVP=%CD%
@set RVP_DLL=%RVP%\scilexer.dll

@if exist %RVP_DLL% goto chech_rpg
@echo !Error: rvp が見つかりません。
@echo  %RVP_DLL% が存在しません。
goto failed

:chech_rpg
@echo.
@echo ...RPGツクールVX Aceをインストールしたフォルダを探します。
@reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Enterbrain\RPGVXAce" /v ApplicationPath /reg:32 >NUL 2>&1
@if "%ERRORLEVEL%"=="0" goto get_rpg
@echo !Error: RPGツクールVX Aceが見つかりません。
goto failed


:get_rpg
@for /f "TOKENS=1,2,*" %%A IN ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Enterbrain\RPGVXAce" /v ApplicationPath /reg:32') do (
	@if "%%A"=="ApplicationPath" set PATH_RPG=%%C
)
@if exist "%PATH_RPG%" (
	@echo RPGツクールVX Ace: "%PATH_RPG%"
	goto check_dll
)
@echo !Error: RPGツクールVX Aceが見つかりません。
@echo  - レジストリに設定されているパス "%PATH_RPG%" は存在しません。
goto failed


:check_dll
@echo.
@echo ...SciLexer.dllを退避します。
@if exist "%PATH_RPG%\SciLexer.dll" goto make_dll_dir
@echo !Error: RPGツクールVX Aceがインストールされているフォルダに SciLexer.dll が存在しません。
@echo  既にrvpがインストールされている可能性があります。
goto abort


:make_dll_dir
@if not exist "%PATH_RPG%\SciLexer" goto move_dll
@echo !Error: RPGツクールVX Aceがインストールされているフォルダに既に SciLexer が存在します。
@echo  既にrvpがインストールされている可能性があります。
goto abort


:move_dll
@mkdir "%PATH_RPG%\SciLexer"
@if not "%ERRORLEVEL%"=="0" goto required_admin_authorship
@move "%PATH_RPG%\SciLexer.dll" "%PATH_RPG%\SciLexer"
@if not "%ERRORLEVEL%"=="0" goto required_admin_authorship

:move_rvp
@echo.
@echo ...rvpをコピーします。
@copy /B "%RVP_DLL%" "%PATH_RPG%"
@if not "%ERRORLEVEL%"=="0" goto required_admin_authorship

goto exit


:required_admin_authorship
@echo.
@echo rvp をインストールするために管理者権限が必要な可能性があります。
@echo インストール用のバッチファイルを「管理者として実行」してください。
goto failed


:abort
@echo.
@echo rvp のインストールを中断しました。
@pause

@cd %HOME%
@exit /B 1

:failed
@echo.
@echo rvp のインストールに失敗しました。
@pause

@cd %HOME%
@exit /B 2

:exit
@echo rvp のインストールが完了しました。
@pause

@cd %HOME%
@exit /B 0
