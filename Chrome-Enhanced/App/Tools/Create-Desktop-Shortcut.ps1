[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

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

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$appDir = Split-Path -Parent $toolsDir
$rootDir = Split-Path -Parent $appDir
if (-not (Test-Path (Join-Path $rootDir 'App'))) {
    $rootDir = $appDir
    $appDir = Join-Path $rootDir 'App'
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'Google Chrome (Portable).lnk'

# 1. 优先使用便携版 Chrome
$chromePath = Join-Path $appDir 'Chrome-bin\chrome.exe'
if (-not (Test-Path -LiteralPath $chromePath -PathType Leaf)) {
    # 2. 系统 Chrome
    $chromePaths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    $chromePath = $chromePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1

    if (-not $chromePath) {
        $registryPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe'
        )
        foreach ($registryPath in $registryPaths) {
            $candidate = (Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue).'(default)'
            if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $chromePath = $candidate
                break
            }
        }
    }
}

if (-not $chromePath) {
    throw "未找到 Chrome 程序，请先运行【一键安装配置.bat】。"
}

$ext1 = Join-Path $appDir 'Extensions\Violentmonkey'
$ext2 = Join-Path $appDir 'Extensions\KissTranslator'
$ext3 = Join-Path $appDir 'Extensions\DarkReader'
$userDataDir = Join-Path $rootDir 'Data\UserData'
$extArgs = "$ext1,$ext2,$ext3"

$arguments = "--user-data-dir=`"$userDataDir`" --load-extension=`"$extArgs`" --disable-extensions-except=`"$extArgs`" --lang=zh-CN --no-first-run --disable-fre --no-default-browser-check --disable-sync --disable-signin-promo `"https://www.bing.com`""
$workDir = Split-Path -Parent $chromePath
$desc = "Google Chrome Portable (Violentmonkey, KISS Translator, Dark Reader)"

[NativeShortcutHelper]::CreateShortcut($shortcutPath, $chromePath, $arguments, $workDir, $desc, $chromePath, 0)

Write-Host "桌面快捷方式已创建: $shortcutPath" -ForegroundColor Green
