@echo off
@rem �Z�[�u������̏���
@rem �V�����ۑ����ꂽrvdata2��json�ɓW�J����

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

