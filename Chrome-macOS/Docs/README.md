# Google Chrome 官方版一键下载、安装与插件配置工具 (100% 纯脚本安全合规版)

轻量化、全自动、**100% 纯脚本开源透明**的 Google Chrome 增强配置工具。告别笨重的内置浏览器安装包（精简至 ~2MB），支持直接从谷歌中国官方 CDN 高速下载 64 位 Chrome 正式版，验证官方数字签名并自动部署精选合规实用插件与环境。

---

## 🌟 核心特性

1. **100% 纯脚本架构，零第三方 EXE 二进制**：
   - 项目内**绝无任何第三方自定义编译的 `.exe` 或二进制文件**。
   - 所有文件均为纯文本开源代码（`.bat`、`.ps1`、`.json`、`.js`、`.md`），任何人均可随时直接右键查看与审计代码，杜绝任何杀毒软件误报或木马后门担忧。
2. **官方直连，极速安全**：
   - 自动连接谷歌中国官方 CDN (`dl.google.com`)，国内直连高速下载 64 位完整独立安装包。
   - 自动校验 `CN=Google LLC` 官方 Authenticode 数字签名，杜绝任何篡改或损坏。
3. **全自动静默安装**：一键调用官方静默安装引擎，无需繁琐点击下一步。
4. **三大精选合规插件预置**：
   - **Violentmonkey (暴力猴)**：强大且开源的 Userscript 用户脚本管理器（纯净空白容器，默认不预装任何侵权脚本）。
   - **KISS Translator**：沉浸式双语对照网页翻译扩展（使用合规公开翻译通道）。
   - **Dark Reader**：实时深色护眼模式扩展（MIT开源，纯前端CSS滤镜实时渲染，舒适夜间护眼）。
5. **原生桌面图标与启动**：
   - 自动生成桌面快捷方式 **`Google Chrome (增强版)`**，直接调用官方原版 `chrome.exe`，通过官方原生参数载入插件。
6. **严格遵守中国大陆法律法规**：
   - 绝无任何 VPN、代理（Proxy）或非法网络穿透代码。
   - 完全移除广告拦截等涉《反不正当竞争法》争议模块。
   - 零数据采集、零用户追踪、无任何隐蔽商业劫持行为。

---

## 🚀 使用方法

### 方式 1：一键双击运行（推荐）
直接在项目根目录下双击运行：
👉 **`一键安装配置.bat`**

控制台将自动进行：
1. 检测系统中已安装的 Chrome（若已有则直接进行插件与快捷方式配置）。
2. 从中国官网高速下载最新 Chrome 64位正式版安装包。
3. 校验官方数字签名并静默安装。
4. 部署 Violentmonkey、KISS Translator、Dark Reader 3大扩展。
5. 在桌面创建启动图标并提供一键启动。

### 方式 2：PowerShell 命令行运行
```powershell
# 标准配置
powershell -ExecutionPolicy Bypass -File .\Setup-Chrome.ps1

# 静默配置并自动启动
powershell -ExecutionPolicy Bypass -File .\Setup-Chrome.ps1 -Silent -AutoLaunch

# 强制重新下载并安装官方最新版
powershell -ExecutionPolicy Bypass -File .\Setup-Chrome.ps1 -ForceReinstall
```

---

## 📂 项目结构说明

```text
GoogleChrome一键安装与插件增强版/
├── 一键安装配置.bat            # 用户双击一键执行入口 (纯批处理脚本)
├── Installer.bat               # 兼容入口 (纯批处理脚本)
├── Setup-Chrome.ps1            # 核心下载、校验、安装与配置引擎 (纯 PowerShell 脚本)
├── Config/
│   └── extensions.json         # 插件配置清单与元数据
├── Extensions/                 # 精选插件源码包 (~2MB)
│   ├── Violentmonkey/          # 暴力猴脚本管理器
│   └── KissTranslator/         # KISS 双语翻译
├── Tools/
│   ├── ShortcutHelper.cs       # Unicode 快捷方式底层接口源码
│   ├── Create-Desktop-Shortcut.ps1 # 快捷方式生成脚本
│   └── Verify-Package.ps1      # 完整性与合规安全自检脚本
├── Licenses/                   # 各开源组件授权许可声明
├── LEGAL.md                    # 法律合规与免责声明白皮书
└── README.md                   # 本说明文档
```

---

## 🛡️ 法律合规与安全声明

本项目严格遵从《网络安全法》、《刑法》第285/286条、《反不正当竞争法》、《互联网广告管理办法》、《个人信息保护法》等法律法规。详见 **[LEGAL.md](LEGAL.md)**。

---

## 🔧 自检与验证

可在 `Tools/` 目录下随时运行完整性与合规检查脚本：
```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Verify-Package.ps1
```
