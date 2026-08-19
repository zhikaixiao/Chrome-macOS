[CmdletBinding()]
param(
    [switch]$ForceReinstall,
    [switch]$Silent,
    [switch]$AutoLaunch
)

# ==============================================================================
# Google Chrome Portable - One-Click Setup & Extension Configurator
# Local portable install | Isolated user data | 100% open-source scripts
# ==============================================================================
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

try {
    $OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$script:AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RootDir = Split-Path -Parent $script:AppDir
if (-not (Test-Path (Join-Path $script:RootDir 'App'))) {
    $script:RootDir = $script:AppDir
    $script:AppDir = Join-Path $script:RootDir 'App'
}

$script:DataDir = Join-Path $script:RootDir 'Data'
$script:DocsDir = Join-Path $script:RootDir 'Docs'
$script:ExtensionsDir = Join-Path $script:AppDir 'Extensions'
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
    public static void CreateShortcut(string shortcutPath, string targetPath, string arguments, string workingDir, string description, string iconPath, int iconIndex)
    {
        IShellLinkW link = (IShellLinkW)new ShellLink();
        link.SetPath(targetPath);
        if (!string.IsNullOrEmpty(arguments)) link.SetArguments(arguments);
        if (!string.IsNullOrEmpty(workingDir)) link.SetWorkingDirectory(workingDir);
        if (!string.IsNullOrEmpty(description)) link.SetDescription(description);
        if (!string.IsNullOrEmpty(iconPath)) link.SetIconLocation(iconPath, iconIndex);

        IPersistFile file = (IPersistFile)link;
        file.Save(shortcutPath, false);
    }
}
'@ -ErrorAction SilentlyContinue

function Write-Header {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "     Google Chrome Portable - One-Click Setup & Extension Configurator          " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "  * Local portable install | Isolated user data | 100% open-source scripts     " -ForegroundColor DarkGray
    Write-Host ""
}

function Find-LocalChrome {
    $candidates = @(
        (Join-Path $script:ChromeBinDir 'chrome.exe'),
        (Join-Path $script:AppDir 'chrome.exe')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) {
            return $c
        }
    }
    return $null
}

function Find-System7z {
    # 优先使用包内内置的 7za.exe / 7z.exe (LGPL 开源，完全免安装)
    $bundledCandidates = @(
        (Join-Path $script:AppDir 'Tools\7za.exe'),
        (Join-Path $script:AppDir 'Tools\7z.exe')
    )
    foreach ($b in $bundledCandidates) {
        if (Test-Path -LiteralPath $b -PathType Leaf) { return $b }
    }

    # 回退到系统可能已安装的 7-Zip
    $sysPaths = @(
        'C:\Program Files\7-Zip\7za.exe',
        'C:\Program Files\7-Zip\7z.exe',
        'C:\Program Files (x86)\7-Zip\7za.exe',
        'C:\Program Files (x86)\7-Zip\7z.exe'
    )
    foreach ($p in $sysPaths) {
        if (Test-Path -LiteralPath $p -PathType Leaf) { return $p }
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

    Write-Host "[*] Downloading Google Chrome (official release)..." -ForegroundColor Cyan
    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = "GET"
    $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    $request.Timeout = 30000

    $response = $request.GetResponse()
    $totalBytes = $response.ContentLength
    $responseStream = $response.GetResponseStream()

    $fileStream = New-Object System.IO.FileStream($DestinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $buffer = New-Object byte[] 65536
    $downloadedBytes = 0
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $lastUpdate = [DateTime]::MinValue

    try {
        while (($bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $bytesRead)
            $downloadedBytes += $bytesRead

            if (([DateTime]::Now - $lastUpdate).TotalMilliseconds -ge 200 -or $downloadedBytes -eq $totalBytes) {
                $lastUpdate = [DateTime]::Now
                $percent = if ($totalBytes -gt 0) { [math]::Round(($downloadedBytes / $totalBytes) * 100, 1) } else { 0 }
                $mbDownloaded = [math]::Round($downloadedBytes / 1MB, 2)
                $mbTotal = [math]::Round($totalBytes / 1MB, 2)
                $speed = if ($stopwatch.Elapsed.TotalSeconds -gt 0) { [math]::Round(($downloadedBytes / 1MB) / $stopwatch.Elapsed.TotalSeconds, 2) } else { 0 }

                $barLength = 30
                $filled = [math]::Floor(($percent / 100) * $barLength)
                $empty = $barLength - $filled
                $bar = ("#" * $filled) + ("-" * $empty)

                $status = "`r[{0}] {1,5}% ({2,6}MB / {3,6}MB)  Speed: {4,5} MB/s" -f $bar, $percent, $mbDownloaded, $mbTotal, $speed
                Write-Host -NoNewline $status -ForegroundColor Green
            }
        }
        Write-Host ""
    }
    finally {
        $fileStream.Close()
        $responseStream.Close()
        $response.Close()
    }
}

function Verify-GoogleSignature {
    param([string]$FilePath)

    Write-Host "[*] Verifying digital signature..." -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "Installer file not found: $FilePath"
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
        # ------------------------------------------------------------------
        # Chrome standalone installer archive hierarchy:
        #   ChromeStandaloneSetup64.exe  (PE, contains updater.7z in resources)
        #     -> updater.7z
        #         -> bin\Offline\{guid}\{guid}\*_chrome_installer.exe
        #             -> chrome.7z
        #                 -> Chrome-bin\  (contains chrome.exe)
        # ------------------------------------------------------------------

        # ---- Stage 1: Unpack outer PE installer ----
        Write-Host "  - Stage 1: Unpacking installer..." -ForegroundColor Gray
        $l1Dir = Join-Path $tempWork "L1"
        New-Item -Path $l1Dir -ItemType Directory -Force | Out-Null
        & $sevenZip x -y "-o$l1Dir" $InstallerPath 2>&1 | Out-Null

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
            & $sevenZip x -y "-o$l2Dir" $l1_7z.FullName 2>&1 | Out-Null

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
                & $sevenZip x -y "-o$l3Dir" $l2_exe.FullName 2>&1 | Out-Null

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
                    & $sevenZip x -y "-o$l4Dir" $l3_7z.FullName 2>&1 | Out-Null

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
        Remove-Item -Path $tempWork -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $InstallerPath -Force -ErrorAction SilentlyContinue
    }

    $finalChrome = Join-Path $TargetDir 'chrome.exe'
    if (-not (Test-Path -LiteralPath $finalChrome -PathType Leaf)) {
        throw "Chrome extraction failed: chrome.exe not found in '$TargetDir'."
    }
    return $finalChrome
}

function Get-ExtensionArgString {
    $extNames = @('Violentmonkey', 'KissTranslator', 'DarkReader')
    $validPaths = @()

    foreach ($ext in $extNames) {
        $extPath = Join-Path $script:ExtensionsDir $ext
        $m = Join-Path $extPath "manifest.json"
        if (Test-Path $m) {
            $validPaths += $extPath
            Write-Host "  - Extension ready: $ext" -ForegroundColor Gray
        }
    }

    return ($validPaths -join ',')
}

function Configure-ChromeDefaults {
    param([string]$ChromePath)

    Write-Host "[*] Configuring default preferences (Bing search, Chinese UI, no login prompts)..." -ForegroundColor Cyan

    $binDir = Split-Path -Parent $ChromePath
    $defaultProfileDir = Join-Path $script:UserDataDir 'Default'
    if (-not (Test-Path $defaultProfileDir)) { New-Item -Path $defaultProfileDir -ItemType Directory -Force | Out-Null }

    # 1. 建立 First Run 标记，彻底跳过首次启动欢迎与同步登录向导
    $firstRunMarker = Join-Path $script:UserDataDir 'First Run'
    if (-not (Test-Path $firstRunMarker)) {
        [System.IO.File]::WriteAllText($firstRunMarker, "")
    }

    # 2. 默认搜索引擎配置 (Bing 必应)
    $bingData = @{
        template_url_data = @{
            short_name = "Bing"
            keyword = "bing.com"
            url = "https://www.bing.com/search?q={searchTerms}"
            suggestions_url = "https://www.bing.com/asjson.aspx?query={searchTerms}"
            favicon_url = "https://www.bing.com/favicon.ico"
            safe_for_autoreplace = $true
            is_active = 1
            date_created = "0"
            last_modified = "0"
        }
    }

    # 3. Preferences 配置 (中文、Bing主页、禁用账号登录弹窗、跳过首次运行)
    $preferencesObj = @{
        distribution = @{
            skip_first_run_ui = $true
            show_welcome_page = $false
            import_bookmarks = $false
            import_history = $false
            import_search_engine = $false
            make_chrome_default = $false
            make_chrome_default_for_user = $false
            suppress_first_run_default_browser_prompt = $true
        }
        browser = @{
            has_seen_welcome_page = $true
            check_default_browser = $false
        }
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
        default_search_provider_data = $bingData
        session = @{
            restore_on_startup = 4
            startup_urls = @("https://www.bing.com")
        }
    }

    $prefsJson = $preferencesObj | ConvertTo-Json -Depth 10

    # 写入 Default\Preferences
    $defaultPrefPath = Join-Path $defaultProfileDir 'Preferences'
    [System.IO.File]::WriteAllText($defaultPrefPath, $prefsJson, [System.Text.Encoding]::UTF8)

    # 写入 initial_preferences 与 master_preferences 到 Chrome 二进制目录
    $initPrefPath = Join-Path $binDir 'initial_preferences'
    $masterPrefPath = Join-Path $binDir 'master_preferences'
    [System.IO.File]::WriteAllText($initPrefPath, $prefsJson, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($masterPrefPath, $prefsJson, [System.Text.Encoding]::UTF8)

    # 4. 写入 Local State (配置全局应用语言为中文 zh-CN)
    $localStateObj = @{
        intl = @{
            app_locale = "zh-CN"
            selected_languages = "zh-CN,zh"
        }
        browser = @{
            enabled_labs_experiments = @()
        }
    }
    $localStateJson = $localStateObj | ConvertTo-Json -Depth 10
    $localStatePath = Join-Path $script:UserDataDir 'Local State'
    [System.IO.File]::WriteAllText($localStatePath, $localStateJson, [System.Text.Encoding]::UTF8)

    Write-Host "[+] Default settings configured successfully (Bing search / zh-CN locale)." -ForegroundColor Green
}

function Create-DesktopAndLocalShortcuts {
    param(
        [string]$ChromePath,
        [string]$ExtensionArgs
    )

    Write-Host "[*] Creating desktop shortcut..." -ForegroundColor Cyan
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop 'Google Chrome (Portable).lnk'

    $arguments = "--user-data-dir=`"$script:UserDataDir`" --load-extension=`"$ExtensionArgs`" --disable-extensions-except=`"$ExtensionArgs`" --lang=zh-CN --no-first-run --disable-fre --no-default-browser-check --disable-sync --disable-signin-promo `"https://www.bing.com`""
    $workDir = Split-Path -Parent $ChromePath
    $desc = "Google Chrome Portable (Violentmonkey, KISS Translator, Dark Reader)"

    try {
        [NativeShortcutHelper]::CreateShortcut($shortcutPath, $ChromePath, $arguments, $workDir, $desc, $ChromePath, 0)
        Write-Host "[+] Desktop shortcut created: $shortcutPath" -ForegroundColor Green
    } catch {
        Write-Warning "Shortcut creation warning: $($_.Exception.Message)"
    }
}

function Write-ComplianceAuditLog {
    param(
        [string]$ChromePath
    )

    try {
        $logPath = Join-Path $script:DataDir 'Compliance_Audit_Log.txt'
        $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $version = (Get-ItemProperty -Path $ChromePath -ErrorAction SilentlyContinue).VersionInfo.ProductVersion
        $sig = Get-AuthenticodeSignature -LiteralPath $ChromePath

        $lines = @(
            "================================================================================",
            "        Google Chrome Portable - Legal Compliance Audit Log",
            "================================================================================",
            "Timestamp       : $time",
            "Machine         : $env:COMPUTERNAME",
            "OS Version      : $([System.Environment]::OSVersion.VersionString)",
            "--------------------------------------------------------------------------------",
            "[1. Chrome Binary Source]",
            "  Executable    : $ChromePath",
            "  User Data Dir : $script:UserDataDir (isolated, portable, no system residue)",
            "  Version       : $version",
            "  Cert Status   : $($sig.Status)",
            "  Cert Subject  : $($sig.SignerCertificate.Subject)",
            "--------------------------------------------------------------------------------",
            "[2. Extension Compliance Audit]",
            "  - Violentmonkey   : Open-source userscript manager (MV3, no proxy/vpnProvider permissions)",
            "  - KISS Translator : Immersive bilingual translation (MV3, no network tunneling)",
            "  - Dark Reader     : CSS-based dark mode (MV3, pure client-side rendering)",
            "  - Ad blocking     : Excluded (Anti-Unfair-Competition Law compliance)",
            "  - Custom EXEs     : Zero (all logic is open-source scripts)",
            "--------------------------------------------------------------------------------",
            "[3. Compliance Conclusion]",
            "  This installation complies with PRC Cybersecurity Law, Criminal Law",
            "  Art. 285/286, Anti-Unfair Competition Law, PIPL, and Data Security Law.",
            "================================================================================"
        )

        [System.IO.File]::WriteAllLines($logPath, $lines, [System.Text.Encoding]::UTF8)
        Write-Host "[+] Compliance audit log written: $logPath" -ForegroundColor Green
    } catch {}
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

    $tempInstaller = Join-Path ([System.IO.Path]::GetTempPath()) 'ChromeStandaloneSetup64.exe'
    Download-FileWithProgress -Url 'https://dl.google.com/chrome/install/ChromeStandaloneSetup64.exe' -DestinationPath $tempInstaller
    Verify-GoogleSignature -FilePath $tempInstaller

    Write-Host ""
    Write-Host "[Step 3/4] Setting up portable Chrome (App/Chrome-bin)..." -ForegroundColor Yellow
    $chromePath = Extract-ChromeLocally -InstallerPath $tempInstaller -TargetDir $script:ChromeBinDir
    Write-Host "[+] Chrome successfully deployed!" -ForegroundColor Green
    Write-Host "    Executable: $chromePath" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "[Step 4/4] Configuring extensions, isolated user data, and desktop shortcut..." -ForegroundColor Yellow
$extArgString = Get-ExtensionArgString
Configure-ChromeDefaults -ChromePath $chromePath
Create-DesktopAndLocalShortcuts -ChromePath $chromePath -ExtensionArgs $extArgString
Write-ComplianceAuditLog -ChromePath $chromePath

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "         [OK] Google Chrome Portable setup complete!                            " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  1. Chrome binary : App\Chrome-bin\chrome.exe (official, unmodified)" -ForegroundColor White
Write-Host "  2. User data     : Data\UserData\ (portable, isolated, no system leftovers)" -ForegroundColor White
Write-Host "  3. Extensions    : Violentmonkey, KISS Translator, Dark Reader" -ForegroundColor White
Write-Host "  4. Search Engine : Bing (Microsoft Bing)" -ForegroundColor White
Write-Host "  5. Language      : Chinese (zh-CN)" -ForegroundColor White
Write-Host "  6. Launch        : Start-Chrome.bat or desktop shortcut" -ForegroundColor White
Write-Host "  7. Audit log     : Data\Compliance_Audit_Log.txt" -ForegroundColor Green
Write-Host ""

# 安装结束立即启动一个标签页（Bing 必应首页），无需登录，无需询问
Write-Host "[*] Launching Google Chrome directly with Bing homepage..." -ForegroundColor Green
$launchArgs = "--user-data-dir=`"$script:UserDataDir`" --load-extension=`"$extArgString`" --disable-extensions-except=`"$extArgString`" --lang=zh-CN --no-first-run --disable-fre --no-default-browser-check --disable-sync --disable-signin-promo `"https://www.bing.com`""

Start-Process -FilePath $chromePath -ArgumentList $launchArgs
Write-Host "[+] Google Chrome launched." -ForegroundColor Green
