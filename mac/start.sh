#!/bin/bash
# Starts the Offline AI Kit on macOS: library (Kiwix), AI models (Ollama), chat page,
# and the full-Wikipedia background download if it is not finished yet.
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_dirs
say "=============================================="
say "  Offline AI Kit (Mac)"
say "  $KIT"
say "  $(date '+%Y-%m-%d %H:%M %Z')"
say "=============================================="
if ! ollama_bin >/dev/null || ! kiwix_bin >/dev/null; then
  err "The kit is not set up yet. Run SETUP-MAC.command first (needs internet once)."
  pause_exit 1
fi

say ""; say "[1/3] Offline Library..."
start_kiwix || true
say "[2/3] AI model server (port $OLLAMA_PORT, separate from any normal Ollama)..."
start_ollama || true

say "[3/3] Full English Wikipedia..."
if f="$(wikipedia_verified)"; then
  ok "  Ready: $f"; write_wiki_status "done" 0 0 100 0 "Wikipedia ready: $f"
elif kit_pid wiki-download >/dev/null; then
  say "  Still downloading in the background (STATUS-MAC.command shows progress)."
else
  nohup bash "$MAC_DIR/wiki-download.sh" >> "$LOG_DIR/wikipedia-download-mac.log" 2>&1 < /dev/null &
  warn "  Not downloaded yet - started downloading it in the background (about 127 GB)."
  say  "  Everything else works meanwhile. STATUS-MAC.command and the chat page show progress."
  say  "  It resumes automatically if interrupted, and appears in the library when finished."
  say  "  Keep the Mac plugged in; it is kept awake while downloading."
fi

say ""; say "Opening the chat page and the Offline Library in your browser..."
open_url "$WWW_DIR/chat.html"
port_up "$LIBRARY_PORT" && open_url "http://127.0.0.1:$LIBRARY_PORT/"
say ""
ok  "READY."
say "  Chat:     $WWW_DIR/chat.html  (opens from the kit folder; no internet needed)"
say "  Library:  http://127.0.0.1:$LIBRARY_PORT/"
say "  Stop:     STOP-OFFLINE-AI-MAC.command"
say "  Logs:     $LOG_DIR"
say ""
say "You can close this window; the kit keeps running until you stop it or restart the Mac."
pause_exit 0
