# Offline AI Kit (Windows)

A "no internet needed" survival kit for your laptop:

- **An AI chat assistant** that runs completely on your own computer (on your NVIDIA GPU).
- **An offline library**: full English Wikipedia with pictures, a medical encyclopedia,
  first-aid and survival guides, water and food safety, repair guides, travel guides and more.

Once it's set up, you can unplug from the internet (or lose power to the router in a storm)
and still ask questions and look things up.

> ⚠️ The AI can be wrong. For anything medical, check the Offline Library (WikiMed,
> Wikipedia Medicine) too, and call emergency services when you can. This is not a doctor.

---

## What you need

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

## Using it with no internet

Nothing to change – just double-click `START-OFFLINE-AI.bat`. It never needs the internet after setup.
On battery, use the small models (`llama3.2:3b`, `phi4-mini`) – they're quick and gentle on power.
Keep `README-OUTAGE.txt` handy; it's the one-page version of this.

## The AI models

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
- A tiny PowerShell web server shows the chat page on `127.0.0.1:8091`. No Python needed.
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
