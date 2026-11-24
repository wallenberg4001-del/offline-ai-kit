#!/bin/bash
# Prints a JSON array of drives the guided installer can offer.
# External drives, plus the drive this copy is already on. No downloads.
# Fields: name, path, format, freeGB, fat32, current, external.
KIT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib.sh
. "$KIT/mac/lib.sh"

json_bool() { if [ "$1" = yes ]; then printf 'true'; else printf 'false'; fi; }

mount_of() {
  df -kP "$1" 2>/dev/null | awk 'NR==2 { $1=$2=$3=$4=$5=""; sub(/^[[:space:]]+/, ""); print }'
}

free_gb_of() {
  local kb
  kb="$(df -kP "$1" 2>/dev/null | awk 'NR==2 { print $4 }')"
  awk -v k="${kb:-0}" 'BEGIN { printf "%.1f", (k + 0) * 1024 / 1000000000 }'
}

is_fat() {
  local fs
  fs="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$fs" in
    *exfat*) return 1 ;;
    *fat32*|*fat16*|*fat12*|*ms-dos*|*msdos*|*vfat*) return 0 ;;
  esac
  return 1
}

ITEMS=""
SEEN="|"
add_item() { # name path format fat current external
  local name="$1" path="$2" format="$3" fat="$4" current="$5" external="$6" free
  case "$SEEN" in *"|$path|"*) return ;; esac
  SEEN="${SEEN}${path}|"
  free="$(free_gb_of "$path")"
  [ -n "$ITEMS" ] && ITEMS="${ITEMS},"
  ITEMS="${ITEMS}{\"name\":\"$(json_escape "$name")\",\"path\":\"$(json_escape "$path")\",\"format\":\"$(json_escape "$format")\",\"freeGB\":$free,\"fat32\":$(json_bool "$fat"),\"current\":$(json_bool "$current"),\"external\":$(json_bool "$external")}"
}

under_mount() { # mount
  [ "$KIT" = "$1" ] || [ "${KIT#"$1"/}" != "$KIT" ]
}

if [ "$(uname -s)" = Darwin ]; then
  KIT_MOUNT="$(mount_of "$KIT")"
  for vol in /Volumes/*; do
    [ -d "$vol" ] && [ ! -L "$vol" ] || continue
    info="$(diskutil info "$vol" 2>/dev/null)" || continue
    loc="$(printf '%s\n' "$info" | awk -F': +' '/^[[:space:]]*Device Location:/ { print $2; exit }')"
    [ "$loc" = "External" ] || continue
    fs="$(printf '%s\n' "$info" | awk -F': +' '/^[[:space:]]*File System Personality:/ { print $2; exit }')"
    [ -n "$fs" ] || continue
    name="$(printf '%s\n' "$info" | awk -F': +' '/^[[:space:]]*Volume Name:/ { print $2; exit }')"
    [ -n "$name" ] || name="$(basename "$vol")"
    fat=no; is_fat "$fs" && fat=yes
    cur=no; under_mount "$vol" && cur=yes
    add_item "$name" "$vol" "$fs" "$fat" "$cur" yes
  done
  case "$SEEN" in
    *"|$KIT_MOUNT|"*) ;;
    *)
      if [ -n "$KIT_MOUNT" ] && [ -d "$KIT_MOUNT" ]; then
        info="$(diskutil info "$KIT_MOUNT" 2>/dev/null || true)"
        fs="$(printf '%s\n' "$info" | awk -F': +' '/^[[:space:]]*File System Personality:/ { print $2; exit }')"
        name="$(printf '%s\n' "$info" | awk -F': +' '/^[[:space:]]*Volume Name:/ { print $2; exit }')"
        loc="$(printf '%s\n' "$info" | awk -F': +' '/^[[:space:]]*Device Location:/ { print $2; exit }')"
        [ -n "$name" ] || name="$(basename "$KIT_MOUNT")"
        [ -n "$fs" ] || fs="unknown"
        fat=no; is_fat "$fs" && fat=yes
        ext=no; [ "$loc" = "External" ] && ext=yes
        add_item "$name" "$KIT_MOUNT" "$fs" "$fat" yes "$ext"
      fi
      ;;
  esac
else
  KIT_MOUNT="$(mount_of "$KIT")"
  if command -v lsblk >/dev/null 2>&1; then
    while IFS= read -r line; do
      mount="$(printf '%s\n' "$line" | sed -n 's/.*MOUNTPOINT="\([^"]*\)".*/\1/p')"
      [ -n "$mount" ] && [ "$mount" != "/" ] && [ -d "$mount" ] || continue
      tran="$(printf '%s\n' "$line" | sed -n 's/.*TRAN="\([^"]*\)".*/\1/p')"
      rm="$(printf '%s\n' "$line" | sed -n 's/.*\bRM="\([^"]*\)".*/\1/p')"
      hot="$(printf '%s\n' "$line" | sed -n 's/.*HOTPLUG="\([^"]*\)".*/\1/p')"
      fs="$(printf '%s\n' "$line" | sed -n 's/.*FSTYPE="\([^"]*\)".*/\1/p')"
      label="$(printf '%s\n' "$line" | sed -n 's/.*LABEL="\([^"]*\)".*/\1/p')"
      ext=no
      if [ "$tran" = "usb" ] || [ "$rm" = "1" ] || [ "$hot" = "1" ]; then ext=yes; fi
      cur=no; under_mount "$mount" && cur=yes
      [ "$ext" = yes ] || [ "$cur" = yes ] || continue
      [ -n "$fs" ] || continue
      [ -n "$label" ] || label="$(basename "$mount")"
      fat=no; is_fat "$fs" && fat=yes
      add_item "$label" "$mount" "$fs" "$fat" "$cur" "$ext"
    done <<EOF
$(lsblk -b -P -o MOUNTPOINT,LABEL,FSTYPE,TRAN,RM,HOTPLUG,TYPE 2>/dev/null || true)
EOF
  fi
  case "$SEEN" in
    *"|$KIT_MOUNT|"*) ;;
    *)
      if [ -n "$KIT_MOUNT" ] && [ -d "$KIT_MOUNT" ]; then
        fs="$(findmnt -no FSTYPE -T "$KIT_MOUNT" 2>/dev/null | head -1 || true)"
        [ -n "$fs" ] || fs="unknown"
        fat=no; is_fat "$fs" && fat=yes
        add_item "$(basename "$KIT_MOUNT")" "$KIT_MOUNT" "$fs" "$fat" yes no
      fi
      ;;
  esac
fi

printf '[%s]\n' "$ITEMS"
