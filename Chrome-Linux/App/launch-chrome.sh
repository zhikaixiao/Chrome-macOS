#!/usr/bin/env bash
# ==============================================================================
# Google Chrome Portable Launcher for Linux
# Launches Chrome with isolated user data and preloaded verified extensions
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$ROOT_DIR/App"
DATA_DIR="$ROOT_DIR/Data"
USER_DATA_DIR="$DATA_DIR/UserData"
CHROME_BIN_DIR="$APP_DIR/Chrome-bin"
CHROME_BIN="$CHROME_BIN_DIR/google-chrome"

if [ ! -f "$CHROME_BIN" ]; then
    CHROME_BIN="$CHROME_BIN_DIR/chrome"
fi

# 若尚未安装，自动引导执行一键安装配置
if [ ! -f "$CHROME_BIN" ]; then
    echo "未检测到便携版 Google Chrome，正在为您自动拉取官方正版并完成配置..."
    if [ -f "$ROOT_DIR/Installer/setup-chrome.sh" ]; then
        "$ROOT_DIR/Installer/setup-chrome.sh"
    fi
    CHROME_BIN="$CHROME_BIN_DIR/google-chrome"
    [ -f "$CHROME_BIN" ] || CHROME_BIN="$CHROME_BIN_DIR/chrome"
fi

mkdir -p "$USER_DATA_DIR"

# 扫描并组装扩展路径
EXTENSIONS_DIR="$APP_DIR/Extensions"
EXT_LIST=()

if [ -d "$EXTENSIONS_DIR" ]; then
    for ext in "$EXTENSIONS_DIR"/*; do
        if [ -d "$ext" ] && [ -f "$ext/manifest.json" ]; then
            EXT_LIST+=("$ext")
        fi
    done
fi

LOAD_EXT_ARG=""
if [ ${#EXT_LIST[@]} -gt 0 ]; then
    IFS=','
    EXT_PATHS="${EXT_LIST[*]}"
    unset IFS
    LOAD_EXT_ARG="--load-extension=$EXT_PATHS"
fi

# 容器、CI 或 root 环境下的沙盒兼容参数
EXTRA_ARGS=()
if [ "$(id -u)" -eq 0 ] || [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
    EXTRA_ARGS+=("--no-sandbox" "--disable-gpu" "--disable-dev-shm-usage")
fi

export LD_LIBRARY_PATH="$CHROME_BIN_DIR:$LD_LIBRARY_PATH"

# 若为版本探测模式，直接输出版本
if [[ "$*" == *"--version"* ]]; then
    "$CHROME_BIN" "${EXTRA_ARGS[@]}" --version
    exit 0
fi

# 启动便携版 Google Chrome
nohup "$CHROME_BIN" \
    --user-data-dir="$USER_DATA_DIR" \
    $LOAD_EXT_ARG \
    --no-first-run \
    --no-default-browser-check \
    "${EXTRA_ARGS[@]}" \
    "$@" >/dev/null 2>&1 &
