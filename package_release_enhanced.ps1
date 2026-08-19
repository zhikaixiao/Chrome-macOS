[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

try {
    $OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$rootDir = 'c:\Users\xdani\Documents\Chrome'
$sourceDir = Join-Path $rootDir 'Chrome-Enhanced'
$stagingParent = Join-Path $rootDir 'ReleaseStagingEnhanced'
$stagingDir = Join-Path $stagingParent 'GoogleChrome-Portable'
$releaseOutDir = Join-Path $rootDir 'Release'

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "     Building Google Chrome Enhanced Release Package (ZIP format)               " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Clean previous staging
if (Test-Path $stagingParent) {
    Remove-Item -Path $stagingParent -Recurse -Force
}
if (-not (Test-Path $releaseOutDir)) {
    New-Item -Path $releaseOutDir -ItemType Directory -Force | Out-Null
}

New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null

# 2. Copy files to staging
Write-Host "[1/3] Copying Enhanced package files..." -ForegroundColor Cyan
Copy-Item -Path "$sourceDir\*" -Destination $stagingDir -Recurse -Force

# 3. Clean UTF-8 BOM
Write-Host "[2/3] Optimizing script encoding..." -ForegroundColor Cyan
$ps1Files = Get-ChildItem -Path $stagingDir -Filter '*.ps1' -Recurse
foreach ($f in $ps1Files) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    while ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length - 1)]
    }
    $singleBom = [byte[]]@(0xEF, 0xBB, 0xBF)
    [System.IO.File]::WriteAllBytes($f.FullName, $singleBom + $bytes)
}
Write-Host "  - Script encoding optimized." -ForegroundColor Green

# 4. Compress to ZIP
Write-Host "[3/3] Compressing into ZIP..." -ForegroundColor Cyan
$zipPath = Join-Path $releaseOutDir 'GoogleChrome-Enhanced-Portable.zip'
if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $stagingParent,
    $zipPath,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false
)

# Generate SHA256 Checksum
$hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
$hashFile = "$zipPath.sha256"
"$hash  $(Split-Path -Leaf $zipPath)" | Out-File -FilePath $hashFile -Encoding ASCII
$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host "  - File: $(Split-Path -Leaf $zipPath) (Size: $sizeMB MB)" -ForegroundColor White
Write-Host "    SHA256: $hash" -ForegroundColor Gray

# Copy to desktop
$desktop = [Environment]::GetFolderPath('Desktop')
Copy-Item $zipPath $desktop -Force
Copy-Item $hashFile $desktop -Force
Write-Host "  - Copied to Desktop: $(Join-Path $desktop (Split-Path -Leaf $zipPath))" -ForegroundColor Green

# Clean staging directory
Remove-Item -Path $stagingParent -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "    [OK] Google Chrome Enhanced ZIP package generated successfully!             " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "Release file: $zipPath" -ForegroundColor Cyan
Write-Host ""
