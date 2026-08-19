@echo off
chcp 65001 >nul
setlocal
title Google Chrome

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0App\Launch-Chrome.ps1"
endlocal
