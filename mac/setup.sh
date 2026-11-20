#!/bin/bash
# One-time setup for the Offline AI Kit on a Mac - Apple chip or Intel, detected automatically (needs internet).
# Safe to run again: finished downloads are skipped, half-finished ones resume.
#   EASY-INSTALL (Mac).command -> setup.sh --easy   (no questions; picks everything from the hardware)
#   SETUP-MAC.command        -> setup.sh          (Setup Wizard: choose your features step by step)
# Power-user options (see ADVANCED.md): --profile lite|standard|large|largest|intel|intel-small  --tier essentials|recommended
#   --models lite|8|16|24|32|"name,name"  --zims id,id  --path DIR  --skip-wikipedia  --with-wikipedia
#   --use-system-ollama  --no-start  --yes  --test (quick test install, see ADVANCED.md)
#   --share-wifi  --extra-libraries id,id|all  --maps id,id|all
# Linux: linux/setup.sh sets OFFLINE_AI_OS=linux and runs this same wizard.
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

DETECT=no; TEST=no; TIER=""; MODELS=""; YES=no; EASY=no; HWPROFILE=""; ZIMS=""; INSTALL_PATH=""; SKIPW=no; WITHW=no; SYSOLL=no; NOSTART=no; SHAREW=no; EXTRAS=""; MAPS=""
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
    --share-wifi) SHAREW=yes ;;
    --extra-libraries) EXTRAS="${2:-}"; shift ;;
    --maps) MAPS="${2:-}"; shift ;;
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
  if [ "$YES" = yes ]; then printf '%s\n' "$2"; return; fi
  if [ -t 0 ]; then read -r -p "$1 [$2] " a || a=""
  else a=""; read -r a || true; printf '%s [%s] %s\n' "$1" "$2" "$a" >&2; fi   # scripted answers, one per line
  a="$(printf '%s' "$a" | tr -d '\r')"
  if [ -z "$a" ]; then printf '%s\n' "$2"; else printf '%s\n' "$a"; fi
}

say "=================================================="
if [ "${KIT_OS:-mac}" = linux ]; then
  if [ "$EASY" = yes ]; then say "  Offline AI Kit - EASY INSTALL for Linux (no questions)"; else say "  Offline AI Kit - Linux setup"; fi
else
  if [ "$EASY" = yes ]; then say "  Offline AI Kit - EASY INSTALL for Mac (no questions)"; else say "  Offline AI Kit - Mac setup"; fi
fi
say "  Downloads everything once, so it all works later with NO internet."
say "=================================================="
say ""
if [ "${KIT_OS:-mac}" = linux ]; then
  say "This computer: Linux ($(uname -m), $LINUX_LIBC)"
  say "  Library program: kiwix-tools_linux-${LINUX_KIWIX_ARCH} ($LINUX_LIBC)"
  say "  AI program: $LINUX_OLLAMA_ASSET"
else
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
fi
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
  for item in mac linux scripts www catalog VERSION SETUP-MAC.command "EASY-INSTALL (Mac).command" START-OFFLINE-AI-MAC.command STOP-OFFLINE-AI-MAC.command \
              STATUS-MAC.command SETUP-LINUX.sh "EASY-INSTALL (Linux).sh" START-OFFLINE-AI-LINUX.sh STOP-OFFLINE-AI-LINUX.sh STATUS-LINUX.sh \
              SETUP.bat "EASY-INSTALL (Windows).bat" START-OFFLINE-AI.bat STOP-OFFLINE-AI.bat STATUS.bat README.md \
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
chmod +x "$KIT"/*.command "$KIT"/mac/*.sh "$KIT"/linux/*.sh "$KIT"/*.sh 2>/dev/null || true
command -v xattr >/dev/null 2>&1 && xattr -dr com.apple.quarantine "$KIT" 2>/dev/null || true
if ! exec_bits_stick; then
  warn "This drive does not let programs run directly (common on exFAT)."
  warn "Start the kit with this exact command:"
  warn "  bash \"$KIT/$LAUNCH_START\""
  warn "Kiwix and Ollama will be copied to a local cache and run from there. Your library stays on this drive."
fi

# ---------- 2. Hardware check and choices ----------
RAM="$(ram_gb)"
FREE="$(free_bytes "$KIT")"
FREE_GB="$(awk -v b="$FREE" 'BEGIN { printf "%.0f", b / 1e9 }')"
say ""
PROFILE="$(profile_for_ram "$RAM")"
[ -n "$HWPROFILE" ] && PROFILE="$HWPROFILE"
case "$PROFILE" in lite|standard|large|largest|intel|intel-small) ;; *) PROFILE="$(profile_for_ram "$RAM")" ;; esac
if [ "${KIT_OS:-mac}" = linux ]; then
  say "This computer: ${RAM} GB memory, ${FREE_GB} GB free on this drive."
  say "Best fit for this computer: $(profile_label "$PROFILE")"
else
  say "This Mac: ${RAM} GB memory, ${FREE_GB} GB free on this drive."
  say "Best fit for this Mac: $(profile_label "$PROFILE")"
fi
if [ "$DETECT" = yes ]; then
  if pk="$(pick_profile_for_disk "$PROFILE" "$FREE_GB")"; then say "PROFILE: $PROFILE  (Easy install would use: ${pk% *}, Wikipedia: ${pk#* })"
  else say "PROFILE: $PROFILE  (Easy install: not enough disk space)"; fi
  exit 0
fi
is_yes "${OFFLINE_AI_SKIP_WIKIPEDIA:-no}" && SKIPW=yes
WANT_WIKI=yes; [ "$SKIPW" = yes ] && WANT_WIKI=no
EXTRA_SEL=""; [ -n "$EXTRAS" ] && EXTRA_SEL="$(resolve_extra_ids "$EXTRAS" | tr '\n' ' ')"
MAP_SEL=""; [ -n "$MAPS" ] && MAP_SEL="$(resolve_map_ids "$MAPS" | tr '\n' ' ')"
SHARE_CHOICE="$SHARE_ON_WIFI"; [ "$SHAREW" = yes ] && SHARE_CHOICE=yes   # Easy keeps the current setting (off on a new kit)
WIZARD_STEPS=7   # maps are step 6; the summary is step 7. Easy Install never asks.
step() { say ""; printf '%s\n' "--- Step $1 of $WIZARD_STEPS: $2 ------------------------------------------------" | cut -c1-64; }

if [ "$EASY" = yes ]; then
  if pick="$(pick_profile_for_disk "$PROFILE" "$FREE_GB")"; then
    NEWP="${pick% *}"; PW="${pick#* }"
    [ "$NEWP" != "$PROFILE" ] && warn "To fit the free space, installing the $(profile_label "$NEWP") version instead."
    PROFILE="$NEWP"
    if [ "$PW" = no ] && [ "$SKIPW" != yes ] && [ "$TEST_MODE" != yes ]; then
      warn "Full Wikipedia (127 GB) will NOT be downloaded because there is not enough free space."
      warn "Everything else works. You can add Wikipedia later: free up about 140 GB and run $LAUNCH_SETUP."
      WANT_WIKI=no
    fi
  elif [ "$TEST_MODE" != yes ]; then
    err ""
    err "There is not enough free space on this drive. The smallest version needs about $(profile_need_gb lite) GB"
    err "and this drive has ${FREE_GB} GB free. Please delete some files (or plug in a bigger drive"
    err "and copy this folder onto it), then run $LAUNCH_EASY again."
    pause_exit 1
  fi
  TIER="$(profile_tier "$PROFILE")"
  MODEL_LIST="$(profile_models "$PROFILE")"
else
  say ""
  say "=================== SETUP WIZARD ==================="
  say "Choose what to install. Press Return to take the suggested answer [in brackets]."
  say "Nothing is downloaded until you say yes on the summary screen at the end."

  # Step 1: AI model size
  step 1 "AI model size"
  if [ "${KIT_OS:-mac}" = linux ]; then say "This computer: Linux ($(uname -m)), ${RAM} GB memory."
  else say "This Mac: $MAC_KIND, ${RAM} GB memory, macOS $MACOS_VER."; fi
  [ "$TEST_MODE" = yes ] && warn "  (TEST MODE: the test installs only llama3.2:3b, whatever you pick here.)"
  if [ "$AI_AVAILABLE" != yes ]; then MODEL_LIST=""; say "  The AI needs macOS 13 or newer, so only the library will be installed."
  elif [ "${KIT_OS:-mac}" != linux ] && [ "$MAC_ARCH" = x86_64 ]; then
    REC="$(intel_models)"
    say "  Intel Mac: small models only - bigger ones would be far too slow."
    say "  Recommended for this Mac: $REC"
    [ -n "$MODELS" ] || MODELS="$(ask 'Press Return for these, or type model names separated by commas:' "$(printf '%s' "$REC" | tr ' ' ',')")"
    MODEL_LIST="$(printf '%s' "$MODELS" | tr ',' ' ')"
  else
    if [ "${KIT_OS:-mac}" = linux ] && [ "$MAC_ARCH" = x86_64 ]; then
      say "  This PC runs the AI on the processor, so bigger models are slower."
      say "  Easy Install uses the small set. You can still pick a larger one here."
      if [ "$RAM" -ge 16 ]; then REC=8; else REC=lite; fi
    else
      case "$PROFILE" in lite) REC=lite ;; standard) REC=16 ;; large) REC=24 ;; *) REC=32 ;; esac
    fi
    say "  lite) Lite    - llama3.2:3b, medgemma:4b                         (~5 GB)  for 8 GB of memory"
    say "     8) Small   - Lite + phi4-mini                                 (~8 GB)  for 8 GB of memory"
    say "    16) Medium  - Small + qwen3.5:9b, gemma3:4b                    (~18 GB) for 16 GB of memory"
    say "    24) Large   - Medium + gemma3:12b, qwen3:14b                   (~35 GB) for 24 GB of memory or more"
    say "    32) Largest - Large + qwen3:30b                                (~54 GB) for 32 GB of memory or more"
    if [ "${KIT_OS:-mac}" = linux ]; then say "  Recommended for this computer: $REC"
    else say "  Recommended for this Mac: $REC"; fi
    [ -n "$MODELS" ] || MODELS="$(ask "Type lite, 8, 16, 24 or 32:" "$REC")"
    case "$MODELS" in
      *:*|*,*) MODEL_LIST="$(printf '%s' "$MODELS" | tr ',' ' ')" ;;
      lite|8|16|24|32) MODEL_LIST="$(models_for_set "$MODELS")" ;;
      *) MODEL_LIST="$(models_for_set "$REC")" ;;
    esac
    case "$MODELS" in 16|24|32) [ "$RAM" -gt 0 ] && [ "$MODELS" -gt "$RAM" ] && warn "  Note: the biggest models in that set may be too slow on ${RAM} GB. Use the smaller ones if so." ;; esac
    MODEL_LIST="$(compat_models "$MODEL_LIST")"
  fi

  # Step 2: core library
  step 2 "Core library (always included)"
  DEF_T=2; [ "$(profile_tier "$PROFILE")" = essentials ] && DEF_T=1
  say "  1) Essentials   - survival, first aid, water, food, knots, WikiMed   (~4 GB)"
  say "  2) Recommended  - Essentials + Wikipedia Medicine, Wikivoyage,"
  say "                    iFixit repair guides, Gardening Q&A               (~11 GB)"
  [ -n "$TIER" ] || [ -n "$ZIMS" ] || TIER="$(ask 'Type 1 or 2:' "$DEF_T")"
  case "$TIER" in 1|essentials) TIER=essentials ;; *) TIER=recommended ;; esac

  # Step 3: full English Wikipedia
  step 3 "Full English Wikipedia"
  say "  All of English Wikipedia with pictures, about $(gb "$(awk -v g="$WIKIPEDIA_GB" 'BEGIN { printf "%.0f", g * 1e9 }')"). It downloads in the background the"
  say "  first time you start the kit (everything else works meanwhile) and resumes if interrupted."
  if [ "$SKIPW" != yes ] && [ "$WITHW" != yes ]; then
    DEF_W=Y
    if [ "$TEST_MODE" != yes ] && [ "$FREE_GB" -lt 167 ]; then DEF_W=N; warn "  This drive has only ${FREE_GB} GB free, so the suggestion is No."; fi
    case "$(ask 'Download full English Wikipedia? (Y/N)' "$DEF_W")" in [Yy]*) WANT_WIKI=yes ;; *) WANT_WIKI=no ;; esac
  else say "  Chosen on the command line: $WANT_WIKI"; fi

  # Step 4: extra libraries
  step 4 "Extra Libraries (optional)"
  show_extra_catalog
  if [ -z "$EXTRAS" ]; then
    ans="$(ask 'Type numbers or names (e.g. 1,3), "all", or press Return for none:' '')"
    EXTRA_SEL="$(resolve_extra_ids "$ans" | tr '\n' ' ')"
  fi
  if [ -n "${EXTRA_SEL// /}" ]; then say "  Chosen: $EXTRA_SEL"; else say "  None (you can add them any time from $LAUNCH_STATUS)."; fi

  # Step 5: share on Wi-Fi
  step 5 "Share on home Wi-Fi (phones and tablets)"
  say "  Lets phones and tablets on the same Wi-Fi use the chat and library. Trusted home Wi-Fi only."
  if [ "$SHAREW" != yes ]; then
    DEF_S=N; [ "$SHARE_ON_WIFI" = yes ] && DEF_S=Y
    case "$(ask 'Turn on Share on Wi-Fi? (Y/N)' "$DEF_S")" in [Yy]*) SHARE_CHOICE=yes ;; *) SHARE_CHOICE=no ;; esac
  else say "  Chosen on the command line: ON"; fi
  [ "$SHARE_CHOICE" = yes ] && wifi_warning

  # Step 6: optional offline maps. Easy Install never reaches this (maps stay off unless --maps was passed).
  step 6 "Offline maps (optional)"
  say "  Clean offline maps in the browser, stored in this kit (OpenStreetMap data packed by Kiwix)."
  say "  Vancouver Island, British Columbia and Alberta are all inside the one Canada map"
  say "  (about 10 GB). Kiwix does not publish those three places as their own files."
  say "  Picking more than one of those three downloads that Canada file once."
  say "  Broader regions are separate, larger files."
  show_map_catalog
  if [ -z "$MAPS" ]; then
    ans="$(ask 'Type numbers or names (e.g. 1,4), "all", or press Return for none:' '')"
    MAP_SEL="$(resolve_map_ids "$ans" | tr '\n' ' ')"
  fi
  if [ -n "${MAP_SEL// /}" ]; then
    uniq="$(map_unique_ids $MAP_SEL | tr '\n' ' ')"
    say "  Chosen: $MAP_SEL ($(printf '%s' "$uniq" | wc -w | tr -d ' ') file(s), about $(size_label "$(map_gb $MAP_SEL)"))"
  else say "  None (you can add them any time from $LAUNCH_STATUS)."; fi
fi
if [ "$TEST_MODE" = yes ]; then
  TIER="test"; ZIMS="knots,water,wpmed"; MODEL_LIST="llama3.2:3b"; [ "$AI_AVAILABLE" = yes ] || MODEL_LIST=""
fi

lib_gb=11.2; [ "$TIER" = essentials ] && lib_gb=3.8; [ "$TIER" = test ] && lib_gb=0.2
EXTRA_GB="$(extra_gb "$EXTRA_SEL")"
MAP_GB="$(map_gb $MAP_SEL)"
est="$(awk -v l="$lib_gb" -v m="$(models_gb "$MODEL_LIST")" -v x="$EXTRA_GB" -v p="$MAP_GB" 'BEGIN { printf "%.1f", 0.5 + l + m + x + p + 0.5 }')"
total="$est"; [ "$WANT_WIKI" = yes ] && total="$(awk -v a="$est" -v b="$WIKIPEDIA_GB" 'BEGIN { printf "%.1f", a + b }')"
if [ "$EASY" = yes ]; then say ""; else step "$WIZARD_STEPS" "Summary"; fi
say "  AI models:        ${MODEL_LIST:-none (AI needs macOS 13+)}"
say "  Core library:     $TIER"
if [ "$WANT_WIKI" = yes ]; then say "  Full Wikipedia:   Yes - about $(gb "$(awk -v g="$WIKIPEDIA_GB" 'BEGIN { printf "%.0f", g * 1e9 }')"), downloads in the background on first start"
else say "  Full Wikipedia:   No"; fi
if [ -n "${EXTRA_SEL// /}" ]; then say "  Extra libraries:  $EXTRA_SEL($(size_label "$EXTRA_GB"))"; else say "  Extra libraries:  none"; fi
if [ -n "${MAP_SEL// /}" ]; then say "  Offline maps:     $MAP_SEL($(size_label "$MAP_GB"), shared files counted once)"; else say "  Offline maps:     none"; fi
if [ "$SHARE_CHOICE" = yes ]; then say "  Share on Wi-Fi:   ON (trusted home Wi-Fi only)"; else say "  Share on Wi-Fi:   off"; fi
say "  Download now:     about $est GB   (with Wikipedia later: about $total GB in total)"
say "  Free space:       $(gb "$FREE") on this drive"
if awk -v f="$FREE" -v e="$est" 'BEGIN { exit !(f < e * 1e9) }'; then err "Not enough free space for these choices. Free up space, pick fewer extras or a smaller model size, or choose another drive."; pause_exit 1; fi
if [ "$WANT_WIKI" = yes ] && [ "$TEST_MODE" != yes ] && awk -v f="$FREE" -v e="$est" 'BEGIN { exit !(f < (e + 140) * 1e9) }'; then warn "WARNING: there will not be enough room for full Wikipedia (~127 GB) on this drive."; fi
if [ "$EASY" != yes ]; then
  case "$(ask 'Proceed? (Y/N)' Y)" in
    [Yy]*) ;;
    *) say "OK - nothing was downloaded or changed. Run $LAUNCH_SETUP again any time."; say "RESULT: SETUP CANCELLED"; pause_exit 0 ;;
  esac
fi
# Save the choices so START / STOP / STATUS follow them.
if [ "$WANT_WIKI" = yes ]; then set_setting SKIP_WIKIPEDIA no; else set_setting SKIP_WIKIPEDIA yes; fi
set_share_on_wifi "$SHARE_CHOICE"
[ -n "${EXTRA_SEL// /}" ] && set_setting EXTRA_LIBRARIES "$(printf '%s' "$EXTRA_SEL" | sed 's/ *$//' | tr ' ' ',')"
if [ "$EASY" != yes ] || [ -n "$MAPS" ]; then set_setting MAPS "$(printf '%s' "$MAP_SEL" | sed 's/ *$//' | tr ' ' ',')"; fi
load_settings
printf 'profile=%s\ntier=%s\nmodels=%s\nwikipedia=%s\ncreated=%s\n' "$PROFILE" "$TIER" "$MODEL_LIST" "$WANT_WIKI" "$(date '+%Y-%m-%d')" > "$CONFIG_FILE"
stay_awake
FAILED=""
if [ "$WANT_WIKI" = yes ] && [ "$TEST_MODE" != yes ]; then
  fat32_blocked "$KIT" && { err "This drive is FAT32, which cannot store a file larger than 4 GB. Full Wikipedia needs exFAT, NTFS, or APFS."; pause_exit 1; }
fi
for id in $EXTRA_SEL $MAP_SEL; do
  g="$(extra_field "$id" 4)"; [ -n "$g" ] || g="$(map_field "$id" 4)"
  if awk -v g="${g:-0}" 'BEGIN { exit !(g+0 >= 4) }' && fat32_blocked "$KIT"; then
    err "This drive is FAT32, which cannot store a file larger than 4 GB. $id needs exFAT, NTFS, or APFS."
    pause_exit 1
  fi
done

# ---------- 3. Kiwix and 4. Ollama (Mac or Linux build, chosen by KIT_OS) ----------
say ""
install_kiwix_tools || pause_exit 1
install_portable_ollama || pause_exit 1

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

if [ -n "${EXTRA_SEL// /}" ]; then
  say "Extra Libraries..."
  for id in $EXTRA_SEL; do install_extra "$id" || FAILED="$FAILED $id"; done
fi
if [ -n "${MAP_SEL// /}" ]; then
  say "Offline maps..."
  for id in $(map_unique_ids $MAP_SEL); do install_map "$id" || FAILED="$FAILED $id"; done
fi
write_maps_index

# ---------- 6. Models ----------
say "[4/4] AI models..."
if [ -z "$MODEL_LIST" ]; then say "  None to install."
else
start_ollama || { err "The kit AI server would not start; see logs/ollama-${LOG_TAG:-mac}.log"; pause_exit 1; }
OLL="$(ollama_bin)" || true
if [ "$USE_SYSTEM_OLLAMA" = yes ]; then OLL="$(command -v ollama || true)"; [ -n "$OLL" ] || { err "USE_SYSTEM_OLLAMA is on but the ollama command was not found."; pause_exit 1; }; fi
for m in $MODEL_LIST; do
  n="${m%%:*}"; t=latest; case "$m" in *:*) t="${m#*:}" ;; esac
  code="$(curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' "https://registry.ollama.ai/v2/library/$n/manifests/$t")"
  if [ "$code" != 200 ]; then warn "  Skipping $m: not found in the Ollama library right now (HTTP $code)."; FAILED="$FAILED $m"; continue; fi
  say "  - $m"
  done_ok=no
  for try in 1 2 3 4 5; do
    if [ -t 1 ]; then OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" "$OLL" pull "$m" < /dev/null; rc=$?
    else OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" "$OLL" pull "$m" < /dev/null 2>&1 | tr '\r' '\n' | grep -avE 'pulling manifest|[0-9]+% ' ; rc=${PIPESTATUS[0]}; fi   # keep logs readable
    if [ "$rc" -eq 0 ]; then done_ok=yes; break; fi
    warn "    Retrying in 20 seconds... ($try)"; sleep 20
  done
  if [ "$done_ok" != yes ]; then FAILED="$FAILED $m"; continue; fi
  reply="$(OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" "$OLL" run "$m" 'Reply with just the word OK.' 2>/dev/null < /dev/null | tr '\n' ' ')"
  say "    Test answer: ${reply:0:60}"
done
fi

say ""
if [ -n "$FAILED" ]; then
  warn "Setup finished with some problems (run $LAUNCH_SETUP again to retry just these):"
  for f in $FAILED; do say "   - $f"; done
else
  ok "Setup finished. Everything downloaded and checked."
fi
say ""
if [ "$EASY" = yes ]; then
  if [ "${KIT_OS:-mac}" = linux ]; then make_linux_desktop; else make_desktop_shortcut; fi
fi
if [ -n "$FAILED" ]; then say "RESULT: SETUP FINISHED WITH PROBLEMS"; else say "RESULT: SETUP OK"; fi
if [ "${KIT_OS:-mac}" = linux ]; then say "NEXT: bash \"$KIT/$LAUNCH_START\" (or 'Offline AI' on the Desktop)."
else say "NEXT: double-click $LAUNCH_START (or 'Offline AI' on the Desktop)."; fi
if [ "$WANT_WIKI" = yes ] && [ "$TEST_MODE" = yes ]; then
  say "The first start also downloads a small Wikipedia test file in the background (test mode)."
elif [ "$WANT_WIKI" = yes ]; then
  say "The first start also begins downloading FULL English Wikipedia (~127 GB) in the"
  say "background. Leave the computer plugged in and online until it finishes (could be many hours)."
fi
[ "$NOSTART" = yes ] && pause_exit 0
go=Y; [ "$EASY" = yes ] || go="$(ask 'Start the kit now? (Y/N)' Y)"
case "$go" in [Yy]*) say ""; say "Starting the kit..."; exec bash "$MAC_DIR/start.sh" ;; esac
pause_exit 0
