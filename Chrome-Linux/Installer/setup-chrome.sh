#!/usr/bin/env bash
# ==============================================================================
# Google Chrome Portable for Linux - One-Click Setup & Configurator
# Dual-Engine: Official DEB (Primary) + Official RPM (Auto-Fallback)
# 100% Pure-Script | Non-Root Extraction | Portable Data Isolation
# ==============================================================================

set -eo pipefail

# 颜色与样式
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 目录解析 (从 Installer/ 解析到根目录)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$ROOT_DIR/App"
DATA_DIR="$ROOT_DIR/Data"
USER_DATA_DIR="$DATA_DIR/UserData"
CHROME_BIN_DIR="$APP_DIR/Chrome-bin"
LOG_FILE="$DATA_DIR/Compliance_Audit_Log.txt"

# Google 官方 Linux 下载源 (国内 100% 直连无阻断)
GOOGLE_CHROME_DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
GOOGLE_CHROME_RPM_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"

# 参数处理
FORCE_REINSTALL=false
SILENT=false
AUTO_LAUNCH=false

for arg in "$@"; do
    case $arg in
        --force|-f)
            FORCE_REINSTALL=true
            ;;
        --silent|-s)
            SILENT=true
            ;;
        --auto-launch|-a)
            AUTO_LAUNCH=true
            ;;
    esac
done

mkdir -p "$DATA_DIR" "$USER_DATA_DIR" "$CHROME_BIN_DIR"

print_header() {
    clear 2>/dev/null || true
    echo -e "${CYAN}================================================================================${NC}"
    echo -e "${YELLOW}${BOLD}     Google Chrome 便携版 (Linux) - 一键安装配置与免 Root 提取工具            ${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    echo -e "${BLUE}  * 本地便携安装 | 独立隔离用户数据 | 免 sudo/免 root 解包 | 双引擎容灾保障       ${NC}"
    echo ""
}

log_message() {
    local msg="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date)
    echo "[$timestamp] $msg" >> "$LOG_FILE" 2>/dev/null || true
}

check_dependencies() {
    echo -e "${BLUE}[1/4] 检查 Linux 系统环境与必要组件...${NC}"
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        echo -e "${RED}❌ 缺少网络下载工具 (curl 或 wget)${NC}"
        exit 1
    fi
    echo -e "${GREEN}  ✓ Linux 系统环境就绪 ($(uname -m 2>/dev/null || echo 'x86_64'))${NC}"
}

download_file() {
    local url="$1"
    local dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -L --retry 3 --progress-bar "$url" -o "$dest"
    else
        wget -q --show-progress "$url" -O "$dest"
    fi
}

# 引擎 1: Google 官方 DEB 包免 Root 提取 (Ubuntu / Debian / UOS / 统信 / 麒麟 Kylin / Deepin)
try_install_via_deb() {
    echo -e "${BLUE}[2/4] [引擎 1/2] 正在从 Google 官方直连下载 Linux 64位 DEB 安装包...${NC}"
    local temp_deb="$DATA_DIR/google-chrome-stable.deb"
    local extract_dir="$DATA_DIR/deb_extract_temp_$$"
    rm -f "$temp_deb"
    rm -rf "$extract_dir"

    if ! download_file "$GOOGLE_CHROME_DEB_URL" "$temp_deb"; then
        echo -e "${YELLOW}  ! DEB 下载失败，准备切换备用引擎...${NC}"
        return 1
    fi

    echo -e "${BLUE}[3/4] 正在执行免 Root 深度解包...${NC}"
    mkdir -p "$extract_dir"

    local extract_success=false
    if command -v dpkg-deb >/dev/null 2>&1; then
        dpkg-deb -x "$temp_deb" "$extract_dir" && extract_success=true
    elif command -v ar >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
        (cd "$extract_dir" && ar -x "$temp_deb" && tar -xf data.tar.*) && extract_success=true
    fi

    local chrome_src=""
    if [ -d "$extract_dir/opt/google/chrome" ]; then
        chrome_src="$extract_dir/opt/google/chrome"
    fi

    if [ -z "$chrome_src" ] || [ "$extract_success" = false ]; then
        echo -e "${YELLOW}  ! DEB 解包异常，切换至 RPM 备用引擎...${NC}"
        rm -rf "$temp_deb" "$extract_dir"
        return 1
    fi

    echo -e "${BLUE}[4/4] 部署 Google Chrome 核心程序到便携目录...${NC}"
    rm -rf "$CHROME_BIN_DIR"/*
    cp -R "$chrome_src"/* "$CHROME_BIN_DIR/"
    chmod -R 755 "$CHROME_BIN_DIR" 2>/dev/null || true

    rm -rf "$temp_deb" "$extract_dir"
    return 0
}

# 引擎 2: Google 官方 RPM 包免 Root 提取 (Fedora / CentOS / RHEL / openSUSE)
try_install_via_rpm() {
    echo -e "${YELLOW}[2/4] [引擎 2/2] 启用 Google 官方 RPM 备用提取引擎...${NC}"
    local temp_rpm="$DATA_DIR/google-chrome-stable.rpm"
    local extract_dir="$DATA_DIR/rpm_extract_temp_$$"
    rm -f "$temp_rpm"
    rm -rf "$extract_dir"

    if ! download_file "$GOOGLE_CHROME_RPM_URL" "$temp_rpm"; then
        echo -e "${RED}❌ RPM 下载失败${NC}"
        return 1
    fi

    echo -e "${BLUE}[3/4] 使用 rpm2cpio 免 Root 解包...${NC}"
    mkdir -p "$extract_dir"
    if command -v rpm2cpio >/dev/null 2>&1 && command -v cpio >/dev/null 2>&1; then
        (cd "$extract_dir" && rpm2cpio "$temp_rpm" | cpio -idmv >/dev/null 2>&1)
    fi

    local chrome_src=""
    if [ -d "$extract_dir/opt/google/chrome" ]; then
        chrome_src="$extract_dir/opt/google/chrome"
    fi

    if [ -z "$chrome_src" ]; then
        echo -e "${RED}❌ RPM 解包失败${NC}"
        rm -rf "$temp_rpm" "$extract_dir"
        return 1
    fi

    echo -e "${BLUE}[4/4] 部署 Google Chrome 核心程序到便携目录...${NC}"
    rm -rf "$CHROME_BIN_DIR"/*
    cp -R "$chrome_src"/* "$CHROME_BIN_DIR/"
    chmod -R 755 "$CHROME_BIN_DIR" 2>/dev/null || true

    rm -rf "$temp_rpm" "$extract_dir"
    return 0
}

install_chrome() {
    local target_bin="$CHROME_BIN_DIR/google-chrome"
    [ -f "$target_bin" ] || target_bin="$CHROME_BIN_DIR/chrome"
    
    if [ -f "$target_bin" ] && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "${BLUE}[2/4] 检测到便携版 Google Chrome 已就绪...${NC}"
        echo -e "${GREEN}  ✓ 核心路径: $target_bin${NC}"
        return 0
    fi

    if ! try_install_via_deb; then
        echo -e "${YELLOW}➔ 正在切换至 RPM 备用容灾引擎...${NC}"
        if ! try_install_via_rpm; then
            echo -e "${RED}❌ 下载与解包失败，请检查您的网络连接与系统基础工具！${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}  ✓ Google Chrome Linux 便携版部署完成！${NC}"
}

verify_extensions() {
    local ext_dir="$APP_DIR/Extensions"
    local extensions=("DarkReader" "KissTranslator" "Violentmonkey")
    local found_count=0
    
    for ext in "${extensions[@]}"; do
        if [ -d "$ext_dir/$ext" ]; then
            echo -e "${GREEN}  ✓ 已加载合规开源扩展: $ext${NC}"
            found_count=$((found_count + 1))
        fi
    done

    if [ "$found_count" -eq 0 ]; then
        echo -e "${GREEN}  ✓ 纯净无扩展模式就绪 (原生 Chrome 环境)${NC}"
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}================================================================================${NC}"
    echo -e "${GREEN}${BOLD}                   🎉 Google Chrome Linux 便携版安装配置成功！                  ${NC}"
    echo -e "${GREEN}================================================================================${NC}"
    echo -e "  * 启动入口: 直接运行根目录下的 ${YELLOW}${BOLD}./启动Chrome.sh${NC}"
    echo -e "  * 用户数据: 独立保存在 ${CYAN}$USER_DATA_DIR${NC} (完全隔离、随文件夹移动)"
    echo -e "  * 合规保障: 100% 官方原版核心解包、0 预装二进制分发、0 侵权违规"
    echo -e "${GREEN}================================================================================${NC}"
    echo ""
}

# 执行主流程
print_header
check_dependencies
install_chrome
verify_extensions
print_summary
log_message "Installation and configuration completed successfully on Linux ($(uname -a 2>/dev/null || echo 'unknown'))"

if [ "$AUTO_LAUNCH" = true ]; then
    echo -e "${CYAN}正在为您自动启动 Google Chrome...${NC}"
    "$APP_DIR/launch-chrome.sh" &
fi
