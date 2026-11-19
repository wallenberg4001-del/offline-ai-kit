#!/bin/bash
# Shows what is running and how the Wikipedia download is going (live while it downloads).
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_dirs
show() { if port_up "$2"; then ok "  $(printf '%-18s' "$1") running  (http://127.0.0.1:$2)"; else warn "  $(printf '%-18s' "$1") stopped"; fi; }
wiki_line() {
  if f="$(wikipedia_verified)"; then ok "Full Wikipedia: ready ($f)"; return; fi
  if [ -f "$WIKI_PROGRESS" ]; then
    st="$(sed -n 's/.*"state":"\([^"]*\)".*/\1/p' "$WIKI_PROGRESS")"
    ms="$(sed -n 's/.*"message":"\(.*\)","updated".*/\1/p' "$WIKI_PROGRESS")"
    say "Full Wikipedia: $st - $ms"
  else
    say "Full Wikipedia: not started yet (it starts with START-OFFLINE-AI-MAC.command)"
  fi
}
say "Offline AI Kit status"
show "Offline Library" "$LIBRARY_PORT"
show "AI model server" "$OLLAMA_PORT"
say ""; say "Verified library collections:"
for m in "$VERIFIED_DIR"/*.zim; do
  [ -e "$m" ] || continue
  z="$LIBRARY/$(basename "$m")"; [ -f "$z" ] && say "  $(basename "$m")  ($(gb "$(file_size "$z")"))"
done
say ""; wiki_line
if kit_pid wiki-download >/dev/null && [ -t 1 ] && [ "${1:-}" != "--once" ]; then
  say ""; say "Live progress (updates every 10 s). Closing this window does NOT stop the download."
  while kit_pid wiki-download >/dev/null; do sleep 10; printf '\r'; wiki_line; done
fi
pause_exit 0
