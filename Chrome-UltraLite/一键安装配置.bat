@echo off
chcp 65001 >nul
setlocal
title Google Chrome - One-Click Portable Setup

echo ==============================================================================
echo        Google Chrome Portable - One-Click Setup
echo ==============================================================================
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0App\Setup-Chrome.ps1"
if errorlevel 1 (
  echo.
  echo [ERROR] Setup did not complete.
  pause
  exit /b 1
)

endlocal
