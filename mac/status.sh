#!/bin/bash
# Shows what is running and how the Wikipedia download is going, then offers a small menu:
# Share on Wi-Fi on/off, add Extra Libraries, add offline maps, check for updates, watch the Wikipedia download.
#   bash mac/status.sh --once                 (just the status, no menu)
#   bash mac/status.sh --share-wifi on|off    (turn Share on Wi-Fi on or off and apply it now)
#   bash mac/status.sh --check-updates        (ask GitHub for a newer version; needs internet)
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_dirs
ONCE=no; SHARE=""; CHECK=no
while [ $# -gt 0 ]; do
  case "$1" in
    --once) ONCE=yes ;;
    --share-wifi) SHARE="${2:-}"; shift ;;
    --check-updates) CHECK=yes ;;
  esac
  shift
done
show() { if port_up "$2"; then ok "  $(printf '%-18s' "$1") running  (http://127.0.0.1:$2)"; else warn "  $(printf '%-18s' "$1") stopped"; fi; }
wiki_line() {
  if f="$(wikipedia_verified)"; then ok "Full Wikipedia: ready ($f)"; return; fi
  if [ "$SKIP_WIKIPEDIA" = yes ]; then say "Full Wikipedia: switched off (SKIP_WIKIPEDIA=yes)"; return; fi
  if [ -f "$WIKI_PROGRESS" ]; then
    st="$(sed -n 's/.*"state":"\([^"]*\)".*/\1/p' "$WIKI_PROGRESS")"
    ms="$(sed -n 's/.*"message":"\(.*\)","updated".*/\1/p' "$WIKI_PROGRESS")"
    say "Full Wikipedia: $st - $ms"
  else
    say "Full Wikipedia: not started yet (it starts with $LAUNCH_START)"
  fi
}
show_status() {
  say "Offline AI Kit status (version $KIT_VERSION)"
  show "Offline Library" "$LIBRARY_PORT"
  if [ "$AI_AVAILABLE" = yes ]; then show "AI model server" "$OLLAMA_PORT"; else warn "  AI model server    not available (needs macOS 13+, this Mac has $MACOS_VER)"; fi
  [ "$SHARE_ON_WIFI" = yes ] && show "Chat page server" "$CHAT_PORT"
  show_share_status
  if [ "${KIT_OS:-mac}" = linux ]; then say "  This computer: Linux ($(uname -m), $LINUX_LIBC)"
  else say "  This Mac: $MAC_KIND, macOS $MACOS_VER"; fi
  say ""; say "Verified library collections:"
  for m in "$VERIFIED_DIR"/*.zim; do
    [ -e "$m" ] || continue
    z="$LIBRARY/$(basename "$m")"; [ -f "$z" ] && say "  $(basename "$m")  ($(gb "$(file_size "$z")"))"
  done
  say ""; wiki_line
}
switch_share() {
  say ""
  if [ "$1" = yes ]; then warn "Turning Share on Wi-Fi ON."; wifi_warning
  elif [ "${KIT_OS:-mac}" = linux ]; then say "Turning Share on Wi-Fi off (only this computer can use the kit)."
  else say "Turning Share on Wi-Fi off (only this Mac can use the kit)."; fi
  set_share_on_wifi "$1" apply
  show_share_status
}

if [ -n "$SHARE" ]; then
  case "$SHARE" in on|ON|1|yes) switch_share yes ;; off|OFF|0|no) switch_share no ;; *) err "Use --share-wifi on or --share-wifi off"; exit 1 ;; esac
  exit 0
fi
if [ "$CHECK" = yes ]; then update_check; exit 0; fi

show_status
if [ "$ONCE" = yes ] || [ ! -t 0 ]; then exit 0; fi
while :; do
  if [ "$SHARE_ON_WIFI" = yes ]; then now=ON; to=OFF; else now=off; to=ON; fi
  say ""
  say "What would you like to do?"
  say "  1) Turn Share on Wi-Fi $to   (now: $now - lets phones/tablets on your home Wi-Fi use the kit)"
  say "  2) Add Extra Libraries   (Wiktionary, Project Gutenberg, Stack Exchange Q&A, preparedness guides...)"
  say "  3) Add offline maps      (Vancouver Island / BC / Alberta, and broader regions)"
  say "  4) Check for updates     (needs internet; nothing is downloaded or changed)"
  say "  5) Show the status again"
  kit_pid wiki-download >/dev/null && say "  6) Watch the Wikipedia download live"
  c=""; read -r -p "Type a number, or just press Return to close: " c || c=""
  case "$c" in
    1) if [ "$SHARE_ON_WIFI" = yes ]; then switch_share no; else switch_share yes; fi ;;
    2) bash "$MAC_DIR/add-libraries.sh" ;;
    3) bash "$MAC_DIR/add-maps.sh" ;;
    4) say ""; update_check ;;
    5) say ""; show_status ;;
    6) say "Live progress (updates every 10 s). Press Control-C to stop watching (the download keeps going)."
       while kit_pid wiki-download >/dev/null; do sleep 10; printf '\r'; wiki_line; done ;;
    *) exit 0 ;;
  esac
done
