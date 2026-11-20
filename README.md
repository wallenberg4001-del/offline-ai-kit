# Offline AI Kit

A chat assistant (AI) and a big reference library – including all of Wikipedia – that work on your own
computer with **no internet**. Set it up once, then it works during power cuts, storms, or anywhere with no signal.

## 👉 Which one do I need?

There is **one file to double-click**. Pick the line that matches your computer:

| Your computer | Double-click this file | Notes |
|---|---|---|
| 🪟 **Windows PC** | **`EASY-INSTALL (Windows).bat`** | |
| 🍎 **Mac with an Apple chip** (M1, M2, M3, M4, M5) | **`EASY-INSTALL (Mac).command`** | Fastest Mac version. |
| 🍏 **Older Mac with an Intel chip** | **the same `EASY-INSTALL (Mac).command`** | It works out which Mac you have by itself. The AI answers more slowly on Intel Macs. |
| 🐧 **Linux** | **`EASY-INSTALL (Linux).sh`** | In a terminal: `bash "EASY-INSTALL (Linux).sh"`. No questions. |

### Two ways to install – pick one

| I want… | Windows | Mac (Apple chip or Intel) | Linux |
|---|---|---|---|
| ⚡ **No questions** – just set it up with good choices for my computer | **`EASY-INSTALL (Windows).bat`** | **`EASY-INSTALL (Mac).command`** | **`EASY-INSTALL (Linux).sh`** |
| 🧭 **To choose my features** step by step (Setup Wizard) | **`SETUP.bat`** | **`SETUP-MAC.command`** | **`SETUP-LINUX.sh`** |

**EASY-INSTALL** picks the AI size for your computer, includes full Wikipedia (if there's room), leaves
"Share on Wi-Fi" **off**, adds no extra libraries and downloads **no maps**. You can change all of that later with **STATUS**.

**SETUP (the Setup Wizard)** asks, one screen at a time, before anything downloads:
1. **AI model size** – it shows your computer and suggests the right size (press Enter to accept).
2. **Core library** – Essentials (~4 GB) or Recommended (~11 GB).
3. **Full English Wikipedia** (~127 GB, downloads in the background on first start) – Yes or No.
4. **Extra Libraries** – optional extras such as Wiktionary, Project Gutenberg books, Stack Exchange Q&A and
   preparedness guides (type numbers like `1,3`, or `all`, or just press Enter for none).
5. **Share on home Wi-Fi** for phones and tablets – off unless you say yes.
6. **Offline maps** – optional. Vancouver Island, British Columbia, Alberta and Saskatchewan are inside the one Canada map
   (about 10 GB). Kiwix publishes Canada as one file, so picking any combination, or Canada itself, downloads it once.
   Other regions are separate files. Press Enter for none. Easy Install skips this.
7. **Which computers** – **This computer only**, or **All computers (universal drive)**. Universal downloads the
   programs for Windows, Mac (Apple chip and Intel) and Linux (64-bit PC and ARM) so one exFAT drive works on each.
   Models, Wikipedia, extra libraries and maps stay **one shared copy**. The summary shows the extra disk space
   (about 5.5 GB more on Windows, about 7 GB more on Mac and Linux, on top of this computer's programs).
8. **Summary** – every choice, the total download size and your free space, then **Proceed? (Y/N)**.

**How do I check which Mac I have?** Click the **Apple menu** () in the top-left corner, then **About This Mac**.
- If you see **Chip: Apple M1** (or M2, M3, M4, M5), you have an **Apple chip**.
- If you see **Processor: … Intel …**, you have an **Intel Mac**.

**How do I check if I have a PC?** If your computer runs **Windows** (it has a Start button with the Windows logo),
it is a PC. Use the Windows file.

## How to get it

1. **Download the kit:** go to the **[latest release](https://github.com/wallenberg4001-del/offline-ai-kit/releases/latest)**
   and click **`Offline-AI-Kit-x.y.z.zip`** under **Assets** (for example `Offline-AI-Kit-1.3.0.zip`).
   *(Or, on this page, click the green **Code** button, then **Download ZIP**. That works too.)*
2. **Unzip it.**
   - **Windows:** right-click the ZIP, choose **Properties**, tick **Unblock**, click **OK**.
     Then right-click the ZIP again and choose **Extract All…**
   - **Mac:** Safari unzips it for you into **Downloads**. (If not, double-click the ZIP.)
3. Open the folder and **double-click the file for your computer** (see the table above).
   - Windows may say **"Windows protected your PC"**. Click **More info**, then **Run anyway**.
   - A Mac may say it **"cannot be opened"**. **Right-click** the file (or hold Control and click), choose **Open**, then **Open** again.
     More help is in [`START-HERE.txt`](START-HERE.txt).

## What happens next, and how long it takes

- A window opens and shows what it is doing. **There are no questions to answer.**
- It looks at your computer and picks the right size of everything by itself.
- It downloads the programs, the library and the AI. **This usually takes 1–3 hours.** Keep the computer plugged in and online.
- When it is done, your web browser opens with the **chat** and the **library**.
- An **Offline AI** shortcut appears on your Desktop. Double-click it next time.
- **Full Wikipedia** then downloads quietly in the background. That can take from about an hour to a day or two,
  depending on your internet. Everything else works while it downloads.
- If the internet drops, double-click the same file again. It carries on where it stopped.

## What you need

- **Windows PC:** Windows 10 or 11 (64-bit). An NVIDIA graphics card makes the AI faster, but is not needed.
- **Mac with an Apple chip:** macOS 13 (Ventura) or newer. (macOS 14 or newer gets the newest AI program. On macOS 12, only the library is installed.)
- **Intel Mac:** macOS 13 (Ventura) or newer for the AI. On macOS 12 (Monterey), only the library is installed.
- **Memory:** 8 GB works. 16 GB or more is better.
- **Internet:** only once, for setup.
- **Free disk space** – it picks a size that fits, and skips Wikipedia if there isn't room:

| Version (picked for you) | Library | AI models | Space needed | With full Wikipedia |
|---|---|---|---|---|
| Small computers (LITE) | Essentials (~4 GB) | 2 small models | ~10–12 GB | ~150 GB |
| Intel Mac | Recommended (~11 GB) | 2–3 small models | ~20 GB | ~160 GB |
| Most computers (STANDARD) | Recommended (~11 GB) | 4–5 models | ~28 GB | ~170 GB |
| Strong computers (FULL / LARGE) | Recommended (~11 GB) | 7 models | ~47–50 GB | ~190 GB |
| Big Macs, 32 GB+ (LARGEST) | Recommended (~11 GB) | 8 models | ~66 GB | ~205 GB |

An external drive (USB SSD) is fine. Copy the unzipped folder onto it first, then double-click from there.

---

## What is this?

**Offline AI Kit** turns an ordinary laptop or desktop into a little "know-it-all" that works with **no internet at all**:

1. **A chat assistant (AI)** – like ChatGPT, but it runs entirely on your own computer. Ask it how to purify water,
   treat a burn, fix a leaking pipe, cook without power, or anything else. Nothing you type ever leaves the computer.
   By default it **looks the answer up in the offline library first** and shows the articles it used, as clickable
   numbers like **[1] [2]** (see [Ask the library](#ask-the-library-answers-with-sources)).
2. **An offline library** you can search and read in your web browser – including **all of English Wikipedia with
   pictures**, a medical encyclopedia, first-aid and survival guides, and repair manuals.

## Why would I want it?

- **Power cuts, storms, wildfires, earthquakes** – the internet and phone networks are often the first things to go,
  exactly when you most need answers.
- **Cabins, boats, RVs and remote places** with poor or no signal.
- **Privacy** – your questions stay on your computer.
- **Peace of mind** – a whole reference library that can't be taken offline, paywalled or changed.

## What's included

| | What it is | Size |
|---|---|---|
| 🤖 **AI assistant** | 2–8 free, open AI models (picked to suit your computer), including a medical-tuned one | 5–55 GB |
| 📚 **Wikipedia** | All ~7 million English Wikipedia articles **with pictures** | ~127 GB |
| 🩺 **Medical** | WikiMed medical encyclopedia, Wikipedia Medicine, survival medicine guides | ~4 GB |
| 🏕️ **Survival** | Post-disaster library, water, food preparation & preserving, USDA canning, knots, Appropedia low-tech how-tos | ~1.5 GB |
| 🔧 **Repair & more** | iFixit repair guides, gardening Q&A, Wikivoyage travel guide | ~5.5 GB |

Everything is free and comes from the official sources (Kiwix, Ollama). Every file is checked against its official
fingerprint (checksum) so nothing is damaged or tampered with.

## Want choices, or more control?

- **Want to choose for yourself?** Use the **Setup Wizard** instead: `SETUP.bat` on Windows, `SETUP-MAC.command` on Mac
  (see [Two ways to install](#two-ways-to-install--pick-one)).
- **Already installed?** Double-click **STATUS** (`STATUS.bat` / `STATUS-MAC.command`). Besides showing what's running,
  it has a small menu: **turn Share on Wi-Fi on/off**, **add Extra Libraries**, and **check for updates**.
- **Power user?** See [ADVANCED.md](ADVANCED.md) for options, `kit-settings.ini`, ports, and using your own Ollama.

## 📱 Use it on phones and tablets (Share on Wi-Fi)

Off by default. When it's on, phones, tablets and other computers **on the same home Wi-Fi** can use the chat and
the library in their web browser – handy in a power cut when the laptop is the only "smart" thing with a battery.

- **Turn it on:** double-click **STATUS** and choose **1) Turn Share on Wi-Fi ON** (or say yes in the Setup Wizard).
  It takes effect straight away; turn it off the same way.
- **Connect a phone:** the chat page on the computer shows the address (like `http://192.168.1.20:8091`) and a
  **QR code**. Point the phone's camera at the QR code, or type the address into the phone's browser.
  START and STATUS print the address too.
- ⚠️ **Only turn it on at home on Wi-Fi you trust – never on public Wi-Fi** (cafés, hotels, airports). Anyone on
  the same Wi-Fi can open the chat and the library. There is no password.
- **What stays private:** the AI program itself always listens only to the computer it runs on. Phones reach it
  through the chat page, which only allows chatting – not downloading, deleting or changing AI models.
- **Phone can't connect?**
  - Windows: the first time, Windows may ask whether to allow **Windows PowerShell** – tick
    **Private networks** and click **Allow**. Your home network must be set to **Private** (Settings → Network &
    internet → your Wi-Fi or Ethernet → **Private network**). Allowing apps through the firewall needs an
    administrator account.
  - Mac: if the Mac asks whether **perl** may "accept incoming connections", click **Allow**.
  - Make sure the phone is on the **same Wi-Fi** (not mobile data, not a guest network).

## 📚 Extra Libraries

Optional collections you can add any time: double-click **STATUS** and choose **2) Add Extra Libraries**, then type
the numbers you want. They download from the official Kiwix server (resuming if interrupted), are checked with their
SHA-256 fingerprint, and appear in the library and in **Ask the library** straight away.

| # | Collection | Size (Nov 2026) |
|---|---|---|
| 1 | Sustainable Living Q&A (Stack Exchange) | 26 MB |
| 2 | Simple English Wiktionary (dictionary) | 30 MB |
| 3 | Lifehacks Q&A | 47 MB |
| 4 | Medical Sciences Q&A | 58 MB |
| 5 | Amateur (ham) Radio Q&A | 74 MB |
| 6 | The Great Outdoors / survival Q&A | 135 MB |
| 7 | Cooking Q&A | 227 MB |
| 8 | Car and motor repair Q&A | 326 MB |
| 9 | TruePrepper emergency preparedness guides | 1.3 GB |
| 10 | Ready.gov (US government emergency preparedness) | 1.9 GB |
| 11 | Home Improvement / DIY Q&A | 1.9 GB |
| 12 | Project Gutenberg books: Medicine | 1.9 GB |
| 13 | Wikibooks: free textbooks and manuals (no pictures) | 3.3 GB |
| 14 | Project Gutenberg books: Agriculture | 4.2 GB |
| 15 | Project Gutenberg books: Technology | 12 GB |
| 16 | English Wiktionary (full dictionary, no pictures) | 14 GB |
| 17 | **All** of Project Gutenberg in English | **206 GB** |

Sizes change a little with each new edition. wikiHow is not offered because Kiwix no longer publishes it.
The list lives in `catalog/extra-libraries.txt`.

## Offline maps

Optional regional maps you can add in the Setup Wizard (step 6) or any time from **STATUS → 3) Add offline maps**.
They are clean offline browser maps from Kiwix (`zim/maps` on download.kiwix.org): the same mirror choice, resume
and SHA-256 check as the rest of the library. Easy Install does not ask and does not download them.

Vancouver Island, British Columbia, Alberta and Saskatchewan are easy choices. Kiwix publishes Canada as one file
(`maps_en_canada`, about 10 GB), so picking any combination of those, or `canada`, downloads that file once.
Other regions (United States, North America, Central and South America, the United Kingdom, Europe, the Nordics,
France, Germany, Italy, Switzerland, Australia, New Zealand, Australia and Oceania, Asia, Southeast Asia, Africa,
and the whole world) are their own files.

Open **Offline maps** on the chat page. With Share on Wi-Fi, a phone opens the same page through the chat address
(port 8091). The map program itself stays on this computer.

## 🔄 Check for updates

The chat page has a **Check for updates** button (and STATUS has **4) Check for updates**). It only runs when you
click it – the kit never contacts the internet on its own. It tells you whether you have the newest version; if a
newer one exists it shows a link to what's new and to the download. **Nothing is downloaded or changed for you.**
With no internet it simply says so – the kit doesn't need internet to run.

**Updating:** download the new ZIP, unzip it, then move your `library`, `ollama-models` and `runtime` folders (and
`kit-settings.ini`, if you have one) from the old kit folder into the new one. Run **STOP** on the old one first.

## FAQ

**Does it really work with no internet?** Yes. After setup, unplug the router and try it.

**Is it free?** Yes. The kit, the AI models and the library are all free. No subscriptions, no accounts.

**Is my data private?** Yes. Everything runs on your computer and only listens to your own computer (`127.0.0.1`), not the network –
unless you turn on [Share on Wi-Fi](#-use-it-on-phones-and-tablets-share-on-wi-fi), which opens the chat page and library (never the AI program itself) to your home Wi-Fi.

**Can my family use it on their phones?** Yes – turn on [Share on Wi-Fi](#-use-it-on-phones-and-tablets-share-on-wi-fi) and scan the QR code on the chat page. Home Wi-Fi only.

**How long does setup take?** Usually 1–3 hours for the main part (depends on your internet), then Wikipedia keeps
downloading in the background – from about an hour to a day or two. Everything else works meanwhile.

**I have an older Intel Mac. Will it work?** Yes, with macOS 13 (Ventura) or newer. The AI runs on the Mac's processor,
so answers are slower – often 10 to 60 seconds. The library is just as fast as on any other computer.
On macOS 12 (Monterey) you get the library only. Older than macOS 12 is not supported.

**Which file do I double-click on a Mac?** Always `EASY-INSTALL (Mac).command`. It works on Apple-chip and Intel Macs.

**Will it slow down or change my computer?** No. Nothing is installed into Windows or macOS; it all lives in one folder.
It only uses the computer while it's running, and STOP turns it off. To remove it, delete the folder.

**Is the AI always right?** No – it can make mistakes. For medical or safety questions, also check the library, and call
emergency services when you can. The kit is a helper, not a doctor.

**What are the [1] [2] numbers in answers?** They are the library articles the answer came from. Click one to read
that article. The kit checks every number: it only ever shows articles it really opened from your library, and it
removes any number or link the AI made up. If the library has nothing on your question, it says so, and offers an
answer from the AI's own memory instead – clearly marked as **not** from the library.

**Can I turn the sources off?** Yes. Untick **Ask the library** at the top of the chat page. The AI then answers from
its memory only (faster, but more likely to be wrong).

**Can I put it on a USB/external drive?** Yes. Use exFAT, NTFS or APFS (not FAT32). See [Running from a USB drive](#running-from-a-usb-drive).

**Do I need a gaming PC?** No. Lighter computers get the LITE version automatically (smaller library, two small AI models).

**Windows/Mac warns me the file is from the internet – is that OK?** Yes; it does that for any downloaded script.
See `START-HERE.txt` for exactly what to click.

**Can I share it?** Yes – it's MIT-licensed. Send the folder or the download link to anyone.

## Running from a USB drive

The whole kit folder can live on one USB drive and run on Windows, Mac and Linux. Format the drive as **exFAT**
(or NTFS, or APFS). **FAT32 cannot store a file larger than 4 GB**, so setup refuses Wikipedia, the bigger
libraries and the maps on a FAT32 drive and tells you to use exFAT, NTFS or APFS.

- **Where it looks for free space.** The free-space check uses the drive the kit folder is on, including when Windows gives that drive a different letter the next time you plug it in.
- **Drive letters.** Paths inside the kit are relative to the folder. The Desktop shortcut stores a full path, and **START** rewrites that shortcut every time, so run START from the USB after the letter changes.
- **Execute permission on Mac and Linux.** exFAT often drops the execute bit, or refuses to run a program directly. Shell launchers still work. Start with `bash "/Volumes/YOURDRIVE/.../START-OFFLINE-AI-MAC.command"` or `bash "/media/.../START-OFFLINE-AI-LINUX.sh"`. If Kiwix or Ollama cannot be executed from the USB, the kit copies that program folder to a local cache (`~/Library/Caches/offline-ai-kit` on a Mac, `~/.cache/offline-ai-kit` on Linux) and runs the copy. Your library and models stay on the USB. The kit prints the exact `bash` command when it has to do this.
- **No symlinks.** After each unpack the kit turns any symlink inside `runtime/` into a real copy, so the folder stays valid on exFAT. A universal drive stores a real copy of the Mac AI program in both Mac folders (the upstream file is one universal binary).
- **Which programs run.** START, STATUS and STOP look at the processor and pick `runtime/windows-x64`, `runtime/mac-arm64`, `runtime/mac-x64`, `runtime/linux-x64` or `runtime/linux-arm64`. If that folder has no programs, they say so in plain English and tell you to run SETUP while online and choose **All computers (universal drive)** (or **This computer only**). Older folders (`runtime/ollama`, `runtime/mac-ollama`, `runtime/linux-ollama`, and the matching Kiwix folders) still work for the computer they were built for.
- **Execute bit and quarantine.** Launchers are started with `bash` or PowerShell, not by relying on the execute bit. If Mac or Linux cannot run a program directly from exFAT, the kit copies that program folder to a local cache and runs the copy. On a Mac it also clears the quarantine flag on those programs.
- **Stay awake.** Setup and the big downloads ask the computer not to sleep (Windows execution state, `caffeinate` on a Mac, `systemd-inhibit` on Linux when it is installed).
- **Large files and a Mac.** `kiwix-serve` on macOS opens a ZIM with `mmap`. Apple's exFAT driver fails that call once a file is over 4 GB (`Invalid argument`). Windows and Linux open those same files. On a Mac, keep files over 4 GB on APFS or the internal disk. Files under 4 GB on the USB still open. The kit does not hide the ZIMs in a Mac-only disk image, because that would break the one-drive setup for Windows and Linux. If the library fails to start for this reason, START says so.

---

> ⚠️ The AI can be wrong. For anything medical, check the Offline Library (WikiMed,
> Wikipedia Medicine) too, and call emergency services when you can. This is not a doctor.

**The rest of this page is the detailed guide for SETUP (the Setup Wizard, the version with questions).**
**Windows:** Steps 1–4 below. **Mac (Apple chip or Intel):** jump to [Mac](#mac-apple-chip-or-intel).

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
2. Answer the Setup Wizard's questions (just pressing **Enter** picks the suggested choice):
   - **Folder** – keep the one shown, or type another (e.g. on an external drive).
   - **Step 1 – AI model size** – `0` Lite, `1` Core or `2` All (it suggests one for your PC).
   - **Step 2 – Core library** – `1` Essentials or `2` Recommended.
   - **Step 3 – Full English Wikipedia** – `Y` or `N`.
   - **Step 4 – Extra Libraries** – numbers like `1,3`, `all`, or Enter for none.
   - **Step 5 – Share on home Wi-Fi** – `N` (default) or `Y`.
   - **Step 6 – Offline maps** – numbers like `1,4`, `all`, or Enter for none. Vancouver Island, British Columbia, Alberta, Saskatchewan and Canada share one file.
   - **Step 7 – Summary** – check the sizes and free space, then `Y` to start downloading (`N` changes nothing).
3. Wait. It downloads the programs, the library and the AI models, and **checks every file**
   against the official checksum so nothing is corrupted. If the internet drops, just run
   `SETUP.bat` again – it picks up where it stopped.

## Step 3 – Start it

Double-click **`START-OFFLINE-AI.bat`**. Your browser opens two tabs:

- **Chat** – http://127.0.0.1:8091/chat.html – pick a model from the drop-down and ask away.
- **Offline Library** – http://127.0.0.1:8090/ – search and read Wikipedia, WikiMed, survival guides, etc.

You can close the black window; the kit keeps running in the background.

### 📚 Full Wikipedia downloads by itself the first time

Full English Wikipedia (~127 GB) is part of the kit (unless there isn't room, or you switched it off – LITE machines are asked). Because it is so big, it is not
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
- Before each big download the kit times a few official Kiwix mirrors for a few seconds and uses the fastest one
  (some mirrors are very slow). If that server slows down a lot later, it switches. The SHA256 check always uses
  the checksum from download.kiwix.org, so a mirror cannot slip in a bad file.
  Leave the laptop plugged in with sleep turned off until it's done.

## Step 4 – Stop it

Double-click **`STOP-OFFLINE-AI.bat`**. (A half-finished Wikipedia download is kept and continues next start.)

`STATUS.bat` shows what's running and how far the Wikipedia download has got.

---

## Mac (Apple chip or Intel)

Same kit, same library, same chat page – just different double-click files ending in `.command`.
The Mac scripts work out by themselves whether your Mac has an Apple chip or an Intel chip, and download the right programs.

### What you need (Mac)

| | Mac with Apple chip (M1–M5) | Intel Mac |
|---|---|---|
| **macOS** | 13 Ventura or newer (14 Sonoma+ gets the newest Ollama); on 12 Monterey, library only | 13 Ventura or newer for the AI; on 12 Monterey, library only |
| **AI speed** | Fast – uses the Apple GPU | Slower – runs on the processor (often 10–60 s per answer) |
| **Models** | By memory, see the table below | `llama3.2:3b`, `medgemma:4b`, plus `phi4-mini` with 16 GB+ |
| **Library** | Recommended (Essentials if under 16 GB) | Recommended (Essentials if the disk is tight) |

- **~190 GB free** for everything on Apple-chip Macs (setup ~10–65 GB, plus ~127 GB for full Wikipedia); ~160 GB on Intel Macs.
  An external SSD is fine.
- Internet for the first setup.

On Apple-chip Macs the memory (RAM) is shared between the computer and the AI, so setup checks how much
your Mac has ( → About This Mac) and picks a model set:

| Your Mac's memory | Set | Models | Download |
|---|---|---|---|
| 8 GB | Small | `llama3.2:3b`, `phi4-mini`, `medgemma:4b` | ~8 GB |
| 16 GB | Medium | Small + `qwen3.5:9b`, `gemma3:4b` | ~18 GB |
| 24 GB or more | Large | Medium + `gemma3:12b`, `qwen3:14b` | ~35 GB |
| 32 GB or more (optional) | Largest | Large + `qwen3:30b` (18.6 GB) | ~54 GB |

On macOS 13 the kit uses Ollama v0.12.9 (the last one made for macOS 13; its checksum is built into the kit),
and swaps `qwen3.5:9b` for `qwen3:8b`, which that version can run.

### Step 1 – Get the kit

1. On this GitHub page click **Code** → **Download ZIP**. Safari unzips it into **Downloads** automatically
   (otherwise double-click the ZIP).
2. Move the `offline-ai-kit-main` folder where you want it (e.g. your home folder or an external SSD).

### Step 2 – Run setup (once, needs internet)

The easiest way (works every time, no security pop-ups):

1. Open **Terminal** (press ⌘-Space, type *Terminal*, press Return).
2. Type `bash ` (with a space after it), then **drag `SETUP-MAC.command` from the folder into the Terminal window**, and press **Return**.
   (For no questions at all, drag `EASY-INSTALL (Mac).command` instead.)
3. Answer the Setup Wizard's questions (Return picks the suggested choice): folder, then AI model size, core library,
   full Wikipedia, Extra Libraries, Share on home Wi-Fi, and a summary with **Proceed? (Y/N)** before anything downloads.

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
- With **Share on Wi-Fi** on, the Mac also runs a tiny web server for phones (port 8091), using the `perl` that is
  built into macOS (no Python or developer tools needed), and the chat page opens from `http://127.0.0.1:8091`.
- Use **Chrome, Safari or Firefox**; if Safari won't connect, try Chrome or Firefox.
- The kit's Ollama runs on port 11435 with its models in `ollama-models/` and its settings in `home/`;
  an Ollama app you installed yourself (port 11434) is never touched.
- **Apple chip or Intel** is read from the hardware (`sysctl hw.optional.arm64`), so an Apple-chip Mac whose Terminal
  runs under Rosetta still gets the fast Apple-chip programs. Kiwix comes from `kiwix-tools_macos-arm64` or
  `kiwix-tools_macos-x86_64`; Ollama's `ollama-darwin.tgz` contains both.
- One kit folder on an external drive can be used from Windows, Apple-chip Macs, Intel Macs **and Linux**. Choose **All computers (universal drive)** in SETUP so the programs for each are downloaded. The library and models are shared. Programs live in `runtime/windows-x64`, `runtime/mac-arm64`, `runtime/mac-x64`, `runtime/linux-x64` and `runtime/linux-arm64`. See [Running from a USB drive](#running-from-a-usb-drive).

## Linux

Same kit and the same Setup Wizard. In a terminal, from the kit folder:

```bash
bash "EASY-INSTALL (Linux).sh"     # no questions
bash SETUP-LINUX.sh                # wizard, including optional maps
bash START-OFFLINE-AI-LINUX.sh
bash STATUS-LINUX.sh
bash STOP-OFFLINE-AI-LINUX.sh
```

Linux downloads `kiwix-tools_linux-x86_64` or `kiwix-tools_linux-aarch64` (the musl build when `ldd --version` says musl) and `ollama-linux-amd64` or `ollama-linux-arm64` (`.tgz`, or `.tar.zst` when that is the file the release publishes). The chat page server is `mac/serve-chat.py`. The address phones use comes from `ip route get` (the `src` address). Ollama stays on `127.0.0.1:11435` and Kiwix on `127.0.0.1:8090`. Port 8091 is open to the network only when Share on Wi-Fi is on. On x86_64, Easy Install uses the smaller CPU-sized models (same idea as an Intel Mac); the wizard can choose a larger set.

---

## Ask the library (answers with sources)

The chat page has a switch at the top: **Ask the library (answers with sources)**. It is **on** by default.

When it is on, each question goes like this:

1. The kit searches your Offline Library – WikiMed, Wikipedia Medicine, iFixit, Appropedia, Wikivoyage, gardening
   Q&A and, once it has downloaded, **full Wikipedia** – using the library's own search.
2. It opens the best few articles and keeps the parts that match your question.
3. The AI writes the answer **only from those parts**, putting **[1]**, **[2]** after each point.
4. Under the answer you get the list of articles. Click a number or a title to read the article itself.

Safety checks:

- **Only real sources.** Every number is checked against the articles the kit actually opened. A number that doesn't
  match one of them, or a web link, is removed (the answer then says so). The list only ever shows articles from your library.
- **Not in the library?** It tells you, and gives you a button to get an answer from the AI's memory instead. That
  answer is labelled **"from the AI's memory (not the library)"**.
- Medical answers keep the **"not medical advice – call your emergency number"** note.

Good to know:

- Some survival collections (knots, water, food, medicine and post-disaster guides) are **PDF and picture
  collections**. The chat can't read inside those, but you can still open them in the Offline Library.
- Asking the library takes a few seconds longer than a plain answer. Small models (like `llama3.2:3b`) sometimes
  forget to add numbers; the kit then lists the articles it gave the AI so you can still check.
- Short, specific questions work best ("how to treat a burn", "purify water with bleach").

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
- **Share on Wi-Fi** (off by default): only the chat page server (port 8091) listens on the home network. It passes
  chat requests on to the AI program and library pages on to Kiwix. The AI program (port 11435) and the library
  (port 8090) always stay on `127.0.0.1`; only chat/list requests and read-only library pages are passed through. The QR code is made inside the page, offline.
- **Ask the library** is plain JavaScript in the chat page (`www/ask-library.js`). It uses Kiwix's built-in search,
  reads the articles straight from Kiwix, and sends them to the kit's Ollama. No extra programs, no extra index.
- Unless Share on Wi-Fi is on, everything listens only on `127.0.0.1` (this computer), not your network.
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
| Chat says it "couldn't reach the Offline Library" | The library is still starting or has no files yet. Wait a minute and ask again, or untick **Ask the library**. |
| Chat says "not in the offline library" for everything | Try other, simpler words. Check the library opens at http://127.0.0.1:8090/. Open `www/selftest.html` (see ADVANCED.md) to test it. |
| Answers are very slow | Pick a smaller model. Make sure the laptop is plugged in and on its performance mode. Update the NVIDIA driver. |
| Library page won't open | Check `logs\kiwix.log`. Another program may be using port 8090. |
| Wikipedia isn't in the library yet | Run `STATUS.bat` to see progress. It appears automatically when the download and check finish. |
| Wikipedia says "not enough free space" | Free up space (or move the kit folder to a bigger drive) and start again. It resumes. |
| A file "was damaged and deleted" | Run `SETUP.bat` (or `START` for Wikipedia) again to re-download it. |
| A phone can't open the shared address | See [Phone can't connect?](#-use-it-on-phones-and-tablets-share-on-wi-fi). Check STATUS says **Share on Wi-Fi: ON** and the phone is on the same Wi-Fi. |
| "Check for updates" says I'm offline | That's fine – the kit works without internet. Try again when you're online. |
| Want a fresh start | Run `STOP-OFFLINE-AI.bat`, then delete the folders `runtime`, `library`, `ollama-models`, `home`, `logs`. |

## Credits & licences

This kit is just glue scripts (MIT licence, see `LICENSE`). It downloads:
[Ollama](https://github.com/ollama/ollama) (MIT), [Kiwix tools](https://github.com/kiwix/kiwix-tools) (GPL-3.0),
library content from [download.kiwix.org](https://download.kiwix.org/zim/) (Wikipedia etc., CC BY-SA and others),
and AI models from the [Ollama library](https://ollama.com/library), each under its own licence.
