# Offline AI Kit (Windows and Apple Silicon Mac)

A "no internet needed" survival kit for your laptop:

- **An AI chat assistant** that runs completely on your own computer (on your NVIDIA GPU).
- **An offline library**: full English Wikipedia with pictures, a medical encyclopedia,
  first-aid and survival guides, water and food safety, repair guides, travel guides and more.

Once it's set up, you can unplug from the internet (or lose power to the router in a storm)
and still ask questions and look things up.

> ⚠️ The AI can be wrong. For anything medical, check the Offline Library (WikiMed,
> Wikipedia Medicine) too, and call emergency services when you can. This is not a doctor.

**Windows:** follow Steps 1–4 below. **Mac (M1 or newer):** jump to [Mac (Apple Silicon)](#mac-apple-silicon).

---

## What you need (Windows)

- Windows 10 (1803 or newer) or Windows 11, 64-bit.
- An NVIDIA GPU is best (built for an RTX 5070 Ti laptop with 12 GB). It also runs without one, just slower.
- Up-to-date NVIDIA driver (GeForce Experience / NVIDIA App → Drivers).
- **Disk space** (any drive works, including an external SSD):

| What | Size |
|---|---|
| Programs (Ollama + Kiwix) | ~2 GB |
| Library – **Essentials** (survival, first aid, water, food, knots, WikiMed, Appropedia) | ~4 GB |
| Library – **Recommended** (Essentials + Wikipedia Medicine, Wikivoyage, iFixit, Gardening Q&A) | ~11 GB |
| AI models – **Core** (4 models) | ~15 GB |
| AI models – **All** (7 models) | ~35 GB |
| **Full English Wikipedia** (always included, downloads in the background) | **~127 GB** |
| **Total with Recommended + All models + Wikipedia** | **~175 GB** (have ~190 GB free to be comfortable) |

- Internet for the first setup (the downloads are big: plan on an evening, plus overnight for Wikipedia).

---

## Step 1 – Get the kit onto the laptop

1. On this GitHub page click the green **Code** button → **Download ZIP**.
2. **Before unzipping:** right-click the ZIP → **Properties** → tick **Unblock** (bottom of the window) → **OK**.
   (This stops Windows from nagging about every file.)
3. Right-click the ZIP → **Extract All…** Put it where you have lots of space, for example `D:\Offline-AI-Kit`.

## Step 2 – Run setup (once, needs internet)

1. Open the folder and double-click **`SETUP.bat`**.
   - If Windows shows "Windows protected your PC", click **More info** → **Run anyway**.
2. Answer the questions (just pressing **Enter** picks the recommended choice):
   - **Folder** – keep the one shown, or type another (e.g. on an external drive).
   - **Library** – `1` Essentials or `2` Recommended.
   - **AI models** – `1` Core or `2` All.
3. Wait. It downloads the programs, the library and the AI models, and **checks every file**
   against the official checksum so nothing is corrupted. If the internet drops, just run
   `SETUP.bat` again – it picks up where it stopped.

## Step 3 – Start it

Double-click **`START-OFFLINE-AI.bat`**. Your browser opens two tabs:

- **Chat** – http://127.0.0.1:8091/chat.html – pick a model from the drop-down and ask away.
- **Offline Library** – http://127.0.0.1:8090/ – search and read Wikipedia, WikiMed, survival guides, etc.

You can close the black window; the kit keeps running in the background.

### 📚 Full Wikipedia downloads by itself the first time

Full English Wikipedia (~127 GB) is **always** part of the kit. Because it is so big, it is not
downloaded during setup. Instead:

- The **first time you run `START-OFFLINE-AI.bat`**, if Wikipedia isn't downloaded and verified yet,
  it **automatically starts downloading in the background** in a small minimised window on the
  taskbar (it shows GB done, percent, speed and time left). The chat page also shows a progress line at the top.
- **Everything else works normally while it downloads.**
- It checks free space first. If the drive has less than ~140 GB free it warns you; if there isn't
  enough room at all it doesn't start, and tells you how much space to free up.
- It **resumes** if you close it, lose internet, or restart the laptop – just run
  `START-OFFLINE-AI.bat` again and it continues where it left off.
- When it finishes, it checks the file's SHA256 checksum from Kiwix (takes 10–30 minutes on a big file),
  marks it verified, and **restarts the library by itself** so Wikipedia appears. Nothing else to do.
- Depending on your internet this can take many hours (127 GB at 50 Mbit/s ≈ 6 hours; at 10 Mbit/s ≈ 1.5 days).
  Leave the laptop plugged in with sleep turned off until it's done.

## Step 4 – Stop it

Double-click **`STOP-OFFLINE-AI.bat`**. (A half-finished Wikipedia download is kept and continues next start.)

`STATUS.bat` shows what's running and how far the Wikipedia download has got.

---

## Mac (Apple Silicon)

Same kit, same library, same chat page – just different double-click files ending in `.command`.

### What you need (Mac)

- A Mac with **Apple Silicon (M1, M2, M3, M4 or newer)**.
- **macOS 14 Sonoma or newer** (Ollama needs it).
- **~190 GB free** for everything (setup ~10–65 GB depending on choices, plus ~127 GB for full Wikipedia).
  An external SSD is fine.
- Internet for the first setup.

The Mac's memory (RAM) is shared between the computer and the AI, so setup checks how much
your Mac has ( → About This Mac) and suggests a model set:

| Your Mac's memory | Set | Models | Download |
|---|---|---|---|
| 8 GB | Small | `llama3.2:3b`, `phi4-mini`, `medgemma:4b` | ~8 GB |
| 16 GB | Medium | Small + `qwen3.5:9b`, `gemma3:4b` | ~18 GB |
| 24 GB or more | Large | Medium + `gemma3:12b`, `qwen3:14b` | ~35 GB |
| 32 GB or more (optional) | Largest | Large + `qwen3:30b` (18.6 GB) | ~54 GB |

### Step 1 – Get the kit

1. On this GitHub page click **Code** → **Download ZIP**. Safari unzips it into **Downloads** automatically
   (otherwise double-click the ZIP).
2. Move the `offline-ai-kit-main` folder where you want it (e.g. your home folder or an external SSD).

### Step 2 – Run setup (once, needs internet)

The easiest way (works every time, no security pop-ups):

1. Open **Terminal** (press ⌘-Space, type *Terminal*, press Return).
2. Type `bash ` (with a space after it), then **drag `SETUP-MAC.command` from the folder into the Terminal window**, and press **Return**.
3. Answer the questions (Return picks the suggested choice): folder, library tier, model set.

Setup downloads the programs (Kiwix for macOS and Ollama for macOS from their official sites),
the library and the models, and checks every file against its official checksum. If the internet
drops, run it again – it picks up where it stopped. It also fixes the files so that from now on you
can simply **double-click** the `.command` files.

> **If you double-click a `.command` file before running setup:** macOS may say it "cannot be opened"
> or is "from an unidentified developer". Either **right-click (or Control-click) → Open → Open**, or go to
> ** → System Settings → Privacy & Security**, scroll down and click **Open Anyway**. If it says you don't
> have permission, use the Terminal method above (`bash` + drag the file) – that always works.

### Step 3 – Start, stop, status

- **`START-OFFLINE-AI-MAC.command`** – starts everything and opens the chat page and the Offline Library.
- **`STOP-OFFLINE-AI-MAC.command`** – stops everything.
- **`STATUS-MAC.command`** – shows what's running and live Wikipedia download progress.

(You can always run any of them as `bash START-OFFLINE-AI-MAC.command` in Terminal.)

**Full Wikipedia works the same as on Windows:** the first START begins downloading it (~127 GB) in the
background after checking free space (warns under ~140 GB, refuses if it can't fit), keeps the Mac awake
while it downloads (plug it in), resumes if interrupted, checks the SHA256, and then restarts the library
by itself so Wikipedia appears. Progress shows in `STATUS-MAC.command` and at the top of the chat page.

### Mac notes

- The chat page is opened straight from the kit folder (`www/chat.html`) instead of from a little web server,
  because new Macs don't come with Python or another dependable built-in web server. The kit's own Ollama is
  set to accept requests from that page. Everything still only listens on `127.0.0.1` (this Mac).
- Use **Chrome, Safari or Firefox**; if Safari won't connect, try Chrome or Firefox.
- The kit's Ollama runs on port 11435 with its models in `ollama-models/` and its settings in `home/`;
  an Ollama app you installed yourself (port 11434) is never touched.
- One kit folder on an external drive can be used from **both** Windows and Mac: the library and models are
  shared; each system keeps its own programs in `runtime/`.

---

## Using it with no internet

Nothing to change – just double-click `START-OFFLINE-AI.bat` (Mac: `START-OFFLINE-AI-MAC.command`). It never needs the internet after setup.
On battery, use the small models (`llama3.2:3b`, `phi4-mini`) – they're quick and gentle on power.
Keep `README-OUTAGE.txt` handy; it's the one-page version of this.

## The AI models (Windows)

All run on a 12 GB laptop GPU. Bigger = smarter but slower and more power-hungry.

| Model | Download | Good for |
|---|---|---|
| `qwen3.5:9b` (default) | 6.6 GB | Best all-rounder; fits fully in GPU memory with room to spare |
| `llama3.2:3b` | 2.0 GB | Fastest, battery saver |
| `phi4-mini` | 2.5 GB | Small and practical |
| `medgemma:4b` | 3.3 GB | Medical-tuned (still double-check in the library) |
| `gemma3:4b` *(All)* | 3.3 GB | Light model |
| `gemma3:12b` *(All)* | 8.2 GB | Stronger answers |
| `qwen3:14b` *(All)* | 9.3 GB | Strongest; uses most of the 12 GB GPU |

Only one model is loaded at a time, so they don't add up in GPU memory.

## How it works (for the curious)

- **Kiwix** (`kiwix-serve`) serves the `.zim` library files on `127.0.0.1:8090`. Only files whose
  SHA256 checksum matched are served (a marker is written in `library\checksums\VERIFIED`).
- A **portable Ollama** runs the AI models on `127.0.0.1:11435`. Models, settings and keys stay
  inside the kit folder (`ollama-models\`, `home\`). It does **not** touch a normal Ollama install
  (which uses port 11434), so you can have both.
- On Windows a tiny PowerShell web server shows the chat page on `127.0.0.1:8091`. No Python needed.
  On Mac the page is opened directly from the kit folder (see Mac notes).
- Everything listens only on `127.0.0.1` (this computer), not your network.
- To move the kit to another drive, stop it and move the whole folder. Nothing is installed in Windows.
- Program and library versions are looked up when you run setup, so you get the newest ones.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Windows protected your PC" | **More info → Run anyway**. Or unblock the ZIP before extracting (Step 1). |
| A red error in the black window | Read the message (it says what to do). Administrator rights are *not* needed. Most problems are fixed by running the same `.bat` again. |
| "curl.exe was not found" | Run Windows Update (curl is built into Windows 10 1803+ / 11). |
| Setup stopped half way | Run `SETUP.bat` again. Finished files are skipped, partial ones resume. |
| Chat says "Cannot reach the local model server" | Run `START-OFFLINE-AI.bat`. Check `logs\ollama.log`. |
| Answers are very slow | Pick a smaller model. Make sure the laptop is plugged in and on its performance mode. Update the NVIDIA driver. |
| Library page won't open | Check `logs\kiwix.log`. Another program may be using port 8090. |
| Wikipedia isn't in the library yet | Run `STATUS.bat` to see progress. It appears automatically when the download and check finish. |
| Wikipedia says "not enough free space" | Free up space (or move the kit folder to a bigger drive) and start again. It resumes. |
| A file "was damaged and deleted" | Run `SETUP.bat` (or `START` for Wikipedia) again to re-download it. |
| Want a fresh start | Run `STOP-OFFLINE-AI.bat`, then delete the folders `runtime`, `library`, `ollama-models`, `home`, `logs`. |

## Credits & licences

This kit is just glue scripts (MIT licence, see `LICENSE`). It downloads:
[Ollama](https://github.com/ollama/ollama) (MIT), [Kiwix tools](https://github.com/kiwix/kiwix-tools) (GPL-3.0),
library content from [download.kiwix.org](https://download.kiwix.org/zim/) (Wikipedia etc., CC BY-SA and others),
and AI models from the [Ollama library](https://ollama.com/library), each under its own licence.
