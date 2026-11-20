#!/bin/bash
# Background downloader for FULL English Wikipedia (~127 GB). Started by START-OFFLINE-AI-MAC.command.
# Resumes after interruptions, checks the SHA256 from Kiwix, then restarts the library to show it.
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_dirs
printf '%s\n' "$$" > "$(pid_file wiki-download)"
trap 'rm -f "$(pid_file wiki-download)"' EXIT
# Keep the computer from idle-sleeping while this runs (stops automatically when we exit).
stay_awake
if [ "$TEST_MODE" != yes ] && fat32_blocked "$LIBRARY"; then
  write_wiki_status error 0 0 0 0 "Paused: this drive is FAT32. Wikipedia needs exFAT, NTFS, or APFS."
  err "This drive is FAT32, which cannot store a file larger than 4 GB."
  err "Full Wikipedia needs exFAT, NTFS, or APFS."
  exit 1
fi

say "$(date '+%Y-%m-%d %H:%M:%S') Full Wikipedia download starting"
if f="$(wikipedia_verified)"; then
  write_wiki_status "done" 0 0 100 0 "Wikipedia ready: $f"; ok "Already verified: $f"; exit 0
fi
write_wiki_status starting 0 0 0 0 "Looking up the newest Wikipedia file..."
dir="$(catalog_field wikipedia 2)"

# Prefer finishing a partial download we already started (if that edition is still on the server).
file=""
for p in "$LIBRARY/$WIKIPEDIA_PREFIX"_*.zim.part "$LIBRARY/$WIKIPEDIA_PREFIX"_*.zim; do
  [ -e "$p" ] || continue
  cand="$(basename "$p" .part)"
  if [ "$(remote_size "$KIWIX_BASE/$dir/$cand")" -gt 0 ]; then file="$cand"; break; fi
done
[ -n "$file" ] || file="$(resolve_latest_zim "$dir" "$WIKIPEDIA_PREFIX")"
if [ -z "$file" ]; then
  write_wiki_status error 0 0 0 0 "Paused: could not reach download.kiwix.org (no internet?). It continues next time you start the kit."
  err "Could not find the Wikipedia file online."; exit 1
fi
url="$KIWIX_BASE/$dir/$file"
total="$(remote_size "$url")"
if [ "$total" -le 0 ]; then
  write_wiki_status error 0 0 0 0 "Paused: could not get the file size (no internet?). It continues next time you start the kit."
  exit 1
fi
dest="$LIBRARY/$file"
already="$(file_size "$dest.part")"
[ -f "$dest" ] && already="$total"
needed=$((total - already))
free="$(free_bytes "$LIBRARY")"
say "File: $file  Size: $(gb "$total")  Already: $(gb "$already")  Free: $(gb "$free")"
if [ "$free" -lt $((needed + 2000000000)) ]; then
  msg="Not enough free space: Wikipedia needs $(gb "$needed") more but only $(gb "$free") is free on this drive. Free up space (or move the kit to a bigger drive) and start the kit again."
  write_wiki_status no-space "$already" "$total" 0 0 "$msg"; err "$msg"; exit 2
fi
if [ "$free" -lt "$WARN_FREE_BYTES" ] && [ "$already" -eq 0 ]; then
  warn "WARNING: only $(gb "$free") free. Wikipedia needs about $(gb "$total"); that leaves very little room."
fi
log_to wikipedia-download.log "START $file total=$total already=$already free=$free"
if [ ! -f "$dest" ]; then
  download_resumable "$url" "$dest" "$total" "Wikipedia" yes 1000 ||
    { write_wiki_status error "$(file_size "$dest.part")" "$total" 0 0 "Paused; it continues next time you start the kit."; exit 1; }
fi
if ! get_zim "$dir" "$file" yes; then
  write_wiki_status failed 0 "$total" 0 0 "Checksum did not match; the damaged file was deleted. It downloads again next time you start the kit."
  exit 3
fi
write_wiki_status "done" "$total" "$total" 100 0 "Wikipedia ready: $file"
log_to wikipedia-download.log "DONE $file"
if kit_pid kiwix >/dev/null; then say "Restarting the library so Wikipedia shows up..."; start_kiwix || true; fi
ok "Full Wikipedia is ready in the Offline Library."
