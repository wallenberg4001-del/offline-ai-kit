# Offline AI Kit

A chat assistant (AI) and a big reference library – including all of Wikipedia – that work on your own computer with **no internet**. Set it up once, then it works during power cuts, storms, or anywhere with no signal.

**Works on every major operating system** – Windows, Mac (Apple silicon and Intel), and Linux (x64 and ARM64). The Setup Wizard's **All computers (universal drive)** option bundles programs for all of them onto one **exFAT** drive, so a single drive runs anywhere. Copy the folder onto a fast portable SSD, and you can keep it in a drawer for a rainy day – plug it into any supported computer and it just works.

It also has a **built-in hardware detector**. On launch it checks your RAM, graphics card, and free disk space, then automatically picks the right AI model sizes, library, and settings to fit *your* machine – from a lightweight laptop up to a 32 GB gaming rig. No manual tuning needed.

## Where to click

Open the folder **`Click these`**. The numbered folders are the whole kit, in the order you need them:

| Folder | What it does |
|---|---|
| **1 Install - guided** | A page in your web browser. It explains every choice in plain language, then downloads. Best the first time. |
| **2 Install - no questions** | Installs with good choices for your computer. No questions. |
| **3 Start** | Opens the chat and the library. Use this after it is installed. |
| **4 Stop** | Turns it off. |
| **5 Check status** | Phones on Wi-Fi, extra libraries, maps, and updates. |

`FOLDER-GUIDE.txt` says what every other folder is, and which ones not to delete. Pick the file inside the folder that matches your computer (Windows, Mac, or Linux).

The files at the top of the kit (`EASY-INSTALL`, `SETUP`, `START-OFFLINE-AI`, `STOP`, `STATUS`) do the same jobs. They stay so older notes and the Desktop shortcut still work.

## 👉 Which one do I need?

There is **one file to double-click** if you do not want to open `Click these`. Pick the line that matches your computer:

| Your computer | Double-click this file | Notes |
|---|---|---|
| 🗺️ **Windows PC** | **`EASY-INSTALL (Windows).bat`** | |
| 🍏 **Mac with an Apple chip** (M1, M2, M3, M4, M5) | **`EASY-INSTALL (Mac).command`** | Fastest Mac version. |
| 🍏 **Older Mac with an Intel chip** | **the same `EASY-INSTALL (Mac).command`** | It works out which Mac you have by itself. The AI answers more slowly on Intel Macs. |
| 🐙 **Linux** | **`EASY-INSTALL (Linux).sh`** | In a terminal: `bash "EASY-INSTALL (Linux).sh"`. No questions. |

### Three ways to install – pick one

| I want… | Windows | Mac (Apple chip or Intel) | Linux |
|---|---|---|---|
| 🧭 **Every choice explained** (guided installer) | **`Click these/1 Install - guided/Windows.bat`** | **`Click these/1 Install - guided/Mac.command`** | **`bash "Click these/1 Install - guided/Linux.sh"`** |
| ⚡ **No questions** – just set it up with good choices for my computer | **`EASY-INSTALL (Windows).bat`** | **`EASY-INSTALL (Mac).command`** | **`EASY-INSTALL (Linux).sh`** |
| ⌨️ **The same choices, in a text window** | **`SETUP.bat`** | **`SETUP-MAC.command`** | **`SETUP-LINUX.sh`** |

**The guided installer** asks the same questions as the text Setup Wizard, one screen at a time, with a short explanation and a suggestion for your computer. Nothing downloads until you press **Install**.

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
   programs for Windows x64, Mac (Apple silicon and Intel) and Linux (x64 and ARM64) so one **exFAT** drive works on each.
   Models, Wikipedia, extra libraries and maps stay **one shared copy**. The summary shows the extra disk space
   (about 11.5 GB more on Windows, about 13 GB more on Mac and Linux, on top of this computer's programs).
   Windows on ARM, 32-bit Windows, and Alpine or other musl Linux are not included. On macOS 12 only the library is installed.
8. **Summary** – every choice, the total download size and your free space, then **Proceed? (Y/N)**.

**How do I check which Mac I have?** Click the **Apple menu** (⌘) in the top-left corner, then **About This Mac**.
- If you see **Chip: Apple M1** (or M2, M3, M4, M5), you have an **Apple chip**.
- If you see **Processor: … Intel …**, you have an **Intel Mac**.

**How do I check if I have a PC?** If your computer runs **Windows** (it has a Start button with the Windows logo),
it is a PC. Use the Windows file.

## How to get it

1. **Download the kit:** go to the **[latest release](https://github.com/wallenberg4001-del/offline-ai-kit/releases/latest)**
   and click **`Offline-AI-Kit-x.y.z.zip`** under **Assets** (for example `Offline-AI-Kit-1.4.0.zip`).
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

- **Windows PC:** Windows 10 or 11, **64-bit Intel or AMD** (x64). An NVIDIA graphics card makes the AI faster, but is not needed. Windows on ARM and 32-bit Windows are not supported.
- **Mac with an Apple chip:** macOS 13 (Ventura) or newer. (macOS 14 or newer gets the newest AI program. On macOS 12, only the library is installed.)
- **Intel Mac:** macOS 13 (Ventura) or newer for the AI. On macOS 12 (Monterey), only the library is installed.
- **Linux:** 64-bit PC (x64) or ARM64, with glibc (Ubuntu, Debian, Fedora and similar). Alpine and other musl Linux are not supported.
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
| 🧡 **Medical** | WikiMed medical encyclopedia, Wikipedia Medicine, survival medicine guides | ~4 GB |
| 🏕️ **Survival** | Post-disaster library, water, food preparation & preserving, USDA canning, knots, Appropedia low-tech how-tos | ~1.5 GB |
| 🔧 **Repair & more** | iFixit repair guides, gardening Q&A, Wikivoyage travel guide | ~5.5 GB |

Everything is free and comes from the official sources (Kiwix, Ollama). Every file is checked against its official
fingerprint (checksum) so nothing is damaged or tampered with.

## Want choices, or more control?

- **Want every choice explained?** Open **`Click these/1 Install - guided`** (see [Three ways to install](#three-ways-to-install--pick-one)).
- **Prefer a text window?** Use the **Setup Wizard**: `SETUP.bat` on Windows, `SETUP-MAC.command` on Mac.
- **Already installed?** Double-click **STATUS** (`STATUS.bat` / `STATUS-MAC.command`). Besides showing what's running,
  it has a small menu: **turn Share on Wi-Fi on/off**, **add Extra Libraries**, and **check for updates**.
- **Power user?** See [ADVANCED.md](ADVANCED.md) for options, `kit-settings.ini`, ports, and using your own Ollama.

## Emergency first aid

On the chat page, **Emergency first aid** opens large buttons for bleeding, choking, burns, chest pain, water, a power cut, shelter, and other urgent problems. Each button searches the offline library and shows the articles first. A short summary is written from those articles afterwards. Call your local emergency number if you can (911 in Canada and the United States). The summary can be wrong. Read the article. This is not a doctor.

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

**Windows/Mac warns me the file is from the internet – is it OK?** Yes; it does that for any downloaded script.
See `START-HERE.txt` for exactly what to click.

**Can I share it?** Yes – it's MIT-licensed. Send the folder or the download link to anyone.

## Running from a USB drive

The whole kit folder can live on one USB drive and run on Windows, Mac and Linux. Format the drive as **exFAT**
(or NTFS, or APFS). **FAT32 cannot store a file larger than 4 GB**, so setup refuses Wikipedia, the bigger
libraries and the maps on a FAT32 drive and tells you to use exFAT, NTFS or APFS.

**All computers (universal drive).** In the Setup Wizard, under **Which computers**, choose **All computers (universal drive)** (or **This computer only**). Universal downloads the programs for every supported computer onto that one drive. Use **exFAT** so Windows, Mac and Linux can all read it. Models, Wikipedia, extra libraries and maps stay one shared copy. Before anything downloads, the summary shows the extra programs: about 11.5 GB more on Windows, about 13 GB more on Mac and Linux, on top of this computer's programs.

Supported computers are **Windows x64** (64-bit Intel and AMD), **Mac** (Apple silicon and Intel) and **Linux** (x64 and ARM64). Not included: Windows on ARM, 32-bit Windows, and Alpine or other musl Linux. On macOS 12 only the library is installed; the AI program needs macOS 13 or newer.

- **Where it looks for free space.** The free-space check uses the drive the kit folder is on, including when Windows gives that drive a different letter the next time you plug it in.
- **Drive letters.** Paths inside the kit are relative to the folder. The Desktop shortcut stores a full path, and **START** rewrites that shortcut every time, so run START from the USB after the letter changes.
- **Execute permission on Mac and Linux.** exFAT often drops the execute bit, or refuses to run a program directly. Shell launchers still work. Start with `bash "/Volumes/YOURDRIVE/.../START-OFFLINE-AI-MAC.command"` or `bash "/media/.../START-OFFLINE-AI-LINUX.sh"`. If Kiwix or Ollama cannot be executed from the USB, the kit copies that program folder to a local cache (`~/Library/Caches/offline-ai-kit` on a Mac, `~/.cache/offline-ai-kit` on Linux) and runs it from there instead.
