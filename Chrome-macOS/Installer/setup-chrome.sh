#!/usr/bin/env bash
# ==============================================================================
# Google Chrome Portable for macOS - One-Click Setup & Extension Configurator
# Dual-Engine: Universal DMG (Primary) + Enterprise PKG (Auto-Fallback)
# 100% Pure-Script | Apple codesign Verification (Google LLC EQHXZ8M8AV)
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

# Google 官方 Universal 下载源 (国内 100% 直连无阻断)
GOOGLE_CHROME_DMG_URL="https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg"
GOOGLE_CHROME_PKG_URL="https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.pkg"
GOOGLE_TEAM_ID="EQHXZ8M8AV"

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
    echo -e "${YELLOW}${BOLD}     Google Chrome 便携版 (macOS) - 一键安装配置与正版数字验签工具          ${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    echo -e "${BLUE}  * 本地便携安装 | 独立隔离用户数据 | 100% 官方正版数字证书校验 | 双引擎容灾保障     ${NC}"
    echo ""
}

log_message() {
    local msg="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date)
    echo "[$timestamp] $msg" >> "$LOG_FILE" 2>/dev/null || true
}

check_dependencies() {
    echo -e "${BLUE}[1/5] 检查 macOS 系统环境与核心工具...${NC}"
    local missing_tools=()
    for tool in curl codesign ditto; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}❌ 缺少系统核心工具: ${missing_tools[*]}${NC}"
        exit 1
    fi
    echo -e "${GREEN}  ✓ macOS 原生安全组件 (curl, codesign, ditto) 就绪${NC}"
}

verify_app_signature() {
    local target_app="$1"
    echo -e "  正在严格校验 Google LLC (Team ID: ${YELLOW}${GOOGLE_TEAM_ID}${NC}) 数字签名..."
    
    # 深度严格校验代码签名完整性
    if ! codesign --verify --deep --strict --verbose=2 "$target_app" 2>/dev/null; then
        echo -e "${RED}❌ 致命安全拦截: 下载的程序未通过 Apple 代码签名校验，疑似被篡改！${NC}"
        return 1
    fi

    # 比对 Developer ID 和 TeamIdentifier
    local signature_info
    signature_info=$(codesign -dv --verbose=4 "$target_app" 2>&1)
    
    if [[ "$signature_info" != *"$GOOGLE_TEAM_ID"* ]] || [[ "$signature_info" != *"Google LLC"* ]]; then
        echo -e "${RED}❌ 致命安全拦截: 签名开发者 ID 不匹配 (非 Google LLC 官方出品)！${NC}"
        return 1
    fi

    echo -e "${GREEN}  ✓ Google LLC 官方开发者证书验证 100% 通过 (Team ID: $GOOGLE_TEAM_ID)${NC}"
    log_message "Verified Apple Developer ID: Google LLC ($GOOGLE_TEAM_ID) - 100% Authentic"
    return 0
}

# 方案 A: 官方 Universal DMG 镜像挂载引擎 (主引擎)
try_install_via_dmg() {
    echo -e "${BLUE}[2/5] [引擎 1/2] 正在从 Google 官方静态 CDN 下载 Universal DMG 镜像...${NC}"
    local temp_dmg="$DATA_DIR/googlechrome.dmg"
    rm -f "$temp_dmg"
    
    if ! curl -L --retry 3 --progress-bar "$GOOGLE_CHROME_DMG_URL" -o "$temp_dmg"; then
        echo -e "${YELLOW}  ! DMG 下载失败，准备切换备用引擎...${NC}"
        return 1
    fi

    echo -e "${BLUE}[3/5] 挂载 DMG 镜像并提取 Google Chrome.app...${NC}"
    local mount_output
    mount_output=$(hdiutil attach "$temp_dmg" -nobrowse -readonly 2>&1 || true)
    local mount_point
    mount_point=$(echo "$mount_output" | grep -o '/Volumes/.*' | tail -n 1)

    if [ -z "$mount_point" ] || [ ! -d "$mount_point" ]; then
        echo -e "${YELLOW}  ! DMG 挂载受限 ($mount_output)，准备自动切换备用 PKG 引擎...${NC}"
        rm -f "$temp_dmg"
        return 1
    fi

    local source_app="$mount_point/Google Chrome.app"
    if [ ! -d "$source_app" ]; then
        echo -e "${YELLOW}  ! 未在 DMG 中找到应用，切换备用引擎...${NC}"
        hdiutil detach "$mount_point" -force -quiet || true
        rm -f "$temp_dmg"
        return 1
    fi

    if ! verify_app_signature "$source_app"; then
        hdiutil detach "$mount_point" -force -quiet || true
        rm -f "$temp_dmg"
        return 1
    fi

    echo -e "${BLUE}[4/5] 提取并部署 Google Chrome.app 到便携目录...${NC}"
    local target_app="$CHROME_BIN_DIR/Google Chrome.app"
    rm -rf "$target_app"
    ditto "$source_app" "$target_app"

    # 清理
    hdiutil detach "$mount_point" -force -quiet || true
    rm -f "$temp_dmg"
    return 0
}

# 方案 B: 官方 Universal PKG 企业包免挂载解包引擎 (备用容灾引擎)
try_install_via_pkg() {
    echo -e "${YELLOW}[2/5] [引擎 2/2] 启用 Google 官方 Universal PKG 免挂载备用引擎...${NC}"
    local temp_pkg="$DATA_DIR/googlechrome.pkg"
    local extract_dir="$DATA_DIR/pkg_extract_temp_$$"
    rm -f "$temp_pkg"
    rm -rf "$extract_dir"

    echo -e "  正在下载 Google 官方 PKG 安装包: ${CYAN}$GOOGLE_CHROME_PKG_URL${NC}"
    if ! curl -L --retry 3 --progress-bar "$GOOGLE_CHROME_PKG_URL" -o "$temp_pkg"; then
        echo -e "${RED}❌ PKG 下载失败${NC}"
        return 1
    fi

    echo -e "${BLUE}[3/5] 使用 macOS 原生 pkgutil 免挂载解包 PKG 结构...${NC}"
    mkdir -p "$extract_dir"
    if ! pkgutil --expand-full "$temp_pkg" "$extract_dir" 2>/dev/null; then
        echo -e "${RED}❌ PKG 解包失败${NC}"
        rm -rf "$temp_pkg" "$extract_dir"
        return 1
    fi

    # 扫描解压出的 Google Chrome.app 路径
    local source_app
    source_app=$(find "$extract_dir" -type d -name "Google Chrome.app" | head -n 1)

    if [ -z "$source_app" ] || [ ! -d "$source_app" ]; then
        echo -e "${RED}❌ 未在解包目录中发现 Google Chrome.app${NC}"
        rm -rf "$temp_pkg" "$extract_dir"
        return 1
    fi

    if ! verify_app_signature "$source_app"; then
        rm -rf "$temp_pkg" "$extract_dir"
        return 1
    fi

    echo -e "${BLUE}[4/5] 部署 Google Chrome.app 到便携目录...${NC}"
    local target_app="$CHROME_BIN_DIR/Google Chrome.app"
    rm -rf "$target_app"
    ditto "$source_app" "$target_app"

    # 清理临时文件
    rm -rf "$temp_pkg" "$extract_dir"
    return 0
}

install_chrome() {
    local target_app="$CHROME_BIN_DIR/Google Chrome.app"
    
    if [ -d "$target_app" ] && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "${BLUE}[2/5] 检测到便携版 Google Chrome 已就绪...${NC}"
        echo -e "${GREEN}  ✓ 目标路径: $target_app${NC}"
        return 0
    fi

    # 优先尝试 DMG 挂载引擎，若失败自动无缝切换至 PKG 解包引擎
    if ! try_install_via_dmg; then
        echo -e "${YELLOW}➔ 正在无缝切换至 PKG 容灾解包引擎...${NC}"
        if ! try_install_via_pkg; then
            echo -e "${RED}❌ 两套官方下载与提取引擎均未成功，请检查您的网络连接！${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}  ✓ 官方原版部署完成，已安全清理临时安装包${NC}"
}

verify_extensions() {
    echo -e "${BLUE}[5/5] 校验便携扩展与用户数据目录...${NC}"
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
    echo -e "${GREEN}${BOLD}                   🎉 Google Chrome macOS 便携版安装配置成功！                  ${NC}"
    echo -e "${GREEN}================================================================================${NC}"
    echo -e "  * 启动入口: 双击根目录下的 ${YELLOW}${BOLD}启动Chrome.command${NC}"
    echo -e "  * 用户数据: 独立保存在 ${CYAN}$USER_DATA_DIR${NC} (完全隔离、随文件夹移动)"
    echo -e "  * 合规保障: 100% 官方代码签名、0 预装二进制分发、0 侵权违规"
    echo -e "${GREEN}================================================================================${NC}"
    echo ""
}

# 执行主流程
print_header
check_dependencies
install_chrome
verify_extensions
print_summary
log_message "Installation and configuration completed successfully on macOS ($(uname -m 2>/dev/null || echo 'unknown'))"

if [ "$AUTO_LAUNCH" = true ]; then
    echo -e "${CYAN}正在为您自动启动 Google Chrome...${NC}"
    "$APP_DIR/launch-chrome.sh" &
fi
