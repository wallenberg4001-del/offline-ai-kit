#!/bin/bash
# One-time setup for the Offline AI Kit on a Mac - Apple chip or Intel, detected automatically (needs internet).
# Safe to run again: finished downloads are skipped, half-finished ones resume.
#   EASY-INSTALL (Mac).command -> setup.sh --easy   (no questions; picks everything from the hardware)
#   SETUP-MAC.command        -> setup.sh          (menus)
# Power-user options (see ADVANCED.md): --profile lite|standard|large|largest|intel|intel-small  --tier essentials|recommended
#   --models lite|8|16|24|32|"name,name"  --zims id,id  --path DIR  --skip-wikipedia  --with-wikipedia
#   --use-system-ollama  --no-start  --yes  --test (quick test install, see ADVANCED.md)
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

DETECT=no; TEST=no; TIER=""; MODELS=""; YES=no; EASY=no; HWPROFILE=""; ZIMS=""; INSTALL_PATH=""; SKIPW=no; WITHW=no; SYSOLL=no; NOSTART=no
ORIG_ARGS=("$@")
while [ $# -gt 0 ]; do
  case "$1" in
    --easy) EASY=yes; YES=yes ;;
    --test) TEST=yes ;;
    --detect-only) DETECT=yes ;;
    --profile) HWPROFILE="${2:-}"; shift ;;
    --tier) TIER="${2:-}"; shift ;;
    --models) MODELS="${2:-}"; shift ;;
    --zims) ZIMS="${2:-}"; shift ;;
    --path) INSTALL_PATH="${2:-}"; shift ;;
    --skip-wikipedia) SKIPW=yes ;;
    --with-wikipedia) WITHW=yes ;;
    --use-system-ollama) SYSOLL=yes ;;
    --no-start) NOSTART=yes ;;
    --yes) YES=yes ;;
    *) warn "Unknown option: $1 (see ADVANCED.md)" ;;
  esac
  shift
done
[ -n "$TIER" ]   || TIER="$(setting LIBRARY_TIER '')"
[ -n "$MODELS" ] || MODELS="$(setting MODELS '')"
[ -n "$ZIMS" ]   || ZIMS="$(setting ZIMS '')"
if [ "$SYSOLL" = yes ]; then set_setting USE_SYSTEM_OLLAMA yes; load_settings; fi
ask() { # ask <question> <default>
  local a
  if [ "$YES" = yes ] || [ ! -t 0 ]; then printf '%s\n' "$2"; return; fi
  read -r -p "$1 [$2] " a || true
  if [ -z "$a" ]; then printf '%s\n' "$2"; else printf '%s\n' "$a"; fi
}

say "=================================================="
if [ "$EASY" = yes ]; then say "  Offline AI Kit - EASY INSTALL for Mac (no questions)"; else say "  Offline AI Kit - Mac setup"; fi
say "  Downloads everything once, so it all works later with NO internet."
say "=================================================="
say ""
[ "$(uname -s)" = Darwin ] || warn "Note: this script is for macOS. Continuing anyway (script testing)."
say "This Mac: $MAC_KIND, macOS $MACOS_VER"
[ "$TRANSLATED" = yes ] && say "  (This Terminal is running under Rosetta; the kit will still use the Apple-chip programs.)"
if [ "$MACOS_MAJOR" -lt 12 ]; then
  err "Sorry - this kit needs macOS 12 (Monterey) or newer, and this Mac has macOS $MACOS_VER."
  err "If Software Update offers a newer macOS, install it and try again."
  pause_exit 1
fi
if [ "$OLLAMA_CHANNEL" = none ]; then
  warn "Note: the AI chat needs macOS 13 (Ventura) or newer. This Mac has macOS $MACOS_VER,"
  warn "so only the Offline Library (Wikipedia, medicine, survival guides...) will be installed."
  warn "That part works fully. If you update macOS later, run this installer again to add the AI."
elif [ "$OLLAMA_CHANNEL" = pinned ]; then
  say "  macOS 13: using Ollama $OLLAMA_PIN_VERSION (the last version made for macOS 13)."
fi
[ "$MAC_ARCH" = x86_64 ] && [ "$AI_AVAILABLE" = yes ] && warn "Intel Mac: everything works, but AI answers are slower (the AI runs on the processor)."
KIWIX_ARCH="$MAC_ARCH"

# ---------- 1. Install folder ----------
TARGET="$KIT"
if [ -n "$INSTALL_PATH" ]; then TARGET="$INSTALL_PATH"
elif [ "$EASY" != yes ]; then
  say "The kit will live in this folder (any drive is fine, e.g. an external SSD):"
  say "  $KIT"
  TARGET="$(ask 'Press Return to keep it, or type/drag a different folder:' "$KIT")"
fi
# Folders dragged into Terminal arrive as "/Volumes/My\ SSD/ " - tidy that up.
TARGET="$(printf '%s' "$TARGET" | sed -e 's/[[:space:]]*$//' -e "s/^['\"]//" -e "s/['\"]\$//" -e 's/\\ / /g')"
TARGET="${TARGET%/}"; TARGET="${TARGET/#\~/$HOME}"
if [ "$TARGET" != "$KIT" ]; then
  mkdir -p "$TARGET" || { err "Cannot create $TARGET"; pause_exit 1; }
  TARGET="$(cd "$TARGET" && pwd)"
fi
if [ "$TARGET" != "$KIT" ]; then
  say "Copying the kit files to $TARGET ..."
  for item in mac scripts www SETUP-MAC.command "EASY-INSTALL (Mac).command" START-OFFLINE-AI-MAC.command STOP-OFFLINE-AI-MAC.command \
              STATUS-MAC.command SETUP.bat "EASY-INSTALL (Windows).bat" START-OFFLINE-AI.bat STOP-OFFLINE-AI.bat STATUS.bat README.md \
              START-HERE.txt ADVANCED.md README-OUTAGE.txt kit-settings.example.ini kit-settings.ini LICENSE; do
    [ -e "$KIT/$item" ] && cp -R "$KIT/$item" "$TARGET/"
  done
  say "Continuing setup in the new folder..."
  args=()
  for a in ${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}; do args+=("$a"); done
  exec bash "$TARGET/mac/setup.sh" ${args[@]+"${args[@]}"} --path "$TARGET"
fi
ensure_dirs
start_log "setup-$(date '+%Y%m%d-%H%M%S').log"
if [ "$TEST" = yes ] || is_yes "${OFFLINE_AI_TEST:-no}"; then set_setting TEST_MODE yes; enable_test_mode; fi
[ "$TEST_MODE" = yes ] && warn "TEST MODE: tiny library, one small model, 13 MB Wikipedia stand-in. Delete kit-settings.ini (or set TEST_MODE=no) to leave test mode."
# Make double-clicking work later: executable bits + remove the "downloaded from internet" flag.
chmod +x "$KIT"/*.command "$KIT"/mac/*.sh 2>/dev/null || true
command -v xattr >/dev/null 2>&1 && xattr -dr com.apple.quarantine "$KIT" 2>/dev/null || true

# ---------- 2. Hardware check and choices ----------
RAM="$(ram_gb)"
FREE="$(free_bytes "$KIT")"
FREE_GB="$(awk -v b="$FREE" 'BEGIN { printf "%.0f", b / 1e9 }')"
say ""
say "This Mac: ${RAM} GB memory, ${FREE_GB} GB free on this drive."
PROFILE="$(profile_for_ram "$RAM")"
[ -n "$HWPROFILE" ] && PROFILE="$HWPROFILE"
case "$PROFILE" in lite|standard|large|largest|intel|intel-small) ;; *) PROFILE="$(profile_for_ram "$RAM")" ;; esac
say "Best fit for this Mac: $(profile_label "$PROFILE")"
if [ "$DETECT" = yes ]; then
  if pk="$(pick_profile_for_disk "$PROFILE" "$FREE_GB")"; then say "PROFILE: $PROFILE  (Easy install would use: ${pk% *}, Wikipedia: ${pk#* })"
  else say "PROFILE: $PROFILE  (Easy install: not enough disk space)"; fi
  exit 0
fi
is_yes "${OFFLINE_AI_SKIP_WIKIPEDIA:-no}" && SKIPW=yes
WANT_WIKI=yes; [ "$SKIPW" = yes ] && WANT_WIKI=no

if [ "$TEST_MODE" = yes ]; then
  TIER="test"; ZIMS="knots,water,wpmed"; MODEL_LIST="llama3.2:3b"; [ "$AI_AVAILABLE" = yes ] || MODEL_LIST=""
elif [ "$EASY" = yes ]; then
  if ! pick="$(pick_profile_for_disk "$PROFILE" "$FREE_GB")"; then
    err ""
    err "There is not enough free space on this drive. The smallest version needs about $(profile_need_gb lite) GB"
    err "and this drive has ${FREE_GB} GB free. Please delete some files (or plug in a bigger drive"
    err "and copy this folder onto it), then double-click EASY-INSTALL (Mac) again."
    pause_exit 1
  fi
  NEWP="${pick% *}"; PW="${pick#* }"
  [ "$NEWP" != "$PROFILE" ] && warn "To fit the free space, installing the $(profile_label "$NEWP") version instead."
  PROFILE="$NEWP"
  if [ "$PW" = no ] && [ "$SKIPW" != yes ]; then
    warn "Full Wikipedia (127 GB) will NOT be downloaded because there is not enough free space."
    warn "Everything else works. You can add Wikipedia later: free up about 140 GB and run SETUP-MAC."
    WANT_WIKI=no
  fi
  TIER="$(profile_tier "$PROFILE")"
  MODEL_LIST="$(profile_models "$PROFILE")"
else
  DEF_T=2; [ "$(profile_tier "$PROFILE")" = essentials ] && DEF_T=1
  say ""
  say "Which library? (Full English Wikipedia ~127 GB is included; it downloads"
  say "in the background the first time you start the kit.)"
  say "  1) Essentials   - survival, first aid, water, food, knots, WikiMed   (~4 GB)"
  say "  2) Recommended  - Essentials + Wikipedia Medicine, Wikivoyage,"
  say "                    iFixit repair guides, Gardening Q&A               (~11 GB)"
  [ -n "$TIER" ] || [ -n "$ZIMS" ] || TIER="$(ask 'Type 1 or 2:' "$DEF_T")"
  case "$TIER" in 1|essentials) TIER=essentials ;; *) TIER=recommended ;; esac

  if [ "$AI_AVAILABLE" != yes ]; then MODEL_LIST=""
  elif [ "$MAC_ARCH" = x86_64 ]; then
    REC="$(intel_models)"
    say ""
    say "Which AI models? (Intel Mac: small models only - bigger ones would be far too slow)"
    say "  Recommended for this Mac: $REC"
    [ -n "$MODELS" ] || MODELS="$(ask 'Press Return for these, or type model names separated by commas:' "$(printf '%s' "$REC" | tr ' ' ',')")"
    MODEL_LIST="$(printf '%s' "$MODELS" | tr ',' ' ')"
  else
  case "$PROFILE" in lite) REC=lite ;; standard) REC=16 ;; large) REC=24 ;; *) REC=32 ;; esac
  say ""
  say "Which AI models?"
  say "  lite) Lite    - llama3.2:3b, medgemma:4b                         (~5 GB)  for 8 GB Macs"
  say "     8) Small   - Lite + phi4-mini                                 (~8 GB)  for 8 GB Macs"
  say "    16) Medium  - Small + qwen3.5:9b, gemma3:4b                    (~18 GB) for 16 GB Macs"
  say "    24) Large   - Medium + gemma3:12b, qwen3:14b                   (~35 GB) for 24 GB+ Macs"
  say "    32) Largest - Large + qwen3:30b                                (~54 GB) for 32 GB+ Macs"
  [ -n "$MODELS" ] || MODELS="$(ask "Type lite, 8, 16, 24 or 32 (recommended for this Mac: $REC):" "$REC")"
  case "$MODELS" in
    *:*|*,*) MODEL_LIST="$(printf '%s' "$MODELS" | tr ',' ' ')" ;;
    lite|8|16|24|32) MODEL_LIST="$(models_for_set "$MODELS")" ;;
    *) MODEL_LIST="$(models_for_set "$REC")" ;;
  esac
  case "$MODELS" in 16|24|32) [ "$RAM" -gt 0 ] && [ "$MODELS" -gt "$RAM" ] && warn "Note: the biggest models in that set may be too slow on ${RAM} GB. Use the smaller ones if so." ;; esac
  MODEL_LIST="$(compat_models "$MODEL_LIST")"
  fi
  if [ "$SKIPW" != yes ] && [ "$WITHW" != yes ] && { [ "$PROFILE" = lite ] || [ "$FREE_GB" -lt 187 ]; }; then
    DEF_W=Y; [ "$FREE_GB" -lt 167 ] && DEF_W=N
    case "$(ask 'Also download full English Wikipedia later (127 GB)? (Y/N)' "$DEF_W")" in [Yy]*) WANT_WIKI=yes ;; *) WANT_WIKI=no ;; esac
  fi
fi
if [ "$WANT_WIKI" = yes ]; then set_setting SKIP_WIKIPEDIA no; else set_setting SKIP_WIKIPEDIA yes; fi
load_settings

lib_gb=11.2; [ "$TIER" = essentials ] && lib_gb=3.8; [ "$TIER" = test ] && lib_gb=0.1
est="$(awk -v l="$lib_gb" -v m="$(models_gb "$MODEL_LIST")" 'BEGIN { printf "%.0f", 0.5 + l + m + 0.5 }')"
say ""
say "Installing: library \"$TIER\", models: ${MODEL_LIST:-none (AI needs macOS 13+)}"
if [ "$WANT_WIKI" = yes ]; then say "Setup needs about ${est} GB now; full Wikipedia later needs about $(gb "$(awk -v g="$WIKIPEDIA_GB" 'BEGIN { printf "%.0f", g * 1e9 }')") more."
else say "Setup needs about ${est} GB. Full Wikipedia is switched off."; fi
say "Free space on this drive: $(gb "$FREE")"
if [ "$FREE" -lt $((est * 1000000000)) ]; then err "Not enough free space for setup. Free up space or choose another drive."; pause_exit 1; fi
if [ "$WANT_WIKI" = yes ] && [ "$TEST_MODE" != yes ] && [ "$FREE" -lt $(( (est + 140) * 1000000000 )) ]; then warn "WARNING: there will not be enough room for full Wikipedia (~127 GB) on this drive."; fi
printf 'profile=%s\ntier=%s\nmodels=%s\nwikipedia=%s\ncreated=%s\n' "$PROFILE" "$TIER" "$MODEL_LIST" "$WANT_WIKI" "$(date '+%Y-%m-%d')" > "$CONFIG_FILE"
command -v caffeinate >/dev/null 2>&1 && { caffeinate -i -w "$$" >/dev/null 2>&1 & }
FAILED=""

# ---------- 3. Kiwix ----------
say ""; say "[1/4] Library program (kiwix-tools for macOS $KIWIX_ARCH)..."
if kiwix_bin >/dev/null; then ok "  Already installed."
else
  rel="$KIWIX_BASE/release/kiwix-tools/"
  kfile="$(curl_text "$rel" | grep -oE "href=\"kiwix-tools_macos-${KIWIX_ARCH}-[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?\.tar\.gz\"" |
           sed -e 's/^href="//' -e 's/"$//' |
           awk '{ v = $0; sub(/^kiwix-tools_macos-[a-z0-9_]+-/, "", v); sub(/\.tar\.gz$/, "", v); gsub(/-/, ".", v); n = split(v, p, ".");
                  printf "%05d%05d%05d%05d %s\n", p[1], p[2], p[3], (n > 3 ? p[4] : 0), $0 }' | sort | tail -1 | awk '{ print $2 }')"
  if [ -z "$kfile" ]; then err "Could not find kiwix-tools for macOS on download.kiwix.org"; pause_exit 1; fi
  say "  Downloading $kfile"
  download_resumable "$rel$kfile" "$RUNTIME/$kfile" 0 "$kfile" no 20 || pause_exit 1
  want="$(curl_text "$rel$kfile.md5" | awk '{ print $1 }')"
  if [ "$(md5_of "$RUNTIME/$kfile")" != "$want" ]; then rm -f "$RUNTIME/$kfile"; err "kiwix-tools download was damaged (checksum mismatch). Run setup again."; pause_exit 1; fi
  tar -xzf "$RUNTIME/$kfile" -C "$KIWIX_DIR" 2>/dev/null || tar -xzf "$RUNTIME/$kfile" -C "$KIWIX_DIR"
  rm -f "$RUNTIME/$kfile"
  command -v xattr >/dev/null 2>&1 && xattr -dr com.apple.quarantine "$KIWIX_DIR" 2>/dev/null || true
  ok "  Installed."
fi

# ---------- 4. Ollama ----------
say "[2/4] AI program (Ollama for macOS, portable)..."
if [ "$USE_SYSTEM_OLLAMA" = yes ]; then say "  Using your own Ollama on port $OLLAMA_PORT (USE_SYSTEM_OLLAMA) - not downloading one."
elif [ "$AI_AVAILABLE" != yes ]; then warn "  Skipped: needs macOS 13 (Ventura) or newer (this Mac has $MACOS_VER)."
elif ollama_bin >/dev/null; then ok "  Already installed."
else
  # ollama-darwin.tgz is one download for both kinds of Mac (it contains Apple-chip and Intel programs).
  asset="ollama-darwin.tgz"
  if [ "$OLLAMA_CHANNEL" = pinned ]; then base="https://github.com/ollama/ollama/releases/download/$OLLAMA_PIN_VERSION/"
  else base="https://github.com/ollama/ollama/releases/latest/download/"; fi
  download_resumable "$base$asset" "$RUNTIME/$asset" 0 "$asset" no 20 || pause_exit 1
  want="$(curl_text "${base}sha256sum.txt" | tr -d '\r' | awk -v a="$asset" '$2 == a || $2 == "./" a { print $1 }')"
  if [ -z "$want" ]; then err "Could not read the Ollama checksum list."; pause_exit 1; fi
  if [ "$OLLAMA_CHANNEL" = pinned ] && [ "$want" != "$OLLAMA_PIN_SHA256" ]; then rm -f "$RUNTIME/$asset"; err "The Ollama $OLLAMA_PIN_VERSION checksum online does not match the one built into this kit. Not installing it."; pause_exit 1; fi
  if [ "$(sha256_of "$RUNTIME/$asset")" != "$want" ]; then rm -f "$RUNTIME/$asset"; err "Ollama download was damaged (checksum mismatch). Run setup again."; pause_exit 1; fi
  tar -xzf "$RUNTIME/$asset" -C "$OLLAMA_DIR" 2>/dev/null || tar -xzf "$RUNTIME/$asset" -C "$OLLAMA_DIR"
  rm -f "$RUNTIME/$asset"
  command -v xattr >/dev/null 2>&1 && xattr -dr com.apple.quarantine "$OLLAMA_DIR" 2>/dev/null || true
  [ -x "$OLLAMA_DIR/ollama" ] || { err "Ollama did not unpack as expected."; pause_exit 1; }
  ok "  Installed."
fi

# ---------- 5. Library files ----------
say "[3/4] Library collections ($TIER)..."
while IFS='|' read -r id dir prefix tier about; do
  [ -n "$id" ] || continue
  [ "$tier" = always ] && continue
  if [ -n "$ZIMS" ]; then case ",$ZIMS," in *",$id,"*) ;; *) continue ;; esac
  else case "$tier" in essentials) ;; recommended) [ "$TIER" = recommended ] || continue ;; *) continue ;; esac; fi
  file="$(resolve_latest_zim "$dir" "$prefix")"
  if [ -z "$file" ]; then warn "  Problem: no file found for $prefix"; FAILED="$FAILED $prefix"; continue; fi
  say "  - $about: $file"
  get_zim "$dir" "$file" no || FAILED="$FAILED $file"
done <<< "$ZIM_CATALOG"

# ---------- 6. Models ----------
say "[4/4] AI models..."
if [ -z "$MODEL_LIST" ]; then say "  None to install."
else
start_ollama || { err "The kit AI server would not start; see logs/ollama-mac.log"; pause_exit 1; }
OLL="$(ollama_bin)" || true
if [ "$USE_SYSTEM_OLLAMA" = yes ]; then OLL="$(command -v ollama || true)"; [ -n "$OLL" ] || { err "USE_SYSTEM_OLLAMA is on but the ollama command was not found."; pause_exit 1; }; fi
for m in $MODEL_LIST; do
  n="${m%%:*}"; t=latest; case "$m" in *:*) t="${m#*:}" ;; esac
  code="$(curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' "https://registry.ollama.ai/v2/library/$n/manifests/$t")"
  if [ "$code" != 200 ]; then warn "  Skipping $m: not found in the Ollama library right now (HTTP $code)."; FAILED="$FAILED $m"; continue; fi
  say "  - $m"
  done_ok=no
  for try in 1 2 3 4 5; do
    if [ -t 1 ]; then OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" "$OLL" pull "$m"; rc=$?
    else OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" "$OLL" pull "$m" 2>&1 | tr '\r' '\n' | grep -avE 'pulling manifest|[0-9]+% ' ; rc=${PIPESTATUS[0]}; fi   # keep logs readable
    if [ "$rc" -eq 0 ]; then done_ok=yes; break; fi
    warn "    Retrying in 20 seconds... ($try)"; sleep 20
  done
  if [ "$done_ok" != yes ]; then FAILED="$FAILED $m"; continue; fi
  reply="$(OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" "$OLL" run "$m" 'Reply with just the word OK.' 2>/dev/null | tr '\n' ' ')"
  say "    Test answer: ${reply:0:60}"
done
fi

say ""
if [ -n "$FAILED" ]; then
  warn "Setup finished with some problems (run SETUP-MAC.command again to retry just these):"
  for f in $FAILED; do say "   - $f"; done
else
  ok "Setup finished. Everything downloaded and checked."
fi
say ""
[ "$EASY" = yes ] && make_desktop_shortcut
if [ -n "$FAILED" ]; then say "RESULT: SETUP FINISHED WITH PROBLEMS"; else say "RESULT: SETUP OK"; fi
say "NEXT: double-click START-OFFLINE-AI-MAC.command (or 'Offline AI' on the Desktop)."
if [ "$WANT_WIKI" = yes ] && [ "$TEST_MODE" = yes ]; then
  say "The first start also downloads a small Wikipedia test file in the background (test mode)."
elif [ "$WANT_WIKI" = yes ]; then
  say "The first start also begins downloading FULL English Wikipedia (~127 GB) in the"
  say "background. Leave the Mac plugged in and online until it finishes (could be many hours)."
fi
[ "$NOSTART" = yes ] && pause_exit 0
go=Y; [ "$EASY" = yes ] || go="$(ask 'Start the kit now? (Y/N)' Y)"
case "$go" in [Yy]*) say ""; say "Starting the kit..."; exec bash "$MAC_DIR/start.sh" ;; esac
pause_exit 0
