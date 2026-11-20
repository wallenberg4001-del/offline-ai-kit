#!/bin/bash
# Shared settings and helpers for the Offline AI Kit (macOS, and Linux when OFFLINE_AI_OS=linux).
# macOS uses bash 3.2, curl, shasum, tar, df, sysctl, open, caffeinate.
# Linux scripts set OFFLINE_AI_OS=linux before sourcing this file. Running the Mac scripts on Linux
# for a test does not switch them: they keep Mac paths unless that variable is set.
# Everything lives inside the kit folder; nothing is installed system-wide.
# shellcheck disable=SC2034  # variables are used by the scripts that source this file

set -u

MAC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT="$(cd "$MAC_DIR/.." && pwd)"
RUNTIME="$KIT/runtime"
SETTINGS_FILE="$KIT/kit-settings.ini"   # optional, for power users (see ADVANCED.md)
LIBRARY="$KIT/library"                # shared with Windows (same .zim files)
CHECKSUMS="$LIBRARY/checksums"
VERIFIED_DIR="$CHECKSUMS/VERIFIED"
MODELS_DIR="$KIT/ollama-models"       # shared with Windows (same model store format)
HOME_DIR="$KIT/home"
LOG_DIR="$KIT/logs"
WWW_DIR="$KIT/www"
CONFIG_FILE="$KIT/kit-config-mac.txt"
WIKI_PROGRESS="$LOG_DIR/wikipedia-progress.json"
WIKI_STATUS_JS="$WWW_DIR/wiki-status.js"
EXTRA_CATALOG_FILE="$KIT/catalog/extra-libraries.txt"
MAPS_CATALOG_FILE="$KIT/catalog/maps.txt"
RELEASES_API="https://api.github.com/repos/wallenberg4001-del/offline-ai-kit/releases/latest"
KIT_VERSION="$(head -1 "$KIT/VERSION" 2>/dev/null | tr -d '\r[:space:]')"; [ -n "$KIT_VERSION" ] || KIT_VERSION=0.0.0

setting() { # setting <KEY> <default>
  local v=""
  if [ -f "$SETTINGS_FILE" ]; then
    v="$(grep -E "^[[:space:]]*$1[[:space:]]*=" "$SETTINGS_FILE" | tail -1 | sed -e 's/^[^=]*=//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -d '\r')"
  fi
  if [ -n "$v" ]; then printf '%s\n' "$v"; else printf '%s\n' "$2"; fi
}
set_setting() { # set_setting <KEY> <value>
  local tmp="$SETTINGS_FILE.tmp"
  if [ -f "$SETTINGS_FILE" ]; then grep -vE "^[[:space:]]*$1[[:space:]]*=" "$SETTINGS_FILE" > "$tmp" || true; else : > "$tmp"; fi
  printf '%s=%s\n' "$1" "$2" >> "$tmp"
  mv -f "$tmp" "$SETTINGS_FILE"
}
is_yes() { case "$1" in [Yy]|[Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|1|[Oo][Nn]) return 0 ;; esac; return 1; }
load_settings() {
  USE_SYSTEM_OLLAMA=no; is_yes "$(setting USE_SYSTEM_OLLAMA no)" && USE_SYSTEM_OLLAMA=yes
  SKIP_WIKIPEDIA=no;    is_yes "$(setting SKIP_WIKIPEDIA no)" && SKIP_WIKIPEDIA=yes
  LIBRARY_PORT="$(setting LIBRARY_PORT 8090)"
  if [ "$USE_SYSTEM_OLLAMA" = yes ]; then OLLAMA_PORT="$(setting OLLAMA_PORT 11434)"; else OLLAMA_PORT="$(setting OLLAMA_PORT 11435)"; fi
  CHAT_PORT="$(setting CHAT_PORT 8091)"
  # Share on Wi-Fi (off by default). The AI server (Ollama) always stays on 127.0.0.1 either way.
  SHARE_ON_WIFI=no; is_yes "$(setting SHARE_ON_WIFI 0)" && SHARE_ON_WIFI=yes
}
load_settings                         # kit Ollama defaults to 11435, never the normal 11434

# ---------- Which Mac is this? (Apple chip or Intel, and the macOS version) ----------
# hw.optional.arm64 is 1 on every Apple-chip Mac, even when this script runs under Rosetta
# (then uname -m says x86_64 and sysctl.proc_translated is 1). Intel Macs do not have it.
# For testing: OFFLINE_AI_MAC_ARCH=arm64|x86_64 and OFFLINE_AI_MACOS=13.6 (env), or MAC_ARCH in kit-settings.ini.
OLLAMA_PIN_VERSION="v0.12.9"          # last Ollama that runs on macOS 13 Ventura (v0.12.10+ needs macOS 14)
OLLAMA_PIN_SHA256="a3bd64569cb945133dd714f3568989f6bcd4d988a3ba47d2c0dc644770547f17"   # its ollama-darwin.tgz
detect_mac() {
  HW_ARCH=x86_64
  if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; then HW_ARCH=arm64
  elif [ "$(uname -s)" != Darwin ]; then case "$(uname -m)" in arm64|aarch64) HW_ARCH=arm64 ;; esac
  fi
  TRANSLATED=no; [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = 1 ] && TRANSLATED=yes
  MAC_ARCH="${OFFLINE_AI_MAC_ARCH:-$(setting MAC_ARCH "$HW_ARCH")}"
  case "$MAC_ARCH" in arm64|x86_64) ;; *) MAC_ARCH="$HW_ARCH" ;; esac
  if [ -n "${OFFLINE_AI_MACOS:-}" ]; then MACOS_VER="$OFFLINE_AI_MACOS"
  elif [ "$(uname -s)" = Darwin ]; then MACOS_VER="$(sw_vers -productVersion 2>/dev/null || echo 0)"
  else MACOS_VER="99.0"; fi           # not a Mac (script testing on Linux)
  MACOS_MAJOR="${MACOS_VER%%.*}"
  case "$MACOS_MAJOR" in ''|*[!0-9]*) MACOS_MAJOR=0 ;; esac
  # Run the programs as the chosen type even if this Terminal is running under Rosetta.
  ARCH_CMD=""
  if [ "$HW_ARCH" = arm64 ] && [ "$MAC_ARCH" = x86_64 ]; then ARCH_CMD="arch -x86_64"
  elif [ "$HW_ARCH" = arm64 ] && [ "$TRANSLATED" = yes ]; then ARCH_CMD="arch -arm64"; fi
  # Which Ollama this macOS can run: current (14+), the last one for 13, or none (12 and older).
  if [ "$MACOS_MAJOR" -ge 14 ]; then OLLAMA_CHANNEL=current
  elif [ "$MACOS_MAJOR" -eq 13 ]; then OLLAMA_CHANNEL=pinned
  else OLLAMA_CHANNEL=none; fi
  if [ "$MAC_ARCH" = x86_64 ]; then MAC_KIND="Intel Mac"; else MAC_KIND="Mac with Apple chip"; fi
}
detect_mac
# Separate program folders per build, so a kit on an external drive works on both kinds of Mac.
if [ "$MAC_ARCH" = x86_64 ]; then KIWIX_DIR="$RUNTIME/mac-kiwix-intel"; else KIWIX_DIR="$RUNTIME/mac-kiwix"; fi
if [ "$OLLAMA_CHANNEL" = pinned ]; then OLLAMA_DIR="$RUNTIME/mac-ollama-$OLLAMA_PIN_VERSION"; else OLLAMA_DIR="$RUNTIME/mac-ollama"; fi
                                      # (Windows uses runtime/ollama, so one drive can hold all of them)
AI_AVAILABLE=yes; [ "$OLLAMA_CHANNEL" = none ] && AI_AVAILABLE=no
# Defaults stay Mac. OFFLINE_AI_OS=linux (set by linux/*.sh) switches programs, pid files and the LAN lookup.
KIT_OS=mac
PID_TAG=mac
LOG_TAG=mac
OS_NAME="Mac"
LAUNCH_START="START-OFFLINE-AI-MAC.command"
LAUNCH_SETUP="SETUP-MAC.command"
LAUNCH_STATUS="STATUS-MAC.command"
LAUNCH_STOP="STOP-OFFLINE-AI-MAC.command"
LAUNCH_EASY="EASY-INSTALL (Mac).command"
LINUX_CPU=""
LINUX_LIBC="glibc"
LINUX_KIWIX_ARCH=""
LINUX_OLLAMA_ASSET=""
apply_os() {
  [ "${OFFLINE_AI_OS:-}" = linux ] || return 0
  KIT_OS=linux
  PID_TAG=linux
  LOG_TAG=linux
  OS_NAME="Linux"
  LAUNCH_START="START-OFFLINE-AI-LINUX.sh"
  LAUNCH_SETUP="SETUP-LINUX.sh"
  LAUNCH_STATUS="STATUS-LINUX.sh"
  LAUNCH_STOP="STOP-OFFLINE-AI-LINUX.sh"
  LAUNCH_EASY="EASY-INSTALL (Linux).sh"
  AI_AVAILABLE=yes
  ARCH_CMD=""
  OLLAMA_CHANNEL=current
  case "$(uname -m)" in
    aarch64|arm64) LINUX_CPU=arm; LINUX_KIWIX_ARCH=aarch64; LINUX_OLLAMA_ASSET="ollama-linux-arm64.tgz" ;;
    *) LINUX_CPU=x64; LINUX_KIWIX_ARCH=x86_64; LINUX_OLLAMA_ASSET="ollama-linux-amd64.tgz" ;;
  esac
  LINUX_LIBC=glibc
  if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then LINUX_LIBC=musl; fi
  if [ "$LINUX_CPU" = arm ]; then KIWIX_DIR="$RUNTIME/linux-kiwix-arm"; else KIWIX_DIR="$RUNTIME/linux-kiwix"; fi
  OLLAMA_DIR="$RUNTIME/linux-ollama"
  MAC_KIND="Linux"
}
apply_os
KIWIX_BASE="https://download.kiwix.org"
WIKIPEDIA_PREFIX="wikipedia_en_all_maxi"
WARN_FREE_BYTES=140000000000          # warn when under ~140 GB free

# id|kiwix folder|file prefix (newest _YYYY-MM.zim is picked at run time)|tier|description
ZIM_CATALOG="knots|zim/other|zimgit-knots_en|essentials|Knots (how to tie them)
medicine|zim/other|zimgit-medicine_en|essentials|Medicine survival guides
food|zim/other|zimgit-food-preparation_en|essentials|Food preparation and preserving
water|zim/other|zimgit-water_en|essentials|Water: finding, cleaning, storing
postdisaster|zim/other|zimgit-post-disaster_en|essentials|Post-disaster survival library
usda|zim/other|usda-2015_en|essentials|USDA home canning / food safety
appropedia|zim/other|appropedia_en_all_maxi|essentials|Appropedia: low-tech how-tos
mdwiki|zim/other|mdwiki_en_all_maxi|essentials|WikiMed (mdwiki): medical encyclopedia
wpmed|zim/wikipedia|wikipedia_en_medicine_maxi|recommended|Wikipedia medicine articles
wikivoyage|zim/wikivoyage|wikivoyage_en_all_maxi|recommended|Wikivoyage travel guide
gardening|zim/stack_exchange|gardening.stackexchange.com_en_all|recommended|Gardening Q&A
ifixit|zim/ifixit|ifixit_en_all|recommended|iFixit repair guides
wikipedia|zim/wikipedia|wikipedia_en_all_maxi|always|FULL English Wikipedia with pictures (~127 GB)"

# model|download GB|smallest model set it belongs to (8, 16, 24, 32 = GB of RAM)|hint
MODEL_CATALOG="llama3.2:3b|2.0|8|Fastest / battery saver
phi4-mini|2.5|8|Small and practical
medgemma:4b|3.3|8|Medical-tuned (still check the library)
qwen3.5:9b|6.6|16|Best all-rounder
gemma3:4b|3.3|16|Light, can read photos
gemma3:12b|8.2|24|Stronger answers, can read photos
qwen3:14b|9.3|24|Strong reasoning
qwen3:30b|18.6|32|Biggest; fast for its size (mixture-of-experts)
qwen3:8b|5.2|99|All-rounder for macOS 13 (stands in for qwen3.5:9b)"

# Model sets: lite = 2 small models; 8/16/24/32 = everything up to that much RAM.
models_for_set() {
  if [ "$1" = lite ]; then printf '%s\n' "llama3.2:3b medgemma:4b"; return; fi
  printf '%s\n' "$MODEL_CATALOG" | awk -F'|' -v r="$1" '$3 + 0 <= r + 0 { printf "%s ", $1 }' | sed 's/ $//'
  printf '\n'
}
models_gb() { # total download GB for a space-separated model list
  local m total=0 g
  for m in $1; do
    g="$(printf '%s\n' "$MODEL_CATALOG" | awk -F'|' -v n="$m" '$1 == n { print $2 }')"
    total="$(awk -v a="$total" -v b="${g:-0}" 'BEGIN { printf "%.1f", a + b }')"
  done
  printf '%s\n' "$total"
}
# Older Ollama (macOS 13) cannot run the newest models; swap in ones it can.
compat_models() {
  if [ "$OLLAMA_CHANNEL" = pinned ]; then printf '%s\n' "$1" | sed 's/qwen3\.5:9b/qwen3:8b/g'; else printf '%s\n' "$1"; fi
}
# Intel Macs: the AI runs on the processor only (no Apple GPU), so only small models are worth it.
intel_models() { if [ "$(ram_gb)" -ge 16 ]; then echo "llama3.2:3b medgemma:4b phi4-mini"; else echo "llama3.2:3b medgemma:4b"; fi; }
# Hardware profiles. Apple chip (by unified memory): lite <16 GB, standard 16-23, large 24-31, largest 32+.
# Intel: intel (Recommended library) or intel-small (Essentials library, when disk is tight).
profile_tier()   { case "$1" in lite|intel-small) echo essentials ;; *) echo recommended ;; esac; }
profile_models() {
  [ "$AI_AVAILABLE" = yes ] || { echo ""; return; }
  case "$1" in
    intel|intel-small) intel_models ;;
    lite) compat_models "$(models_for_set lite)" ;; standard) compat_models "$(models_for_set 16)" ;;
    large) compat_models "$(models_for_set 24)" ;; *) compat_models "$(models_for_set 32)" ;;
  esac
}
profile_label()  {
  case "$1" in
    lite) echo "LITE (8 GB of memory)" ;; standard) echo "STANDARD (16 GB of memory)" ;; large) echo "LARGE (24 GB of memory or more)" ;;
    intel)
      if [ "${KIT_OS:-mac}" = linux ]; then echo "SMALL CPU (Linux on a 64-bit PC - the AI runs on the processor, so answers are slower)"
      else echo "INTEL (Intel Macs - AI runs on the processor, so answers are slower)"; fi ;;
    intel-small)
      if [ "${KIT_OS:-mac}" = linux ]; then echo "SMALL CPU, smaller library (Linux on a 64-bit PC, to fit the disk)"
      else echo "INTEL SMALL (Intel Macs, smaller library to fit the disk)"; fi ;;
    *) echo "LARGEST (32 GB of memory or more)" ;;
  esac
}
profile_for_ram() {
  if [ "$MAC_ARCH" = x86_64 ]; then echo intel; return; fi
  if [ "$1" -lt 16 ]; then echo lite; elif [ "$1" -lt 24 ]; then echo standard; elif [ "$1" -lt 32 ]; then echo large; else echo largest; fi
}
if [ "$MAC_ARCH" = x86_64 ]; then PROFILE_ORDER="intel intel-small"; else PROFILE_ORDER="largest large standard lite"; fi
WIKIPEDIA_GB=127.4

# ---------- Test mode ----------
# OFFLINE_AI_TEST=1 (env), --test (setup) or TEST_MODE=yes (kit-settings.ini): tiny library, one small model,
# and a 13 MB Wikipedia stand-in so the background download / verify / library restart is exercised.
# OFFLINE_AI_SKIP_WIKIPEDIA=1 (env) skips Wikipedia entirely.
TEST_MODE=no
enable_test_mode() {
  TEST_MODE=yes
  WIKIPEDIA_PREFIX="wikipedia_en_knots_maxi"
  WIKIPEDIA_GB=0.02
  WARN_FREE_BYTES=1000000000
  ZIM_CATALOG="$(printf '%s\n' "$ZIM_CATALOG" | sed 's#^wikipedia|zim/wikipedia|wikipedia_en_all_maxi|always|.*#wikipedia|zim/wikipedia|wikipedia_en_knots_maxi|always|TEST stand-in for full Wikipedia (13 MB)#')"
  # Small searchable medical stand-in (~170 MB) so 'Ask the library' can be tested with a first-aid question.
  ZIM_CATALOG="$(printf '%s\n' "$ZIM_CATALOG" | sed 's#^wpmed|zim/wikipedia|wikipedia_en_medicine_maxi|recommended|.*#wpmed|zim/wikipedia|wikipedia_en_medicine_mini|recommended|TEST stand-in for Wikipedia medicine (intros only, ~170 MB)#')"
}
if is_yes "${OFFLINE_AI_TEST:-no}" || is_yes "$(setting TEST_MODE no)"; then enable_test_mode; fi
if is_yes "${OFFLINE_AI_SKIP_WIKIPEDIA:-no}"; then SKIP_WIKIPEDIA=yes; fi
start_log() { # start_log <name>: copy everything shown to logs/<name> (once per run)
  [ -n "${KIT_LOGGING:-}" ] && return 0
  export KIT_LOGGING=1
  mkdir -p "$LOG_DIR"
  KIT_LOG_FILE="$LOG_DIR/$1"
  exec > >(tee -a "$KIT_LOG_FILE") 2>&1
  say "(A copy of everything shown here is saved in $KIT_LOG_FILE)"
}
profile_need_gb() { # programs + library + models
  local lib=11.2; case "$1" in lite|intel-small) lib=3.8 ;; esac
  awk -v l="$lib" -v m="$(models_gb "$(profile_models "$1")")" 'BEGIN { printf "%.1f\n", 0.5 + l + m }'
}
pick_profile_for_disk() { # pick_profile_for_disk <preferred> <free GB> -> "profile yes|no" (with Wikipedia?)
  local pref="$1" free="$2" w p started need
  for w in yes no; do
    started=no
    for p in $PROFILE_ORDER; do
      [ "$p" = "$pref" ] && started=yes
      [ "$started" = yes ] || continue
      need="$(profile_need_gb "$p")"
      [ "$w" = yes ] && need="$(awk -v a="$need" -v b="$WIKIPEDIA_GB" 'BEGIN { printf "%.1f", a + b + 12 }')"
      if awk -v f="$free" -v n="$need" 'BEGIN { exit !(f >= n) }'; then printf '%s %s\n' "$p" "$w"; return 0; fi
    done
  done
  return 1
}

write_chat_config() {
  local share=false lan="" ip
  if [ "$SHARE_ON_WIFI" = yes ]; then share=true; ip="$(lan_ip)"; [ -n "$ip" ] && lan="http://$ip:$CHAT_PORT/"; fi
  printf 'window.KIT_CONFIG = { ollamaPort: %s, libraryPort: %s, chatPort: %s, shareOnWifi: %s, lanUrl: "%s", version: "%s" };\n' \
    "$OLLAMA_PORT" "$LIBRARY_PORT" "$CHAT_PORT" "$share" "$lan" "$KIT_VERSION" > "$WWW_DIR/kit-config.js" 2>/dev/null || true
}

make_desktop_shortcut() {
  local d="$HOME/Desktop" f
  [ -d "$d" ] || return 0
  f="$d/Offline AI.command"
  if printf '#!/bin/bash\n# Starts the Offline AI Kit\nexec bash "%s/START-OFFLINE-AI-MAC.command"\n' "$KIT" > "$f" 2>/dev/null; then
    chmod +x "$f"; ok "  Put an 'Offline AI' shortcut on the Desktop."
  else
    warn "  Could not create the Desktop shortcut (not a problem; use START-OFFLINE-AI-MAC.command)."
  fi
}

# ---------- output ----------
if [ -t 1 ]; then C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_OFF=$'\033[0m'; else C_RED=''; C_GRN=''; C_YEL=''; C_OFF=''; fi
say()  { printf '%s\n' "$*"; }
ok()   { printf '%s%s%s\n' "$C_GRN" "$*" "$C_OFF"; }
warn() { printf '%s%s%s\n' "$C_YEL" "$*" "$C_OFF"; }
err()  { printf '%s%s%s\n' "$C_RED" "$*" "$C_OFF" >&2; }
log_to() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$2" >> "$LOG_DIR/$1" 2>/dev/null || true; }

ensure_dirs() {
  mkdir -p "$RUNTIME" "$OLLAMA_DIR" "$KIWIX_DIR" "$LIBRARY" "$CHECKSUMS" "$VERIFIED_DIR" \
           "$MODELS_DIR" "$HOME_DIR" "$LOG_DIR"
}

# ---------- small portable helpers (macOS first, Linux fallback for testing) ----------
file_size() { if [ -f "$1" ]; then wc -c < "$1" | tr -d ' '; else echo 0; fi; }
sha256_of() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi; }
md5_of()    { if command -v md5 >/dev/null 2>&1; then md5 -q "$1"; else md5sum "$1" | awk '{print $1}'; fi; }
free_bytes() { df -Pk "$1" | awk 'NR==2 { printf "%.0f\n", $4 * 1024 }'; }
fs_type() { # filesystem name of the volume that holds this path (lowercase)
  local p="$1" t="" dev=""
  if [ "$(uname -s)" = Darwin ]; then
    # diskutil info on a folder inside FAT32/exFAT fails with "Could not find disk".
    # Look up the device first, then fall back to the path.
    dev="$(df -Pk "$p" 2>/dev/null | awk 'NR==2 { print $1 }')"
    if [ -n "$dev" ]; then
      t="$(diskutil info "$dev" 2>/dev/null | awk -F': ' '/File System Personality/ { gsub(/^ +| +$/, "", $2); print $2; exit }')"
    fi
    if [ -z "$t" ]; then
      t="$(diskutil info "$p" 2>/dev/null | awk -F': ' '/File System Personality/ { gsub(/^ +| +$/, "", $2); print $2; exit }')"
    fi
  elif command -v findmnt >/dev/null 2>&1; then
    t="$(findmnt -no FSTYPE -T "$p" 2>/dev/null | head -1)"
  elif df -T "$p" >/dev/null 2>&1; then
    t="$(df -T "$p" 2>/dev/null | awk 'NR==2 { print $2 }')"
  fi
  printf '%s\n' "$t" | tr 'A-Z' 'a-z'
}
fat32_blocked() { # true when this volume cannot store a file of 4 GiB or more
  local t
  t="$(fs_type "$1" | tr -cd 'a-z0-9')"
  case "$t" in fat32|vfat|msdos|msdosfat32|fat) return 0 ;; esac
  return 1
}
large_file_fits() { # large_file_fits <path> <bytes> <label>
  local bytes="${2:-0}"
  case "$bytes" in ''|*[!0-9]*) bytes=0 ;; esac
  if [ "$bytes" -lt 4294967296 ]; then return 0; fi
  if fat32_blocked "$1"; then
    err "This drive is FAT32, which cannot store a file larger than 4 GB."
    err "$3 needs exFAT, NTFS, or APFS."
    err "Copy this folder onto an exFAT, NTFS, or APFS drive, then run this again."
    return 1
  fi
  return 0
}
stay_awake() { # keep the computer awake for the life of this process
  if [ "${KIT_OS:-mac}" = linux ]; then
    if command -v systemd-inhibit >/dev/null 2>&1; then
      systemd-inhibit --what=sleep:idle --who="Offline AI Kit" --why="A download is running" --mode=block sleep infinity >/dev/null 2>&1 &
      say "  This computer will stay awake while the download runs."
      return 0
    fi
  fi
  if command -v caffeinate >/dev/null 2>&1; then
    caffeinate -i -w "$$" >/dev/null 2>&1 &
    say "  This computer will stay awake while the download runs."
    return 0
  fi
  warn "  Could not keep the computer awake. Leave it plugged in and set sleep to Never while downloading."
}
exec_bits_stick() { # 0 when a program on this volume can be executed directly
  local d t
  d="$(mktemp -d "$KIT/.exec-probe.XXXXXX" 2>/dev/null)" || return 1
  t="$d/probe.sh"
  printf '#!/bin/sh\nexit 0\n' > "$t"
  chmod +x "$t" 2>/dev/null || true
  if [ -x "$t" ] && "$t" >/dev/null 2>&1; then rm -rf "$d"; return 0; fi
  rm -rf "$d"
  return 1
}
stage_program_tree() { # stage_program_tree <source dir> <name> -> cache dir that can execute programs
  local src="$1" name="$2" cache dest marker
  if [ "$(uname -s)" = Darwin ]; then cache="$HOME/Library/Caches/offline-ai-kit"
  else cache="${XDG_CACHE_HOME:-$HOME/.cache}/offline-ai-kit"; fi
  dest="$cache/$name"
  marker="$dest/.staged-from"
  mkdir -p "$cache"
  if [ ! -d "$dest" ] || [ ! -f "$marker" ] || [ "$src" -nt "$marker" ]; then
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
    chmod -R u+rx "$dest" 2>/dev/null || true
    command -v xattr >/dev/null 2>&1 && xattr -dr com.apple.quarantine "$dest" 2>/dev/null || true
    touch "$marker"
    say "  This drive cannot run programs directly. Running $name from $dest."
    say "  Your library and models stay on this drive."
  fi
  printf '%s\n' "$dest"
}
materialize_symlinks() { # copy symlink targets into real files, deepest first (no symlinks left in the kit)
  local list f target base
  [ -d "$1" ] || return 0
  list="$(find "$1" -type l 2>/dev/null | awk '{ print length($0) "\t" $0 }' | sort -nr | cut -f2-)"
  [ -n "$list" ] || return 0
  printf '%s\n' "$list" | while IFS= read -r f; do
    [ -n "$f" ] && [ -L "$f" ] || continue
    target="$(readlink "$f" 2>/dev/null || true)"
    [ -n "$target" ] || { rm -f "$f"; continue; }
    case "$target" in /*) ;; *) base="$(dirname "$f")"; target="$base/$target" ;; esac
    if [ -d "$target" ]; then rm -f "$f"; mkdir -p "$f"; cp -R "$target/." "$f/"
    elif [ -e "$target" ]; then rm -f "$f"; cp -f "$target" "$f"
    else rm -f "$f"; fi
  done
}
ensure_executable() { # ensure_executable <file>
  [ -f "$1" ] || return 1
  [ -x "$1" ] && return 0
  chmod +x "$1" 2>/dev/null || true
  [ -x "$1" ]
}
gb() { awk -v b="$1" 'BEGIN { if (b < 1e9) printf "%.0f MB", b / 1e6; else printf "%.1f GB", b / 1e9 }'; }
ram_gb() {
  local b
  b="$(sysctl -n hw.memsize 2>/dev/null || true)"
  if [ -z "$b" ] && [ -r /proc/meminfo ]; then b=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) * 1024 )); fi
  awk -v b="${b:-0}" 'BEGIN { printf "%d\n", (b / 1073741824) + 0.5 }'
}
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
port_up() { curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$1/"; }

curl_text() { curl -sSL --fail --retry 3 --connect-timeout 20 "$1"; }

remote_size() {
  # Follows Kiwix mirror redirects; prints the final Content-Length (bytes) or 0.
  curl -sSIL --retry 3 --connect-timeout 20 "$1" 2>/dev/null | tr -d '\r' |
    awk 'tolower($1) == "content-length:" { s = $2 } END { print (s == "" ? 0 : s) }'
}

catalog_field() { # catalog_field <id> <field number>
  printf '%s\n' "$ZIM_CATALOG" | awk -F'|' -v id="$1" -v f="$2" '$1 == id { print $f }'
}

resolve_latest_zim() { # resolve_latest_zim <kiwix folder> <prefix>  -> newest file name
  # Accepts prefix_YYYY-MM.zim and prefix_YYYY-MMa.zim. Sort order is 2026-08 < 2026-08a < 2026-09.
  # OFFLINE_AI_ZIM_LISTING = a saved listing, so tests do not touch the network.
  local dir="$1" prefix="$2" esc html
  esc="$(printf '%s' "$prefix" | sed 's/[.]/\\./g')"
  if [ -n "${OFFLINE_AI_ZIM_LISTING:-}" ] && [ -f "$OFFLINE_AI_ZIM_LISTING" ]; then html="$(cat "$OFFLINE_AI_ZIM_LISTING")"
  else html="$(curl_text "$KIWIX_BASE/$dir/")"; fi
  printf '%s\n' "$html" | grep -oE "href=\"${esc}_[0-9]{4}-[0-9]{2}[a-z]?\.zim\"" |
    sed -e 's/^href="//' -e 's/"$//' | sort | tail -1
}

expected_sha() { curl_text "$1" | grep -oE '[0-9a-fA-F]{64}' | head -1 | tr 'A-F' 'a-f'; }

# ---------- Wikipedia progress (read by STATUS and the chat page) ----------
write_wiki_status() { # state bytes total percent mbps message
  local msg json
  msg="$(json_escape "$6")"
  json="{\"state\":\"$1\",\"bytes\":$2,\"total\":$3,\"percent\":$4,\"mbps\":$5,\"message\":\"$msg\",\"updated\":\"$(date '+%Y-%m-%d %H:%M:%S')\"}"
  printf '%s\n' "$json" > "$WIKI_PROGRESS" 2>/dev/null || true
  # Also written as .js so a page opened as a file can still read it.
  printf 'window.WIKI_STATUS = %s;\n' "$json" > "$WIKI_STATUS_JS" 2>/dev/null || true
}

wikipedia_verified() { # prints the verified Wikipedia file name, if any
  local f
  for f in "$VERIFIED_DIR/$WIKIPEDIA_PREFIX"_*.zim; do
    [ -e "$f" ] || continue
    if [ -f "$LIBRARY/$(basename "$f")" ]; then basename "$f"; return 0; fi
  done
  return 1
}

# ---------- resumable download ----------
# Big Kiwix files: download.kiwix.org sends each request to a random mirror and some crawl at
# 0.2 MB/s (5+ days for Wikipedia). For big files, time a few well-known mirrors and use the fastest.
# Safe: the SHA256 always comes from download.kiwix.org itself.
KIWIX_MIRRORS="$KIWIX_BASE https://mirrors.dotsrc.org/kiwix https://ftp.fau.de/kiwix https://mirror.accum.se/mirror/kiwix.org"
FAST_URL="" FAST_SPEED=0
pick_fastest_url() { # sets FAST_URL / FAST_SPEED (bytes/s; 0 = not tested)
  local url="$1" path m r code sp
  FAST_URL="$url"; FAST_SPEED=0
  case "$url" in "$KIWIX_BASE"/*) ;; *) return 0 ;; esac
  path="${url#"$KIWIX_BASE"}"
  say "  Finding the fastest download server..."
  for m in $KIWIX_MIRRORS; do
    r="$(curl -s -L -o /dev/null --connect-timeout 5 --max-time 6 -r 0-300000000 -w '%{http_code} %{speed_download}' "$m$path" 2>/dev/null)"
    code="${r%% *}"; sp="${r##* }"; sp="${sp%%.*}"
    [ "$code" = 206 ] || continue
    case "$sp" in ''|*[!0-9]*) continue ;; esac
    if [ "$sp" -gt "$FAST_SPEED" ]; then FAST_SPEED="$sp"; FAST_URL="$m$path"; fi
  done
  if [ "$FAST_SPEED" -gt 0 ]; then
    say "  Using $(printf '%s' "$FAST_URL" | awk -F/ '{print $3}') ($(awk -v s="$FAST_SPEED" 'BEGIN { printf "%.1f", s / 1e6 }') MB/s in a quick test)"
  fi
}

# download_resumable <url> <out file> <expected bytes or 0> <label> <track wiki progress: yes/no> <max tries>
download_resumable() {
  local url="$1" out="$2" total="$3" label="$4" track="$5" max="${6:-1000}"
  local part="$out.part" tries=0 have pid code now last last_t t speed pct mbps line src slow_since switched
  [ "$total" -gt 0 ] 2>/dev/null || total="$(remote_size "$url")"
  while :; do
    have="$(file_size "$part")"
    if [ "$total" -gt 0 ] && [ "$have" -eq "$total" ]; then break; fi
    if [ "$total" -gt 0 ] && [ "$have" -gt "$total" ]; then rm -f "$part"; have=0; fi
    tries=$((tries + 1))
    if [ "$tries" -gt "$max" ]; then err "Gave up downloading $label after $max tries."; return 1; fi
    FAST_URL="$url"; FAST_SPEED=0
    [ "$total" -gt 500000000 ] && pick_fastest_url "$url"
    src="$FAST_URL"
    curl -sS -L --fail --retry 5 --retry-delay 10 --connect-timeout 30 \
         --speed-limit 1000 --speed-time 120 -C - -o "$part" "$src" &
    pid=$!
    last="$have"; last_t="$(date +%s)"; speed=0; line=0; slow_since=0; switched=no
    while kill -0 "$pid" 2>/dev/null; do
      sleep 2
      now="$(file_size "$part")"; t="$(date +%s)"
      if [ $((t - last_t)) -ge 5 ]; then speed=$(( (now - last) / (t - last_t) )); last="$now"; last_t="$t"; fi
      # If the server slows to under a quarter of its tested speed for 3 minutes, pick a server again.
      if [ "$FAST_SPEED" -gt 0 ] && [ "$speed" -gt 0 ] && [ "$speed" -lt $((FAST_SPEED / 4)) ]; then
        [ "$slow_since" -eq 0 ] && slow_since="$t"
      else slow_since=0; fi
      if [ "$slow_since" -gt 0 ] && [ $((t - slow_since)) -ge 180 ]; then
        [ -t 1 ] && printf '\n'; warn "  This server got slow - switching to a faster one..."
        kill "$pid" 2>/dev/null; switched=yes; break
      fi
      pct=0; [ "$total" -gt 0 ] && pct="$(awk -v a="$now" -v b="$total" 'BEGIN { printf "%.1f", 100 * a / b }')"
      mbps="$(awk -v s="$speed" 'BEGIN { printf "%.1f", s / 1e6 }')"
      local eta=""
      if [ "$speed" -gt 0 ] && [ "$total" -gt 0 ]; then
        eta="$(awk -v r=$(( (total - now) / speed )) 'BEGIN { if (r >= 86400) printf " - about %d d %d h left", r / 86400, (r % 86400) / 3600; else if (r >= 3600) printf " - about %d h %d min left", r / 3600, (r % 3600) / 60; else printf " - about %d min left", (r + 59) / 60 }')"
      fi
      local status_msg
      status_msg="$(gb "$now") of $(gb "$total") (${pct}%) at ${mbps} MB/s${eta}"
      if [ -t 1 ]; then printf '\r  %s          ' "$status_msg"
      else line=$((line + 1)); [ $((line % 30)) -eq 1 ] && say "  $status_msg"; fi
      [ "$track" = yes ] && write_wiki_status downloading "$now" "$total" "$pct" "$mbps" "$status_msg"
    done
    wait "$pid"; code=$?
    [ -t 1 ] && printf '\n'
    have="$(file_size "$part")"
    if [ "$code" -eq 0 ] && { [ "$total" -le 0 ] || [ "$have" -eq "$total" ]; }; then break; fi
    if [ "$switched" = yes ]; then tries=$((tries - 1)); continue; fi
    warn "  Connection problem (curl code $code). Resuming in 30 seconds... (try $tries)"
    [ "$track" = yes ] && write_wiki_status waiting-for-internet "$have" "$total" 0 0 "Waiting for internet, will resume"
    sleep 30
  done
  mv -f "$part" "$out"
}

# get_zim <kiwix folder> <file name> <track wiki progress: yes/no>  -> 0 when verified
get_zim() {
  local dir="$1" file="$2" track="$3" url sha got dest
  dest="$LIBRARY/$file"
  if [ -f "$VERIFIED_DIR/$file" ] && [ -f "$dest" ]; then ok "  Already verified: $file"; return 0; fi
  url="$KIWIX_BASE/$dir/$file"
  sha="$(expected_sha "$url.sha256")"
  if [ -z "$sha" ]; then err "  Could not read the checksum for $file"; return 1; fi
  if [ ! -f "$dest" ]; then
    local size
    size="$(remote_size "$url")"
    large_file_fits "$LIBRARY" "$size" "$file" || return 1
    download_resumable "$url" "$dest" 0 "$file" "$track" 1000 || return 1
  fi
  say "  Checking the file is complete and undamaged (SHA256)..."
  [ "$track" = yes ] && write_wiki_status verifying 0 0 99 0 "Checking SHA256 (10-30 minutes for Wikipedia)"
  got="$(sha256_of "$dest")"
  if [ "$got" = "$sha" ]; then
    printf '%s\n' "$sha" > "$VERIFIED_DIR/$file"
    log_to zim-downloads.log "VERIFIED $file $sha"
    ok "  Verified: $file"
    return 0
  fi
  log_to zim-downloads.log "SHA256_MISMATCH $file - deleted"
  err "  The file was damaged in transit and has been deleted: $file. Run again to re-download."
  rm -f "$dest"
  return 1
}

# ---------- processes ----------
pid_file() { printf '%s/%s.%s.pid' "$LOG_DIR" "$1" "${PID_TAG:-mac}"; }
kit_pid() { # prints the pid if that kit process is running (and really is ours)
  local pf p comm want
  pf="$(pid_file "$1")"
  [ -f "$pf" ] || return 1
  p="$(head -1 "$pf" 2>/dev/null)"
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null || return 1
  comm="$(ps -p "$p" -o command= 2>/dev/null)"
  case "$1" in kiwix) want=kiwix-serve ;; ollama) want=ollama ;; chat-server) want=serve-chat ;; add-libraries) want=add-libraries ;; add-maps) want=add-maps ;; *) want=wiki-download ;; esac
  case "$comm" in *"$want"*) printf '%s\n' "$p"; return 0 ;; esac
  return 1
}
kill_tree() { # TERM a process's children and grandchildren (e.g. curl inside $(...)), deepest first
  local c
  for c in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$c"; kill -TERM "$c" 2>/dev/null || true; done
}

stop_kit() {
  local p
  if p="$(kit_pid "$1")"; then
    kill_tree "$p"
    kill -TERM "$p" 2>/dev/null || true
    local i=0
    while kill -0 "$p" 2>/dev/null && [ $i -lt 20 ]; do sleep 0.25; i=$((i + 1)); done
    kill -KILL "$p" 2>/dev/null || true
    say "  Stopped $1 (pid $p)"
  fi
  rm -f "$(pid_file "$1")"
}

ollama_bin() {
  local c staged
  clear_quarantine "$OLLAMA_DIR"
  for c in "$OLLAMA_DIR/ollama" "$OLLAMA_DIR/bin/ollama"; do
    [ -f "$c" ] || continue
    if ensure_executable "$c"; then printf '%s\n' "$c"; return 0; fi
  done
  if [ -d "$OLLAMA_DIR" ] && { [ -f "$OLLAMA_DIR/ollama" ] || [ -f "$OLLAMA_DIR/bin/ollama" ]; }; then
    staged="$(stage_program_tree "$OLLAMA_DIR" "ollama-${PLATFORM_ID:-mac}")"
    for c in "$staged/ollama" "$staged/bin/ollama"; do
      [ -f "$c" ] || continue
      chmod +x "$c" 2>/dev/null || true
      if [ -x "$c" ]; then printf '%s\n' "$c"; return 0; fi
    done
  fi
  return 1
}
kiwix_bin() {
  local f staged found=""
  clear_quarantine "$KIWIX_DIR"
  for f in "$KIWIX_DIR"/*/kiwix-serve "$KIWIX_DIR"/kiwix-serve; do
    [ -f "$f" ] || continue
    if ensure_executable "$f"; then printf '%s\n' "$f"; return 0; fi
    found="$f"
  done
  if [ -n "$found" ]; then
    staged="$(stage_program_tree "$KIWIX_DIR" "kiwix-${PLATFORM_ID:-mac}")"
    for f in "$staged"/*/kiwix-serve "$staged"/kiwix-serve; do
      [ -f "$f" ] || continue
      chmod +x "$f" 2>/dev/null || true
      if [ -x "$f" ]; then printf '%s\n' "$f"; return 0; fi
    done
  fi
  return 1
}

start_ollama() {
  local bin
  if port_up "$OLLAMA_PORT"; then say "  AI model server already running on port $OLLAMA_PORT."; return 0; fi
  if [ "$USE_SYSTEM_OLLAMA" = yes ]; then warn "  USE_SYSTEM_OLLAMA is on, but nothing answers on port $OLLAMA_PORT. Start your Ollama app first."; return 1; fi
  if [ "$AI_AVAILABLE" != yes ]; then warn "  The AI part needs macOS 13 (Ventura) or newer; this Mac has macOS $MACOS_VER. The library still works."; return 1; fi
  bin="$(ollama_bin)" || { err "  Ollama is missing. Run $LAUNCH_SETUP first."; return 1; }
  ensure_dirs
  # Kit-only environment: models, keys and settings stay inside the kit folder.
  # OLLAMA_ORIGINS=* lets a page opened as a file talk to it. The server only listens on 127.0.0.1.
  # ARCH_CMD is empty or "arch -x86_64" / "arch -arm64" (two words on purpose).
  # shellcheck disable=SC2086
  HOME="$HOME_DIR" OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" OLLAMA_MODELS="$MODELS_DIR" \
  OLLAMA_ORIGINS='*' OLLAMA_KEEP_ALIVE=10m \
    nohup $ARCH_CMD "$bin" serve >> "$LOG_DIR/ollama-${LOG_TAG:-mac}.log" 2>&1 < /dev/null &
  printf '%s\n' "$!" > "$(pid_file ollama)"
  local i
  for i in $(seq 1 40); do port_up "$OLLAMA_PORT" && return 0; sleep 0.5; done
  warn "  The AI server did not answer yet. See logs/ollama-${LOG_TAG:-mac}.log"
  return 1
}

start_kiwix() { # (re)starts kiwix-serve with every verified ZIM
  local bin zims=() m i
  stop_kit kiwix
  bin="$(kiwix_bin)" || { err "  Kiwix is missing. Run $LAUNCH_SETUP first."; return 1; }
  for m in "$VERIFIED_DIR"/*.zim; do
    [ -e "$m" ] || continue
    [ -f "$LIBRARY/$(basename "$m")" ] && zims+=("$LIBRARY/$(basename "$m")")
  done
  if [ "${#zims[@]}" -eq 0 ]; then warn "  No verified library files yet - the library will be empty."; return 1; fi
  for i in $(seq 1 10); do port_up "$LIBRARY_PORT" || break; sleep 0.5; done
  if port_up "$LIBRARY_PORT"; then err "  Port $LIBRARY_PORT is used by another program; the library cannot start."; return 1; fi
  local addr=127.0.0.1   # always private; with Share on Wi-Fi the chat page server passes library pages through
  # shellcheck disable=SC2086  # see start_ollama
  nohup $ARCH_CMD "$bin" --address="$addr" --port="$LIBRARY_PORT" "${zims[@]}" >> "$LOG_DIR/kiwix-${LOG_TAG:-mac}.log" 2>&1 < /dev/null &
  printf '%s\n' "$!" > "$(pid_file kiwix)"
  for i in $(seq 1 30); do
    if port_up "$LIBRARY_PORT"; then say "  Library is serving ${#zims[@]} collection(s)."; return 0; fi
    sleep 0.5
  done
  warn "  The library did not answer yet. See logs/kiwix-${LOG_TAG:-mac}.log"
  warn_exfat_mmap
  return 1
}
warn_exfat_mmap() {
  # macOS kiwix-serve maps a ZIM with mmap. Apple's exFAT driver returns Invalid argument past 4 GiB.
  # Windows and Linux open the same files. Do not hide the ZIMs in a disk image; one drive must work everywhere.
  [ "$(uname -s)" = Darwin ] || return 0
  [ "${KIT_OS:-mac}" = mac ] || return 0
  local t big=no f log hit=no
  t="$(fs_type "$LIBRARY" | tr -cd 'a-z0-9')"
  case "$t" in *exfat*|*fat32*|*vfat*|*msdos*) ;; *) return 0 ;; esac
  for f in "$LIBRARY"/*.zim; do
    [ -f "$f" ] || continue
    if [ "$(file_size "$f")" -gt 4294967295 ]; then big=yes; break; fi
  done
  [ "$big" = yes ] || return 0
  log="$LOG_DIR/kiwix-${LOG_TAG:-mac}.log"
  if grep -qiE 'mmap|Invalid argument|Unable to add' "$log" 2>/dev/null; then hit=yes; fi
  if ! port_up "$LIBRARY_PORT" || [ "$hit" = yes ]; then
    warn "Large library or map files (over 4 GB) on an exFAT or FAT drive cannot be opened by kiwix-serve on a Mac."
    warn "Windows and Linux can open those same files. On a Mac, keep files over 4 GB on APFS or the internal disk."
    warn "Files under 4 GB on this drive still open."
  fi
}

# ---------- Share on Wi-Fi ----------
lan_ip() { # the address phones on the same Wi-Fi use to reach this computer (IPv4), or nothing
  local ifc="" ip=""
  if [ "${KIT_OS:-mac}" = linux ]; then
    # `ip route get` prints this computer's src address. Do not use the gateway.
    if command -v ip >/dev/null 2>&1; then
      ip="$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src[[:space:]]+[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+' | awk '{ print $2 }' | head -1)"
    fi
    case "$ip" in 127.*|169.254.*|0.*|"") return 1 ;; esac
    printf '%s\n' "$ip"
    return 0
  fi
  ifc="$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')"
  [ -n "$ifc" ] && ip="$(ipconfig getifaddr "$ifc" 2>/dev/null)"
  if [ -z "$ip" ]; then for ifc in en0 en1 en2 en3 en4 en5 en6 en7 en8; do ip="$(ipconfig getifaddr "$ifc" 2>/dev/null)" && [ -n "$ip" ] && break; done; fi
  if [ -z "$ip" ] && command -v hostname >/dev/null 2>&1 && [ "$(uname -s)" != Darwin ]; then ip="$(hostname -I 2>/dev/null | awk '{print $1}')"; fi
  case "$ip" in 127.*|169.254.*|"") return 1 ;; esac
  printf '%s\n' "$ip"
}
wifi_warning() {
  warn "  Only use this at home on Wi-Fi you trust - never on public Wi-Fi (cafes, hotels, airports)."
  warn "  Anyone on the same Wi-Fi can open the chat and the library. The AI server itself stays private."
}
show_share_status() {
  local ip
  if [ "$SHARE_ON_WIFI" = yes ]; then
    ok "  Share on Wi-Fi: ON"
    if ip="$(lan_ip)"; then ok "    Phones and tablets on the same Wi-Fi open:  http://$ip:$CHAT_PORT/"; say "    (the chat page also shows a QR code to scan)"
    else warn "    No home network found right now (is Wi-Fi connected?)."; fi
    if [ "${KIT_OS:-mac}" = linux ]; then
      say "    If a phone cannot connect, allow incoming connections for python3 on your home network."
    else
      say "    If a phone cannot connect and the Mac asks whether \"perl\" may accept incoming"
      say "    connections, click Allow (System Settings > Network > Firewall)."
    fi
    wifi_warning
  else
    if [ "${KIT_OS:-mac}" = linux ]; then say "  Share on Wi-Fi: off (only this computer can use the kit)"
    else say "  Share on Wi-Fi: off (only this Mac can use the kit)"; fi
  fi
}
chat_server_cmd() { # prints which program runs the chat page server: perl (built into macOS) or python3
  if command -v perl >/dev/null 2>&1 && perl -MIO::Socket::INET -e 1 >/dev/null 2>&1; then echo perl; return 0; fi
  # Do not call /usr/bin/python3 on a Mac without the developer tools: it pops up an install dialog.
  if command -v python3 >/dev/null 2>&1; then
    if [ "$(command -v python3)" != /usr/bin/python3 ] || [ "$(uname -s)" != Darwin ] || xcode-select -p >/dev/null 2>&1; then echo python3; return 0; fi
  fi
  return 1
}
start_chat_server() { # the chat page over http (127.0.0.1, or the home network only when Share on Wi-Fi is on)
  local how i bind=127.0.0.1
  [ "$SHARE_ON_WIFI" = yes ] && bind=0.0.0.0
  if kit_pid chat-server >/dev/null; then say "  Chat page server already running."; return 0; fi
  if port_up "$CHAT_PORT"; then warn "  Port $CHAT_PORT is used by another program; phones cannot open the chat page."; return 1; fi
  if [ "${KIT_OS:-mac}" = linux ]; then
    if ! command -v python3 >/dev/null 2>&1; then warn "  python3 is not installed, so phones cannot open the chat page (the library still works)."; return 1; fi
    nohup python3 "$MAC_DIR/serve-chat.py" --bind "$bind" --port "$CHAT_PORT" --www "$WWW_DIR" --logs "$LOG_DIR" --ollama-port "$OLLAMA_PORT" --library-port "$LIBRARY_PORT" >> "$LOG_DIR/chat-server-${LOG_TAG:-mac}.log" 2>&1 < /dev/null &
    printf '%s\n' "$!" > "$(pid_file chat-server)"
    for i in $(seq 1 30); do port_up "$CHAT_PORT" && return 0; sleep 0.3; done
    warn "  The chat page server did not answer yet. See logs/chat-server-${LOG_TAG:-mac}.log"
    return 1
  fi
  how="$(chat_server_cmd)" || { warn "  Neither perl nor python3 is available, so phones cannot open the chat page (the library still works)."; return 1; }
  if [ "$how" = perl ]; then
    nohup perl "$MAC_DIR/serve-chat.pl" --bind "$bind" --port "$CHAT_PORT" --www "$WWW_DIR" --logs "$LOG_DIR" --ollama-port "$OLLAMA_PORT" --library-port "$LIBRARY_PORT" >> "$LOG_DIR/chat-server-mac.log" 2>&1 < /dev/null &
  else
    nohup python3 "$MAC_DIR/serve-chat.py" --bind "$bind" --port "$CHAT_PORT" --www "$WWW_DIR" --logs "$LOG_DIR" --ollama-port "$OLLAMA_PORT" --library-port "$LIBRARY_PORT" >> "$LOG_DIR/chat-server-mac.log" 2>&1 < /dev/null &
  fi
  printf '%s\n' "$!" > "$(pid_file chat-server)"
  for i in $(seq 1 30); do port_up "$CHAT_PORT" && return 0; sleep 0.3; done
  warn "  The chat page server did not answer yet. See logs/chat-server-mac.log"
  return 1
}
set_share_on_wifi() { # set_share_on_wifi yes|no [apply]
  if [ "$1" = yes ]; then set_setting SHARE_ON_WIFI 1; else set_setting SHARE_ON_WIFI 0; fi
  load_settings
  [ "${2:-}" = apply ] || return 0
  if ! kit_pid kiwix >/dev/null && ! kit_pid chat-server >/dev/null; then say "  The kit is not running; this applies the next time you start it."; return 0; fi
  say "  Restarting the chat page server..."
  write_chat_config
  stop_kit chat-server
  start_chat_server || true
  return 0
}

# ---------- Extra Libraries (catalog/extra-libraries.txt) ----------
extra_catalog() { [ -f "$EXTRA_CATALOG_FILE" ] && tr -d '\r' < "$EXTRA_CATALOG_FILE" | grep -vE '^[[:space:]]*(#|$)'; }
extra_field() { extra_catalog | awk -F'|' -v id="$1" -v f="$2" '$1 == id { print $f }'; }
prefix_installed() { # prefix_installed <prefix> -> verified file name (YYYY-MM or YYYY-MMa)
  local prefix="$1" f b rest
  [ -n "$prefix" ] || return 1
  for f in "$VERIFIED_DIR/${prefix}"_*.zim; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    rest="${b#"${prefix}"_}"
    case "$rest" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9].zim|[0-9][0-9][0-9][0-9]-[0-9][0-9][a-z].zim)
        [ -f "$LIBRARY/$b" ] && { printf '%s\n' "$b"; return 0; } ;;
    esac
  done
  return 1
}
extra_installed() { prefix_installed "$(extra_field "$1" 3)"; }
size_label() { awk -v g="$1" 'BEGIN { if (g < 1) printf "%.0f MB", g * 1000; else printf "%.1f GB", g }'; }
show_extra_catalog() {
  local n=0 id gb about mark
  while IFS='|' read -r id _ _ gb _ about; do
    n=$((n + 1)); mark="   "; extra_installed "$id" >/dev/null && mark="[x]"
    printf '  %2d) %s %-22s %9s  %s\n' "$n" "$mark" "$id" "$(size_label "$gb")" "$about"
  done <<EOF_CAT
$(extra_catalog)
EOF_CAT
  say '  [x] = already added. "all" means everything except gutenberg-all (206 GB).'
}
resolve_extra_ids() { # "1,3" / "se-diy wiktionary" / "all" -> ids, one per line (catalog order of first mention)
  local tok out="" id total
  total="$(extra_catalog | wc -l | tr -d ' ')"
  for tok in $(printf '%s' "$1" | tr ',' ' ' | tr 'A-Z' 'a-z'); do
    if [ "$tok" = all ]; then extra_catalog | awk -F'|' '$1 != "gutenberg-all" { print $1 }'; return 0; fi
    case "$tok" in
      *[!0-9]*) id="$(extra_field "$tok" 1)"; [ -n "$id" ] || { warn "  (Unknown library '$tok' - skipped)" >&2; continue; } ;;
      *) if [ "$tok" -ge 1 ] && [ "$tok" -le "$total" ]; then id="$(extra_catalog | sed -n "${tok}p" | cut -d'|' -f1)"; else warn "  (No number $tok in the list - skipped)" >&2; continue; fi ;;
    esac
    case " $out " in *" $id "*) ;; *) out="$out $id" ;; esac
  done
  for id in $out; do printf '%s\n' "$id"; done
}
extra_gb() { # total GB still to download for the given ids (already added ones count 0)
  local id total=0 g
  for id in $1; do extra_installed "$id" >/dev/null && continue; g="$(extra_field "$id" 4)"; total="$(awk -v a="$total" -v b="${g:-0}" 'BEGIN { printf "%.2f", a + b }')"; done
  printf '%s\n' "$total"
}
install_extra() { # install_extra <id>: fastest mirror + resume + SHA-256 + VERIFIED marker
  local id="$1" dir prefix about file have url size part free
  if have="$(extra_installed "$id")"; then ok "  Already added: $(extra_field "$id" 6) ($have)"; return 0; fi
  dir="$(extra_field "$id" 2)"; prefix="$(extra_field "$id" 3)"; about="$(extra_field "$id" 6)"
  file="$(resolve_latest_zim "$dir" "$prefix")"
  [ -n "$file" ] || { err "  Could not find $prefix on download.kiwix.org (no internet?)"; return 1; }
  url="$KIWIX_BASE/$dir/$file"; size="$(remote_size "$url")"; part="$(file_size "$LIBRARY/$file.part")"
  free="$(free_bytes "$LIBRARY")"
  say "  - $about: $file ($(gb "$size"))"
  if [ "$size" -gt 0 ] && [ "$free" -lt $((size - part + 2000000000)) ]; then
    err "    Not enough free space: needs $(gb $((size - part))), only $(gb "$free") free on this drive. Skipped."; return 1
  fi
  if [ "$size" -ge 4294967296 ] || awk -v g="$(extra_field "$id" 4)" 'BEGIN { exit !(g+0 >= 4) }'; then
    fat32_blocked "$LIBRARY" && { err "    This drive is FAT32, which cannot store a file larger than 4 GB. $about needs exFAT, NTFS, or APFS. Skipped."; return 1; }
  fi
  get_zim "$dir" "$file" no
}

# ---------- Offline maps (catalog/maps.txt). Same download path as Extra Libraries. ----------
map_catalog() { [ -f "$MAPS_CATALOG_FILE" ] && tr -d '\r' < "$MAPS_CATALOG_FILE" | grep -vE '^[[:space:]]*(#|$)'; }
map_field() { map_catalog | awk -F'|' -v id="$1" -v f="$2" '$1 == id { print $f }'; }
show_map_catalog() {
  local n=0 id gb about mark
  while IFS='|' read -r id _ _ gb _ about; do
    n=$((n + 1)); mark="   "; prefix_installed "$(map_field "$id" 3)" >/dev/null && mark="[x]"
    printf '  %2d) %s %-20s %9s  %s\n' "$n" "$mark" "$id" "$(size_label "$gb")" "$about"
  done <<EOF_MAP
$(map_catalog)
EOF_MAP
  say '  [x] = already added. Vancouver Island, British Columbia, Alberta, Saskatchewan and Canada share one Canada file (counted once).'
  say '  "all" downloads every different map file in this list.'
}
resolve_map_ids() { # "1,3" / "alberta europe" / "all" -> ids, one per line
  local tok out="" id total
  total="$(map_catalog | wc -l | tr -d ' ')"
  [ -n "$total" ] || total=0
  for tok in $(printf '%s' "$1" | tr ',' ' ' | tr 'A-Z' 'a-z'); do
    if [ "$tok" = all ]; then map_catalog | awk -F'|' '{ print $1 }'; return 0; fi
    case "$tok" in
      *[!0-9]*) id="$(map_field "$tok" 1)"; [ -n "$id" ] || { warn "  (Unknown map '$tok' - skipped)" >&2; continue; } ;;
      *) if [ "$tok" -ge 1 ] && [ "$tok" -le "$total" ]; then id="$(map_catalog | sed -n "${tok}p" | cut -d'|' -f1)"; else warn "  (No number $tok in the list - skipped)" >&2; continue; fi ;;
    esac
    case " $out " in *" $id "*) ;; *) out="$out $id" ;; esac
  done
  for id in $out; do printf '%s\n' "$id"; done
}
map_unique_ids() { # ids on the command line -> one id per file prefix (first wins)
  local id seen="" prefix
  for id in "$@"; do
    [ -n "$id" ] || continue
    prefix="$(map_field "$id" 3)"
    [ -n "$prefix" ] || continue
    case " $seen " in *" $prefix "*) ;; *) seen="$seen $prefix"; printf '%s\n' "$id" ;; esac
  done
}
map_gb() { # total GB still to download, shared prefixes counted once
  local id total=0 g
  for id in $(map_unique_ids "$@"); do
    prefix_installed "$(map_field "$id" 3)" >/dev/null && continue
    g="$(map_field "$id" 4)"; total="$(awk -v a="$total" -v b="${g:-0}" 'BEGIN { printf "%.2f", a + b }')"
  done
  printf '%s\n' "$total"
}
install_map() { # install_map <id>
  local id="$1" dir prefix about file have url size part free gb
  if have="$(prefix_installed "$(map_field "$id" 3)")"; then ok "  Already added: $(map_field "$id" 6) ($have)"; return 0; fi
  dir="$(map_field "$id" 2)"; prefix="$(map_field "$id" 3)"; about="$(map_field "$id" 6)"; gb="$(map_field "$id" 4)"
  if awk -v g="${gb:-0}" 'BEGIN { exit !(g+0 >= 4) }' && fat32_blocked "$LIBRARY"; then
    err "    This drive is FAT32, which cannot store a file larger than 4 GB. $about needs exFAT, NTFS, or APFS. Skipped."; return 1
  fi
  file="$(resolve_latest_zim "$dir" "$prefix")"
  [ -n "$file" ] || { err "  Could not find $prefix on download.kiwix.org (no internet?)"; return 1; }
  url="$KIWIX_BASE/$dir/$file"; size="$(remote_size "$url")"; part="$(file_size "$LIBRARY/$file.part")"
  free="$(free_bytes "$LIBRARY")"
  say "  - $about: $file ($(gb "$size"))"
  if [ "$size" -gt 0 ] && [ "$free" -lt $((size - part + 2000000000)) ]; then
    err "    Not enough free space: needs $(gb $((size - part))), only $(gb "$free") free on this drive. Skipped."; return 1
  fi
  get_zim "$dir" "$file" no
}
write_maps_index() {
  local id file about first=yes
  {
    printf 'window.KIT_MAPS = [\n'
    while IFS='|' read -r id _ prefix _ _ about; do
      [ -n "$id" ] || continue
      file="$(prefix_installed "$prefix" 2>/dev/null || true)"
      [ -n "$file" ] || continue
      about="$(json_escape "$about")"
      [ "$first" = yes ] || printf ',\n'
      first=no
      printf '  { id: "%s", file: "%s", about: "%s" }' "$id" "$file" "$about"
    done <<EOF_IDX
$(map_catalog)
EOF_IDX
    printf '\n];\n'
  } > "$WWW_DIR/maps-index.js" 2>/dev/null || true
}
make_linux_desktop() {
  local d="${XDG_DESKTOP_DIR:-$HOME/Desktop}" f
  [ -d "$d" ] || return 0
  f="$d/offline-ai-kit.desktop"
  if printf '[Desktop Entry]\nType=Application\nName=Offline AI\nComment=Start the Offline AI Kit\nExec=bash "%s/%s"\nPath=%s\nTerminal=true\nCategories=Utility;\n' "$KIT" "$LAUNCH_START" "$KIT" > "$f" 2>/dev/null; then
    chmod +x "$f" 2>/dev/null || true
    ok "  Put an 'Offline AI' shortcut on the Desktop."
  else
    warn "  Could not create the Desktop shortcut (not a problem; use bash \"$KIT/$LAUNCH_START\")."
  fi
}

# ---------- Which computer is this, and where its programs live ----------
# Keep folder names and the missing-program sentences in step with www/universal.js.
UNIVERSAL_PROGRAM_GB=14.0
dir_has_ollama() {
  [ -f "$1/ollama" ] || [ -f "$1/bin/ollama" ] || [ -f "$1/ollama.exe" ] || [ -f "$1/bin/ollama.exe" ]
}
dir_has_kiwix() {
  local f
  [ -f "$1/kiwix-serve" ] || [ -f "$1/kiwix-serve.exe" ] && return 0
  for f in "$1"/*/kiwix-serve "$1"/*/kiwix-serve.exe; do
    [ -f "$f" ] && return 0
  done
  return 1
}
legacy_ollama_dir() {
  if [ "${KIT_OS:-mac}" = linux ]; then printf '%s\n' "$RUNTIME/linux-ollama"; return; fi
  if [ "$OLLAMA_CHANNEL" = pinned ]; then printf '%s\n' "$RUNTIME/mac-ollama-$OLLAMA_PIN_VERSION"
  else printf '%s\n' "$RUNTIME/mac-ollama"; fi
}
legacy_kiwix_dir() {
  if [ "${KIT_OS:-mac}" = linux ]; then
    if [ "$LINUX_CPU" = arm ]; then printf '%s\n' "$RUNTIME/linux-kiwix-arm"; else printf '%s\n' "$RUNTIME/linux-kiwix"; fi
    return
  fi
  if [ "$MAC_ARCH" = x86_64 ]; then printf '%s\n' "$RUNTIME/mac-kiwix-intel"; else printf '%s\n' "$RUNTIME/mac-kiwix"; fi
}
libc_file_matches() { # libc_file_matches <platform id>
  local f="$RUNTIME/$1/LIBC" got
  [ "${KIT_OS:-mac}" = linux ] || return 0
  [ -f "$f" ] || return 0
  got="$(tr -d '[:space:]' < "$f")"
  [ -z "$got" ] || [ "$got" = "$LINUX_LIBC" ]
}
select_runtime_dirs() {
  local new_o new_k leg_o leg_k
  if [ -n "${OFFLINE_AI_PLATFORM:-}" ]; then PLATFORM_ID="$OFFLINE_AI_PLATFORM"
  elif [ "${KIT_OS:-mac}" = linux ]; then
    if [ "$LINUX_CPU" = arm ]; then PLATFORM_ID=linux-arm64; else PLATFORM_ID=linux-x64; fi
  elif [ "$MAC_ARCH" = x86_64 ]; then PLATFORM_ID=mac-x64
  else PLATFORM_ID=mac-arm64
  fi
  if [ "${KIT_OS:-mac}" != linux ] && [ "$OLLAMA_CHANNEL" = pinned ]; then new_o="$RUNTIME/$PLATFORM_ID/ollama-$OLLAMA_PIN_VERSION"
  else new_o="$RUNTIME/$PLATFORM_ID/ollama"; fi
  new_k="$RUNTIME/$PLATFORM_ID/kiwix"
  leg_o="$(legacy_ollama_dir)"
  leg_k="$(legacy_kiwix_dir)"
  if dir_has_ollama "$new_o"; then OLLAMA_DIR="$new_o"
  elif dir_has_ollama "$leg_o"; then OLLAMA_DIR="$leg_o"
  else OLLAMA_DIR="$new_o"; fi
  if dir_has_kiwix "$new_k" && libc_file_matches "$PLATFORM_ID"; then KIWIX_DIR="$new_k"
  elif dir_has_kiwix "$leg_k"; then KIWIX_DIR="$leg_k"
  else KIWIX_DIR="$new_k"; fi
}
clear_quarantine() {
  command -v xattr >/dev/null 2>&1 || return 0
  [ "$(uname -s)" = Darwin ] || return 0
  [ -e "$1" ] || return 0
  xattr -dr com.apple.quarantine "$1" 2>/dev/null || true
}
# Static zstd v1.5.6-bcr2. Stock macOS tar cannot read .tar.zst, and some Windows tar cannot either.
# Same pins as scripts/programs.ps1. The checked file is cached under runtime/_host-tools.
# zstd_windows_x86_64.exe 8765d39af6a89f5b7b05854d08027e739c8f2245c4488c8365b3ddaf5cdbcf28
# zstd_windows_arm64.exe ef983e169862f9d32652c9017e500052bd31ce5a2c7cb16bccdb71bcfa90c884
ZSTD_TOOL_BASE="https://github.com/aspect-build/zstd-prebuilt/releases/download/v1.5.6-bcr2"
ZSTD_BIN=""
host_zstd_spec() { # prints "<file> <sha256>" for the computer running setup
  local arch
  arch="$(uname -m)"
  case "$(uname -s)" in
    Darwin)
      if [ "$arch" = arm64 ] || [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = 1 ]; then
        printf '%s %s\n' zstd_darwin_arm64 9848858f7332effb071818f282b3ac3052085e3dafa9ae09f0060b7e211a80dc
      else
        printf '%s %s\n' zstd_darwin_amd64 d81be8618553d7d658e09da669ffd68ec76d8095161a590c9b8a1a99fce67ca8
      fi
      ;;
    Linux)
      case "$arch" in
        aarch64|arm64) printf '%s %s\n' zstd_linux_arm64 4fa2386a975c2120f91f3103bd4268a19a341cb9063417f3829018e94f28c8c6 ;;
        *) printf '%s %s\n' zstd_linux_amd64 190c196b46883a234238d9c52a211c1494df79bb170fbe30c6fc22639d5d4731 ;;
      esac
      ;;
  esac
}
ensure_zstd() { # sets ZSTD_BIN to a zstd that can decompress. Downloads one if this computer has none.
  local spec file want dest got cache run
  ZSTD_BIN=""
  if command -v zstd >/dev/null 2>&1; then ZSTD_BIN="$(command -v zstd)"; return 0; fi
  if [ -x /opt/homebrew/bin/zstd ]; then ZSTD_BIN=/opt/homebrew/bin/zstd; return 0; fi
  if [ -x /usr/local/bin/zstd ]; then ZSTD_BIN=/usr/local/bin/zstd; return 0; fi
  spec="$(host_zstd_spec)"
  [ -n "$spec" ] || return 1
  file="${spec%% *}"
  want="${spec##* }"
  dest="$RUNTIME/_host-tools/$file"
  if [ ! -f "$dest" ] || [ "$(sha256_of "$dest")" != "$want" ]; then
    say "  Getting a small zstd program so this computer can open Linux archives..."
    mkdir -p "$RUNTIME/_host-tools"
    rm -f "$dest"
    download_resumable "$ZSTD_TOOL_BASE/$file" "$dest" 0 "zstd" no 5 || return 1
    got="$(sha256_of "$dest")"
    if [ "$got" != "$want" ]; then rm -f "$dest"; err "The zstd program was damaged (checksum mismatch). Run setup again."; return 1; fi
  fi
  chmod +x "$dest" 2>/dev/null || true
  clear_quarantine "$dest"
  run="$dest"
  if [ ! -x "$run" ] || ! "$run" --version >/dev/null 2>&1; then
    if [ "$(uname -s)" = Darwin ]; then cache="$HOME/Library/Caches/offline-ai-kit"
    else cache="${XDG_CACHE_HOME:-$HOME/.cache}/offline-ai-kit"; fi
    mkdir -p "$cache"
    cp -f "$dest" "$cache/$file"
    chmod +x "$cache/$file" 2>/dev/null || true
    clear_quarantine "$cache/$file"
    run="$cache/$file"
  fi
  if ! "$run" --version >/dev/null 2>&1; then err "Could not run the zstd program ($file)."; return 1; fi
  ZSTD_BIN="$run"
  return 0
}
unpack_archive() { # unpack_archive <archive> <dest>
  local file="$1" dest="$2"
  mkdir -p "$dest"
  case "$file" in
    *.zip)
      if command -v unzip >/dev/null 2>&1 && unzip -q -o "$file" -d "$dest"; then return 0; fi
      if tar -xf "$file" -C "$dest" 2>/dev/null; then return 0; fi
      if command -v python3 >/dev/null 2>&1 && python3 -c 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$file" "$dest"; then return 0; fi
      err "Could not unpack $file (need unzip, tar, or python3)."
      return 1
      ;;
    *)
      if tar -xf "$file" -C "$dest" 2>/dev/null; then return 0; fi
      case "$file" in
        *.zst|*.tar.zst) ;;
        *) err "Could not unpack $file."; return 1 ;;
      esac
      # The first tar can leave a partial tree when it cannot read zstd.
      rm -rf "$dest"
      mkdir -p "$dest"
      if tar --zstd -xf "$file" -C "$dest" 2>/dev/null; then return 0; fi
      rm -rf "$dest"
      mkdir -p "$dest"
      if ensure_zstd && (set -o pipefail; "$ZSTD_BIN" -dc "$file" | tar -xf - -C "$dest"); then return 0; fi
      err "Could not unpack $file."
      err "This file is compressed with zstd, and this computer could not read it."
      return 1
      ;;
  esac
}
missing_program_message() {
  local id="${1:-${PLATFORM_ID:-}}" who setup folder
  case "$id" in
    windows-x64) who="Windows (64-bit)" ;;
    windows-arm64) who="Windows on ARM" ;;
    windows-x86) who="32-bit Windows" ;;
    mac-arm64) who="a Mac with an Apple chip" ;;
    mac-x64) who="an Intel Mac" ;;
    linux-x64) who="64-bit Linux" ;;
    linux-arm64) who="Linux on ARM" ;;
    *) who="this computer" ;;
  esac
  case "$id" in
    mac-*) setup="SETUP-MAC.command" ;;
    linux-*) setup="bash SETUP-LINUX.sh" ;;
    *) setup="SETUP.bat" ;;
  esac
  folder="runtime/${id:-windows-x64}"
  say "This drive does not have the Offline AI programs for $who (folder $folder)."
  say "The library, models and maps on the drive are shared, and they are still here."
  say "Connect this computer to the internet and run $setup, then choose All computers (universal drive)."
  say "You can also choose This computer only, which adds just this computer's programs."
  if [ "$id" = windows-arm64 ] || [ "$id" = windows-x86 ]; then
    say "The Windows programs in this kit are for 64-bit Intel and AMD PCs (runtime/windows-x64)."
  fi
  if [ "${KIT_OS:-mac}" = linux ] && [ -f "$RUNTIME/$PLATFORM_ID/LIBC" ]; then
    local got
    got="$(tr -d '[:space:]' < "$RUNTIME/$PLATFORM_ID/LIBC")"
    if [ -n "$got" ] && [ "$got" != "$LINUX_LIBC" ]; then
      say "The programs in runtime/$PLATFORM_ID were built for $got. This computer uses $LINUX_LIBC."
      say "Connect to the internet and run bash SETUP-LINUX.sh on this computer to add the matching programs."
    fi
  fi
}
programs_missing() {
  if [ "${KIT_OS:-mac}" = linux ] && [ -f "$RUNTIME/$PLATFORM_ID/LIBC" ]; then
    local got
    got="$(tr -d '[:space:]' < "$RUNTIME/$PLATFORM_ID/LIBC")"
    if [ -n "$got" ] && [ "$got" != "$LINUX_LIBC" ] && [ "$KIWIX_DIR" = "$RUNTIME/$PLATFORM_ID/kiwix" ]; then return 0; fi
  fi
  dir_has_kiwix "$KIWIX_DIR" || return 0
  if [ "$AI_AVAILABLE" = yes ] && [ "$USE_SYSTEM_OLLAMA" != yes ]; then
    dir_has_ollama "$OLLAMA_DIR" || return 0
  fi
  return 1
}
universal_extra_gb() {
  # Mac and Linux estimates already include about 1 GB for this computer's programs.
  local mine=1.0
  case "${PLATFORM_ID:-}" in
    windows-x64|windows-arm64|windows-x86) mine=2.5 ;;
  esac
  awk -v u="$UNIVERSAL_PROGRAM_GB" -v m="$mine" 'BEGIN { printf "%.1f", u - m }'
}
ollama_sha_for() { # ollama_sha_for <sha256sum text> <asset>
  printf '%s\n' "$1" | tr -d '\r' | awk -v a="$2" '{ h=$1; f=$2; sub(/^\*/, "", f); sub(/^\.\//, "", f); if (f == a) { print h; exit } }'
}

# ---------- Which Kiwix / Ollama build to unpack ----------
install_kiwix_tools() { # [dest] [filename-regex] [label] [libc]
  local dest pattern label libc rel kfile want
  rel="$KIWIX_BASE/release/kiwix-tools/"
  if [ $# -ge 2 ]; then
    dest="$1"; pattern="$2"; label="${3:-programs}"; libc="${4:-}"
  else
    dest="$KIWIX_DIR"; libc=""
    if [ "${KIT_OS:-mac}" = linux ]; then
      if [ "$LINUX_LIBC" = musl ]; then pattern="kiwix-tools_linux-${LINUX_KIWIX_ARCH}-musl-[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9]+)?\\.tar\\.gz"
      else pattern="kiwix-tools_linux-${LINUX_KIWIX_ARCH}-[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9]+)?\\.tar\\.gz"; fi
      label="Linux $LINUX_KIWIX_ARCH $LINUX_LIBC"
      libc="$LINUX_LIBC"
    else
      pattern="kiwix-tools_macos-${KIWIX_ARCH}-[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9]+)?\\.tar\\.gz"
      label="macOS $KIWIX_ARCH"
    fi
    say "[1/4] Library program (kiwix-tools for $label)..."
  fi
  [ $# -ge 2 ] && say "  Library program (kiwix-tools for $label)..."
  if dir_has_kiwix "$dest"; then ok "  Already installed."; return 0; fi
  kfile="$(curl_text "$rel" | grep -oE "href=\"${pattern}\"" | sed -e 's/^href="//' -e 's/"$//' |
    awk '{ v = $0
           if (match(v, /[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?\.(tar\.gz|zip)$/)) {
             ver = substr(v, RSTART, RLENGTH); sub(/\.(tar\.gz|zip)$/, "", ver); gsub(/-/, ".", ver)
             n = split(ver, p, ".")
             printf "%05d%05d%05d%05d %s\n", p[1], p[2], p[3], (n > 3 ? p[4] : 0), $0
           } }' | sort | tail -1 | awk '{ print $2 }')"
  if [ -z "$kfile" ]; then err "Could not find kiwix-tools for $label on download.kiwix.org"; return 1; fi
  say "  Downloading $kfile"
  download_resumable "$rel$kfile" "$RUNTIME/$kfile" 0 "$kfile" no 20 || return 1
  want="$(curl_text "$rel$kfile.md5" | awk '{ print $1 }')"
  if [ "$(md5_of "$RUNTIME/$kfile")" != "$want" ]; then rm -f "$RUNTIME/$kfile"; err "kiwix-tools download was damaged (checksum mismatch). Run setup again."; return 1; fi
  rm -rf "$dest"
  mkdir -p "$dest"
  unpack_archive "$RUNTIME/$kfile" "$dest" || { rm -f "$RUNTIME/$kfile"; return 1; }
  rm -f "$RUNTIME/$kfile"
  materialize_symlinks "$dest"
  clear_quarantine "$dest"
  case "$dest" in
    "$RUNTIME/linux-x64/kiwix"|"$RUNTIME/linux-arm64/kiwix")
      [ -n "$libc" ] && printf '%s\n' "$libc" > "$(dirname "$dest")/LIBC" ;;
  esac
  dir_has_kiwix "$dest" || { err "kiwix-tools for $label did not unpack as expected."; return 1; }
  ok "  Installed."
  select_runtime_dirs
}
install_one_ollama() { # install_one_ollama <dest> <asset> <base-url> [pinned]
  local dest="$1" asset="$2" base="$3" pin="${4:-}" sums want archive tmp
  if dir_has_ollama "$dest"; then ok "  Already installed."; return 0; fi
  sums="$(curl_text "${base}sha256sum.txt" || true)"
  want="$(ollama_sha_for "$sums" "$asset")"
  if [ -z "$want" ] && [ "${asset%.tgz}" != "$asset" ]; then
    asset="${asset%.tgz}.tar.zst"
    say "  Using $asset (this release has no .tgz)."
    want="$(ollama_sha_for "$sums" "$asset")"
  fi
  if [ -z "$want" ]; then err "Could not read the Ollama checksum list."; return 1; fi
  if [ "$pin" = yes ] && [ "$want" != "$OLLAMA_PIN_SHA256" ]; then
    err "The Ollama $OLLAMA_PIN_VERSION checksum online does not match the one built into this kit. Not installing it."; return 1
  fi
  archive="$RUNTIME/$asset"
  # A failed unpack leaves this file. Reuse it when the checksum still matches.
  if [ -f "$archive" ] && [ "$(sha256_of "$archive")" = "$want" ]; then
    say "  Using the checked download already on the drive: $asset"
  else
    download_resumable "$base$asset" "$archive" 0 "$asset" no 20 || return 1
    if [ "$(sha256_of "$archive")" != "$want" ]; then rm -f "$archive"; err "Ollama download was damaged (checksum mismatch). Run setup again."; return 1; fi
  fi
  # Unpack beside the platform folder. A failure leaves that folder, and a checked .tar.zst, alone.
  tmp="$RUNTIME/_unpack-$asset"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  if ! unpack_archive "$archive" "$tmp"; then
    rm -rf "$tmp"
    case "$archive" in
      *.tar.zst|*.zst) err "Left the checked download in place: $archive" ;;
      *) rm -f "$archive" ;;
    esac
    return 1
  fi
  if ! dir_has_ollama "$tmp"; then
    rm -rf "$tmp"
    err "Ollama did not unpack as expected."
    case "$archive" in
      *.tar.zst|*.zst) err "Left the checked download in place: $archive" ;;
      *) rm -f "$archive" ;;
    esac
    return 1
  fi
  materialize_symlinks "$tmp"
  clear_quarantine "$tmp"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  if ! mv "$tmp" "$dest"; then err "Could not put Ollama into $dest. The checked download is still at $archive."; return 1; fi
  rm -f "$archive"
  ok "  Installed."
}
install_darwin_copies() { # install_darwin_copies current|pinned  (real copies in both Mac folders)
  local channel="$1" destname asset base pin tmp archive id dest sums want
  destname="ollama"
  asset="ollama-darwin.tgz"
  base="https://github.com/ollama/ollama/releases/latest/download/"
  pin=""
  if [ "$channel" = pinned ]; then
    destname="ollama-$OLLAMA_PIN_VERSION"
    base="https://github.com/ollama/ollama/releases/download/$OLLAMA_PIN_VERSION/"
    pin=yes
  fi
  if dir_has_ollama "$RUNTIME/mac-arm64/$destname" && dir_has_ollama "$RUNTIME/mac-x64/$destname"; then
    ok "  Mac AI program ($destname) already installed for both chips."; return 0
  fi
  sums="$(curl_text "${base}sha256sum.txt" || true)"
  want="$(ollama_sha_for "$sums" "$asset")"
  [ -n "$want" ] || { err "Could not read the Ollama checksum list for the Mac build."; return 1; }
  if [ "$pin" = yes ] && [ "$want" != "$OLLAMA_PIN_SHA256" ]; then
    err "The Ollama $OLLAMA_PIN_VERSION checksum online does not match the one built into this kit. Not installing it."; return 1
  fi
  archive="$RUNTIME/ollama-darwin-$channel.tgz"
  download_resumable "$base$asset" "$archive" 0 "Mac $asset" no 20 || return 1
  if [ "$(sha256_of "$archive")" != "$want" ]; then rm -f "$archive"; err "Ollama for Mac was damaged (checksum mismatch). Run setup again."; return 1; fi
  tmp="$RUNTIME/_unpack-darwin-$channel"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  unpack_archive "$archive" "$tmp" || { rm -rf "$tmp" "$archive"; return 1; }
  rm -f "$archive"
  materialize_symlinks "$tmp"
  for id in mac-arm64 mac-x64; do
    dest="$RUNTIME/$id/$destname"
    if dir_has_ollama "$dest"; then ok "  Already installed: runtime/$id/$destname"; continue; fi
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -R "$tmp/." "$dest/"
    materialize_symlinks "$dest"
    clear_quarantine "$dest"
    ok "  Installed runtime/$id/$destname"
  done
  rm -rf "$tmp"
}
install_universal_programs() {
  local base failed=""
  if [ "$TEST_MODE" = yes ]; then warn "TEST MODE: not downloading programs for other computers."; return 0; fi
  say "All computers (universal drive): programs for Windows, Mac and Linux."
  say "Models, Wikipedia, extra libraries and maps stay one shared copy."
  base="https://github.com/ollama/ollama/releases/latest/download/"
  # One platform failing must not skip the rest, and must not remove folders that already installed.
  install_kiwix_tools "$RUNTIME/windows-x64/kiwix" 'kiwix-tools_win-x86_64-[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?\.zip' "Windows x64" "" || failed="$failed windows-x64/kiwix"
  install_kiwix_tools "$RUNTIME/mac-arm64/kiwix" 'kiwix-tools_macos-arm64-[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?\.tar\.gz' "macOS Apple chip" "" || failed="$failed mac-arm64/kiwix"
  install_kiwix_tools "$RUNTIME/mac-x64/kiwix" 'kiwix-tools_macos-x86_64-[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?\.tar\.gz' "macOS Intel" "" || failed="$failed mac-x64/kiwix"
  install_kiwix_tools "$RUNTIME/linux-x64/kiwix" 'kiwix-tools_linux-x86_64-[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?\.tar\.gz' "Linux 64-bit PC" glibc || failed="$failed linux-x64/kiwix"
  install_kiwix_tools "$RUNTIME/linux-arm64/kiwix" 'kiwix-tools_linux-aarch64-[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?\.tar\.gz' "Linux ARM" glibc || failed="$failed linux-arm64/kiwix"
  install_darwin_copies current || failed="$failed mac-ollama"
  install_darwin_copies pinned || failed="$failed mac-ollama-v0.12.9"
  install_one_ollama "$RUNTIME/windows-x64/ollama" "ollama-windows-amd64.zip" "$base" "" || failed="$failed windows-x64/ollama"
  install_one_ollama "$RUNTIME/linux-x64/ollama" "ollama-linux-amd64.tgz" "$base" "" || failed="$failed linux-x64/ollama"
  install_one_ollama "$RUNTIME/linux-arm64/ollama" "ollama-linux-arm64.tgz" "$base" "" || failed="$failed linux-arm64/ollama"
  select_runtime_dirs
  if [ -n "$failed" ]; then
    err "Some programs for other computers were not installed:$failed"
    err "Programs that installed were left in place. Run setup again to finish the rest."
    err "A checked .tar.zst is kept, so a failed Linux download is not fetched again."
    return 1
  fi
}
install_portable_ollama() {
  local asset base pin=""
  if [ "${KIT_OS:-mac}" = linux ]; then say "[2/4] AI program (Ollama for Linux, portable)..."
  else say "[2/4] AI program (Ollama for macOS, portable)..."; fi
  if [ "$USE_SYSTEM_OLLAMA" = yes ]; then say "  Using your own Ollama on port $OLLAMA_PORT (USE_SYSTEM_OLLAMA) - not downloading one."; return 0; fi
  if [ "${KIT_OS:-mac}" != linux ] && [ "$AI_AVAILABLE" != yes ]; then warn "  Skipped: needs macOS 13 (Ventura) or newer (this Mac has $MACOS_VER)."; return 0; fi
  if dir_has_ollama "$OLLAMA_DIR"; then ok "  Already installed."; return 0; fi
  if [ "${KIT_OS:-mac}" = linux ]; then
    asset="$LINUX_OLLAMA_ASSET"
    base="https://github.com/ollama/ollama/releases/latest/download/"
  else
    asset="ollama-darwin.tgz"
    if [ "$OLLAMA_CHANNEL" = pinned ]; then
      base="https://github.com/ollama/ollama/releases/download/$OLLAMA_PIN_VERSION/"
      pin=yes
    else base="https://github.com/ollama/ollama/releases/latest/download/"; fi
  fi
  install_one_ollama "$OLLAMA_DIR" "$asset" "$base" "$pin" || return 1
  select_runtime_dirs
}

# ---------- Check for updates (only when asked; needs internet; never downloads or changes anything) ----------
version_cmp() { # version_cmp A B -> prints -1, 0 or 1 (accepts v1.2.3 and 1.2.3-beta; pre-release sorts first)
  awk -v a="$1" -v b="$2" 'function parse(v, n, pre,   p, i, k) { sub(/^[vV]/, "", v); pre[1] = ""; i = index(v, "-"); if (i) { pre[1] = substr(v, i + 1); v = substr(v, 1, i - 1) }
      k = split(v, p, "."); for (i = 1; i <= 3; i++) { n[i] = (i <= k) ? p[i] + 0 : 0 } }
    BEGIN { parse(a, x, xp); parse(b, y, yp)
      for (i = 1; i <= 3; i++) { if (x[i] < y[i]) { print -1; exit } if (x[i] > y[i]) { print 1; exit } }
      if (xp[1] == yp[1]) { print 0; exit } if (xp[1] == "") { print 1; exit } if (yp[1] == "") { print -1; exit }
      print (xp[1] < yp[1]) ? -1 : 1 }'
}
update_check() {
  local api="${OFFLINE_AI_RELEASES_API:-$RELEASES_API}" json latest page zip
  say "  This kit: version $KIT_VERSION. Asking GitHub for the newest version..."
  if ! json="$(curl -sS -L --fail --connect-timeout 8 --max-time 20 -H 'Accept: application/vnd.github+json' -H 'User-Agent: offline-ai-kit' "$api" 2>/dev/null)" || [ -z "$json" ]; then
    warn "  You appear to be offline (or GitHub could not be reached) - that's fine, the kit doesn't need internet to run."
    say "UPDATE CHECK: OFFLINE"; return 0
  fi
  json="$(printf '%s' "$json" | tr -d '\n')"
  latest="$(printf '%s' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"; latest="${latest#[vV]}"
  if [ -z "$latest" ]; then warn "  GitHub sent an answer the kit could not read. Try again later."; say "UPDATE CHECK: ERROR"; return 0; fi
  if [ "$(version_cmp "$KIT_VERSION" "$latest")" -ge 0 ]; then ok "  You're on the latest version, v$KIT_VERSION."; say "UPDATE CHECK: UP TO DATE (latest v$latest)"; return 0; fi
  page="$(printf '%s' "$json" | grep -oE '"html_url"[[:space:]]*:[[:space:]]*"https://github.com/[^"]*/releases/tag/[^"]*"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
  zip="$(printf '%s' "$json" | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*Offline-AI-Kit-[^"]*\.zip"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
  warn "  A newer version is available: v$latest (you have v$KIT_VERSION)."
  say  "  What's new:   ${page:-https://github.com/wallenberg4001-del/offline-ai-kit/releases/latest}"
  [ -n "$zip" ] && say "  Download:     $zip"
  say  "  Nothing was downloaded or changed. To update: download the ZIP, unzip it, and copy your"
  say  "  \"library\", \"ollama-models\" and \"runtime\" folders (and kit-settings.ini) into the new folder."
  say  "UPDATE CHECK: UPDATE AVAILABLE v$latest"
}

open_url() {
  if [ "${KIT_OS:-mac}" = linux ] && command -v xdg-open >/dev/null 2>&1; then xdg-open "$1" >/dev/null 2>&1 || true; return 0; fi
  if command -v open >/dev/null 2>&1; then open "$1" 2>/dev/null || true; else say "  Open: $1"; fi
}

pause_exit() { # keep a double-clicked Terminal window readable
  local code="${1:-0}"
  if [ -t 0 ]; then printf '\n'; read -r -p "Press Return to close this window. " _ || true; fi
  exit "$code"
}
select_runtime_dirs
