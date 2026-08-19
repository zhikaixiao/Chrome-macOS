@echo off
chcp 65001 >nul
setlocal
title Google Chrome Setup

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0App\Setup-Chrome.ps1" %*
if errorlevel 1 (
  echo.
  echo [ERROR] Setup did not complete. See Data\ChromeInstallerDiagnostics.txt if it was created.
  pause
  exit /b 1
)

endlocal
