#!/bin/bash
# Offline check of this drive. No downloads.
#   --quick   presence, size, and an open probe (default)
#   --full    also re-hash every file in DRIVE-MANIFEST.json
set -u
MAC_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$MAC_DIR/lib.sh"
mode=quick
for a in "$@"; do
  case "$a" in
    --full) mode=full ;;
    --quick) mode=quick ;;
    *) err "Use --quick or --full."; exit 1 ;;
  esac
done
v160_check_drive_run "$mode"
