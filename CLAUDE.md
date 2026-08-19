# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **100% pure-script (PowerShell/Batch) Chrome configuration tool**. It downloads official Chrome from Google's CDN (`dl.google.com`), validates its digital signature via `Get-AuthenticodeSignature`, runs the verified Google installer, and launches it with three bundled open-source extensions via `--load-extension`. The package does not contain or distribute a Chrome binary.

## CRITICAL LEGAL COMPLIANCE RULES (PRC Law — DO NOT VIOLATE)

**These are hard constraints. Violating any of them reintroduces serious legal risk under PRC law.**

1. **NO registry writes for extensions** — NEVER write `ExtensionInstallForcelist` or any `Software\Policies\Google\Chrome` or `Software\Google\Chrome\Extensions` registry keys. This constitutes unauthorized system modification and is forbidden.
2. **Only use the verified official installer** — Do not extract, copy, patch, repackage, or distribute Chrome binaries. Download from the official Google endpoint, verify the Google signature, then run the installer.
3. **NO ad-blocking extensions** — NEVER add uBlock Origin, AdGuard, or any ad-blocking extension. Excluded per China's Anti-Unfair Competition Law.
4. **NO VPN/proxy code or permissions** — `proxy` and `vpnProvider` manifest permissions are forbidden. No network tunneling code of any kind.
5. **NO custom .exe binaries** — The release package must contain no executable binaries. Chrome is supplied only by Google's installer at setup time.
6. **NO data collection or telemetry** — All processing is local and offline.

## Architecture

```
GoogleChrome-Setup-Extensions/      ← ROOT (user extracts ZIP here)
├── 一键安装配置.bat                ← ONLY Chinese-named file. Calls App\Setup-Chrome.ps1
├── Start-Chrome.bat                ← Calls App\Launch-Chrome.ps1
├── Generate-Compliance-Report.bat  ← Calls App\Tools\Generate-Compliance-Report.ps1
│
├── App/                            ← All program logic lives here
│   ├── Setup-Chrome.ps1            ← MAIN INSTALLER: downloads, verifies sig, runs Google's installer
│   ├── Launch-Chrome.ps1           ← LAUNCHER: starts chrome.exe with --load-extension + --user-data-dir
│   ├── Config/
│   │   └── extensions.json         ← Extension metadata
│   ├── Extensions/                 ← Three bundled extensions (Violentmonkey, KissTranslator, DarkReader)
│   └── Tools/
│       ├── Verify-Package.ps1      ← Security audit: 0 custom EXEs, forbidden permissions, MV3 check
│       ├── Generate-Compliance-Report.ps1
│       ├── generate_compliance_report.py
│       └── ShortcutHelper.cs       ← C# COM interop for Unicode shortcut creation (compiled at runtime)
│
├── Data/
│   ├── UserData/                   ← Isolated Chrome profile (portable, travels with the folder)
│   └── Compliance_Audit_Log.txt
│
├── Docs/                           ← Legal compliance documents
└── Licenses/                       ← Open-source licenses for bundled extensions
```

## Common Commands

| Task | Command |
|------|---------|
| **Install/configure Chrome** | Double-click `一键安装配置.bat` |
| **Launch Chrome with extensions** | `Start-Chrome.bat` or `powershell -File .\App\Launch-Chrome.ps1` |
| **Generate compliance report** | `Generate-Compliance-Report.bat` |
| **Verify package integrity** | `powershell -File .\App\Tools\Verify-Package.ps1` |
| **Build release ZIP** | `powershell -File .\package_release.ps1` |

### Parameters for App\Setup-Chrome.ps1
- `-ForceReinstall` — Re-download and rerun the verified official Chrome installer
- `-Silent` — Non-interactive (no prompts)
- `-AutoLaunch` — Launch Chrome automatically after setup

## Key Design Decisions

- **Official installation** — `Setup-Chrome.ps1` downloads the official standalone installer, validates its Google signature, then runs it. It never extracts or copies Chrome binaries.
- **`--load-extension` flag** — Extensions loaded via absolute paths; no registry or Chrome Web Store involved.
- **`--user-data-dir`** — Isolated profile at `Data/UserData/`; no conflict with system Chrome.
- **Digital signature validation** — `Get-AuthenticodeSignature` must return `Status = Valid` and `Subject` matching `Google LLC`.
- **Forbidden permissions** — `proxy` and `vpnProvider` in extension manifests trigger `Verify-Package.ps1` failure.

## Note on the root-level Setup-Chrome.ps1

**There is NO `Setup-Chrome.ps1` in the root directory.** The only installer script is `App\Setup-Chrome.ps1`. The entry point is `一键安装配置.bat` which calls `App\Setup-Chrome.ps1`. Do not create a root-level `Setup-Chrome.ps1`.
