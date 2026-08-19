[CmdletBinding()]
param(
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutputDir) {
    $OutputDir = Join-Path $ScriptDir "Release"
}
$SourceDir = Join-Path $ScriptDir "Chrome-macOS"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "     Building macOS Release Package: GoogleChrome-Portable-macOS.zip             " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

if (-not (Test-Path $SourceDir)) {
    throw "Source directory '$SourceDir' does not exist!"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

$ZipPath = Join-Path $OutputDir "GoogleChrome-Portable-macOS.zip"
$ShaPath = Join-Path $OutputDir "GoogleChrome-Portable-macOS.zip.sha256"

if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
if (Test-Path $ShaPath) { Remove-Item $ShaPath -Force }

# 确保清理临时文件
$CleanPaths = @(
    (Join-Path $SourceDir "App\Chrome-bin"),
    (Join-Path $SourceDir "Data\googlechrome.dmg"),
    (Join-Path $SourceDir "Data\UserData\*"),
    (Join-Path $SourceDir "Data\Compliance_Audit_Log.txt")
)
foreach ($p in $CleanPaths) {
    if (Test-Path $p) {
        Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
    }
}
New-Item -Path (Join-Path $SourceDir "Data\UserData") -ItemType Directory -Force | Out-Null

Write-Host "[1/3] Packing release ZIP archive..." -ForegroundColor Blue
Compress-Archive -Path "$SourceDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal

Write-Host "[2/3] Calculating SHA-256 integrity hash..." -ForegroundColor Blue
$Hash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash
$HashContent = "$Hash  GoogleChrome-Portable-macOS.zip"
Set-Content -Path $ShaPath -Value $HashContent -Encoding UTF8

$ZipSize = (Get-Item $ZipPath).Length / 1MB
Write-Host "[3/3] Build finished successfully!" -ForegroundColor Green
Write-Host "  * Release ZIP: $ZipPath ($([math]::Round($ZipSize, 2)) MB)" -ForegroundColor Cyan
Write-Host "  * SHA-256:     $Hash" -ForegroundColor DarkGray
Write-Host ""
