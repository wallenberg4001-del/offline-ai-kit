#!/bin/bash
# Removes the Offline AI Kit from this computer only.
# Stops this copy, removes the Desktop shortcut if it starts this copy,
# removes the program cache, and removes the computer receipt.
# The drive is not changed. Library files, models, and programs stay.
#   --yes       uninstall without the question
#   --dry-run   show the computer items, then stop
#   --root DIR  check DIR instead of this folder. Only allowed with --dry-run.
set -u
MAC_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT="$(cd "$MAC_DIR/.." && pwd)"

finish() {
  local code="${1:-0}"
  if [ -t 0 ]; then
    printf '\n'
    read -r -p "Press Return to close this window. " _ || true
  fi
  exit "$code"
}
refuse() {
  printf 'Refused: %s\n' "$*"
  finish 1
}

YES=no
DRY=no
ROOT_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) YES=yes ;;
    --dry-run) DRY=yes ;;
    --root)
      if [ $# -lt 2 ] || [ -z "${2:-}" ] || [ "${2#-}" != "$2" ]; then
        refuse "--root needs a folder. Nothing was deleted."
      fi
      ROOT_ARG="$2"
      shift
      ;;
    *) refuse "unknown option. Nothing was deleted." ;;
  esac
  shift
done

if [ -n "$ROOT_ARG" ] && [ "$DRY" != yes ]; then
  refuse "checking another folder needs --dry-run. Nothing was deleted."
fi
if [ -n "$ROOT_ARG" ]; then
  if [ -d "$ROOT_ARG" ]; then KIT="$(cd "$ROOT_ARG" && pwd)"; else KIT="$ROOT_ARG"; fi
fi
KIT="${KIT%/}"

parent="$(dirname "$KIT")"
case "$KIT" in
  /|/Users|/Volumes|/System|/private|/tmp|/var|/Applications|"")
    refuse "That folder is not a kit folder. Nothing was deleted."
    ;;
esac
case "$parent" in
  /|/Volumes|/media|/mnt|/run/media)
    refuse "This copy is the whole drive, not a folder on it. The uninstaller will not erase a whole drive. Nothing was deleted."
    ;;
esac
home="${HOME:-}"
home="${home%/}"
if [ -n "$home" ] && [ "$KIT" = "$home" ]; then
  refuse "That folder is your home folder. Nothing was deleted."
fi
if [ ! -f "$KIT/VERSION" ] || { [ ! -d "$KIT/mac" ] && [ ! -d "$KIT/scripts" ]; }; then
  refuse "This folder does not look like the Offline AI Kit. Nothing was deleted."
fi

printf '%s\n' "Remove the Offline AI Kit from this computer?"
printf '%s\n' "  $KIT"
printf '%s\n' ""
printf '%s\n' "Your drive, library, Wikipedia and AI models are not touched."
printf '%s\n' "This removes the Desktop shortcut if it starts this copy,"
printf '%s\n' "and the small cache this kit put on this computer."
printf '%s\n' ""
printf '%s\n' "The drive was not changed. Plug it into any computer and run START to use it again."
if [ "$DRY" = yes ]; then
  wanted="$KIT"
  # shellcheck source=lib.sh
  . "$MAC_DIR/lib.sh"
  KIT="$wanted"
  v160_uninstall_computer yes
  printf '%s\n' "RESULT: UNINSTALL DRY RUN"
  finish 0
fi
if [ "$YES" != yes ]; then
  printf '%s' "Type YES to continue: "
  read -r answer || answer=""
  if [ "$answer" != YES ]; then
    printf '%s\n' "Nothing was deleted."
    finish 0
  fi
fi

wanted="$KIT"
# shellcheck source=lib.sh
. "$MAC_DIR/lib.sh"
if [ "$KIT" != "$wanted" ]; then
  refuse "the folder changed before anything was deleted. Nothing was deleted."
fi
v160_uninstall_computer no
printf '%s\n' "The drive was not changed. Plug it into any computer and run START to use it again."
printf '%s\n' "RESULT: UNINSTALL OK"
finish 0
