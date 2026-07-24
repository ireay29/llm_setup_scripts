@echo off
setlocal
set "LOG_FILE=%~1"
shift
set "SCRIPT_FILE=%~1"
shift

set "SCRIPT_ARGS="
:collect_args
if "%~1"=="" goto run_task
set "SCRIPT_ARGS=%SCRIPT_ARGS% "%~1""
shift
goto collect_args

:run_task
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_FILE%" %SCRIPT_ARGS% > "%LOG_FILE%" 2>&1
exit /b %ERRORLEVEL%
