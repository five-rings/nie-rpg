@echo off
rem Data\Configのファイルを変換する


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

set TARGET=%BUILD%\Data\Config\

rem rvdump
cd %RVDUMP%
for %%F in (%TARGET%*.rb) do (
  echo convert %%F >&2
  call %RVDUMP_CMD% -s "%%F" -o "%%F.dat"
)

rem ##############################
rem # finishing
rem #

cd %HOME%
endlocal

