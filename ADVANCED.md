# Offline AI Kit – Advanced options

For people comfortable with a terminal. Normal users: use **EASY-INSTALL** or **SETUP** (see README.md).

## Three ways to install

| Version | Windows | Mac | What it does |
|---|---|---|---|
| **Easy** | `EASY-INSTALL (Windows).bat` | `EASY-INSTALL (Mac).command` (Apple chip and Intel) | No questions. Detects memory, graphics card and free disk space, picks a hardware profile, installs into the kit folder, adds an **Offline AI** shortcut to the Desktop, starts the kit and opens the browser. If the disk is short it drops to a smaller profile and/or skips Wikipedia instead of failing. |
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

**Mac with an Apple chip** (memory is shared between the CPU and GPU, so the choice is by RAM from `sysctl hw.memsize`):

| Profile | RAM | Library | Models | Approx. size (+127 GB Wikipedia) |
|---|---|---|---|---|
| LITE | under 16 GB | Essentials | `llama3.2:3b`, `medgemma:4b` | ~10 GB |
| STANDARD | 16–23 GB | Recommended | + `phi4-mini`, `qwen3.5:9b`, `gemma3:4b` | ~29 GB |
| LARGE | 24–31 GB | Recommended | + `gemma3:12b`, `qwen3:14b` | ~47 GB |
| LARGEST | 32 GB+ | Recommended | + `qwen3:30b` | ~66 GB |

On **macOS 13** these use Ollama v0.12.9 and `qwen3:8b` instead of `qwen3.5:9b` (see *Which Mac, which programs* below).

**Intel Mac** (Ollama runs on the CPU only, so only small models):

| Profile | When | Library | Models | Approx. size (+127 GB Wikipedia) |
|---|---|---|---|---|
| INTEL | any Intel Mac | Recommended | `llama3.2:3b`, `medgemma:4b` (+ `phi4-mini` with 16 GB+ RAM) | ~18–20 GB |
| INTEL SMALL | Intel Mac, tight disk | Essentials | same models | ~10–12 GB |

### Which Mac, which programs

The Mac scripts decide by themselves – nobody has to choose:

- **Chip:** `sysctl -n hw.optional.arm64` is `1` on every Apple-chip Mac, even when Terminal runs under Rosetta
  (then `uname -m` says `x86_64` and `sysctl.proc_translated` is `1`; the kit then starts its programs with
  `arch -arm64`). Intel Macs don't have that key.
- **Kiwix:** newest `kiwix-tools_macos-arm64-*.tar.gz` or `kiwix-tools_macos-x86_64-*.tar.gz` from
  download.kiwix.org (MD5-checked). Needs macOS 12+. Kept in `runtime/mac-kiwix` or `runtime/mac-kiwix-intel`.
- **Ollama:** `ollama-darwin.tgz` is one universal download (Apple-chip + Intel). SHA256-checked against the release's
  `sha256sum.txt`.

| macOS | Ollama | AI |
|---|---|---|
| 14 Sonoma or newer | newest release (`runtime/mac-ollama`) | yes |
| 13 Ventura | **v0.12.9**, pinned – the last release built for macOS 13 (v0.12.10+ need 14). SHA256 `a3bd6456…7f17` is built into the kit and must match. Kept in `runtime/mac-ollama-v0.12.9` | yes |
| 12 Monterey | none | library only, with a clear message |
| 11 or older | – | setup stops with a clear message (Kiwix needs macOS 12) |

For testing on another Mac: `OFFLINE_AI_MAC_ARCH=x86_64|arm64` and `OFFLINE_AI_MACOS=13.6` (environment), or
`MAC_ARCH=` in `kit-settings.ini`. Forcing `x86_64` on an Apple-chip Mac runs the Intel programs through Rosetta
(`arch -x86_64`), which must be installed.

**Disk fallback (Easy):** it tries the profile above *with* Wikipedia (needs profile + ~140 GB), then each smaller
profile with Wikipedia, then the original profile *without* Wikipedia, then smaller ones without. If even LITE
doesn't fit (~10–12 GB), it stops with a plain-English message.

## Command-line options

Windows (PowerShell, from the kit folder):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1 [options]
  -Easy                     no questions (same as EASY-INSTALL (Windows).bat)
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
  -Test                     quick test install (see Test mode)
  -DetectOnly               only show the hardware check and chosen profile
```

Mac (Terminal, from the kit folder):

```bash
bash mac/setup.sh [options]
  --easy  --profile lite|standard|large|largest|intel|intel-small  --tier essentials|recommended
  --models lite|8|16|24|32   or  --models "qwen3.5:9b,llama3.2:3b"
  --zims id,id  --path /Volumes/SSD/OfflineAI  --skip-wikipedia  --with-wikipedia
  --use-system-ollama  --no-start  --yes  --test  --detect-only
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
| `MAC_ARCH` | (detected) | Mac only: `arm64` or `x86_64` to override the chip detection |

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
| `runtime/` | programs (Windows: `ollama`, `kiwix`; Mac: `mac-ollama` or `mac-ollama-v0.12.9`, `mac-kiwix` or `mac-kiwix-intel`) |
| `library/` | `.zim` files + `checksums/VERIFIED` markers (shared by both platforms) |
| `ollama-models/`, `home/` | the kit's AI models and Ollama settings (shared) |
| `logs/` | logs, pid files, `wikipedia-progress.json` |
| `www/` | chat page (`chat.html`, `ask-library.js`, `selftest.html`); START writes `kit-config.js` (ports) and on Mac `wiki-status.js` |
| `tests/` | offline checks for `ask-library.js` (`node tests/ask-library.test.js`). Only in the GitHub repo, not in the download ZIP; not needed to run the kit |
| `kit-config.json` / `kit-config-mac.txt` | what setup chose last time |

Uninstall: run STOP, then delete the kit folder (and the Desktop shortcut). Nothing else is installed.

## Ask the library: how it works

The chat page's **Ask the library** switch (on by default; remembered per browser) is all in `www/ask-library.js`,
loaded by `www/chat.html`. Nothing else runs for it.

1. **Which collections?** `GET http://127.0.0.1:8090/catalog/v2/entries?count=-1`. Collections tagged `_ftindex:no`
   (the zimgit knots/water/food/medicine/post-disaster PDF collections) have no text index and are skipped.
2. **Search.** For every searchable collection, in parallel:
   `/search?content=<book>&pattern=<keywords>&format=xml&pageLength=8` (Kiwix needs **all** words to match), plus
   `/suggest?content=<book>&term=<word or word pair>` for article titles, plus single-word searches when the all-words
   search finds fewer than 5. Filler words are dropped first ("how do I stop heavy bleeding" → `stop heavy bleeding`).
3. **Rank and read.** Results are scored (title matches, exact titles, Kiwix rank), the best 6 (max 3 per collection)
   are fetched from `/content/...`, turned into text (references, tables, navigation boxes removed), and the lead
   paragraph plus the paragraphs matching the keywords are kept – about 7,500 characters in total.
   An article only counts if its title matches a keyword or it contains at least half of the keywords; up to 3 are used.
   Disambiguation and "List of …" pages are skipped.
4. **Answer.** The AI gets the numbered passages and is told to answer only from them, cite `[n]`, and reply
   `NOT_IN_LIBRARY` if they don't answer the question (`num_ctx` 8192, temperature 0.2).
5. **Check.** Every `[n]` / `[n, m]` / `[n-m]` that isn't one of the fetched articles is removed, as are web links and
   any "Sources:" list the AI wrote itself. The list under the answer is built only from the fetched articles.
   No results, no relevant articles, or `NOT_IN_LIBRARY` → "couldn't find this in the offline library" plus a button
   for a memory-only answer, labelled as such.

**Why no proxy?** `kiwix-serve` 3.x (what setup installs) sends `Access-Control-Allow-Origin: *` on its search,
suggest, catalog and content responses, so the chat page can read it directly – from `http://127.0.0.1:8091`
(Windows) and from a `file://` page (Mac, origin `null`). The kit's Ollama already allows any origin
(`OLLAMA_ORIGINS=*`). Both still listen only on `127.0.0.1`. If you point the kit at a very old kiwix-serve without
that header, the chat says it can't reach the library; untick **Ask the library** or update Kiwix by re-running setup.

**Self-test page.** With the kit running, open `www/selftest.html` (Windows: http://127.0.0.1:8091/selftest.html;
Mac: double-click `www/selftest.html` or drag it into the browser). It checks, with the real library and model:
the catalog is readable, a question (default: "How do I treat mild hypothermia?") gets an answer whose sources all open (HTTP 200), a nonsense question gives
"not in the library", and a forged `[n]` and a fake link are removed. Add `#q=your question` to try another question,
or `#model=llama3.2:3b` to pick the model. Automated tests can add `#report=http://127.0.0.1:PORT/` to receive the
JSON result by POST (127.0.0.1 only).

## Test mode (for trying the kit quickly)

Test mode installs a **tiny** version: 3 small library files (knots, water, and a 170 MB intros-only Wikipedia
Medicine, `wikipedia_en_medicine_mini`, so **Ask the library** can be tried with a first-aid question), one small
model (`llama3.2:3b`, ~2 GB), and a **13 MB stand-in for Wikipedia** (`wikipedia_en_knots_maxi`) so the background download, checksum,
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

