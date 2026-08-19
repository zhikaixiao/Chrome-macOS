[CmdletBinding()]
param(
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $OutputDir) {
    $OutputDir = Join-Path $ScriptDir (Join-Path "Release" "macOS")
}
$SourceDir = Join-Path $ScriptDir "Chrome-macOS"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "     Building macOS Release Packages (POSIX Forward-Slash ZIP Archive)          " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

if (-not (Test-Path $SourceDir)) {
    throw "Source directory '$SourceDir' does not exist!"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

# Clean temporary files in source directory
$CleanPaths = @(
    (Join-Path $SourceDir "App/Chrome-bin"),
    (Join-Path $SourceDir "Data/googlechrome.dmg"),
    (Join-Path $SourceDir "Data/googlechrome.pkg"),
    (Join-Path $SourceDir "Data/UserData/*"),
    (Join-Path $SourceDir "Data/Compliance_Audit_Log.txt")
)
foreach ($p in $CleanPaths) {
    if (Test-Path $p) {
        Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
    }
}
New-Item -Path (Join-Path $SourceDir "Data/UserData") -ItemType Directory -Force | Out-Null

function Create-PosixZipArchive {
    param(
        [string]$SrcDir,
        [string]$TargetZip,
        [string]$RootFolderName,
        [string[]]$Excludes = @()
    )
    if (Test-Path $TargetZip) { Remove-Item $TargetZip -Force }
    $archive = [System.IO.Compression.ZipFile]::Open($TargetZip, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $allItems = Get-ChildItem -Path $SrcDir -Recurse -File
        foreach ($item in $allItems) {
            $rel = $item.FullName.Substring($SrcDir.Length).TrimStart('\', '/')
            $shouldExclude = $false
            foreach ($ex in $Excludes) {
                if ($rel -like $ex) { $shouldExclude = $true; break }
            }
            if ($shouldExclude) { continue }
            
            $posixEntry = "$RootFolderName/$rel" -replace '\\', '/'
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $item.FullName, $posixEntry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
    finally {
        $archive.Dispose()
    }
}

$EnclosingDirName = "GoogleChrome-macOS"

# 1. 构建【增强插件版】
Write-Host "[1/2] Packaging Enhanced Edition (Enclosed in '$EnclosingDirName')..." -ForegroundColor Blue
$EnhancedZip = Join-Path $OutputDir "GoogleChrome-Portable-macOS-Enhanced.zip"
Create-PosixZipArchive -SrcDir $SourceDir -TargetZip $EnhancedZip -RootFolderName $EnclosingDirName

$EnhancedHash = (Get-FileHash -Path $EnhancedZip -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $OutputDir "GoogleChrome-Portable-macOS-Enhanced.zip.sha256") -Value "$EnhancedHash  GoogleChrome-Portable-macOS-Enhanced.zip" -Encoding UTF8
$EnhancedSize = [math]::Round(((Get-Item $EnhancedZip).Length / 1MB), 2)
Write-Host "  * Enhanced Edition: $EnhancedZip ($EnhancedSize MB)" -ForegroundColor Green

# 2. 构建【纯净无插件版】
Write-Host "[2/2] Packaging Clean Edition (Enclosed in '$EnclosingDirName')..." -ForegroundColor Blue
$CleanZip = Join-Path $OutputDir "GoogleChrome-Portable-macOS-Clean.zip"
Create-PosixZipArchive -SrcDir $SourceDir -TargetZip $CleanZip -RootFolderName $EnclosingDirName -Excludes @("App/Extensions/*", "App\Extensions\*")

$CleanHash = (Get-FileHash -Path $CleanZip -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $OutputDir "GoogleChrome-Portable-macOS-Clean.zip.sha256") -Value "$CleanHash  GoogleChrome-Portable-macOS-Clean.zip" -Encoding UTF8
$CleanSize = [math]::Round(((Get-Item $CleanZip).Length / 1KB), 2)
Write-Host "  * Clean Edition:    $CleanZip ($CleanSize KB)" -ForegroundColor Green

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "         Build Completed! Both macOS ZIPs are 100% POSIX compliant!             " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Directory: $OutputDir" -ForegroundColor White
Write-Host "1. Enhanced Edition : $EnhancedZip ($EnhancedSize MB)" -ForegroundColor Yellow
Write-Host "2. Clean Edition    : $CleanZip ($CleanSize KB)" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
