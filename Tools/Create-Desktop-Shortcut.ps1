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

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not (Test-Path (Join-Path $root 'Extensions'))) {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'Google Chrome (增强版).lnk'

# Find Chrome
$chromePath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chromePath)) {
    $chromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
}
if (-not (Test-Path $chromePath)) {
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
}

if (-not (Test-Path $chromePath)) {
    throw "未在系统中找到 Chrome，请先运行【一键安装配置.bat】进行安装。"
}

$ext1 = Join-Path $root 'Extensions\Violentmonkey'
$ext2 = Join-Path $root 'Extensions\KissTranslator'
$ext3 = Join-Path $root 'Extensions\DarkReader'
$arguments = "--load-extension=`"$ext1,$ext2,$ext3`""
$workDir = Split-Path -Parent $chromePath
$desc = "Google Chrome (官方原生启动，内置 Violentmonkey 暴力猴、KISS 翻译、Dark Reader 护眼)"

[NativeShortcutHelper]::CreateShortcut($shortcutPath, $chromePath, $arguments, $workDir, $desc, $chromePath, 0)

Write-Host "桌面原生快捷方式已创建: $shortcutPath" -ForegroundColor Green
