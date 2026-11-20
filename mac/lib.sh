#!/bin/bash
# Shared settings and helpers for the Offline AI Kit (macOS: Apple Silicon and Intel Macs).
# Uses only tools built into macOS: bash 3.2, curl, shasum, tar, df, sysctl, open, caffeinate.
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
is_yes() { case "$1" in [Yy]|[Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|1) return 0 ;; esac; return 1; }
load_settings() {
  USE_SYSTEM_OLLAMA=no; is_yes "$(setting USE_SYSTEM_OLLAMA no)" && USE_SYSTEM_OLLAMA=yes
  SKIP_WIKIPEDIA=no;    is_yes "$(setting SKIP_WIKIPEDIA no)" && SKIP_WIKIPEDIA=yes
  LIBRARY_PORT="$(setting LIBRARY_PORT 8090)"
  if [ "$USE_SYSTEM_OLLAMA" = yes ]; then OLLAMA_PORT="$(setting OLLAMA_PORT 11434)"; else OLLAMA_PORT="$(setting OLLAMA_PORT 11435)"; fi
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
    lite) echo "LITE (8 GB Macs)" ;; standard) echo "STANDARD (16 GB Macs)" ;; large) echo "LARGE (24 GB+ Macs)" ;;
    intel) echo "INTEL (Intel Macs - AI runs on the processor, so answers are slower)" ;;
    intel-small) echo "INTEL SMALL (Intel Macs, smaller library to fit the disk)" ;;
    *) echo "LARGEST (32 GB+ Macs)" ;;
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

write_chat_config() { printf 'window.KIT_CONFIG = { ollamaPort: %s, libraryPort: %s };\n' "$OLLAMA_PORT" "$LIBRARY_PORT" > "$WWW_DIR/kit-config.js" 2>/dev/null || true; }

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
  local dir="$1" prefix="$2" esc
  esc="$(printf '%s' "$prefix" | sed 's/[.]/\\./g')"
  curl_text "$KIWIX_BASE/$dir/" | grep -oE "href=\"${esc}_[0-9]{4}-[0-9]{2}\.zim\"" |
    sed -e 's/^href="//' -e 's/"$//' | sort | tail -1
}

expected_sha() { curl_text "$1" | grep -oE '[0-9a-fA-F]{64}' | head -1 | tr 'A-F' 'a-f'; }

# ---------- Wikipedia progress (read by STATUS and the chat page) ----------
write_wiki_status() { # state bytes total percent mbps message
  local msg json
  msg="$(json_escape "$6")"
  json="{\"state\":\"$1\",\"bytes\":$2,\"total\":$3,\"percent\":$4,\"mbps\":$5,\"message\":\"$msg\",\"updated\":\"$(date '+%Y-%m-%d %H:%M:%S')\"}"
  printf '%s\n' "$json" > "$WIKI_PROGRESS" 2>/dev/null || true
  # The chat page is opened as a file on macOS, so it reads this .js instead of JSON.
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
  if [ ! -f "$dest" ]; then download_resumable "$url" "$dest" 0 "$file" "$track" 1000 || return 1; fi
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
pid_file() { printf '%s/%s.mac.pid' "$LOG_DIR" "$1"; }
kit_pid() { # prints the pid if that kit process is running (and really is ours)
  local pf p comm want
  pf="$(pid_file "$1")"
  [ -f "$pf" ] || return 1
  p="$(head -1 "$pf" 2>/dev/null)"
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null || return 1
  comm="$(ps -p "$p" -o command= 2>/dev/null)"
  case "$1" in kiwix) want=kiwix-serve ;; ollama) want=ollama ;; *) want=wiki-download ;; esac
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

ollama_bin() { [ -x "$OLLAMA_DIR/ollama" ] && printf '%s\n' "$OLLAMA_DIR/ollama"; }
kiwix_bin()  { local f; for f in "$KIWIX_DIR"/*/kiwix-serve "$KIWIX_DIR"/kiwix-serve; do [ -x "$f" ] && { printf '%s\n' "$f"; return 0; }; done; return 1; }

start_ollama() {
  local bin
  if port_up "$OLLAMA_PORT"; then say "  AI model server already running on port $OLLAMA_PORT."; return 0; fi
  if [ "$USE_SYSTEM_OLLAMA" = yes ]; then warn "  USE_SYSTEM_OLLAMA is on, but nothing answers on port $OLLAMA_PORT. Start your Ollama app first."; return 1; fi
  if [ "$AI_AVAILABLE" != yes ]; then warn "  The AI part needs macOS 13 (Ventura) or newer; this Mac has macOS $MACOS_VER. The library still works."; return 1; fi
  bin="$(ollama_bin)" || { err "  Ollama is missing. Run SETUP-MAC.command first."; return 1; }
  ensure_dirs
  # Kit-only environment: models, keys and settings stay inside the kit folder.
  # OLLAMA_ORIGINS=* lets the chat page (opened as a local file) talk to it; it only listens on 127.0.0.1.
  # ARCH_CMD is empty or "arch -x86_64" / "arch -arm64" (two words on purpose).
  # shellcheck disable=SC2086
  HOME="$HOME_DIR" OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" OLLAMA_MODELS="$MODELS_DIR" \
  OLLAMA_ORIGINS='*' OLLAMA_KEEP_ALIVE=10m \
    nohup $ARCH_CMD "$bin" serve >> "$LOG_DIR/ollama-mac.log" 2>&1 < /dev/null &
  printf '%s\n' "$!" > "$(pid_file ollama)"
  local i
  for i in $(seq 1 40); do port_up "$OLLAMA_PORT" && return 0; sleep 0.5; done
  warn "  The AI server did not answer yet. See logs/ollama-mac.log"
  return 1
}

start_kiwix() { # (re)starts kiwix-serve with every verified ZIM
  local bin zims=() m i
  stop_kit kiwix
  bin="$(kiwix_bin)" || { err "  Kiwix is missing. Run SETUP-MAC.command first."; return 1; }
  for m in "$VERIFIED_DIR"/*.zim; do
    [ -e "$m" ] || continue
    [ -f "$LIBRARY/$(basename "$m")" ] && zims+=("$LIBRARY/$(basename "$m")")
  done
  if [ "${#zims[@]}" -eq 0 ]; then warn "  No verified library files yet - the library will be empty."; return 1; fi
  for i in $(seq 1 10); do port_up "$LIBRARY_PORT" || break; sleep 0.5; done
  if port_up "$LIBRARY_PORT"; then err "  Port $LIBRARY_PORT is used by another program; the library cannot start."; return 1; fi
  # shellcheck disable=SC2086  # see start_ollama
  nohup $ARCH_CMD "$bin" --address=127.0.0.1 --port="$LIBRARY_PORT" "${zims[@]}" >> "$LOG_DIR/kiwix-mac.log" 2>&1 < /dev/null &
  printf '%s\n' "$!" > "$(pid_file kiwix)"
  for i in $(seq 1 30); do
    if port_up "$LIBRARY_PORT"; then say "  Library is serving ${#zims[@]} collection(s)."; return 0; fi
    sleep 0.5
  done
  warn "  The library did not answer yet. See logs/kiwix-mac.log"
  return 1
}

open_url() { if command -v open >/dev/null 2>&1; then open "$1" 2>/dev/null || true; else say "  Open: $1"; fi; }

pause_exit() { # keep a double-clicked Terminal window readable
  local code="${1:-0}"
  if [ -t 0 ]; then printf '\n'; read -r -p "Press Return to close this window. " _ || true; fi
  exit "$code"
}
