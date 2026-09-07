#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"

mode="$1"

enum() {
        echo "[*] Enumerating subdomains: $2"
        subfinder -d "$2" -silent > raw.txt
        assetfinder --subs-only "$2" >> raw.txt
        sort -u raw.txt > subs.txt
        echo "[+] $(wc -l < subs.txt) subdomains found"
        rm raw.txt
}

resolve () {
        if [ ! -f subs.txt ]; then
             echo "[-] subs.txt not found"
             return 1
        fi
        echo "[*] Resolving DNS (puredns)"
        puredns resolve subs.txt -r resolvers.txt > resolved.txt 2>/dev/null
        echo "[+] $(wc -l < resolved.txt) hosts resolved"
}

probe () {
        if [ ! -f resolved.txt ]; then
                echo "[-] resolved.txt not found"
                return 1
        fi
        echo "[*] Probing live hosts (httpx)"
        httpx -l resolved.txt -silent -H "User-Agent: $UA" -timeout 15 -retries 2 > live.txt 2>/dev/null
        echo "[+] $(wc -l < live.txt) live hosts"
}

wayback() {
        rm -f wayback_raw.txt
        if [ ! -f "live.txt" ]; then
                echo "[-] live.txt not found"
                return 1
        fi
        echo "[*] Mining archived URLs (wayback + gau)"
        cat live.txt | waybackurls > wayback_raw.txt 2>/dev/null
        cat live.txt | gau >> wayback_raw.txt 2>/dev/null
        sort -u wayback_raw.txt > wayback.txt
        echo "[+] $(wc -l < wayback.txt) URLs found"
        rm wayback_raw.txt
}

pathfuzz() {
        rm -f pathfuzz_raw.txt
        if [ ! -f "live.txt" ]; then
                echo "[-] live.txt not found"
                return 1
        fi
        echo "[*] Path fuzzing (ffuf)"
        while read -r host; do
                ffuf -w /usr/share/seclists/Discovery/Web-Content/common.txt -u "$host/FUZZ" -ac -s | sed "s|^|$host/|" >> pathfuzz_raw.txt 2>/dev/null
        done < live.txt
        sort -u pathfuzz_raw.txt > pathfuzz.txt
        rm pathfuzz_raw.txt
        echo "[+] $(wc -l < pathfuzz.txt) paths found"
}

run_katana() {
       if [ ! -f "live.txt" ]; then
                echo "[-] live.txt not found"
                return 1
       fi
       echo "[*] Crawling + JS mining (katana)"
       katana -list "live.txt" -jc -d 2 -ct 5m > katana_raw.txt 2>/dev/null
       sort -u katana_raw.txt > katana.txt
       rm katana_raw.txt
       echo "[+] $(wc -l < katana.txt) URLs found"
}

detect() {
    if [ ! -f "master.txt" ]; then
        echo "[-] master.txt not found"
        return 1
    fi
    echo "[*] Detecting signals (gf)"
    mkdir -p gf_output
    for pola in sqli idor ssrf redirect lfi; do
        gf "$pola" < master.txt \
          | grep -vE "\.(png|jpg|jpeg|gif|css|js|svg|ico)" \
          | sort -u \
          > gf_output/"$pola".txt
        echo "    $pola : $(wc -l < gf_output/"$pola".txt)"
    done
}

param_fuzz() {
    echo "[*] Param fuzzing (--deep)"
    rm -f param_fuzz_raw.txt
    for file in gf_output/*.txt; do
        if [ ! -f "$file" ]; then
            continue
        fi
        while read -r endpoint; do
            ffuf -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt \
                 -u "$endpoint?FUZZ=1" -ac -s -rate 30 >> param_fuzz_raw.txt
        done < <(head -20 "$file")
    done
    sort -u param_fuzz_raw.txt > param_fuzz.txt
    rm -f param_fuzz_raw.txt
    echo "[+] $(wc -l < param_fuzz.txt) params found"
}


# ===== Mode selection =====
if [[ "$mode" == "--wildcard" ]]; then
        enum "$2"
elif [[ "$mode" == "--list" ]]; then
        cp "$2" subs.txt
elif [[ "$mode" == "--single" ]]; then
        echo "$2" > subs.txt
else
        echo "Usage: ./gendon.sh --wildcard target.com | --list file.txt | --single host [--deep]"
        exit 1
fi

# ===== Scope exclusion (optional) =====
if [ -f "exclude.txt" ]; then
    grep -vf "exclude.txt" subs.txt > subs_scoped.txt && mv subs_scoped.txt subs.txt
    echo "[*] Excluded OOS -> $(wc -l < subs.txt) in-scope hosts"
fi

# ===== Pipeline =====
resolve
probe
wayback
pathfuzz
run_katana
python3 "$SCRIPT_DIR/../python/merge_master.py"
python3 "$SCRIPT_DIR/../python/extract.py"
detect
python3 "$SCRIPT_DIR/../python/report.py"

# ===== Deep mode (optional) =====
if [[ "$3" == "--deep" ]]; then
    param_fuzz
fi

echo "[+] Done. See blueprint.md"
