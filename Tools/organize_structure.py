import os
import shutil

root = r"c:\Users\xdani\Documents\Chrome"

app_dir = os.path.join(root, "App")
docs_dir = os.path.join(root, "Docs")
data_dir = os.path.join(root, "Data")
tools_dir = os.path.join(app_dir, "Tools")
config_dir = os.path.join(app_dir, "Config")
ext_dir = os.path.join(app_dir, "Extensions")

os.makedirs(app_dir, exist_ok=True)
os.makedirs(docs_dir, exist_ok=True)
os.makedirs(data_dir, exist_ok=True)
os.makedirs(tools_dir, exist_ok=True)
os.makedirs(config_dir, exist_ok=True)
os.makedirs(ext_dir, exist_ok=True)

# Copy Config
if os.path.exists(os.path.join(root, "Config", "extensions.json")):
    shutil.copy(os.path.join(root, "Config", "extensions.json"), os.path.join(config_dir, "extensions.json"))

# Copy Extensions
for ext in ["Violentmonkey", "KissTranslator", "DarkReader"]:
    src = os.path.join(root, "Extensions", ext)
    dst = os.path.join(ext_dir, ext)
    if os.path.exists(src):
        if os.path.exists(dst) and dst != src:
            shutil.rmtree(dst)
        if dst != src:
            shutil.copytree(src, dst)

# Copy Tools
for tool in ["Create-Desktop-Shortcut.ps1", "Verify-Package.ps1", "Generate-Compliance-Report.ps1", "generate_compliance_report.py", "ShortcutHelper.cs"]:
    src = os.path.join(root, "Tools", tool)
    dst = os.path.join(tools_dir, tool)
    if os.path.exists(src):
        shutil.copy(src, dst)

# Copy Docs
for doc in ["合规证明与安全审计报告.html", "COMPLIANCE_AUDIT_REPORT.md", "LEGAL_COMPLIANCE_LETTER.md", "LEGAL.md", "README.md"]:
    src = os.path.join(root, doc)
    dst = os.path.join(docs_dir, doc)
    if os.path.exists(src):
        shutil.copy(src, dst)

print("Structure sync completed.")
