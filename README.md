# Gendon 🔍

**Gendon** — *Gideon's Recon*. An automated reconnaissance pipeline for bug bounty and VDP hunting.

> Fun fact: "Gendon" is also the nickname I got bullied with in middle school. Now it's the name of a tool I built from scratch. 😎

Gendon chains passive-to-active recon into a single command, going from a target to an organized attack-surface blueprint — automatically.

---

## What it does

One command runs the full pipeline:

```
enum → resolve → probe → wayback → pathfuzz → katana → merge → extract → detect → report
```

It ends with `blueprint.md`: a clean, per-vulnerability-pattern list of endpoints, ready for hunting.

---

## Requirements

Gendon is an **orchestrator** — it calls external tools, it does not bundle them. Install these first and make sure they're in your `$PATH`:

| Tool | Purpose |
|---|---|
| [subfinder](https://github.com/projectdiscovery/subfinder) | subdomain enumeration |
| [assetfinder](https://github.com/tomnomnom/assetfinder) | subdomain enumeration |
| [puredns](https://github.com/d3mondev/puredns) | DNS resolution |
| [httpx](https://github.com/projectdiscovery/httpx) | HTTP probing (live host detection) |
| [waybackurls](https://github.com/tomnomnom/waybackurls) | archived URL mining |
| [gau](https://github.com/lc/gau) | archived URL mining |
| [katana](https://github.com/projectdiscovery/katana) | crawling + JS mining |
| [ffuf](https://github.com/ffuf/ffuf) | path & parameter fuzzing |
| [gf](https://github.com/tomnomnom/gf) | signal detection (vuln patterns) |
| Python 3 | merge / extract / report scripts |

You also need:
- A **resolvers** file (`resolvers.txt`) in the run directory for puredns.
- [SecLists](https://github.com/danielmiessler/SecLists) wordlists (paths used in the script — adjust if your install path differs).
- `gf` patterns installed (`~/.gf/`) — at minimum: `sqli`, `idor`, `ssrf`, `redirect`, `lfi`.

---

## Usage

Gendon has **three include modes** (pick one) plus optional flags.

### Modes

```bash
# Wildcard — enumerate ALL subdomains (for *.target.com scopes)
./gendon.sh --wildcard target.com

# List — scan a specific set of hosts from a file
./gendon.sh --list scope.txt

# Single — scan one host
./gendon.sh --single app.target.com
```

### Optional: `--deep`

Adds parameter fuzzing (and, later, vhost). Expensive — off by default.

```bash
./gendon.sh --wildcard target.com --deep
```

> ⚠️ `--deep` is **experimental** in v1.0. Parameter fuzzing works but is intentionally minimal; it will be refined in v1.1.

### Optional: scope exclusion

Create an `exclude.txt` in the run directory listing out-of-scope hosts (one per line). Gendon drops them **before resolving** — so out-of-scope hosts are never touched.

```
beta-qa.target.com
internal.target.com
```

---

## Output

| File | Contents |
|---|---|
| `subs.txt` | enumerated/scoped hosts |
| `live.txt` | live hosts (after HTTP probe) |
| `master.txt` | merged raw URLs (all sources) |
| `master_extracted.txt` | normalized + deduplicated endpoints |
| `gf_output/*.txt` | endpoints grouped by vuln pattern |
| **`blueprint.md`** | **the deliverable** — per-pattern summary with counts |

Example `blueprint.md`:

```markdown
## SQLI (190)
http://target.com/detail.php?id=...
...

## IDOR (187)
...

## SSRF (2)
...
```

---

## How it works (design notes)

- **Signal detection uses raw `master.txt`, not the extracted file** — `gf` needs full parameter values (`?url=...`), which extraction strips for deduplication. Two files, two jobs.
- **`--deep` is opt-in** because parameter fuzzing is expensive and often noisy; the ramping default stays fast.
- **Exclusion runs before resolution** so out-of-scope hosts are never queried — scope safety baked into the pipeline.
- **`gf` is greedy by design** — it returns *candidates*, not confirmations. Static-file noise (`.png?id=cache`) is filtered, but manual triage is still expected.
- **Portable paths** — uses `SCRIPT_DIR` so it runs correctly from any clone location, no hardcoded paths.

---

## Notes & limitations (v1.0)

- WAF-protected targets (e.g. Cloudflare) may return inconsistent probe results — this is target behavior, not a bug. A browser User-Agent is set by default to help.
- Recon against live sources (wayback/katana) is non-deterministic — endpoint counts can vary slightly between runs.
- `gf` may surface false positives (e.g. encoded JS fragments) — triage manually.

---

## Roadmap (v1.1+)

- Per-target output folders
- `--single` skips resolution (unnecessary for known hosts)
- vhost fuzzing under `--deep`
- Refined parameter fuzzing + report enrichment

---

## Legal

Only run Gendon against targets you are **explicitly authorized** to test (your own assets, or programs with a clear scope like VDP/bug bounty). Always read the scope. Recon stops at an attack-surface blueprint — no exploitation.

---

*Built solo, from scratch, while learning. — [0xGdn](https://github.com/0xGdn)*
