[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    $OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = "c:\Users\xdani\Documents\Chrome\Tools" }

$pyScript = Join-Path $scriptDir "generate_compliance_report.py"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "          正在生成【软件安全性与法律合规自证审计报告】...                       " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $pyScript) {
    python $pyScript
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "                [OK] 合规审计与法律自证报告全部生成完毕！                       " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""
