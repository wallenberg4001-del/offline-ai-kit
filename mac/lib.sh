#!/bin/bash
# Shared settings and helpers for the Offline AI Kit (macOS, Apple Silicon).
# Uses only tools built into macOS: bash 3.2, curl, shasum, tar, df, sysctl, open, caffeinate.
# Everything lives inside the kit folder; nothing is installed system-wide.
# shellcheck disable=SC2034  # variables are used by the scripts that source this file

set -u

MAC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT="$(cd "$MAC_DIR/.." && pwd)"
RUNTIME="$KIT/runtime"
OLLAMA_DIR="$RUNTIME/mac-ollama"      # Windows uses runtime/ollama, so one drive can hold both
KIWIX_DIR="$RUNTIME/mac-kiwix"
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

SETTINGS_FILE="$KIT/kit-settings.ini"   # optional, for power users (see ADVANCED.md)

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
qwen3:30b|18.6|32|Biggest; fast for its size (mixture-of-experts)"

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
# Hardware profiles (by unified memory): lite <16 GB, standard 16-23, large 24-31, largest 32+
profile_tier()   { case "$1" in lite) echo essentials ;; *) echo recommended ;; esac; }
profile_models() { case "$1" in lite) models_for_set lite ;; standard) models_for_set 16 ;; large) models_for_set 24 ;; *) models_for_set 32 ;; esac; }
profile_label()  { case "$1" in lite) echo "LITE (8 GB Macs)" ;; standard) echo "STANDARD (16 GB Macs)" ;; large) echo "LARGE (24 GB+ Macs)" ;; *) echo "LARGEST (32 GB+ Macs)" ;; esac; }
profile_for_ram() { if [ "$1" -lt 16 ]; then echo lite; elif [ "$1" -lt 24 ]; then echo standard; elif [ "$1" -lt 32 ]; then echo large; else echo largest; fi; }
PROFILE_ORDER="largest large standard lite"
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
  local lib=11.2; [ "$1" = lite ] && lib=3.8
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
# download_resumable <url> <out file> <expected bytes or 0> <label> <track wiki progress: yes/no> <max tries>
download_resumable() {
  local url="$1" out="$2" total="$3" label="$4" track="$5" max="${6:-1000}"
  local part="$out.part" tries=0 have pid code now last last_t t speed pct mbps line
  [ "$total" -gt 0 ] 2>/dev/null || total="$(remote_size "$url")"
  while :; do
    have="$(file_size "$part")"
    if [ "$total" -gt 0 ] && [ "$have" -eq "$total" ]; then break; fi
    if [ "$total" -gt 0 ] && [ "$have" -gt "$total" ]; then rm -f "$part"; have=0; fi
    tries=$((tries + 1))
    if [ "$tries" -gt "$max" ]; then err "Gave up downloading $label after $max tries."; return 1; fi
    curl -sS -L --fail --retry 5 --retry-delay 10 --connect-timeout 30 \
         --speed-limit 1000 --speed-time 120 -C - -o "$part" "$url" &
    pid=$!
    last="$have"; last_t="$(date +%s)"; speed=0; line=0
    while kill -0 "$pid" 2>/dev/null; do
      sleep 2
      now="$(file_size "$part")"; t="$(date +%s)"
      if [ $((t - last_t)) -ge 5 ]; then speed=$(( (now - last) / (t - last_t) )); last="$now"; last_t="$t"; fi
      pct=0; [ "$total" -gt 0 ] && pct="$(awk -v a="$now" -v b="$total" 'BEGIN { printf "%.1f", 100 * a / b }')"
      mbps="$(awk -v s="$speed" 'BEGIN { printf "%.1f", s / 1e6 }')"
      local eta=""
      if [ "$speed" -gt 0 ] && [ "$total" -gt 0 ]; then
        eta="$(awk -v r=$(( (total - now) / speed )) 'BEGIN { printf " - about %dh %02dm left", r / 3600, (r % 3600) / 60 }')"
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
stop_kit() {
  local p
  if p="$(kit_pid "$1")"; then
    pkill -TERM -P "$p" 2>/dev/null || true
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
  bin="$(ollama_bin)" || { err "  Ollama is missing. Run SETUP-MAC.command first."; return 1; }
  ensure_dirs
  # Kit-only environment: models, keys and settings stay inside the kit folder.
  # OLLAMA_ORIGINS=* lets the chat page (opened as a local file) talk to it; it only listens on 127.0.0.1.
  HOME="$HOME_DIR" OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" OLLAMA_MODELS="$MODELS_DIR" \
  OLLAMA_ORIGINS='*' OLLAMA_KEEP_ALIVE=10m \
    nohup "$bin" serve >> "$LOG_DIR/ollama-mac.log" 2>&1 < /dev/null &
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
  nohup "$bin" --address=127.0.0.1 --port="$LIBRARY_PORT" "${zims[@]}" >> "$LOG_DIR/kiwix-mac.log" 2>&1 < /dev/null &
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
