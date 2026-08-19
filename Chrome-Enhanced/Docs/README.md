# Google Chrome 便携增强版

## 项目简介
Google Chrome 便携增强版是一个**绿色、便携、开箱即用**的 Google Chrome 配置包，已预置 3 款实用开源合规扩展。

## 核心特性
1. **官方源静默安装**：一键从 Google 官方节点下载独立安装包并静默解压至本地目录，安装完成后自动清理临时安装包。
2. **精选合规开源扩展**：
   - **Violentmonkey（暴力猴）**：开源用户脚本管理器（MV3 标准）。
   - **KISS Translator**：沉浸式双语对照翻译。
   - **Dark Reader**：夜间/深色护眼模式。
3. **开箱即用默认配置**：
   - 默认搜索引擎：Microsoft Bing（必应）
   - 默认界面语言：简体中文（zh-CN）
   - 启用主页按钮，直达 Bing 首页
   - 启动直接打开 Bing 单标签页，彻底跳过 Google 账号登录/同步及欢迎向导
4. **便携数据隔离**：用户配置文件完全独立存储于 `Data/UserData/`，不污染系统注册表与全局环境。

## 使用方法
1. 解压全部文件至任意本地文件夹（如 `D:\GoogleChrome-Portable\`）。
2. 双击运行 `一键安装配置.bat` 完成自动下载与部署。
3. 后续可通过 `Start-Chrome.bat` 或桌面快捷方式 `Google Chrome.lnk` 启动。
