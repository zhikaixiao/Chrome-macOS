[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $appDir
if (-not (Test-Path (Join-Path $rootDir 'App'))) {
    $rootDir = $appDir
    $appDir = Join-Path $rootDir 'App'
}

$launcherExe = Join-Path $appDir 'Launcher.exe'
$launcherSrc = Join-Path $appDir 'Tools\ChromeLauncher.cs'

if ((-not (Test-Path $launcherExe)) -and (Test-Path $launcherSrc)) {
    $csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path $csc)) {
        $csc = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe'
    }
    if (Test-Path $csc) {
        & $csc /target:winexe /optimize+ "/out:$launcherExe" /r:System.Windows.Forms.dll "$launcherSrc" | Out-Null
    }
}

if (Test-Path $launcherExe) {
    Start-Process -FilePath $launcherExe
    return
}

$chromePath = Join-Path $appDir 'Chrome-bin\chrome.exe'
if (-not (Test-Path -LiteralPath $chromePath -PathType Leaf)) {
    Write-Host "[!] Portable Chrome not found in App\Chrome-bin. Launching setup..." -ForegroundColor Yellow
    & (Join-Path $appDir 'Setup-Chrome.ps1')
    return
}

# 搜集有效扩展路径
$extDir = Join-Path $appDir 'Extensions'
$validExtPaths = @()
foreach ($name in @('Violentmonkey', 'KissTranslator', 'DarkReader')) {
    $p = Join-Path $extDir $name
    if (Test-Path (Join-Path $p 'manifest.json')) {
        $validExtPaths += $p
    }
}

$userDataDir = Join-Path $rootDir 'Data\UserData'
if (-not (Test-Path $userDataDir)) {
    New-Item -Path $userDataDir -ItemType Directory -Force | Out-Null
}

$chromeInput = New-Object System.IO.Pipes.AnonymousPipeServerStream([System.IO.Pipes.PipeDirection]::Out, [System.IO.HandleInheritability]::Inheritable)
$chromeOutput = New-Object System.IO.Pipes.AnonymousPipeServerStream([System.IO.Pipes.PipeDirection]::In, [System.IO.HandleInheritability]::Inheritable)

$inHandle = $chromeInput.GetClientHandleAsString()
$outHandle = $chromeOutput.GetClientHandleAsString()

$chromeArgs = @(
    "--user-data-dir=`"$userDataDir`"",
    "--lang=zh-CN",
    "--no-first-run",
    "--disable-fre",
    "--no-default-browser-check",
    "--disable-sync",
    "--disable-signin-promo",
    "--enable-unsafe-extension-debugging",
    "--remote-debugging-pipe",
    "--remote-debugging-io-pipes=$inHandle,$outHandle",
    "`"https://www.bing.com`""
)

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $chromePath
$psi.Arguments = $chromeArgs -join ' '
$psi.UseShellExecute = $false

$proc = [System.Diagnostics.Process]::Start($psi)

$chromeInput.DisposeLocalCopyOfClientHandle()
$chromeOutput.DisposeLocalCopyOfClientHandle()

$script:msgId = 100
function Send-CDP([string]$method, [string]$paramsJson) {
    $script:msgId += 1
    $id = $script:msgId
    $req = "{`"id`":$id,`"method`":`"$method`",`"params`":$paramsJson}`0"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($req)
    $chromeInput.Write($bytes, 0, $bytes.Length)
    $chromeInput.Flush()

    $ms = New-Object System.IO.MemoryStream
    while ($true) {
        $b = $chromeOutput.ReadByte()
        if ($b -lt 0 -or $b -eq 0) { break }
        $ms.WriteByte([byte]$b)
    }
    return [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
}

Start-Sleep -Milliseconds 400
Send-CDP -method "Browser.getVersion" -paramsJson "{}" | Out-Null

foreach ($ext in $validExtPaths) {
    $escaped = $ext.Replace('\', '\\')
    Send-CDP -method "Extensions.loadUnpacked" -paramsJson "{`"path`":`"$escaped`"}" | Out-Null
}

$proc.WaitForExit()
