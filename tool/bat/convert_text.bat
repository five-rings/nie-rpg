@echo off
rem code\text\にあるファイルを変換する


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

set SRC=%CODE%\text
set DST=%BUILD%\Data\Language\text

if exist %DST% rd /s /q %DST%
mkdir %DST%

rem rvlangc
cd %RVTEXT%
echo convert %SRC% to %DST% >&2
call %RVTEXT_CMD% -s "%SRC%" -o "%DST%"

cd %DST%

rem 多言語ファイルを正しい場所に移動
for /d %%a in (*) do (
  echo %%a
  if not exist ..\%%a ( md ..\%%a)
  if exist ..\%%a\text ( rd /s /q ..\%%a\text)
  move %%a text
  move text ..\%%a
)

rem ##############################
rem # finishing
rem #

cd %HOME%
endlocal

