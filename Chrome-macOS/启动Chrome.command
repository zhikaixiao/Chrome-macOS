#!/usr/bin/env bash
# macOS 双击启动入口
cd "$(dirname "$0")"
chmod +x ./App/launch-chrome.sh 2>/dev/null || true
./App/launch-chrome.sh "$@"
