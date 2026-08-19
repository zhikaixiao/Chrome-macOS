import zipfile

zip_path = r"c:\Users\xdani\Documents\Chrome\Release\GoogleChrome一键安装与插件增强版.zip"
with zipfile.ZipFile(zip_path, 'r') as z:
    names = z.namelist()
    exes = [n for n in names if n.lower().endswith(".exe")]
    exts = set([n.split('/')[2] for n in names if n.startswith("GoogleChrome一键安装与插件增强版/Extensions/") and '/' in n[len("GoogleChrome一键安装与插件增强版/Extensions/"):].strip('/')])
    print(f"Total files in release zip: {len(names)}")
    print(f"EXEs found: {exes}")
    print(f"Extensions included: {exts}")
