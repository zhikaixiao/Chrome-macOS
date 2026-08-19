@echo off
chcp 65001 >nul
setlocal
title Google Chrome

if not exist "%~dp0App\Chrome-bin\chrome.exe" (
    echo [!] 正在初次初始化安装配置，请稍候...
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0App\Setup-Chrome.ps1"
    endlocal
    exit /b
)

if not exist "%~dp0App\Launcher.exe" (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0App\Launch-Chrome.ps1"
    endlocal
    exit /b
)

start "" "%~dp0App\Launcher.exe" %*
endlocal
