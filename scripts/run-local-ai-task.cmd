@echo off
setlocal
set "LOG_FILE=%~1"
shift
set "SCRIPT_FILE=%~1"
shift

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_FILE%" %* > "%LOG_FILE%" 2>&1
exit /b %ERRORLEVEL%
