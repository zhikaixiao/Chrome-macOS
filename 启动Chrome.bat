@echo off
chcp 65001 >nul
setlocal
title Google Chrome 便携增强版

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0App\Launch-Chrome.ps1"
endlocal
