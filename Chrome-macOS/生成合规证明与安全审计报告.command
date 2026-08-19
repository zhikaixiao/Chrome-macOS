#!/usr/bin/env bash
cd "$(dirname "$0")"
chmod +x ./App/Tools/generate-compliance-report.sh 2>/dev/null || true
./App/Tools/generate-compliance-report.sh "$@"
