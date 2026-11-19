#!/bin/bash
# One-time setup for the Offline AI Kit on an Apple Silicon Mac (needs internet).
# Safe to run again: finished downloads are skipped, half-finished ones resume.
# Options for unattended use: --tier essentials|recommended  --models 8|16|24|32  --yes
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

TIER=""; MODELS=""; YES=no
while [ $# -gt 0 ]; do
  case "$1" in
    --tier) TIER="${2:-}"; shift ;;
    --models) MODELS="${2:-}"; shift ;;
    --yes) YES=yes ;;
  esac
  shift
done
ask() { # ask <question> <default>
  local a
  if [ "$YES" = yes ] || [ ! -t 0 ]; then printf '%s\n' "$2"; return; fi
  read -r -p "$1 [$2] " a || true
  if [ -z "$a" ]; then printf '%s\n' "$2"; else printf '%s\n' "$a"; fi
}

say "=================================================="
say "  Offline AI Kit - Mac setup"
say "  Downloads everything once, so it all works later with NO internet."
say "=================================================="
say ""
OS="$(uname -s)"; ARCH="$(uname -m)"
if [ "$OS" = Darwin ]; then
  MACVER="$(sw_vers -productVersion 2>/dev/null || echo 0)"
  if [ "${MACVER%%.*}" -lt 14 ] 2>/dev/null; then err "macOS 14 (Sonoma) or newer is needed (this Mac has $MACVER)."; pause_exit 1; fi
  if [ "$ARCH" != arm64 ]; then warn "This kit is built for Apple Silicon (M1 or newer). This Mac is $ARCH; it may work but will be slow."; fi
else
  warn "Note: this script is for macOS. Continuing anyway (test mode)."
fi
KIWIX_ARCH=arm64; [ "$ARCH" = x86_64 ] && KIWIX_ARCH=x86_64

# ---------- 1. Install folder ----------
say "The kit will live in this folder (any drive is fine, e.g. an external SSD):"
say "  $KIT"
TARGET="$(ask 'Press Return to keep it, or type/drag a different folder:' "$KIT")"
# Folders dragged into Terminal arrive as "/Volumes/My\ SSD/ " - tidy that up.
TARGET="$(printf '%s' "$TARGET" | sed -e 's/[[:space:]]*$//' -e "s/^['\"]//" -e "s/['\"]\$//" -e 's/\\ / /g')"
TARGET="${TARGET%/}"; TARGET="${TARGET/#\~/$HOME}"
if [ "$TARGET" != "$KIT" ]; then
  mkdir -p "$TARGET" || { err "Cannot create $TARGET"; pause_exit 1; }
  TARGET="$(cd "$TARGET" && pwd)"
fi
if [ "$TARGET" != "$KIT" ]; then
  say "Copying the kit files to $TARGET ..."
  for item in mac scripts www SETUP-MAC.command START-OFFLINE-AI-MAC.command STOP-OFFLINE-AI-MAC.command \
              STATUS-MAC.command SETUP.bat START-OFFLINE-AI.bat STOP-OFFLINE-AI.bat STATUS.bat README.md README-OUTAGE.txt LICENSE; do
    [ -e "$KIT/$item" ] && cp -R "$KIT/$item" "$TARGET/"
  done
  say "Continuing setup in the new folder..."
  args=(); [ -n "$TIER" ] && args+=(--tier "$TIER"); [ -n "$MODELS" ] && args+=(--models "$MODELS"); [ "$YES" = yes ] && args+=(--yes)
  exec bash "$TARGET/mac/setup.sh" ${args[@]+"${args[@]}"}
fi
ensure_dirs
# Make double-clicking work later: executable bits + remove the "downloaded from internet" flag.
chmod +x "$KIT"/*.command "$KIT"/mac/*.sh 2>/dev/null || true
command -v xattr >/dev/null 2>&1 && xattr -dr com.apple.quarantine "$KIT" 2>/dev/null || true

# ---------- 2. Choices ----------
RAM="$(ram_gb)"
REC=8; [ "$RAM" -ge 16 ] && REC=16; [ "$RAM" -ge 24 ] && REC=24
say ""
say "Which library? (Full English Wikipedia ~127 GB is ALWAYS included; it downloads"
say "in the background the first time you start the kit.)"
say "  1) Essentials   - survival, first aid, water, food, knots, WikiMed   (~4 GB)"
say "  2) Recommended  - Essentials + Wikipedia Medicine, Wikivoyage,"
say "                    iFixit repair guides, Gardening Q&A               (~11 GB)"
[ -n "$TIER" ] || TIER="$(ask 'Type 1 or 2:' 2)"
case "$TIER" in 1|essentials) TIER=essentials ;; *) TIER=recommended ;; esac

say ""
say "This Mac has ${RAM} GB of memory. Which AI models?"
say "   8) Small   - llama3.2:3b, phi4-mini, medgemma:4b                (~8 GB)  for 8 GB Macs"
say "  16) Medium  - Small + qwen3.5:9b, gemma3:4b                      (~18 GB) for 16 GB Macs"
say "  24) Large   - Medium + gemma3:12b, qwen3:14b                     (~35 GB) for 24 GB+ Macs"
say "  32) Largest - Large + qwen3:30b                                  (~54 GB) for 32 GB+ Macs"
[ -n "$MODELS" ] || MODELS="$(ask "Type 8, 16, 24 or 32 (recommended for this Mac: $REC):" "$REC")"
case "$MODELS" in 8|16|24|32) ;; *) MODELS="$REC" ;; esac
if [ "$MODELS" -gt "$RAM" ] && [ "$RAM" -gt 0 ]; then warn "Note: the biggest models in that set may be too slow on ${RAM} GB. Use the smaller ones if so."; fi

est=4; [ "$TIER" = recommended ] && est=12
MODEL_LIST=""
while IFS='|' read -r name size minram _hint; do
  [ -n "$name" ] || continue
  if [ "$minram" -le "$MODELS" ]; then MODEL_LIST="$MODEL_LIST $name"; est="$(awk -v a="$est" -v b="$size" 'BEGIN { printf "%.0f", a + b }')"; fi
done <<< "$MODEL_CATALOG"
est=$((est + 1))
FREE="$(free_bytes "$KIT")"
say ""
say "Setup needs about ${est} GB now. Wikipedia later needs about 127 GB more (total ~$((est + 127)) GB)."
say "Free space on this drive: $(gb "$FREE")"
if [ "$FREE" -lt $((est * 1000000000)) ]; then err "Not enough free space for setup. Free up space or choose another drive."; pause_exit 1; fi
if [ "$FREE" -lt $(( (est + 140) * 1000000000 )) ]; then warn "WARNING: there will not be enough room for full Wikipedia (~127 GB) on this drive."; fi
printf 'tier=%s\nmodels=%s\ncreated=%s\n' "$TIER" "$MODELS" "$(date '+%Y-%m-%d')" > "$CONFIG_FILE"
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
say "[2/4] AI program (Ollama for macOS, portable, ~190 MB)..."
if ollama_bin >/dev/null; then ok "  Already installed."
else
  base="https://github.com/ollama/ollama/releases/latest/download/"
  asset="ollama-darwin.tgz"
  download_resumable "$base$asset" "$RUNTIME/$asset" 0 "$asset" no 20 || pause_exit 1
  want="$(curl_text "${base}sha256sum.txt" | tr -d '\r' | awk -v a="$asset" '$2 == a || $2 == "./" a { print $1 }')"
  if [ -z "$want" ]; then err "Could not read the Ollama checksum list."; pause_exit 1; fi
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
  case "$tier" in essentials) ;; recommended) [ "$TIER" = recommended ] || continue ;; *) continue ;; esac
  file="$(resolve_latest_zim "$dir" "$prefix")"
  if [ -z "$file" ]; then warn "  Problem: no file found for $prefix"; FAILED="$FAILED $prefix"; continue; fi
  say "  - $about: $file"
  get_zim "$dir" "$file" no || FAILED="$FAILED $file"
done <<< "$ZIM_CATALOG"

# ---------- 6. Models ----------
say "[4/4] AI models..."
start_ollama || { err "The kit AI server would not start; see logs/ollama-mac.log"; pause_exit 1; }
OLL="$(ollama_bin)"
for m in $MODEL_LIST; do
  n="${m%%:*}"; t=latest; case "$m" in *:*) t="${m#*:}" ;; esac
  code="$(curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' "https://registry.ollama.ai/v2/library/$n/manifests/$t")"
  if [ "$code" != 200 ]; then warn "  Skipping $m: not found in the Ollama library right now (HTTP $code)."; FAILED="$FAILED $m"; continue; fi
  say "  - $m"
  done_ok=no
  for try in 1 2 3 4 5; do
    if OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" HOME="$HOME_DIR" "$OLL" pull "$m"; then done_ok=yes; break; fi
    warn "    Retrying in 20 seconds... ($try)"; sleep 20
  done
  if [ "$done_ok" != yes ]; then FAILED="$FAILED $m"; continue; fi
  reply="$(OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" HOME="$HOME_DIR" "$OLL" run "$m" 'Reply with just the word OK.' 2>/dev/null | tr '\n' ' ')"
  say "    Test answer: ${reply:0:60}"
done

say ""
if [ -n "$FAILED" ]; then
  warn "Setup finished with some problems (run SETUP-MAC.command again to retry just these):"
  for f in $FAILED; do say "   - $f"; done
else
  ok "Setup finished. Everything downloaded and checked."
fi
say ""
say "NEXT: double-click START-OFFLINE-AI-MAC.command."
say "The first start also begins downloading FULL English Wikipedia (~127 GB) in the"
say "background. Leave the Mac plugged in and online until it finishes (could be many hours)."
go="$(ask 'Start the kit now? (Y/N)' Y)"
case "$go" in [Yy]*) exec bash "$MAC_DIR/start.sh" ;; esac
pause_exit 0
