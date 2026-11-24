#!/bin/bash
# Drive tools. Separate from Uninstall. Uninstall never calls this.
# Deletes chosen library or model files, the whole kit folder, or asks
# prepare-disk.sh to erase the kit partition (or the whole disk only when
# nothing else is on it).
#   --action library|kit|erase
#   --files a.zim,b.zim          library action, names under library/ or ollama-models/
#   --scope partition|disk       erase only. Default: partition
#   --phrase TEXT                DELETE N FILES, REMOVE KIT FROM DRIVE, or the volume label
#   --erase-word ERASE           second confirmation for erase
#   --yes                        actions 1 and 2 only, and only with the flag below
#   --i-understand-this-deletes-data
#   --dry-run                    show the list and stop
# Erase never accepts --yes.
set -u
MAC_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$MAC_DIR/lib.sh"

ACTION=""
FILES=""
SCOPE="partition"
PHRASE=""
ERASE_WORD=""
YES=no
UNDERSTAND=no
DRY=no

while [ $# -gt 0 ]; do
  case "$1" in
    --action) ACTION="${2:-}"; shift ;;
    --files) FILES="${2:-}"; shift ;;
    --scope) SCOPE="${2:-}"; shift ;;
    --phrase) PHRASE="${2:-}"; shift ;;
    --erase-word) ERASE_WORD="${2:-}"; shift ;;
    --yes) YES=yes ;;
    --i-understand-this-deletes-data) UNDERSTAND=yes ;;
    --dry-run) DRY=yes ;;
    *) err "Unknown option. Nothing was deleted."; exit 1 ;;
  esac
  shift
done

refuse() {
  err "$*"
  err "Nothing was deleted."
  exit 1
}

v160_drive_log() {
  mkdir -p "$LOG_DIR"
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" >> "$LOG_DIR/drive-tools-${PID_TAG:-mac}.log"
}

v160_kit_label() {
  if [ -n "${OFFLINE_AI_KIT_LABEL:-}" ]; then printf '%s\n' "$OFFLINE_AI_KIT_LABEL"; return 0; fi
  printf '%s\n' "OFFLINEAI"
}

v160_collect_library() { # comma-separated names. Prints one absolute path per line.
  local item name path oldifs
  oldifs="$IFS"
  IFS=','
  for item in $FILES; do
    name="$(basename "$item")"
    [ -n "$name" ] || continue
    if [ -f "$LIBRARY/$name" ]; then printf '%s\n' "$LIBRARY/$name"
    elif [ -f "$LIBRARY/${name%.zim}.zimaa" ]; then
      local part
      for part in "$LIBRARY/${name%.zim}".zim??; do
        [ -f "$part" ] && printf '%s\n' "$part"
      done
    elif [ -f "$KIT/ollama-models/$name" ]; then printf '%s\n' "$KIT/ollama-models/$name"
    else
      local found
      found="$(find "$KIT/ollama-models" -type f -name "$name" 2>/dev/null | head -1 || true)"
      if [ -n "$found" ]; then printf '%s\n' "$found"
      else err "Not on this drive: $name"; IFS="$oldifs"; return 1
      fi
    fi
  done
  IFS="$oldifs"
}

v160_bytes() {
  local p total=0 s
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    s="$(file_size "$p")"
    total=$((total + s))
  done
  printf '%s\n' "$total"
}

v160_show_dry() {
  local p rel total
  total=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    rel="${p#"$KIT"/}"
    say "Would delete $rel ($(gb "$(file_size "$p")"))"
    total=$((total + $(file_size "$p")))
  done
  say "Total: $(gb "$total")"
  say "Nothing has been deleted yet."
  say "This permanently deletes $(gb "$total") from the drive $(v160_kit_label). It cannot be undone. The drive will need internet to download this again."
}

v160_under_kit_file() {
  local real
  real="$(v160_realpath "$1")"
  [ "$real" = "$KIT" ] || [ "${real#"$KIT"/}" != "$real" ]
}

v160_apply_library() {
  local p rel
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    v160_under_kit_file "$p" || refuse "Refused (outside the kit drive): $p"
    case "$p" in
      "$LIBRARY"/*|"$KIT/ollama-models"/*) ;;
      *) refuse "Refused (outside the library and models): $p" ;;
    esac
    rel="${p#"$KIT"/}"
    v160_drive_log "deleted $rel $(file_size "$p")"
    rm -f "$p"
    rm -f "$VERIFIED_DIR/$(basename "$p")" "$PROBE_DIR/$(basename "$p")"
    say "Deleted $rel"
  done
  if [ -f "$LIBRARY/library.xml" ]; then
    python3 - "$LIBRARY/library.xml" "$FILES" <<'PY'
import sys
path, names = sys.argv[1], [n for n in sys.argv[2].split(",") if n]
text = open(path, errors="replace").read().splitlines(True)
keep = []
for line in text:
    if any(n and n in line for n in names):
        continue
    keep.append(line)
open(path, "w").write("".join(keep))
PY
  fi
  v160_write_manifest >/dev/null || true
}

v160_prepare_erase() {
  local disk part mode others prep
  disk="${OFFLINE_AI_DISK_ID:-}"
  part="${OFFLINE_AI_PARTITION_ID:-}"
  mode="$SCOPE"
  [ "$mode" = partition ] || [ "$mode" = disk ] || refuse "Pick a scope of partition or disk."
  others="$(v160_other_partitions)"
  if [ "$mode" = disk ] && [ -n "$others" ]; then
    err "This disk also has: $others"
    refuse "Erase the kit partition only, or remove the other partitions first."
  fi
  [ -n "$disk" ] || refuse "Could not see which disk this kit is on."
  if [ "$mode" = partition ] && [ -z "$part" ]; then
    refuse "Could not see which partition this kit is on."
  fi
  json="$(python3 -c 'import json,sys; json.dump({"confirmed": True, "mode": sys.argv[1], "disk": sys.argv[2], "partitionId": sys.argv[3], "sizeGB": 0, "modelsGB": 0, "diskSizeGB": 0}, sys.stdout)' \
    "$mode" "$disk" "$part")"
  if [ -n "${OFFLINE_AI_PREPARE_CMD:-}" ]; then
    printf '%s\n' "$json" | bash -c "$OFFLINE_AI_PREPARE_CMD"
  else
    printf '%s\n' "$json" | bash "$MAC_DIR/prepare-disk.sh"
  fi
}

if [ -z "$ACTION" ]; then
  say "Drive tools. Nothing is selected."
  say "  1) Remove chosen library files or models from this drive"
  say "  2) Remove the whole kit from this drive"
  say "  3) Erase the kit partition (or the whole disk only when nothing else is on it)"
  printf '%s' "Type 1, 2, or 3. Press Return to do nothing: "
  read -r pick || pick=""
  case "$pick" in
    1) ACTION=library ;;
    2) ACTION=kit ;;
    3) ACTION=erase ;;
    *) say "Nothing selected. Nothing was deleted."; exit 0 ;;
  esac
fi

case "$ACTION" in
  library|kit|erase) ;;
  *) refuse "Pick an action." ;;
esac

if [ "$ACTION" = erase ] && [ "$YES" = yes ]; then
  refuse "--yes is not accepted for erase."
fi
if [ "$ACTION" != erase ] && [ "$YES" = yes ] && [ "$UNDERSTAND" != yes ]; then
  refuse "--yes needs --i-understand-this-deletes-data."
fi

list=""
if [ "$ACTION" = library ]; then
  list="$(v160_collect_library)" || exit 1
  [ -n "$list" ] || refuse "Pick at least one file."
elif [ "$ACTION" = kit ]; then
  list="$KIT"
else
  list="$KIT"
fi

printf '%s\n' "$list" | v160_show_dry
if v160_services_running; then
  refuse "The kit is running. Run STOP, then try again."
fi
if v160_on_startup_disk; then
  refuse "This kit is on the startup disk. Drive tools will not change it."
fi
if [ "$DRY" = yes ]; then
  say "RESULT: DRIVE TOOLS DRY RUN"
  exit 0
fi

count=0
if [ "$ACTION" = library ]; then
  count="$(printf '%s\n' "$list" | grep -c . || true)"
  want="DELETE ${count} FILES"
  if [ "$YES" != yes ]; then
    if [ -z "$PHRASE" ]; then
      printf '%s' "Type $want exactly: "
      read -r PHRASE || PHRASE=""
    fi
    [ "$PHRASE" = "$want" ] || { say "Cancelled. Nothing was deleted."; exit 0; }
  fi
  printf '%s\n' "$list" | v160_apply_library
  say "RESULT: DRIVE TOOLS OK"
  exit 0
fi

if [ "$ACTION" = kit ]; then
  if [ "$YES" != yes ]; then
    if [ -z "$PHRASE" ]; then
      printf '%s' "Type REMOVE KIT FROM DRIVE exactly: "
      read -r PHRASE || PHRASE=""
    fi
    [ "$PHRASE" = "REMOVE KIT FROM DRIVE" ] || { say "Cancelled. Nothing was deleted."; exit 0; }
  fi
  v160_drive_log "removed kit folder $(file_size "$KIT" 2>/dev/null || echo 0)"
  python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1])' "$KIT"
  printf '%s\n' "RESULT: DRIVE TOOLS OK"
  exit 0
fi

label="$(v160_kit_label)"
if [ -z "$PHRASE" ]; then
  printf '%s' "Type the volume label ($label) exactly: "
  read -r PHRASE || PHRASE=""
fi
[ "$PHRASE" = "$label" ] || { say "Cancelled. Nothing was deleted."; exit 0; }
if [ -z "$ERASE_WORD" ]; then
  printf '%s' "Type ERASE exactly: "
  read -r ERASE_WORD || ERASE_WORD=""
fi
[ "$ERASE_WORD" = "ERASE" ] || { say "Cancelled. Nothing was deleted."; exit 0; }
v160_drive_log "erase scope=$SCOPE label=$label"
v160_prepare_erase
say "RESULT: DRIVE TOOLS OK"
exit 0
