
rem ##############################
rem # preparation

set CONFIG_CALLER=%CD%


rem ##############################
rem # configuration

cd /d %~dp0
cd ..

rem # Project's Root
set ROOT=%CD%

rem # check if ruby exists
set RUBY_EXISTS=0
ruby -v >NUL 2>&1
if not "%ERRORLEVEL%"=="9009" set RUBY_EXISTS=1

rem # Rvdata2 Resources
set RESOURCE=%ROOT%\resource
set RESOURCE_CONVERTED=%RESOURCE%\_converted
set RESOURCE_BACKUP=%RESOURCE%\_backup
rem # Source Codes
set CODE=%ROOT%\code
set CODE_SCRIPTS=%CODE%\script
rem # Tkool Project Directory
set BUILD=%ROOT%\build
rem # Tkool Data Directory
set DATA=%BUILD%\Data
rem # Release Environment
set RELEASE=%ROOT%\release\master
set RELEASE_DEV=%ROOT%\release\develop
set RELEASE_TEST=%ROOT%\release\testplay

rem # Tools
set TOOL=%ROOT%\tool
rem # rv2da
set RV2DA=%TOOL%\rv2da
rem # rv2sa
set RV2SA=%TOOL%\rv2sa
rem # rvparasite
set RVPARASITE=%TOOL%\rvparasite
rem # rvlangc
set RVLANGC=%TOOL%\rvlangc
rem # rvtext
set RVTEXT=%TOOL%\rvtext
rem # rvdump
set RVDUMP=%TOOL%\rvdump
rem # btc
set BTC=%TOOL%\btc

rem # Command to Run Tools
if "%RUBY_EXISTS%"=="0" (
	set RV2SA_CMD=%RV2SA%\rv2sa.exe
    set RV2DA_CMD=%RV2DA%\rv2da.exe
	set RVLANGC_CMD=%RVLANGC%\rvlangc.exe
	set RVTEXT_CMD=%RVTEXT%\rvtext.exe
	set RVDUMP_CMD=%RVDUMP%\rvdump.exe
	set BTC_CMD=%BTC%\btc.exe
) else (
	set RV2SA_CMD=ruby %RV2SA%\rv2sa.rb
    set RV2DA_CMD=ruby %RV2DA%\rv2da.rb
	set RVLANGC_CMD=ruby %RVLANGC%\rvlangc.rb
	set RVTEXT_CMD=ruby %RVTEXT%\rvtext.rb
	set RVDUMP_CMD=ruby %RVDUMP%\rvdump.rb
	set BTC_CMD=ruby %BTC%\btc.rb
)

set COMPOSE_SCRIPT=%TOOL%\bat\compose_scripts.bat
set DECOMPOSE_SCRIPT=%TOOL%\bat\decompose_scripts.bat
set COMPOSE_DATA=%TOOL%\bat\compose_data.bat
set DECOMPOSE_DATA=%TOOL%\bat\decompose_scripts.bat

set RELEASE_BUILD=%TOOL%\release_master.bat
set RELEASE_DEV_BUILD=%TOOL%\release_dev.bat
set RELEASE_TEST_BUILD=%TOOL%\release_test.bat

rem ##############################
rem # finishing

cd %CONFIG_CALLER%
exit /b 0

