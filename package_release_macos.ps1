[CmdletBinding()]
param(
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutputDir) {
    $OutputDir = Join-Path $ScriptDir "Release\macOS"
}
$SourceDir = Join-Path $ScriptDir "Chrome-macOS"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "     Building macOS Release Packages to: Release\macOS                          " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

if (-not (Test-Path $SourceDir)) {
    throw "Source directory '$SourceDir' does not exist!"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

# Clean temporary files in source directory
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

# 1. Build Enhanced Edition (with 3 extensions)
Write-Host "[1/2] Packaging Enhanced Edition (with 3 extensions)..." -ForegroundColor Blue
$EnhancedZip = Join-Path $OutputDir "GoogleChrome-Portable-macOS-Enhanced.zip"
if (Test-Path $EnhancedZip) { Remove-Item $EnhancedZip -Force }

Compress-Archive -Path "$SourceDir\*" -DestinationPath $EnhancedZip -CompressionLevel Optimal

$EnhancedHash = (Get-FileHash -Path $EnhancedZip -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $OutputDir "GoogleChrome-Portable-macOS-Enhanced.zip.sha256") -Value "$EnhancedHash  GoogleChrome-Portable-macOS-Enhanced.zip" -Encoding UTF8

$EnhancedSize = [math]::Round(((Get-Item $EnhancedZip).Length / 1MB), 2)
Write-Host "  * Enhanced Edition: $EnhancedZip ($EnhancedSize MB)" -ForegroundColor Green

# 2. Build Clean Edition (0 extensions, pure Chrome)
Write-Host "[2/2] Packaging Clean Edition (0 extensions, pure Chrome)..." -ForegroundColor Blue
$CleanZip = Join-Path $OutputDir "GoogleChrome-Portable-macOS-Clean.zip"
if (Test-Path $CleanZip) { Remove-Item $CleanZip -Force }

$TempCleanDir = Join-Path $env:TEMP ("GoogleChrome-macOS-Clean-" + [guid]::NewGuid().ToString())
try {
    Copy-Item -Path $SourceDir -Destination $TempCleanDir -Recurse -Force
    $TempExtDir = Join-Path $TempCleanDir "App\Extensions"
    if (Test-Path $TempExtDir) {
        Remove-Item "$TempExtDir\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Compress-Archive -Path "$TempCleanDir\*" -DestinationPath $CleanZip -CompressionLevel Optimal
    
    $CleanHash = (Get-FileHash -Path $CleanZip -Algorithm SHA256).Hash
    Set-Content -Path (Join-Path $OutputDir "GoogleChrome-Portable-macOS-Clean.zip.sha256") -Value "$CleanHash  GoogleChrome-Portable-macOS-Clean.zip" -Encoding UTF8
    
    $CleanSize = [math]::Round(((Get-Item $CleanZip).Length / 1KB), 2)
    Write-Host "  * Clean Edition:    $CleanZip ($CleanSize KB)" -ForegroundColor Green
}
finally {
    if (Test-Path $TempCleanDir) {
        Remove-Item $TempCleanDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clean any leftover legacy unnamed zip
Remove-Item (Join-Path $OutputDir "GoogleChrome-Portable-macOS.zip*") -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                       Build Completed Successfully!                            " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Dedicated Directory : $OutputDir" -ForegroundColor White
Write-Host "1. Enhanced Edition : $EnhancedZip ($EnhancedSize MB)" -ForegroundColor Yellow
Write-Host "2. Clean Edition    : $CleanZip ($CleanSize KB)" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
