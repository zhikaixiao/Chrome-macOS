# Google Chrome Portable for macOS (便携版一键配置工具)

一套专为 macOS 打造的**100% 纯脚本、零二进制预装、国内直连、官方正版验证、合规便携**的 Google Chrome 自动化配置工具。

---

## 🌟 核心特性

1. **零二进制分发（100% 法律合规）**：
   - 软件包体积仅约 2MB，不预装、不修改、不分发任何 Chrome 二进制程序，完全规避版权与分发合规风险。
2. **国内 100% 顺畅直连官方 CDN**：
   - 安装时直接从 Google 官方 CDN（`https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg`）拉取 Universal 原版 DMG 镜像（支持 Apple Silicon M1/M2/M3/M4 与 Intel 架构）。
3. **Apple 官方 `codesign` 开发者签名硬校验**：
   - 挂载 DMG 后自动深度校验 Google LLC 官方 Apple 开发者签名（`TeamIdentifier=EQHXZ8M8AV`），确保 100% 官方正版。
4. **便携式独立用户数据目录**：
   - 采用 `--user-data-dir` 独立保存配置、书签与缓存，随目录便携移动，且不与系统自带 Chrome 冲突。
5. **合规开源扩展免商店直载 (`--load-extension`)**：
   - 预置 Violentmonkey (暴力猴脚本管家)、KISS Translator (沉浸式翻译) 及 Dark Reader (深色护眼模式)。
   - 严格禁止 AdBlock 广告拦截与代理/VPN 穿透代码，完全符合国内相关法规。

---

## 📁 目录结构

```
Chrome-macOS/
├── 一键安装配置.command                ← 双击执行安装与配置
├── 启动Chrome.command                  ← 双击直接启动便携版 Chrome
├── 生成合规证明与安全审计报告.command    ← 双击生成 HTML 审计报告
│
├── App/
│   ├── setup-chrome.sh                 ← 核心安装器 (下载、挂载、codesign 验签、部署)
│   ├── launch-chrome.sh                ← 核心启动器 (带便携参数拉起 Chrome)
│   ├── Config/
│   │   └── extensions.json             ← 扩展配置清单
│   ├── Extensions/                     ← 内置开源合规扩展 (MV3 标准)
│   └── Tools/
│       ├── verify-package.sh           ← 自动化合规审计工具
│       └── generate-compliance-report.sh
│
├── Data/
│   ├── UserData/                       ← 便携独立用户数据 (随目录移动)
│   └── Compliance_Audit_Log.txt        ← 审计日志
│
├── Docs/                               ← 法律合规说明
└── Licenses/                           ← 开源许可证
```

---

## 🚀 使用方法

1. **初次安装**：
   - 双击 **`一键安装配置.command`**。
   - 脚本会自动从 `dl.google.com` 官方拉取 DMG、完成 Apple 官方签名校验并配置就绪。
2. **日常使用**：
   - 双击 **`启动Chrome.command`** 即可直接启动带有独立配置与扩展的便携版 Chrome。
3. **生成合规报告**：
   - 双击 **`生成合规证明与安全审计报告.command`** 即可在浏览器中查看完整的安全审计证明。
