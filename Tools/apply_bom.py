import glob

for fpath in glob.glob(r"c:\Users\xdani\Documents\Chrome\**\*.ps1", recursive=True):
    try:
        with open(fpath, "rb") as f:
            data = f.read()
        while data.startswith(b"\xef\xbb\xbf"):
            data = data[3:]
        with open(fpath, "wb") as f:
            f.write(b"\xef\xbb\xbf" + data)
    except Exception:
        pass
print("All ps1 BOM cleaned.")
