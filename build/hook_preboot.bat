@echo off
echo pre-boot
echo.

rem ##############################
rem # configure
rem #

setlocal
set HOME=%CD%
cd /d %~dp0
call ..\tool\config.bat

set COMPOSED_SCRIPT=%CODE%\Scripts.rvdata2
set TARGET=%DATA%\Scripts.rvdata2


rem ----------------------------------
rem Compose Scripts.rvdata2
rem 
if exist "%COMPOSED_SCRIPT%" goto check_script

:compose_script
echo.
echo compose Scripts.rvdata2
call %COMPOSE_SCRIPT% "-f debug"

:check_script
echo check if composed script exists
echo n | comp "%TARGET%" "%COMPOSED_SCRIPT%" 2>NUL
if "%ERRORLEVEL%"=="0" goto end_script

:copy_script
echo copy Scripts.rvdata2
copy /B /Y "%COMPOSED_SCRIPT%" "%TARGET%"

:end_script


rem ----------------------------------
rem Check and Compose Data/*.rvdata2
rem jsonとして存在するのにrvdata2が存在しないものだけコンバートする
rem 
echo check if there is any json file which is not converted yet
cd %RESOURCE%
set NEED_TO_COMPOSE_DATA=0
for %%I in (*.json) do (
	if exist %DATA%\%%~nI.rvdata2 (
		echo %%~nI>> excludes
	) else (
		set NEED_TO_COMPOSE_DATA=1
	)
)
if %NEED_TO_COMPOSE_DATA%==0 (
	if exist excludes del excludes
	goto end_data
)

:compose_data
echo ...composing data phase
cd %RV2DA%
copy excludes ex_org >NUL
type %RESOURCE%\excludes>> excludes
call %COMPOSE_DATA%

if exist excludes del excludes
move ex_org excludes
if exist %RESOURCE%\excludes del %RESOURCE%\excludes
:end_data


rem ##############################
rem # finishing
rem #

@echo end of pre-boot
@echo.

cd %HOME%
endlocal
