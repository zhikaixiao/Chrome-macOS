[CmdletBinding()]
param(
    [switch]$ForceReinstall,
    [switch]$Silent,
    [switch]$AutoLaunch
)

# ==============================================================================
# Google Chrome Portable - One-Click Setup
# Pure edition | Zero extensions | Isolated user data | Bing & Chinese default
# ==============================================================================
$ErrorActionPreference = 'Stop'

try {
    # Tls12 = 3072, Tls13 = 12288 (向下兼容旧版 .NET Framework)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 -bor 12288
} catch {}

try {
    $OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$script:AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RootDir = Split-Path -Parent $script:AppDir
if (-not (Test-Path (Join-Path $script:RootDir 'App'))) {
    $script:RootDir = $script:AppDir
    $script:AppDir = Join-Path $script:RootDir 'App'
}

$script:DataDir = Join-Path $script:RootDir 'Data'
$script:UserDataDir = Join-Path $script:DataDir 'UserData'
$script:ChromeBinDir = Join-Path $script:AppDir 'Chrome-bin'

if (-not (Test-Path $script:DataDir)) { New-Item -Path $script:DataDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $script:UserDataDir)) { New-Item -Path $script:UserDataDir -ItemType Directory -Force | Out-Null }

# 注册 Unicode 快捷方式创建接口 (纯 Windows 原生 Shell COM)
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;

[ComImport]
[Guid("00021401-0000-0000-C000-000000000046")]
internal class ShellLink {}

[ComImport]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
[Guid("000214F9-0000-0000-C000-000000000046")]
internal interface IShellLinkW
{
    void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cchMaxPath, out IntPtr pfd, uint fFlags);
    void GetIDList(out IntPtr ppidl);
    void SetIDList(IntPtr pidl);
    void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cchMaxName);
    void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
    void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cchMaxPath);
    void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
    void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cchMaxPath);
    void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
    void GetHotkey(out short pwHotkey);
    void SetHotkey(short wHotkey);
    void GetShowCmd(out int piShowCmd);
    void SetShowCmd(int iShowCmd);
    void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cchIconPath, out int piIcon);
    void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
    void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
    void Resolve(IntPtr hwnd, uint fFlags);
    void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
}

public static class NativeShortcutHelper
{
    public static void CreateShortcut(string shortcutPath, string targetPath, string arguments, string workingDirectory, string description, string iconPath, int iconIndex)
    {
        IShellLinkW link = (IShellLinkW)new ShellLink();
        link.SetPath(targetPath);
        if (!string.IsNullOrEmpty(arguments)) link.SetArguments(arguments);
        if (!string.IsNullOrEmpty(workingDirectory)) link.SetWorkingDirectory(workingDirectory);
        if (!string.IsNullOrEmpty(description)) link.SetDescription(description);
        if (!string.IsNullOrEmpty(iconPath)) link.SetIconLocation(iconPath, iconIndex);

        IPersistFile file = (IPersistFile)link;
        file.Save(shortcutPath, true);
    }
}
'@

function Write-Header {
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "                Google Chrome - One-Click Portable Setup                        " -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "  * Portable install | Isolated user data | Bing default | Chinese UI            " -ForegroundColor Gray
    Write-Host ""
}

function Find-LocalChrome {
    $targetExe = Join-Path $script:ChromeBinDir 'chrome.exe'
    if (Test-Path -LiteralPath $targetExe -PathType Leaf) {
        return $targetExe
    }
    return $null
}

function Find-System7z {
    $bundledCandidates = @(
        (Join-Path $script:AppDir 'Tools\7za.exe'),
        (Join-Path $script:AppDir 'Tools\7z.exe')
    )
    foreach ($b in $bundledCandidates) {
        if (Test-Path -LiteralPath $b -PathType Leaf) { return $b }
    }

    $sysPaths = @(
        (Join-Path $env:ProgramFiles '7-Zip\7za.exe'),
        (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
        (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7za.exe'),
        (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe')
    )
    foreach ($p in $sysPaths) {
        if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) { return $p }
    }
    $cmd = Get-Command '7z.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Download-FileWithProgress {
    param(
        [string]$Url,
        [string]$DestinationPath
    )

    Write-Host "[*] Downloading official Google Chrome installer..." -ForegroundColor Cyan
    Write-Host "    Source: $Url" -ForegroundColor Gray
    Write-Host "    Target: $DestinationPath" -ForegroundColor Gray

    $parent = Split-Path -Parent $DestinationPath
    if (-not (Test-Path $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }

    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = "GET"
    $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    $req.Timeout = 60000

    $resp = $req.GetResponse()
    $totalBytes = $resp.ContentLength
    $stream = $resp.GetResponseStream()

    $fileStream = [System.IO.File]::Create($DestinationPath)
    $buffer = New-Object byte[] 65536
    $readTotal = 0
    $lastReport = [DateTime]::MinValue

    try {
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $read)
            $readTotal += $read

            $now = [DateTime]::Now
            if (($now - $lastReport).TotalMilliseconds -ge 300 -or $readTotal -eq $totalBytes) {
                $lastReport = $now
                if ($totalBytes -gt 0) {
                    $pct = [Math]::Round(($readTotal / $totalBytes) * 100, 1)
                    $mbRead = [Math]::Round($readTotal / 1MB, 2)
                    $mbTotal = [Math]::Round($totalBytes / 1MB, 2)
                    Write-Progress -Activity "Downloading Google Chrome" -Status "$pct% ($mbRead MB / $mbTotal MB)" -PercentComplete $pct
                } else {
                    $mbRead = [Math]::Round($readTotal / 1MB, 2)
                    Write-Progress -Activity "Downloading Google Chrome" -Status "$mbRead MB downloaded" -PercentComplete -1
                }
            }
        }
    }
    finally {
        Write-Progress -Activity "Downloading Google Chrome" -Completed
        $fileStream.Close()
        $stream.Close()
        $resp.Close()
    }

    $finalSize = (Get-Item $DestinationPath).Length
    Write-Host "[+] Download complete! Size: $([Math]::Round($finalSize / 1MB, 2)) MB" -ForegroundColor Green
}

function Verify-GoogleSignature {
    param([string]$FilePath)

    Write-Host "[*] Verifying Authenticode digital signature..." -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "File does not exist: $FilePath"
    }

    $sig = Get-AuthenticodeSignature -LiteralPath $FilePath
    if ($sig.Status -ne 'Valid') {
        throw "Invalid or broken digital signature. Status: $($sig.Status)"
    }

    if ($sig.SignerCertificate.Subject -notmatch 'Google LLC|Google Inc') {
        throw "Signer is not Google LLC. Subject: $($sig.SignerCertificate.Subject)"
    }

    Write-Host "[+] Signature OK: $($sig.SignerCertificate.Subject)" -ForegroundColor Green
}

function Extract-ChromeLocally {
    param([string]$InstallerPath, [string]$TargetDir)

    Write-Host "[*] Extracting official Chrome into local portable directory..." -ForegroundColor Cyan
    if (-not (Test-Path $TargetDir)) { New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null }

    $sevenZip = Find-System7z
    if (-not $sevenZip) {
        throw "Extraction tool (7za.exe / 7z.exe) not found in App\Tools\"
    }

    $tempWork = Join-Path ([System.IO.Path]::GetTempPath()) ("ChromeUnpack_" + [Guid]::NewGuid().ToString("N"))
    New-Item -Path $tempWork -ItemType Directory -Force | Out-Null

    try {
        # ---- Stage 1: Unpack outer PE installer ----
        Write-Host "  - Stage 1: Unpacking installer..." -ForegroundColor Gray
        $l1Dir = Join-Path $tempWork "L1"
        New-Item -Path $l1Dir -ItemType Directory -Force | Out-Null
        & $sevenZip x -y "-o$l1Dir" "$InstallerPath" 2>&1 | Out-Null

        $foundChromeDir = $null
        $chromeExe = Get-ChildItem -Path $l1Dir -Filter 'chrome.exe' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($chromeExe) {
            $foundChromeDir = $chromeExe.DirectoryName
        } else {
            # ---- Stage 2: Find and extract .7z archive (updater.7z or chrome.7z) ----
            Write-Host "  - Stage 2: Unpacking inner archive..." -ForegroundColor Gray
            $l1_7z = Get-ChildItem -Path $l1Dir -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -eq '.7z' } |
                Sort-Object Length -Descending |
                Select-Object -First 1

            if (-not $l1_7z) {
                throw "Could not find .7z archive inside the installer package."
            }

            $l2Dir = Join-Path $tempWork "L2"
            New-Item -Path $l2Dir -ItemType Directory -Force | Out-Null
            & $sevenZip x -y "-o$l2Dir" "$($l1_7z.FullName)" 2>&1 | Out-Null

            $chromeExe = Get-ChildItem -Path $l2Dir -Filter 'chrome.exe' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($chromeExe) {
                $foundChromeDir = $chromeExe.DirectoryName
            } else {
                # ---- Stage 3: Find chrome_installer.exe ----
                Write-Host "  - Stage 3: Unpacking chrome installer..." -ForegroundColor Gray
                $l2_exe = Get-ChildItem -Path $l2Dir -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Extension -eq '.exe' -and $_.Name -match 'chrome_installer' } |
                    Sort-Object Length -Descending |
                    Select-Object -First 1

                if (-not $l2_exe) {
                    $l2_exe = Get-ChildItem -Path $l2Dir -Recurse -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.Extension -eq '.exe' -and $_.Name -notmatch 'uninstall|setup' } |
                        Sort-Object Length -Descending |
                        Select-Object -First 1
                }

                if (-not $l2_exe) {
                    throw "Could not find chrome_installer.exe in unpacked files."
                }

                $l3Dir = Join-Path $tempWork "L3"
                New-Item -Path $l3Dir -ItemType Directory -Force | Out-Null
                & $sevenZip x -y "-o$l3Dir" "$($l2_exe.FullName)" 2>&1 | Out-Null

                $chromeExe = Get-ChildItem -Path $l3Dir -Filter 'chrome.exe' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($chromeExe) {
                    $foundChromeDir = $chromeExe.DirectoryName
                } else {
                    # ---- Stage 4: Find and extract chrome.7z ----
                    Write-Host "  - Stage 4: Unpacking chrome.7z..." -ForegroundColor Gray
                    $l3_7z = Get-ChildItem -Path $l3Dir -Recurse -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.Extension -eq '.7z' } |
                        Sort-Object Length -Descending |
                        Select-Object -First 1

                    if (-not $l3_7z) {
                        throw "Could not find chrome.7z in chrome installer."
                    }

                    $l4Dir = Join-Path $tempWork "L4"
                    New-Item -Path $l4Dir -ItemType Directory -Force | Out-Null
                    & $sevenZip x -y "-o$l4Dir" "$($l3_7z.FullName)" 2>&1 | Out-Null

                    $chromeExe = Get-ChildItem -Path $l4Dir -Filter 'chrome.exe' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($chromeExe) {
                        $foundChromeDir = $chromeExe.DirectoryName
                    } else {
                        throw "Chrome extraction failed: chrome.exe not found after 4 unpack stages."
                    }
                }
            }
        }

        Write-Host "  - Stage final: Deploying Chrome binary files to App\Chrome-bin..." -ForegroundColor Gray
        Get-ChildItem -Path $TargetDir -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "$foundChromeDir\*" -Destination $TargetDir -Recurse -Force
    }
    finally {
        # 清理临时工作目录与下载的安装包（自动删除安装包）
        Remove-Item -Path $tempWork -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $InstallerPath) {
            Remove-Item -LiteralPath $InstallerPath -Force -ErrorAction SilentlyContinue
            Write-Host "[+] Temporary installer package deleted automatically." -ForegroundColor Gray
        }
    }

    $finalChrome = Join-Path $TargetDir 'chrome.exe'
    if (-not (Test-Path -LiteralPath $finalChrome -PathType Leaf)) {
        throw "Chrome extraction failed: chrome.exe not found in '$TargetDir'."
    }
    return $finalChrome
}

function Configure-ChromeDefaults {
    param([string]$ChromePath)

    Write-Host "[*] Configuring default preferences (Bing search, Chinese UI, Home button, disabled Google telemetry)..." -ForegroundColor Cyan

    $binDir = Split-Path -Parent $ChromePath
    $defaultProfileDir = Join-Path $script:UserDataDir 'Default'
    if (-not (Test-Path $defaultProfileDir)) { New-Item -Path $defaultProfileDir -ItemType Directory -Force | Out-Null }

    # 1. 建立 First Run 标记，跳过首次启动欢迎向导与同步提示
    $firstRunMarker = Join-Path $script:UserDataDir 'First Run'
    if (-not (Test-Path $firstRunMarker)) {
        [System.IO.File]::WriteAllText($firstRunMarker, "")
    }

    # 2. 默认搜索引擎配置 (Bing 必应)
    $bingData = @{
        keyword = "bing.com"
        short_name = "Microsoft Bing"
        url = "https://www.bing.com/search?q={searchTerms}"
        suggestions_url = "https://www.bing.com/AS/Suggestions?qry={searchTerms}&cvid={cookieValue}"
        favicon_url = "https://www.bing.com/favicon.ico"
        created_by_policy = $false
        enforced_by_policy = $false
        id = "1"
        is_active = 1
        safe_for_autoreplace = $true
        date_created = "13300000000000000"
        last_modified = "13300000000000000"
    }

    # 3. Default\Preferences 配置（使用 UTF-8 无 BOM）
    $preferencesObj = @{
        profile = @{
            name = "Default"
            default_content_setting_values = @{
                geolocation = 2
                notifications = 2
            }
        }
        browser = @{
            has_seen_welcome_page = $true
            check_default_browser = $false
            show_home_button = $true
        }
        homepage = "https://www.bing.com"
        homepage_is_newtabpage = $false
        signin = @{
            allowed = $false
        }
        sync_promo = @{
            user_skipped = $true
            show_on_first_run_allowed = $false
        }
        intl = @{
            accept_languages = "zh-CN,zh,en-US,en"
            selected_languages = "zh-CN,zh"
        }
        translate = @{
            enabled = $false
        }
        safebrowsing = @{
            enabled = $true
            enhanced = $false
        }
        dns_over_https = @{
            mode = "off"
        }
        default_search_provider_data = $bingData
        session = @{
            restore_on_startup = 4
            startup_urls = @("https://www.bing.com")
        }
    }

    $prefsJson = $preferencesObj | ConvertTo-Json -Depth 10

    # 写入 Default\Preferences
    $defaultPrefPath = Join-Path $defaultProfileDir 'Preferences'
    [System.IO.File]::WriteAllText($defaultPrefPath, $prefsJson, $script:Utf8NoBom)

    # 写入 initial_preferences 与 master_preferences 到 Chrome 二进制目录
    $initPrefPath = Join-Path $binDir 'initial_preferences'
    $masterPrefPath = Join-Path $binDir 'master_preferences'
    [System.IO.File]::WriteAllText($initPrefPath, $prefsJson, $script:Utf8NoBom)
    [System.IO.File]::WriteAllText($masterPrefPath, $prefsJson, $script:Utf8NoBom)

    # 4. 写入 Local State (配置全局应用语言为中文 zh-CN，关闭遥测上报)
    $localStateObj = @{
        intl = @{
            app_locale = "zh-CN"
            selected_languages = "zh-CN,zh"
        }
        metrics = @{
            reporting_enabled = $false
        }
        browser = @{
            enabled_labs_experiments = @()
        }
    }
    $localStateJson = $localStateObj | ConvertTo-Json -Depth 10
    $localStatePath = Join-Path $script:UserDataDir 'Local State'
    [System.IO.File]::WriteAllText($localStatePath, $localStateJson, $script:Utf8NoBom)

    Write-Host "[+] Default settings configured successfully (Bing search / zh-CN locale / Home button / optimized network)." -ForegroundColor Green
}

function Create-DesktopAndLocalShortcuts {
    param(
        [string]$ChromePath
    )

    Write-Host "[*] Creating desktop shortcut..." -ForegroundColor Cyan
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop 'Google Chrome.lnk'

    $arguments = "--user-data-dir=`"$script:UserDataDir`" --lang=zh-CN --no-first-run --disable-fre --no-default-browser-check --disable-sync --disable-signin-promo `"https://www.bing.com`""
    $workDir = Split-Path -Parent $ChromePath
    $desc = "Google Chrome (Portable)"

    try {
        [NativeShortcutHelper]::CreateShortcut($shortcutPath, $ChromePath, $arguments, $workDir, $desc, $ChromePath, 0)
        Write-Host "[+] Desktop shortcut created: $shortcutPath" -ForegroundColor Green
    } catch {
        Write-Warning "Shortcut creation warning: $($_.Exception.Message)"
    }
}

# ------------------------------------------------------------------------------
# 主执行流程
# ------------------------------------------------------------------------------
Write-Header

Write-Host "[Step 1/4] Checking for existing local portable Chrome..." -ForegroundColor Yellow
$chromePath = Find-LocalChrome

if ($chromePath -and (-not $ForceReinstall)) {
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($chromePath)
    Write-Host "[+] Local portable Chrome found!" -ForegroundColor Green
    Write-Host "    Path: $chromePath" -ForegroundColor Gray
    Write-Host "    Version: $($versionInfo.ProductVersion)" -ForegroundColor Gray
    Write-Host ""
}
else {
    Write-Host ""
    Write-Host "[Step 2/4] Downloading Google Chrome..." -ForegroundColor Yellow

    $tempInstaller = Join-Path ([System.IO.Path]::GetTempPath()) ("ChromeSetup_" + [Guid]::NewGuid().ToString("N") + ".exe")
    Download-FileWithProgress -Url 'https://dl.google.com/chrome/install/ChromeStandaloneSetup64.exe' -DestinationPath $tempInstaller
    Verify-GoogleSignature -FilePath $tempInstaller

    Write-Host ""
    Write-Host "[Step 3/4] Setting up portable Chrome (App/Chrome-bin)..." -ForegroundColor Yellow
    $chromePath = Extract-ChromeLocally -InstallerPath $tempInstaller -TargetDir $script:ChromeBinDir
    Write-Host "[+] Chrome successfully deployed!" -ForegroundColor Green
    Write-Host "    Executable: $chromePath" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "[Step 4/4] Configuring isolated user data and desktop shortcut..." -ForegroundColor Yellow
Configure-ChromeDefaults -ChromePath $chromePath
Create-DesktopAndLocalShortcuts -ChromePath $chromePath

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "         [OK] Google Chrome Portable setup complete!                            " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  1. Chrome binary : App\Chrome-bin\chrome.exe (official, unmodified)" -ForegroundColor White
Write-Host "  2. User data     : Data\UserData\ (portable, isolated, zero system residue)" -ForegroundColor White
Write-Host "  3. Extensions    : Zero (pure official standard edition)" -ForegroundColor White
Write-Host "  4. Search Engine : Bing (Microsoft Bing)" -ForegroundColor White
Write-Host "  5. Language      : Chinese (zh-CN)" -ForegroundColor White
Write-Host "  6. Launch        : Start-Chrome.bat or desktop shortcut" -ForegroundColor White
Write-Host ""

# 安装结束立即启动一个标签页（Bing 必应首页），无需登录，无需询问
Write-Host "[*] Launching Google Chrome directly with Bing homepage..." -ForegroundColor Green
$launchArgs = "--user-data-dir=`"$script:UserDataDir`" --lang=zh-CN --no-first-run --disable-fre --no-default-browser-check --disable-sync --disable-signin-promo `"https://www.bing.com`""

Start-Process -FilePath $chromePath -ArgumentList $launchArgs
Write-Host "[+] Google Chrome launched." -ForegroundColor Green
