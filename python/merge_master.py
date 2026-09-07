source = ["wayback.txt", "pathfuzz.txt", "katana.txt"]
hasil = set()
for filename in source:
    with open(filename, "r") as f:
        for line in f:
            clean = line.strip()
            if clean:
                hasil.add(clean)
with open("master.txt", "w") as f:
    for item in hasil:
        f.write(item + "\n")
print(f"[+] Merged {len(hasil)} URLs -> master.txt")
