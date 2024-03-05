@echo off
@rem 初回に必要なセットアップを行います

@echo プロジェクトの初回設定を行います。
@echo.

@set HOME=%CD%
cd /d %~dp0
cd ..
@set ROOT=%CD%

@set VERSION=1
@set INSTALLED=0
@if exist installed set /p INSTALLED=<installed

@if %INSTALLED% LSS %VERSION% goto install
@echo 既に初回の設定は済んでいます。
@echo  installed ver. %VERSION%
goto abort


:install

@set TOOL=%ROOT%\tool
@set BUILD=%ROOT%\build
@set DATA=%BUILD%\Data

@echo rvpのインストールを行います
@echo   ※既にrvpをインストール済みの場合は失敗しても問題ありません。
@echo.
@cd %TOOL%\rvparasite\installer
@echo y| install_rvp.bat
@if "%ERRORLEVEL%"=="2" goto failed_rvp

@cd %ROOT%

@echo ..必要なディレクトリを作成します。
@mkdir %BUILD%\Data

@echo ..データを変換します。
@echo | %TOOL%\all_convert_debug.bat

@cd %ROOT%
>installed echo %VERSION%
goto exit


:failed_rvp
@echo.
@echo rvpのインストールに失敗しました。
@echo エラーログを確認し、install.batを実行しなおしてください。
@pause
@cd %HOME%
exit /B 2

:abort
@echo.
@echo 初回設定を中断しました。
@pause
@cd %HOME%
exit /B 1

:exit
@echo.
@echo インストールが完了しました。
@echo  installed ver. %VERSION%
@pause
@cd %HOME%
exit /B 0

