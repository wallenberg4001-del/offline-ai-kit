#!/bin/bash
# Add optional regional offline maps. The list is in catalog/maps.txt.
# Opened from STATUS, or run directly:
#   bash mac/add-maps.sh                  (menu)
#   bash mac/add-maps.sh --list
#   bash mac/add-maps.sh --add alberta,europe     (numbers from --list work too; "all" = every map file)
#   bash mac/add-maps.sh --remove alberta
# Vancouver Island, British Columbia and Alberta are the same Canada file and download once.
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
[ -n "$(map_catalog)" ] || { err "The maps list (catalog/maps.txt) is missing."; exit 1; }

save_maps_setting() {
  local prev id merged=""
  prev="$(setting MAPS '')"
  prev="$(printf '%s' "$prev" | tr ',' ' ')"
  for id in $prev "$@"; do
    [ -n "$id" ] || continue
    case " $merged " in *" $id "*) ;; *) merged="$merged $id" ;; esac
  done
  set_setting MAPS "$(printf '%s' "$merged" | sed 's/^ *//' | tr ' ' ',')"
}

case "$ACTION" in
  list) say "Offline maps:"; show_map_catalog; exit 0 ;;
  remove)
    was=no; kit_pid kiwix >/dev/null && was=yes
    ids="$(resolve_map_ids "$IDS" | tr '\n' ' ')"
    for id in $ids; do
      prefix="$(map_field "$id" 3)"
      if f="$(prefix_installed "$prefix")"; then
        others=0; also=0; other=""
        for other in $(map_catalog | awk -F'|' -v p="$prefix" -v me="$id" '$3 == p && $1 != me { print $1 }'); do
          others=$((others + 1))
          case " $ids " in *" $other "*) also=$((also + 1)) ;; esac
        done
        if [ "$others" -gt "$also" ]; then
          warn "  $id uses the same file as another region ($f). The file stays."
          continue
        fi
        stop_kit kiwix >/dev/null
        rm -f "$LIBRARY/$f" "$VERIFIED_DIR/$f"
        log_to zim-downloads.log "REMOVED $f"
        ok "  Removed $id ($f)"
      else say "  Not added: $id"; fi
    done
    [ "$was" = yes ] && { start_kiwix || true; }
    write_maps_index
    exit 0 ;;
  menu)
    say "=================================================="
    say "  Add offline maps (needs internet while downloading)"
    say "  Vancouver Island, British Columbia and Alberta are one Canada file (about 10 GB)."
    say "=================================================="
    show_map_catalog
    say "  Free space on this drive: $(gb "$(free_bytes "$LIBRARY")")"
    say ""
    IDS=""
    [ -t 0 ] && { read -r -p 'Type the numbers or names to add (e.g. 1,4), "all", or press Return to go back: ' IDS || true; }
    [ -n "$IDS" ] || exit 0 ;;
esac

printf '%s\n' "$$" > "$(pid_file add-maps)"
trap 'rm -f "$(pid_file add-maps)"' EXIT
SEL="$(resolve_map_ids "$IDS" | tr '\n' ' ')"
[ -n "${SEL// /}" ] || { say "Nothing chosen."; exit 0; }
UNIQ="$(map_unique_ids $SEL | tr '\n' ' ')"
GB="$(map_gb $SEL)"
say "Adding: $SEL ($(printf '%s' "$UNIQ" | wc -w | tr -d ' ') file(s), about $(size_label "$GB") to download)"
if awk -v g="$GB" 'BEGIN { exit !(g > 50) }' && [ "$YES" != yes ]; then
  a=n; [ -t 0 ] && { read -r -p "That is a very big download. Continue? (Y/N) " a || true; }
  case "$a" in [Yy]*) ;; *) exit 0 ;; esac
fi
stay_awake
FAILED=""; ADDED=0
for id in $UNIQ; do
  if install_map "$id"; then ADDED=$((ADDED + 1)); else FAILED="$FAILED $id"; fi
done
save_maps_setting $SEL
write_maps_index
if [ "$ADDED" -gt 0 ]; then
  if kit_pid kiwix >/dev/null; then say "Restarting the library so the new maps show up..."; start_kiwix || true
  else say "The kit is not running; the new maps appear the next time you start it."; fi
fi
if [ -n "$FAILED" ]; then warn "Not added (run again to retry; downloads resume):$FAILED"; say "RESULT: ADD MAPS FINISHED WITH PROBLEMS"; exit 1; fi
ok "RESULT: ADD MAPS OK"
