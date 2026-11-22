# Offline AI Kit – Advanced options

For people comfortable with a terminal. Normal users: open **`Click these`** (see README.md and `FOLDER-GUIDE.txt`).

## Four ways to install

| Version | Windows | Mac | Linux | What it does |
|---|---|---|---|---|
| **Guided** | `Click these/1 Install - guided/Windows.bat` | `Click these/1 Install - guided/Mac.command` | `bash "Click these/1 Install - guided/Linux.sh"` | Browser page on 127.0.0.1. Explains every choice, then runs the setup below with the answers filled in (`-Yes` / `--yes` plus the flags, including `-NoShareWifi` or `--no-share-wifi`, and `-ThisComputer` or `--this-computer`). Nothing downloads until Install is pressed. |
| **Easy** | `EASY-INSTALL (Windows).bat` | `EASY-INSTALL (Mac).command` (Apple chip and Intel) | `bash "EASY-INSTALL (Linux).sh"` | No questions. Detects memory, graphics card and free disk space, picks a hardware profile, installs into the kit folder, adds an **Offline AI** shortcut to the Desktop, starts the kit and opens the browser. If the disk is short it drops to a smaller profile and/or skips Wikipedia instead of failing. Maps are not downloaded. |
| **Setup Wizard** | `SETUP.bat` | `SETUP-MAC.command` | `bash SETUP-LINUX.sh` | Folder, then 8 steps: AI model size (suggested from the hardware), core library tier, full Wikipedia yes/no, Extra Libraries, Share on Wi-Fi, optional offline maps, this computer or all computers (universal drive), and a summary (download size vs free space, including the extra program space) with `Proceed? (Y/N)`. Nothing downloads before that. Choices are saved in `kit-settings.ini`. |
| **Advanced** | `scripts\setup.ps1` with options | `mac/setup.sh` with options | `linux/setup.sh` (same wizard; sets `OFFLINE_AI_OS=linux`) | Everything below, plus `kit-settings.ini`. |

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
  -ShareWifi                turn on Share on Wi-Fi (saved as SHARE_ON_WIFI=1)
  -NoShareWifi              turn Share on Wi-Fi off (the guided installer passes this when the box is left off)
  -ExtraLibraries id,id     also download these Extra Libraries (ids or numbers from the list, or "all")
  -Maps id,id               also download these offline maps (ids or numbers from catalog\maps.txt, or "all")
  -Universal                also download programs for Windows, Mac (both chips) and Linux (x64 and ARM)
  -ThisComputer             this computer only (skips the "which computers" question)
```

Any option given on the command line skips that wizard question. `-Easy` (and `-Yes`) never ask anything.
`-Easy` does not download maps. `-Maps` is honored together with `-Easy` because you passed it on purpose.
The three `EASY-INSTALL` launchers do not pass `-Maps` / `--maps`.

Mac (Terminal, from the kit folder):

```bash
bash mac/setup.sh [options]
  --easy  --profile lite|standard|large|largest|intel|intel-small  --tier essentials|recommended
  --models lite|8|16|24|32   or  --models "qwen3.5:9b,llama3.2:3b"
  --zims id,id  --path /Volumes/SSD/OfflineAI  --skip-wikipedia  --with-wikipedia
  --use-system-ollama  --no-start  --yes  --test  --detect-only
  --share-wifi  --no-share-wifi  --extra-libraries id,id|all  --maps id,id|all  --universal  --this-computer
```

Linux is the same wizard: `bash linux/setup.sh` (or `bash SETUP-LINUX.sh`). It downloads
`kiwix-tools_linux-x86_64` or `kiwix-tools_linux-aarch64` (musl when `ldd --version` mentions musl) and
`ollama-linux-amd64.tgz` or `ollama-linux-arm64.tgz`, or `.tar.zst` when that is the published file (the archive has `bin/ollama` and `lib/ollama`).
The phone address is the `src` address from `ip route get 1.1.1.1`.

**Scripted wizard answers.** Without `--yes`/`-Easy`, the wizard reads one answer per line from standard input when it
is not a terminal (end of input = the suggested answer). The order is: folder, AI model size, core library,
Wikipedia (Y/N), Extra Libraries, Share on Wi-Fi (Y/N), offline maps (empty = none), which computers
(1 = this computer, 2 = all computers), Proceed (Y/N), Start now (Y/N):

```bash
printf '\n16\n2\nY\n1\nN\n\n1\nY\nN\n' | bash mac/setup.sh --test
```

`--universal` / `-Universal` skips that question and downloads every computer's programs. The library,
models and maps are still downloaded once. The summary line `Extra programs:` is the extra allowance
(11.5 GB on Windows, 13.0 GB on Mac and Linux) on top of this computer's programs. The full program
allowance is 14 GB. Measured unpacked trees are about 12.8 GB. Test mode does not download those extra
programs and does not count them. Linux uses `ollama-linux-amd64.tgz` / `ollama-linux-arm64.tgz` when the
release still publishes them, and `.tar.zst` when that is the current file. If this computer cannot read
`.tar.zst`, setup downloads a small checksum-checked zstd program. A failed unpack leaves the checked
archive and any programs that already installed, then continues with the other computers.
```bat
rem Windows (cmd), answers.txt holds one answer per line
type answers.txt | powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup.ps1 -Test
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
| `CHAT_PORT` | `8091` | chat page server port (always on this computer; `0.0.0.0` only when Share on Wi-Fi is on) |
| `SHARE_ON_WIFI` | `0` | `1` = Share on Wi-Fi (library + chat page on the home network; the AI server stays on 127.0.0.1) |
| `EXTRA_LIBRARIES` | – | written by setup as a record of the Extra Libraries you chose (informational) |
| `MAPS` | – | written by setup as a record of the offline maps you chose (informational). Easy Install leaves it unset unless `--maps` / `-Maps` was passed. |
| `USE_SYSTEM_OLLAMA` | `no` | `yes` = don't download/start/stop the kit's Ollama; use yours |
| `MAC_ARCH` | (detected) | Mac only: `arm64` or `x86_64` to override the chip detection |
| `UNIVERSAL` | `no` | `yes` = setup also downloads programs for every supported computer (universal drive). The wizard shows the extra GB. |

Library ids: `knots`, `medicine`, `food`, `water`, `postdisaster`, `usda`, `appropedia`, `mdwiki` (Essentials);
`wpmed`, `wikivoyage`, `gardening`, `ifixit` (Recommended). Full Wikipedia (`wikipedia_en_all_maxi`) is handled
separately by START. The newest dated file of each is looked up on download.kiwix.org at install time and checked
against its published SHA256; only verified files (marker in `library/checksums/VERIFIED/`) are served.

Any model from https://ollama.com/library can go in `MODELS`; setup checks each tag exists before pulling.

### Using an Ollama you already have

Set `USE_SYSTEM_OLLAMA=yes` (or pass the option). Models are pulled into *your* Ollama's store, and START/STOP
leave it alone. Make sure it is running. The chat page is served from `http://127.0.0.1:8091`, which Ollama
allows by default. If that server does not start, the page opens as a local file. On Mac, quit Ollama, run
`launchctl setenv OLLAMA_ORIGINS "*"`, and start Ollama again so a file page can talk to it.

## Share on Wi-Fi (how it works)

Off by default (`SHARE_ON_WIFI=0`): Kiwix, Ollama and the chat page listen on `127.0.0.1` only. With `SHARE_ON_WIFI=1`:

| Part | Listens on | Notes |
|---|---|---|
| Ollama (the kit's AI server) | **`127.0.0.1:11435` always** | never exposed to the network |
| Kiwix library | **`127.0.0.1:8090` always** | phones reach it through the chat page server |
| Chat page server | `0.0.0.0:8091` | the only thing on the network: serves `www/`, `/status.json`, `/ollama/api/...` → `127.0.0.1:11435`, and the library pages (`/library/` home, `/content/...`, `/search`, `/catalog/...`, `/skin/...`, read-only GET/HEAD) → `127.0.0.1:8090` |

- The `/ollama/` proxy only passes `GET /api/tags`, `/api/version`, `/api/ps` and `POST /api/chat`, `/api/generate`,
  `/api/show`, `/api/embed(dings)`. Pulling, deleting, copying or creating models returns 403. Responses are copied
  through byte for byte as they arrive, so streamed answers stay streamed.
- The page decides where to send requests (`AskLibrary.endpoints()` in `www/ask-library.js`): opened as a file or from
  `127.0.0.1`/`localhost` it talks to `127.0.0.1` directly; opened from any other host name (a phone) it uses
  `http://<that host>:8091/ollama` for the AI and `http://<that host>:8091` for the library (citation links open
  on the phone). Only one program accepts network connections, so there is only one firewall question to answer.
- **Windows:** `scripts\serve-chat.ps1` uses a `TcpListener` (binding `0.0.0.0` needs no admin rights, unlike
  `HttpListener`) and a pool of worker threads. Windows Firewall decides whether other devices get through: allow
  *Windows PowerShell* on **Private** networks when asked, and set the home network to Private.
  Creating firewall rules needs an administrator; the kit never changes the firewall itself.
- **Mac:** `mac/serve-chat.pl` (perl and `IO::Socket::INET` ship with macOS; one forked process per connection).
  If perl were missing it falls back to `mac/serve-chat.py`, but only when `xcode-select -p` succeeds or `python3` is
  not the `/usr/bin` stub (which would pop up an install dialog). STOP kills the server and its children.
  The chat page server always runs on `127.0.0.1:8091`. Share on Wi-Fi changes that bind to `0.0.0.0`.
  If the server does not start, the chat page opens as a file. Linux uses the same start script.
- The LAN address is the one used for the default route (Windows: a UDP socket "connect", no packet sent; Mac:
  `route -n get default` + `ipconfig getifaddr`), falling back to the first private address. START, STATUS and the
  chat page show it; the chat page also draws a QR code with `www/qr.js` (offline, no libraries).
- Turn it on/off: STATUS menu, `status.ps1 -ShareWifi on|off` / `bash mac/status.sh --share-wifi on|off` (applies
  immediately), START `-ShareWifi`/`-NoShareWifi` / `--share-wifi`/`--no-share-wifi` (remembered), or the ini key.

## Extra Libraries

The catalog is `catalog/extra-libraries.txt` (`id | kiwix folder | file prefix | approx GB | group | description`).
Like the core library, the newest dated file is resolved on download.kiwix.org at download time, fetched from the
fastest mirror with resume, checked against the `.sha256` published on download.kiwix.org, marked in
`library/checksums/VERIFIED/`, and the library restarts by itself if it is running.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\add-libraries.ps1 -List
powershell -ExecutionPolicy Bypass -File scripts\add-libraries.ps1 -Add se-diy,wiktionary-simple   # or numbers: -Add 2,11
powershell -ExecutionPolicy Bypass -File scripts\add-libraries.ps1 -Remove se-diy
```
```bash
bash mac/add-libraries.sh --list
bash mac/add-libraries.sh --add se-diy,wiktionary-simple      # --yes skips the "very big download" question
bash mac/add-libraries.sh --remove se-diy
```

Ids: `se-sustainability`, `wiktionary-simple`, `se-lifehacks`, `se-medical`, `se-ham`, `se-outdoors`, `se-cooking`,
`se-mechanics`, `trueprepper`, `ready-gov`, `se-diy`, `gutenberg-medicine`, `wikibooks`, `gutenberg-agriculture`,
`gutenberg-technology`, `wiktionary`, `gutenberg-all` (206 GB, no full-text index; `all` skips it).

## Offline maps

`catalog/maps.txt` uses the same `id|folder|prefix|GB|group|description` lines. Downloads go through the existing
Kiwix mirror, resume and SHA-256 flow (`zim/maps` on download.kiwix.org). The newest file may be
`prefix_YYYY-MM.zim` or `prefix_YYYY-MMa.zim`.

Vancouver Island, British Columbia, Alberta, Saskatchewan and Canada are names for `maps_en_canada` (about 10 GB).
Kiwix publishes Canada as one file, so picking any combination downloads it once. The wizard says so.
`all` downloads every different prefix in the file.

```bash
bash mac/add-maps.sh --list
bash mac/add-maps.sh --add vancouver-island,europe
bash linux/add-maps.sh --add alberta
```

Windows: `powershell -File scripts\add-maps.ps1 -Add alberta,europe`. STATUS menu item 3 opens the same list.
After a download the library restarts and `www/maps-index.js` lists the installed regions. The chat page links to
`maps.html`. On a phone (Share on Wi-Fi) that page is served by port 8091 and the map content is proxied from
Kiwix on `127.0.0.1:8090` via `/content/...`. Ollama stays on `127.0.0.1:11435`.

## USB / exFAT

Free space is read from the volume that contains the kit folder. FAT32, vfat and msdos are refused for any download
of 4 GiB or more (and for catalog entries advertised at 4 GB or more); use exFAT, NTFS or APFS. START rewrites the
Desktop shortcut so a Windows drive-letter change is picked up the next time you run START from the USB. Mac and
Linux launchers work as `bash path/to/script` when exFAT strips `+x`. If a program still cannot be executed, its
tree is copied to `~/Library/Caches/offline-ai-kit` or `~/.cache/offline-ai-kit`. Symlinks inside an unpacked
`runtime/` tree are replaced with real copies. Downloads keep the computer awake.

On macOS, `kiwix-serve` uses `mmap`. Apple's exFAT driver returns `Invalid argument` for a ZIM over 4 GB. START
explains that when the library fails to come up and a served ZIM on an exFAT or FAT volume is over 4 GB. Windows
and Linux open those files. Files under 4 GB still work. The kit does not move ZIMs into an APFS disk image.

## Check for updates

`VERSION` (repo root) and `www/version.js` hold the kit version. The chat page button and
`status.ps1 -CheckUpdates` / `bash mac/status.sh --check-updates` ask
`https://api.github.com/repos/wallenberg4001-del/offline-ai-kit/releases/latest` – only when clicked/run – and compare
versions (semver; `1.2.0-beta` < `1.2.0`). They show "up to date", "update available" with links (never download
anything), or "you appear to be offline". `OFFLINE_AI_RELEASES_API=<url>` points the STATUS check elsewhere (testing).

## Files and folders

| Path | What |
|---|---|
| `runtime/` | programs, one folder per computer: `windows-x64`, `mac-arm64`, `mac-x64`, `linux-x64`, `linux-arm64` (each holds `ollama/` and `kiwix/`; Mac also has `ollama-v0.12.9/` for macOS 13). Older folders (`ollama`, `kiwix`, `mac-ollama`, `mac-kiwix`, `mac-kiwix-intel`, `linux-ollama`, `linux-kiwix`, `linux-kiwix-arm`) still start if the new folder is empty. |
| `library/` | `.zim` files + `checksums/VERIFIED` markers (shared across Windows, Mac and Linux) |
| `ollama-models/`, `home/` | the kit's AI models and Ollama settings (shared) |
| `logs/` | logs, pid files, `wikipedia-progress.json` |
| `www/` | chat page (`chat.html`, `ask-library.js`, `maps.html`, `maps.js`, `qr.js`, `updates.js`, `version.js`, `selftest.html`); START writes `kit-config.js` and `maps-index.js`, and on Mac/Linux `wiki-status.js` |
| `catalog/` | `extra-libraries.txt` (Extra Libraries) and `maps.txt` (offline maps) |
| `VERSION` | the kit version |
| `tests/` | offline checks (`node tests/ask-library.test.js`, `node tests/phase2.test.js [--live]`, `node tests/phase3.test.js`, `node tests/universal.test.js`). Only in the GitHub repo, not in the download ZIP; not needed to run the kit |
| `linux/` | Linux launchers. They set `OFFLINE_AI_OS=linux` and run the Mac bash scripts, which then pick Linux Kiwix/Ollama builds and `ip route` for the LAN address. |
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
suggest, catalog and content responses, so the chat page can read it directly from `http://127.0.0.1:8091`, and from a `file://` page (origin `null`)
if the page was opened as a file. The kit's Ollama already allows any origin
(`OLLAMA_ORIGINS=*`). Both still listen only on `127.0.0.1`. If you point the kit at a very old kiwix-serve without
that header, the chat says it can't reach the library; untick **Ask the library** or update Kiwix by re-running setup.

**Self-test page.** With the kit running, open http://127.0.0.1:8091/selftest.html. It checks, with the real library and model:
the catalog is readable, a question (default: "How do I treat mild hypothermia?") gets an answer whose sources all open (HTTP 200), a nonsense question gives
"not in the library", and a forged `[n]` and a fake link are removed. Add `#q=your question` to try another question,
or `#model=llama3.2:3b` to pick the model. (On a Mac, macOS drops the `#…` part when the page is opened by double-click or `open`; type it into the address bar instead.) Automated tests can add `#report=http://127.0.0.1:PORT/` to receive the
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

`OFFLINE_AI_NO_BROWSER=1` (environment) stops START from opening browser windows (for automated tests).

Every setup run writes a full log to `logs/setup-YYYYMMDD-HHMMSS.log`; every START writes `logs/start-latest.log`.
Look for the lines `RESULT: SETUP OK` / `RESULT: SETUP FINISHED WITH PROBLEMS` and `RESULT: START OK`.
Other useful logs: `logs/ollama*.log`, `logs/kiwix*.log`, `logs/wikipedia-download*.log`, `logs/wikipedia-progress.json`,
`logs/zim-downloads.log`. Easy mode also creates the Desktop shortcut (delete it after testing if you like).

