#!/usr/bin/env bash
# ==============================================================================
# Google Chrome Portable for Linux - 启动入口
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/App/launch-chrome.sh" "$@"
