#!/usr/bin/env bash
# macOS 双击可执行入口
cd "$(dirname "$0")"
chmod +x ./App/setup-chrome.sh ./App/launch-chrome.sh ./App/Tools/*.sh 2>/dev/null || true
./App/setup-chrome.sh "$@"
