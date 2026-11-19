# Offline AI Kit – Advanced options

For people comfortable with a terminal. Normal users: use **EASY-INSTALL** or **SETUP** (see README.md).

## Three ways to install

| Version | Windows | Mac | What it does |
|---|---|---|---|
| **Easy** | `EASY-INSTALL.bat` | `EASY-INSTALL-MAC.command` | No questions. Detects memory, graphics card and free disk space, picks a hardware profile, installs into the kit folder, adds an **Offline AI** shortcut to the Desktop, starts the kit and opens the browser. If the disk is short it drops to a smaller profile and/or skips Wikipedia instead of failing. |
| **Standard** | `SETUP.bat` | `SETUP-MAC.command` | Menus: folder, library tier, model set (suggested from the hardware), and – on lighter machines or small disks – whether to include Wikipedia. |
| **Advanced** | `scripts\setup.ps1` with options | `mac/setup.sh` with options | Everything below, plus `kit-settings.ini`. |

## Hardware profiles

**Windows** (chosen by `EASY-INSTALL`, suggested by `SETUP`):

| Profile | When | Library | Models | Approx. size (+127 GB Wikipedia) |
|---|---|---|---|---|
| LITE | no NVIDIA GPU, or under 16 GB RAM, or small disk | Essentials | `llama3.2:3b`, `medgemma:4b` | ~12 GB |
| STANDARD | NVIDIA GPU under 12 GB VRAM | Recommended | Lite + `qwen3.5:9b`, `phi4-mini` | ~28 GB |
| FULL | NVIDIA GPU with 12 GB+ VRAM (e.g. RTX 5070 Ti laptop) | Recommended | Standard + `gemma3:4b`, `gemma3:12b`, `qwen3:14b` | ~49 GB |

VRAM is read with `nvidia-smi` (falls back to `Win32_VideoController` to spot an NVIDIA card; then VRAM counts as unknown and STANDARD is used).

**Mac** (Apple Silicon shares memory between the CPU and GPU, so the choice is by RAM from `sysctl hw.memsize`):

| Profile | RAM | Library | Models | Approx. size (+127 GB Wikipedia) |
|---|---|---|---|---|
| LITE | under 16 GB | Essentials | `llama3.2:3b`, `medgemma:4b` | ~10 GB |
| STANDARD | 16–23 GB | Recommended | + `phi4-mini`, `qwen3.5:9b`, `gemma3:4b` | ~29 GB |
| LARGE | 24–31 GB | Recommended | + `gemma3:12b`, `qwen3:14b` | ~47 GB |
| LARGEST | 32 GB+ | Recommended | + `qwen3:30b` | ~66 GB |

**Disk fallback (Easy):** it tries the profile above *with* Wikipedia (needs profile + ~140 GB), then each smaller
profile with Wikipedia, then the original profile *without* Wikipedia, then smaller ones without. If even LITE
doesn't fit (~10–12 GB), it stops with a plain-English message.

## Command-line options

Windows (PowerShell, from the kit folder):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1 [options]
  -Easy                     no questions (same as EASY-INSTALL.bat)
  -HardwareProfile lite|standard|full
  -Tier essentials|recommended
  -Models lite|core|full    or an exact list: -Models "qwen3.5:9b,llama3.2:3b"
  -Zims id,id,...           exact library list (overrides -Tier)
  -InstallPath D:\OfflineAI copy the kit there and install there
  -SkipWikipedia            never download full Wikipedia
  -WithWikipedia            always include it (no question)
  -UseSystemOllama          use your existing Ollama (default port 11434) instead of the kit's own
  -NoStart                  don't start the kit at the end
  -Yes                      accept every default (unattended)
```

Mac (Terminal, from the kit folder):

```bash
bash mac/setup.sh [options]
  --easy  --profile lite|standard|large|largest  --tier essentials|recommended
  --models lite|8|16|24|32   or  --models "qwen3.5:9b,llama3.2:3b"
  --zims id,id  --path /Volumes/SSD/OfflineAI  --skip-wikipedia  --with-wikipedia
  --use-system-ollama  --no-start  --yes
```

Example – unattended Mac install to an external SSD with three models and no Wikipedia:

```bash
bash mac/setup.sh --path "/Volumes/My SSD/OfflineAI" --tier essentials \
  --models "qwen3.5:9b,llama3.2:3b,medgemma:4b" --skip-wikipedia --yes
```

## kit-settings.ini

Copy `kit-settings.example.ini` to `kit-settings.ini` in the kit folder. Both platforms read it on every
SETUP and START. Command-line options win over the file.

| Key | Default | Meaning |
|---|---|---|
| `LIBRARY_TIER` | (asked) | `essentials` or `recommended` |
| `ZIMS` | – | exact list of library ids (below) |
| `MODELS` | (asked) | set name or comma list of Ollama model tags |
| `SKIP_WIKIPEDIA` | `no` | `yes` = never start the 127 GB download (Easy/SETUP may set this for you) |
| `LIBRARY_PORT` | `8090` | Kiwix library port |
| `OLLAMA_PORT` | `11435` (`11434` with system Ollama) | AI server port |
| `CHAT_PORT` | `8091` | Windows chat page server port |
| `USE_SYSTEM_OLLAMA` | `no` | `yes` = don't download/start/stop the kit's Ollama; use yours |

Library ids: `knots`, `medicine`, `food`, `water`, `postdisaster`, `usda`, `appropedia`, `mdwiki` (Essentials);
`wpmed`, `wikivoyage`, `gardening`, `ifixit` (Recommended). Full Wikipedia (`wikipedia_en_all_maxi`) is handled
separately by START. The newest dated file of each is looked up on download.kiwix.org at install time and checked
against its published SHA256; only verified files (marker in `library/checksums/VERIFIED/`) are served.

Any model from https://ollama.com/library can go in `MODELS`; setup checks each tag exists before pulling.

### Using an Ollama you already have

Set `USE_SYSTEM_OLLAMA=yes` (or pass the option). Models are pulled into *your* Ollama's store, and START/STOP
leave it alone. Make sure it is running. On **Mac** the chat page is opened as a local file, so your Ollama must
allow that origin: quit Ollama, run `launchctl setenv OLLAMA_ORIGINS "*"`, and start Ollama again. (On Windows
the chat page is served from `http://127.0.0.1:8091`, which Ollama allows by default.)

## Files and folders

| Path | What |
|---|---|
| `runtime/` | programs (Windows: `ollama`, `kiwix`; Mac: `mac-ollama`, `mac-kiwix`) |
| `library/` | `.zim` files + `checksums/VERIFIED` markers (shared by both platforms) |
| `ollama-models/`, `home/` | the kit's AI models and Ollama settings (shared) |
| `logs/` | logs, pid files, `wikipedia-progress.json` |
| `www/` | chat page; START writes `kit-config.js` (ports) and on Mac `wiki-status.js` |
| `kit-config.json` / `kit-config-mac.txt` | what setup chose last time |

Uninstall: run STOP, then delete the kit folder (and the Desktop shortcut). Nothing else is installed.

## Test mode (for trying the kit quickly)

Test mode installs a **tiny** version: 2 small library files (knots, water), one small model (`llama3.2:3b`,
~2 GB), and a **13 MB stand-in for Wikipedia** (`wikipedia_en_knots_maxi`) so the background download, checksum,
VERIFIED marker and automatic library restart are all exercised in minutes. Total download ≈ 2–4 GB
(Windows also downloads the 1.6 GB Ollama program).

Turn it on with any of: the `-Test` / `--test` option, the environment variable `OFFLINE_AI_TEST=1`, or
`TEST_MODE=yes` in `kit-settings.ini` (setup writes this so later STARTs stay in test mode).
`OFFLINE_AI_SKIP_WIKIPEDIA=1` (or `-SkipWikipedia` / `--skip-wikipedia`) skips Wikipedia altogether.
To leave test mode, delete `kit-settings.ini` (or set `TEST_MODE=no`) and run setup again.

Non-interactive Easy run in test mode, logging to a file:

```powershell
# Windows (PowerShell in the kit folder)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup.ps1 -Easy -Test
```

```bash
# Mac (Terminal in the kit folder)
bash mac/setup.sh --easy --test < /dev/null
```

Every setup run writes a full log to `logs/setup-YYYYMMDD-HHMMSS.log`; every START writes `logs/start-latest.log`.
Look for the lines `RESULT: SETUP OK` / `RESULT: SETUP FINISHED WITH PROBLEMS` and `RESULT: START OK`.
Other useful logs: `logs/ollama*.log`, `logs/kiwix*.log`, `logs/wikipedia-download*.log`, `logs/wikipedia-progress.json`,
`logs/zim-downloads.log`. Easy mode also creates the Desktop shortcut (delete it after testing if you like).

