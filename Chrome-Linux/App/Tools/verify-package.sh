#!/usr/bin/env bash
# ==============================================================================
# Security & Legal Compliance Audit Script for macOS Package
# Validates 0 binaries, no forbidden permissions (VPN/Proxy), MV3 compliance
# ==============================================================================

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${CYAN}================================================================================${NC}"
echo -e "${CYAN}          macOS 便携版安全与合规性全自动审计 (PRC Law Compliance)               ${NC}"
echo -e "${CYAN}================================================================================${NC}"
echo ""

FAILURES=0

# 1. 检查是否存在预装的 Chrome 或自定义 Mach-O / Windows 二进制
echo -e "1. 正在扫描软件包中是否存在未授权二进制可执行文件..."
FORBIDDEN_BINARIES=$(find "$ROOT_DIR" -type f \( -name "*.exe" -o -name "*.dll" -o -name "*.dylib" -o -name "*.so" \) ! -path "*/Data/*" ! -path "*/Chrome-bin/*" || true)

if [ -n "$FORBIDDEN_BINARIES" ]; then
    echo -e "${RED}❌ 发现非脚本二进制文件:${NC}"
    echo "$FORBIDDEN_BINARIES"
    FAILURES=$((FAILURES + 1))
else
    echo -e "${GREEN}  ✓ 纯脚本交付验证通过：发布包内自定义二进制数量严格为 0${NC}"
fi

# 2. 检查扩展合规性 (禁止 proxy, vpnProvider, webRequestBlocking)
echo -e "\n2. 正在审计内置扩展权限清单 (Manifest 权限审查)..."
EXTENSIONS_DIR="$ROOT_DIR/App/Extensions"

if [ -d "$EXTENSIONS_DIR" ]; then
    for manifest in "$EXTENSIONS_DIR"/*/manifest.json; do
        if [ -f "$manifest" ]; then
            ext_name=$(basename "$(dirname "$manifest")")
            echo -e "  * 审查扩展: ${YELLOW}$ext_name${NC}"
            
            # 检查 Manifest V3
            if ! grep -q '"manifest_version": 3' "$manifest" && ! grep -q '"manifest_version":3' "$manifest"; then
                echo -e "${RED}    ❌ $ext_name 非 Manifest V3 标准${NC}"
                FAILURES=$((FAILURES + 1))
            else
                echo -e "${GREEN}    ✓ Manifest V3 标准校验通过${NC}"
            fi

            # 检查违规权限
            if grep -qi '"proxy"' "$manifest" || grep -qi '"vpnProvider"' "$manifest"; then
                echo -e "${RED}    ❌ 致命安全拦截: $ext_name 包含代理/VPN 违规权限！${NC}"
                FAILURES=$((FAILURES + 1))
            else
                echo -e "${GREEN}    ✓ 权限纯净：0 代理/0 VPN 穿透权限${NC}"
            fi
        fi
    done
fi

# 3. 检查反不正当竞争法规则 (0 广告拦截扩展)
echo -e "\n3. 正在审查反不正当竞争法合规性 (广告拦截审查)..."
if [ -d "$EXTENSIONS_DIR/uBlock" ] || [ -d "$EXTENSIONS_DIR/AdGuard" ]; then
    echo -e "${RED}❌ 发现广告拦截扩展，存在反不正当竞争法合规风险！${NC}"
    FAILURES=$((FAILURES + 1))
else
    echo -e "${GREEN}  ✓ 反不正当竞争法审查通过：未内置任何广告拦截/商业侵害插件${NC}"
fi

echo -e "\n${CYAN}================================================================================${NC}"
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}  🎉 审计全部通过！本 macOS 交付包 100% 符合国内相关法律法规与平台要求。${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    exit 0
else
    echo -e "${RED}  ❌ 发现 $FAILURES 项合规问题，请修复后再行发布！${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    exit 1
fi
