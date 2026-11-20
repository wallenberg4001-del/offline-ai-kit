#!/bin/bash
# Add optional Extra Libraries (Wiktionary, Project Gutenberg, Stack Exchange Q&A, preparedness guides...).
# The list is in catalog/extra-libraries.txt. Opened from STATUS-MAC.command, or run directly:
#   bash mac/add-libraries.sh                  (menu)
#   bash mac/add-libraries.sh --list           (show the list and what is already added)
#   bash mac/add-libraries.sh --add se-diy,wiktionary-simple   (numbers from --list work too)
#   bash mac/add-libraries.sh --remove se-diy  (delete a collection you added)
# Downloads use the fastest mirror, resume if interrupted, are checked with SHA-256, and the library
# restarts by itself afterwards so the chat's "Ask the library" can use them right away.
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_dirs
ACTION=menu; IDS=""; YES=no
while [ $# -gt 0 ]; do
  case "$1" in
    --list) ACTION=list ;;
    --add) ACTION=add; IDS="${2:-}"; shift ;;
    --remove) ACTION=remove; IDS="${2:-}"; shift ;;
    --yes) YES=yes ;;
    *) warn "Unknown option: $1" ;;
  esac
  shift
done
[ -n "$(extra_catalog)" ] || { err "The Extra Libraries list (catalog/extra-libraries.txt) is missing."; exit 1; }

case "$ACTION" in
  list) say "Extra Libraries:"; show_extra_catalog; exit 0 ;;
  remove)
    was=no; kit_pid kiwix >/dev/null && was=yes
    for id in $(resolve_extra_ids "$IDS"); do
      if f="$(extra_installed "$id")"; then
        stop_kit kiwix >/dev/null
        rm -f "$LIBRARY/$f" "$VERIFIED_DIR/$f"; log_to zim-downloads.log "REMOVED $f"; ok "  Removed $id ($f)"
      else say "  Not added: $id"; fi
    done
    [ "$was" = yes ] && { start_kiwix || true; }
    exit 0 ;;
  menu)
    say "=================================================="
    say "  Add Extra Libraries (needs internet while downloading)"
    say "=================================================="
    show_extra_catalog
    say "  Free space on this drive: $(gb "$(free_bytes "$LIBRARY")")"
    say ""
    IDS=""
    [ -t 0 ] && { read -r -p 'Type the numbers or names to add (e.g. 1,3), "all", or press Return to go back: ' IDS || true; }
    [ -n "$IDS" ] || exit 0 ;;
esac

printf '%s\n' "$$" > "$(pid_file add-libraries)"
trap 'rm -f "$(pid_file add-libraries)"' EXIT
SEL="$(resolve_extra_ids "$IDS" | tr '\n' ' ')"
[ -n "${SEL// /}" ] || { say "Nothing chosen."; exit 0; }
GB="$(extra_gb "$SEL")"
say "Adding: $SEL(about $(size_label "$GB") to download)"
if awk -v g="$GB" 'BEGIN { exit !(g > 50) }' && [ "$YES" != yes ]; then
  a=n; [ -t 0 ] && { read -r -p "That is a very big download. Continue? (Y/N) " a || true; }
  case "$a" in [Yy]*) ;; *) exit 0 ;; esac
fi
stay_awake
FAILED=""; ADDED=0
for id in $SEL; do
  if install_extra "$id"; then ADDED=$((ADDED + 1)); else FAILED="$FAILED $id"; fi
done
if [ "$ADDED" -gt 0 ]; then
  if kit_pid kiwix >/dev/null; then say "Restarting the library so the new collections show up..."; start_kiwix || true
  else say "The kit is not running; the new collections appear the next time you start it."; fi
fi
if [ -n "$FAILED" ]; then warn "Not added (run again to retry; downloads resume):$FAILED"; say "RESULT: ADD LIBRARIES FINISHED WITH PROBLEMS"; exit 1; fi
ok "RESULT: ADD LIBRARIES OK"
