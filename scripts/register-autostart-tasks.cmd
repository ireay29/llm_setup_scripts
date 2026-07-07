@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0register-autostart-tasks.ps1" %*
