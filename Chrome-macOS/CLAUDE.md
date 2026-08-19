# CLAUDE.md (macOS Edition)

This file provides guidance to Claude Code (claude.ai/code) when working with code in this macOS repository.

## Project Overview

This is a **100% pure-script (Bash / .command) Chrome configuration tool for macOS**. It downloads official Universal Chrome DMG from Google's static CDN (`dl.google.com`), validates its digital signature via Apple `codesign` (`TeamIdentifier=EQHXZ8M8AV`, Google LLC), extracts it, and launches it with three bundled open-source extensions via `--load-extension`. The package does not contain or distribute a Chrome binary.

## CRITICAL LEGAL COMPLIANCE RULES (PRC Law — DO NOT VIOLATE)

**These are hard constraints. Violating any of them reintroduces serious legal risk under PRC law.**

1. **NO system plist tampering** — NEVER force-write system managed policies or default browser locks without user interaction.
2. **Only use verified official DMG** — Download from official `dl.google.com`, verify Google LLC signature (`EQHXZ8M8AV`), then extract.
3. **NO ad-blocking extensions** — NEVER add uBlock Origin, AdGuard, or any ad-blocking extension. Excluded per China's Anti-Unfair Competition Law.
4. **NO VPN/proxy code or permissions** — `proxy` and `vpnProvider` manifest permissions are strictly forbidden. No network tunneling code of any kind.
5. **NO custom Mach-O executable binaries** — The release package must contain no compiled binaries. Chrome is supplied only by Google's official DMG at setup time.
6. **NO data collection or telemetry** — All processing is local and offline.
