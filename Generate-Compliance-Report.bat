@echo off
chcp 65001 >nul
setlocal
title Software Security and Legal Compliance Audit Report Generator

echo ==============================================================================
echo       Starting Compliance and Security Self-Audit Engine...
echo ==============================================================================
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0App\Tools\Generate-Compliance-Report.ps1"
if errorlevel 1 (
  echo.
  echo [ERROR] Audit report generation failed.
  pause
  exit /b 1
)

echo.
echo Reports successfully generated and updated in Docs\ directory:
echo   1. Docs\Compliance-Audit-Report.html (Double-click to view or print)
echo   2. Docs\COMPLIANCE_AUDIT_REPORT.md (Markdown format report)
echo.
pause
endlocal
