import os, shutil, hashlib

def sha256(p):
    h = hashlib.sha256()
    with open(p,'rb') as f:
        while c := f.read(65536): h.update(c)
    return h.hexdigest().upper()

candidates = [
    r'C:\Program Files\7-Zip\7za.exe',
    r'C:\Program Files\7-Zip\7z.exe',
    r'C:\Program Files (x86)\7-Zip\7za.exe',
    r'C:\Program Files (x86)\7-Zip\7z.exe',
]
src = next((p for p in candidates if os.path.exists(p)), None)
if not src:
    print("ERROR: 7-Zip not found on this machine")
else:
    dst = r'c:\Users\xdani\Documents\Chrome\App\Tools\7za.exe'
    shutil.copy2(src, dst)
    print(f"Copied from: {src}")
    print(f"Destination: {dst}")
    size = os.path.getsize(dst)
    print(f"Size: {size} bytes ({round(size/1024,1)} KB)")
    print(f"SHA256: {sha256(dst)}")
