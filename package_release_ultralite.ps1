[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

try {
    $OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$rootDir = 'c:\Users\xdani\Documents\Chrome'
$sourceDir = Join-Path $rootDir 'Chrome-UltraLite'
$stagingParent = Join-Path $rootDir 'ReleaseStagingUltraLite'
$stagingDir = Join-Path $stagingParent 'GoogleChrome-UltraLite'
$releaseOutDir = Join-Path $rootDir 'Release'

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "     Building Google Chrome UltraLite Release Package (ZIP format)              " -ForegroundColor Yellow
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
Write-Host "[1/3] Copying UltraLite files..." -ForegroundColor Cyan
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

# 4. Compress to ZIP
Write-Host "[3/3] Compressing into ZIP..." -ForegroundColor Cyan
$zipPath = Join-Path $releaseOutDir 'GoogleChrome-UltraLite.zip'
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

# Clean staging directory
Remove-Item -Path $stagingParent -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "    [OK] Google Chrome UltraLite ZIP package generated successfully!            " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "Release file: $zipPath" -ForegroundColor Cyan
Write-Host ""
