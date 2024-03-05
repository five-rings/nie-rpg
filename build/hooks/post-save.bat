@echo off
@rem セーブ処理後の処理
@rem 新しく保存されたrvdata2をjsonに展開する

@timeout /t 1 > nul

@echo run post-save

@set HOME=%CD%
cd /d %~dp0
@set HOOK=%CD%
@cd ..\..
@set ROOT=%CD%
@set TOOL=%ROOT%\tool

@call %TOOL%\bat\decompose_data.bat

@cd %HOME%
exit /B 0

