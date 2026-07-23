@echo off
powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File "%~dp0scripts\local-ai-launcher.ps1" %*
