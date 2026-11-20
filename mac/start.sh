#!/bin/bash
# Starts the Offline AI Kit on macOS: library (Kiwix), AI models (Ollama), chat page,
# and the full-Wikipedia background download if it is not finished yet.
#   --share-wifi / --no-share-wifi : turn Share on Wi-Fi on or off (remembered in kit-settings.ini)
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_dirs
SHARE_ARG=""
for a in "$@"; do case "$a" in --share-wifi) SHARE_ARG=yes ;; --no-share-wifi) SHARE_ARG=no ;; esac; done
start_log start-latest.log
say "=============================================="
say "  Offline AI Kit (Mac)"
say "  $KIT"
say "  $(date '+%Y-%m-%d %H:%M %Z')"
say "=============================================="
if [ "$SHARE_ARG" = yes ]; then set_share_on_wifi yes; warn "Share on Wi-Fi: turned ON (remembered; turn off with STATUS-MAC.command or --no-share-wifi)."
elif [ "$SHARE_ARG" = no ]; then set_share_on_wifi no; say "Share on Wi-Fi: turned off (remembered)."; fi
if { [ "$USE_SYSTEM_OLLAMA" != yes ] && [ "$AI_AVAILABLE" = yes ] && ! ollama_bin >/dev/null; } || ! kiwix_bin >/dev/null; then
  err "The kit is not set up yet. Run SETUP-MAC.command first (needs internet once)."
  pause_exit 1
fi

say ""; say "[1/3] Offline Library..."
start_kiwix || true
write_chat_config
if [ "$USE_SYSTEM_OLLAMA" = yes ]; then say "[2/3] AI model server: using your own Ollama on port $OLLAMA_PORT..."
elif [ "$AI_AVAILABLE" != yes ]; then say "[2/3] AI model server: not available on macOS $MACOS_VER (needs macOS 13 or newer). The library works."
else say "[2/3] AI model server (port $OLLAMA_PORT, separate from any normal Ollama)..."; fi
[ "$AI_AVAILABLE" = yes ] && { start_ollama || true; }
[ "$MAC_ARCH" = x86_64 ] && [ "$AI_AVAILABLE" = yes ] && say "  Intel Mac: answers take longer than on Apple-chip Macs (often 10-60 seconds). That is normal."
stop_kit chat-server >/dev/null
if [ "$SHARE_ON_WIFI" = yes ]; then
  say "  Share on Wi-Fi is ON: starting the chat page server for phones and tablets..."
  start_chat_server || true
fi

say "[3/3] Full English Wikipedia..."
if f="$(wikipedia_verified)"; then
  ok "  Ready: $f"; write_wiki_status "done" 0 0 100 0 "Wikipedia ready: $f"
elif [ "$SKIP_WIKIPEDIA" = yes ]; then
  say "  Switched off (SKIP_WIKIPEDIA=yes in kit-settings.ini). Everything else works."
  write_wiki_status off 0 0 0 0 "Wikipedia is switched off"
elif kit_pid wiki-download >/dev/null; then
  say "  Still downloading in the background (STATUS-MAC.command shows progress)."
else
  nohup bash "$MAC_DIR/wiki-download.sh" >> "$LOG_DIR/wikipedia-download-mac.log" 2>&1 < /dev/null &
  warn "  Not downloaded yet - started downloading it in the background (about $(gb "$(awk -v g="$WIKIPEDIA_GB" 'BEGIN { printf "%.0f", g * 1e9 }')"))."
  say  "  Everything else works meanwhile. STATUS-MAC.command and the chat page show progress."
  say  "  It resumes automatically if interrupted, and appears in the library when finished."
  say  "  Keep the Mac plugged in; it is kept awake while downloading."
fi

CHAT_URL="$WWW_DIR/chat.html"
if [ "$SHARE_ON_WIFI" = yes ] && kit_pid chat-server >/dev/null; then CHAT_URL="http://127.0.0.1:$CHAT_PORT/chat.html"; fi
if ! is_yes "${OFFLINE_AI_NO_BROWSER:-no}"; then
  say ""
  if [ "$AI_AVAILABLE" = yes ]; then say "Opening the chat page and the Offline Library in your browser..."; open_url "$CHAT_URL"
  else say "Opening the Offline Library in your browser..."; fi
  port_up "$LIBRARY_PORT" && open_url "http://127.0.0.1:$LIBRARY_PORT/"
fi
say ""
ok  "READY."
[ "$AI_AVAILABLE" = yes ] && say "  Chat:     $CHAT_URL"
say "  Library:  http://127.0.0.1:$LIBRARY_PORT/"
say "  Stop:     STOP-OFFLINE-AI-MAC.command"
say "  Logs:     $LOG_DIR"
say "  Version:  $KIT_VERSION"
show_share_status
if [ "$SHARE_ON_WIFI" = yes ] && ip="$(lan_ip)"; then say "SHARE URL: http://$ip:$CHAT_PORT/"; fi
say ""
say "You can close this window; the kit keeps running until you stop it or restart the Mac."
[ "$TEST_MODE" = yes ] && warn "TEST MODE is on (kit-settings.ini)."
say "RESULT: START OK"
pause_exit 0
