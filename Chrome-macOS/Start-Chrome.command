#!/usr/bin/env bash
cd "$(dirname "$0")"
chmod +x ./App/launch-chrome.sh 2>/dev/null || true
./App/launch-chrome.sh "$@"
