[CmdletBinding()]
param(
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutputDir) {
    $OutputDir = Join-Path $ScriptDir "Release\macOS"
}
$SourceDir = Join-Path $ScriptDir "Chrome-macOS"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "     Building macOS Packages with Enclosing Folder (GoogleChrome-macOS)         " -ForegroundColor Yellow
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

$StagingParent = Join-Path $env:TEMP ("MacStaging-" + [guid]::NewGuid().ToString())
$EnclosingDirName = "GoogleChrome-macOS"

try {
    # -------------------------------------------------------------------------
    # 1. 构建【增强插件版】(带外层 GoogleChrome-macOS 文件夹)
    # -------------------------------------------------------------------------
    Write-Host "[1/2] Packaging Enhanced Edition (Enclosed in 'GoogleChrome-macOS' folder)..." -ForegroundColor Blue
    $EnhancedStaging = Join-Path $StagingParent "Enhanced\$EnclosingDirName"
    New-Item -Path $EnhancedStaging -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$SourceDir\*" -Destination $EnhancedStaging -Recurse -Force

    $EnhancedZip = Join-Path $OutputDir "GoogleChrome-Portable-macOS-Enhanced.zip"
    if (Test-Path $EnhancedZip) { Remove-Item $EnhancedZip -Force }

    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        (Join-Path $StagingParent "Enhanced"),
        $EnhancedZip,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    $EnhancedHash = (Get-FileHash -Path $EnhancedZip -Algorithm SHA256).Hash
    Set-Content -Path (Join-Path $OutputDir "GoogleChrome-Portable-macOS-Enhanced.zip.sha256") -Value "$EnhancedHash  GoogleChrome-Portable-macOS-Enhanced.zip" -Encoding UTF8
    $EnhancedSize = [math]::Round(((Get-Item $EnhancedZip).Length / 1MB), 2)
    Write-Host "  * Enhanced Edition: $EnhancedZip ($EnhancedSize MB)" -ForegroundColor Green

    # -------------------------------------------------------------------------
    # 2. 构建【纯净无插件版】(带外层 GoogleChrome-macOS 文件夹)
    # -------------------------------------------------------------------------
    Write-Host "[2/2] Packaging Clean Edition (Enclosed in 'GoogleChrome-macOS' folder)..." -ForegroundColor Blue
    $CleanStaging = Join-Path $StagingParent "Clean\$EnclosingDirName"
    New-Item -Path $CleanStaging -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$SourceDir\*" -Destination $CleanStaging -Recurse -Force

    # 清空 Clean 版的扩展
    $CleanExtDir = Join-Path $CleanStaging "App\Extensions"
    if (Test-Path $CleanExtDir) {
        Remove-Item "$CleanExtDir\*" -Recurse -Force -ErrorAction SilentlyContinue
    }

    $CleanZip = Join-Path $OutputDir "GoogleChrome-Portable-macOS-Clean.zip"
    if (Test-Path $CleanZip) { Remove-Item $CleanZip -Force }

    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        (Join-Path $StagingParent "Clean"),
        $CleanZip,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    $CleanHash = (Get-FileHash -Path $CleanZip -Algorithm SHA256).Hash
    Set-Content -Path (Join-Path $OutputDir "GoogleChrome-Portable-macOS-Clean.zip.sha256") -Value "$CleanHash  GoogleChrome-Portable-macOS-Clean.zip" -Encoding UTF8
    $CleanSize = [math]::Round(((Get-Item $CleanZip).Length / 1KB), 2)
    Write-Host "  * Clean Edition:    $CleanZip ($CleanSize KB)" -ForegroundColor Green
}
finally {
    if (Test-Path $StagingParent) {
        Remove-Item $StagingParent -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "         Build Completed! Both ZIPs have clean enclosing root folder!           " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Directory: $OutputDir" -ForegroundColor White
Write-Host "1. Enhanced Edition : $EnhancedZip ($EnhancedSize MB)" -ForegroundColor Yellow
Write-Host "2. Clean Edition    : $CleanZip ($CleanSize KB)" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
