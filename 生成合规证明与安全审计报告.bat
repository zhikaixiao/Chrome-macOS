@echo off
chcp 65001 >nul
setlocal
title 软件安全性与法律合规自证审计报告生成器

echo ==============================================================================
echo           正在启动合规与安全性全量自证审计引擎...
echo ==============================================================================
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0App\Tools\Generate-Compliance-Report.ps1"
if errorlevel 1 (
  echo.
  echo [ERROR] 审计报告生成失败。
  pause
  exit /b 1
)

echo.
echo 已成功生成并更新至 Docs\ 目录：
echo   1. Docs\合规证明与安全审计报告.html (可直接双击查看或打印)
echo   2. Docs\COMPLIANCE_AUDIT_REPORT.md (Markdown 格式审计报告)
echo.
pause
endlocal
