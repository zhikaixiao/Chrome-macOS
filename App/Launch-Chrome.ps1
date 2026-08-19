[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $appDir
if (-not (Test-Path (Join-Path $rootDir 'App'))) {
    $rootDir = $appDir
    $appDir = Join-Path $rootDir 'App'
}

function Find-Chrome {
    # 1. 优先使用本地便携版 Chrome
    $localChrome = Join-Path $appDir 'Chrome-bin\chrome.exe'
    if (Test-Path -LiteralPath $localChrome -PathType Leaf) {
        return $localChrome
    }

    # 2. 系统已安装的 Chrome
    $paths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )

    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            return $p
        }
    }

    $regKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe'
    )
    foreach ($reg in $regKeys) {
        if (Test-Path $reg) {
            $val = (Get-ItemProperty -Path $reg -ErrorAction SilentlyContinue).'(default)'
            if ($val -and (Test-Path -LiteralPath $val -PathType Leaf)) {
                return $val
            }
        }
    }

    return $null
}

$chromePath = Find-Chrome

if (-not $chromePath) {
    Write-Host "[!] Chrome not found. Launching setup..." -ForegroundColor Yellow
    & (Join-Path $appDir 'Setup-Chrome.ps1')
    return
}

Write-Host "[+] Launching Chrome: $chromePath" -ForegroundColor Green

$ext1 = Join-Path $appDir 'Extensions\Violentmonkey'
$ext2 = Join-Path $appDir 'Extensions\KissTranslator'
$ext3 = Join-Path $appDir 'Extensions\DarkReader'
$userDataDir = Join-Path $rootDir 'Data\UserData'
$extArgs = "$ext1,$ext2,$ext3"

$launchArgs = "--user-data-dir=`"$userDataDir`" --load-extension=`"$extArgs`" --disable-extensions-except=`"$extArgs`" --lang=zh-CN --no-first-run --disable-fre --no-default-browser-check --disable-sync --disable-signin-promo `"https://www.bing.com`""

Start-Process -FilePath $chromePath -ArgumentList $launchArgs
