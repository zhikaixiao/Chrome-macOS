#!/usr/bin/env bash
cd "$(dirname "$0")"
chmod +x ./App/setup-chrome.sh 2>/dev/null || true
./App/setup-chrome.sh "$@"
