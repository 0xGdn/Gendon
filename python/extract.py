from urllib.parse import urlparse

def signature(url):
    url = url.strip()
    if not url.startswith("http"):
        url = "https://" + url
    p = urlparse(url)
    host = p.hostname
    if host is None:
        return None
    path = p.path.rstrip("/")
    base = host + path
    names = []
    if p.query:
        for pair in p.query.split("&"):
            name = pair.split("=")[0]
            names.append(name)
        param_sig = "?" + "&".join(sorted(names))
        return base + param_sig
    else:
        return base

total = 0
unik = set()
with open("master.txt", "r") as f:
    for line in f:
        sig = signature(line)
        if sig:
            unik.add(sig)
            total += 1
with open("master_extracted.txt", "w") as out:
    for s in sorted(unik):
        out.write(s + "\n")
print(f"[+] Raw: {total} | Unique: {len(unik)} -> master_extracted.txt")
