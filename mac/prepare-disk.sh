#!/bin/bash
# Erases one external disk or one partition and formats it as exFAT named OFFLINEAI.
# Reads one JSON object on stdin: disk, mode (partition|disk), partitionId, sizeGB,
# modelsGB, diskSizeGB, confirmed. Refuses the startup disk before any erase.
# modelsGB, when the whole disk is erased, makes a second volume named AI-DRIVE
# for a Windows PC to store LLM models. The kit volume OFFLINEAI gets the rest.
# Linux formats the chosen partition only. Whole-disk erase is not offered on Linux.
set -u
KIT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib.sh
. "$KIT/mac/lib.sh"

refuse() {
  printf 'Refused: %s\n' "$*"
  exit 1
}

json="$(cat || true)"
parsed="$(printf '%s' "$json" | perl -MJSON::PP -e '
use strict;
use warnings;
use JSON::PP qw(decode_json);
local $/;
my $raw = <STDIN>;
my $j = eval { decode_json(defined $raw ? $raw : "") };
sub out {
  my ($k, $v) = @_;
  $v = "" unless defined $v;
  $v =~ s/[^0-9A-Za-z._:-]//g;
  print "$k=$v\n";
}
if (!$j || ref($j) ne "HASH") { out("ERROR", "badjson"); exit 0; }
my $c = $j->{confirmed};
my $yes = ($c && "$c" ne "0" && lc("$c") ne "false") ? "yes" : "no";
out("CONFIRMED", $yes);
my $mode = $j->{mode} || "";
$mode = "" unless $mode eq "partition" || $mode eq "disk";
out("MODE", $mode);
out("DISK", $j->{disk} || "");
out("PART", $j->{partitionId} || "");
my $size = $j->{sizeGB};
$size = 0 unless defined $size && "$size" =~ /^\d+(?:\.\d+)?$/;
out("SIZE_GB", $size);
my $models = $j->{modelsGB};
$models = 0 unless defined $models && "$models" =~ /^\d+(?:\.\d+)?$/;
out("MODELS_GB", $models);
my $disk_size = $j->{diskSizeGB};
$disk_size = 0 unless defined $disk_size && "$disk_size" =~ /^\d+(?:\.\d+)?$/;
out("DISK_SIZE_GB", $disk_size);
')"

CONFIRMED=no
MODE=""
DISK=""
PART=""
SIZE_GB=0
MODELS_GB=0
DISK_SIZE_GB=0
PARSE_ERROR=""
while IFS='=' read -r key val; do
  case "$key" in
    CONFIRMED) CONFIRMED="$val" ;;
    MODE) MODE="$val" ;;
    DISK) DISK="$val" ;;
    PART) PART="$val" ;;
    SIZE_GB) SIZE_GB="$val" ;;
    MODELS_GB) MODELS_GB="$val" ;;
    DISK_SIZE_GB) DISK_SIZE_GB="$val" ;;
    ERROR) PARSE_ERROR="$val" ;;
  esac
done <<EOF
$parsed
EOF

[ -n "$PARSE_ERROR" ] && refuse "The request could not be read."
[ "$CONFIRMED" = yes ] || refuse "Tick the box before erasing."
[ "$MODE" = partition ] || [ "$MODE" = disk ] || refuse "Pick what to erase."
if [ "$MODE" = partition ] && awk -v m="$MODELS_GB" 'BEGIN { exit !((m + 0) > 0) }'; then
  refuse "The Windows drive is only made when the whole disk is erased. Nothing was erased."
fi
if awk -v m="$MODELS_GB" 'BEGIN { exit !((m + 0) > 0 && (m + 0) < 200) }'; then
  refuse "The Windows drive needs at least 200 GB. Nothing was erased."
fi

sizes_match() { # actual bytes, page size in GB. exit 2 if the page size is missing, 1 if it differs.
  awk -v b="$1" -v g="$2" 'BEGIN {
    if ((g + 0) <= 0) exit 2
    actual = (b + 0) / 1000000000
    diff = actual - g
    if (diff < 0) diff = -diff
    if (diff / g > 0.05) exit 1
    exit 0
  }'
}

find_offlineai_mount() { # physical disk id
  local disk="$1" found id
  [ -n "$disk" ] || return 1
  found="$(diskutil list -plist "$disk" 2>/dev/null | plutil -convert json -o - - 2>/dev/null | perl -MJSON::PP -e '
    use JSON::PP qw(decode_json);
    local $/;
    my $j = eval { decode_json(<STDIN> // "") } or exit 0;
    for my $disk (@{$j->{AllDisksAndPartitions} || []}) {
      for my $part (@{$disk->{Partitions} || []}) {
        my $name = $part->{VolumeName} || "";
        next unless $name eq "OFFLINEAI" || $name =~ /^OFFLINEAI /;
        my $mount = $part->{MountPoint} || "";
        my $id = $part->{DeviceIdentifier} || "";
        if ($mount ne "") { print $mount; exit 0; }
        if ($id ne "") { print "ID:$id"; exit 0; }
      }
    }
  ')"
  [ -n "$found" ] || return 1
  case "$found" in
    ID:*)
      id="${found#ID:}"
      [[ "$id" =~ ^disk[0-9]+s[0-9]+$ ]] || return 1
      diskutil mount "$id" >/dev/null 2>&1 || true
      found="$(diskutil info "$id" 2>/dev/null | awk -F': +' '/^[[:space:]]*Mount Point:/ { print $2; exit }')"
      ;;
  esac
  case "$found" in
    ""|Not\ Mounted*|Not\ applicable*) return 1 ;;
  esac
  printf '%s\n' "$found"
}

linux_prepare() {
  if [ "$MODE" = disk ]; then
    refuse "Whole-disk erase is not offered on Linux. The startup disk was not touched."
  fi
  [[ "$DISK" =~ ^(sd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$ ]] || refuse "Pick a disk."
  [[ "$PART" =~ ^${DISK}p?[0-9]+$ ]] || refuse "That partition is not on this disk."
  [ -b "/dev/$DISK" ] || refuse "That disk is not on this computer."
  [ -b "/dev/$PART" ] || refuse "That partition is not on this disk."
  local root_src root_disk pk bytes ptype mnt mount out
  root_src="$(findmnt -no SOURCE / 2>/dev/null | awk '{ print $1; exit }')"
  [ -n "$root_src" ] || root_src="$(df -P / 2>/dev/null | awk 'NR==2 { print $1 }')"
  root_disk="$(lsblk -no PKNAME "$root_src" 2>/dev/null | awk 'NR==1 { print $1 }')"
  if [ -z "$root_disk" ] && [ -n "$root_src" ]; then
    root_disk="$(basename "$root_src" | sed -E 's/p?[0-9]+$//')"
  fi
  if [ "$DISK" = "$root_disk" ] || [ "$PART" = "$(basename "$root_src")" ]; then
    refuse "That disk is the startup disk. It cannot be erased."
  fi
  pk="$(lsblk -no PKNAME "/dev/$PART" 2>/dev/null | awk 'NR==1 { print $1 }')"
  [ "$pk" = "$DISK" ] || refuse "That partition is not on this disk."
  bytes="$(lsblk -b -dn -o SIZE "/dev/$DISK" 2>/dev/null | awk 'NR==1 { print $1 }')"
  [ -n "$bytes" ] || refuse "That disk is not on this computer."
  if sizes_match "$bytes" "$DISK_SIZE_GB"; then
    :
  else
    rc=$?
    if [ "$rc" -eq 2 ]; then refuse "The disk size was not confirmed."; fi
    refuse "That disk is a different size from the one on the page. Look again. The startup disk was not touched."
  fi
  ptype="$(lsblk -dn -o PARTTYPENAME "/dev/$PART" 2>/dev/null | head -1 || true)"
  case "$ptype" in
    *EFI*|*Microsoft\ reserved*|*BIOS\ boot*)
      refuse "That partition is a system partition. The startup disk was not touched."
      ;;
  esac
  command -v mkfs.exfat >/dev/null 2>&1 || refuse "mkfs.exfat is not installed. Install exfatprogs, then run this again. The startup disk was not touched."
  mnt="$(findmnt -no TARGET "/dev/$PART" 2>/dev/null | head -1 || true)"
  if [ -n "$mnt" ]; then
    [ "$mnt" = "/" ] && refuse "That partition is the startup disk. It cannot be erased."
    umount "$mnt" || refuse "Could not unmount that partition. Close anything using it and try again."
  fi
  printf '%s\n' "Erasing the chosen partition and formatting it as exFAT, named OFFLINEAI."
  mkfs.exfat -n OFFLINEAI "/dev/$PART" || { printf '%s\n' "The erase did not finish."; exit 1; }
  mount=""
  if command -v udisksctl >/dev/null 2>&1; then
    out="$(udisksctl mount -b "/dev/$PART" 2>&1 || true)"
    mount="$(printf '%s\n' "$out" | sed -n 's/.* at \(.*\)\.$/\1/p' | head -1)"
  fi
  [ -n "$mount" ] || mount="$(findmnt -no TARGET "/dev/$PART" 2>/dev/null | head -1 || true)"
  [ -n "$mount" ] || { printf '%s\n' "The volume was formatted, but it did not mount."; exit 1; }
  printf 'PREPARED %s\n' "$mount"
  exit 0
}

if [ "$(uname -s)" != Darwin ]; then
  linux_prepare
fi

[[ "$DISK" =~ ^disk[0-9]+$ ]] || refuse "Pick a disk."
if [ "$MODE" = partition ]; then
  [[ "$PART" =~ ^${DISK}s[0-9]+$ ]] || refuse "That partition is not on this disk."
fi

root_info="$(diskutil info / 2>/dev/null || true)"
start_whole="$(printf '%s\n' "$root_info" | awk -F': +' '/^[[:space:]]*Part of Whole:/ { print $2; exit }')"
start_phys="$(printf '%s\n' "$root_info" | awk -F': +' '/^[[:space:]]*APFS Physical Store:/ { print $2; exit }')"
[ -n "$start_phys" ] || start_phys="$(printf '%s\n' "$root_info" | awk -F': +' '/^[[:space:]]*Physical Store:/ { print $2; exit }')"
start_disk="$(printf '%s' "$start_phys" | sed -E 's/s[0-9].*$//')"
if [ "$DISK" = "$start_whole" ] || [ "$DISK" = "$start_phys" ] || { [ -n "$start_disk" ] && [ "$DISK" = "$start_disk" ]; }; then
  refuse "That disk is the startup disk. It cannot be erased."
fi

dinfo="$(diskutil info "$DISK" 2>/dev/null)" || refuse "That disk is not on this computer."
[ -n "$dinfo" ] || refuse "That disk is not on this computer."
loc="$(printf '%s\n' "$dinfo" | awk -F': +' '/^[[:space:]]*Device Location:/ { print $2; exit }')"
[ "$loc" = "External" ] || refuse "That disk is not an external disk. The startup disk cannot be erased."
bytes="$(printf '%s\n' "$dinfo" | sed -n 's/.*(\([0-9][0-9]*\) Bytes).*/\1/p' | head -1)"
[ -n "$bytes" ] || refuse "That disk is not on this computer."
if sizes_match "$bytes" "$DISK_SIZE_GB"; then
  :
else
  rc=$?
  if [ "$rc" -eq 2 ]; then refuse "The disk size was not confirmed."; fi
  refuse "That disk is a different size from the one on the page. Look again. The startup disk was not touched."
fi

if [ "$MODE" = partition ]; then
  pinfo="$(diskutil info "$PART" 2>/dev/null)" || refuse "That partition is not on this disk."
  part_whole="$(printf '%s\n' "$pinfo" | awk -F': +' '/^[[:space:]]*Part of Whole:/ { print $2; exit }')"
  [ "$part_whole" = "$DISK" ] || refuse "That partition is not on this disk."
  ptype="$(printf '%s\n' "$pinfo" | awk -F': +' '/^[[:space:]]*Partition Type:/ { print $2; exit }')"
  case "$ptype" in
    EFI*|Apple_Boot*|Microsoft\ Reserved*)
      refuse "That partition is a system partition. The startup disk was not touched."
      ;;
  esac
  printf '%s\n' "Erasing the chosen partition and formatting it as exFAT, named OFFLINEAI."
  if [ "$ptype" = "Apple_APFS" ]; then
    diskutil apfs deleteContainer "$PART" ExFAT OFFLINEAI 0 || { printf '%s\n' "The erase did not finish."; exit 1; }
  else
    diskutil eraseVolume ExFAT OFFLINEAI "$PART" || { printf '%s\n' "The erase did not finish."; exit 1; }
  fi
else
  size_g="$(awk -v g="$SIZE_GB" 'BEGIN { printf "%d", int(g + 0.5) }')"
  actual_gb="$(awk -v b="$bytes" 'BEGIN { printf "%.1f", (b + 0) / 1000000000 }')"
  if [ "$SIZE_GB" != 0 ]; then
    awk -v s="$SIZE_GB" -v a="$actual_gb" 'BEGIN { exit !((s + 0) < 200 || (s + 0) > (a + 1)) }' && refuse "That size does not fit on this disk."
  fi
  if awk -v m="$MODELS_GB" 'BEGIN { exit !((m + 0) > 0) }'; then
    models_g="$(awk -v g="$MODELS_GB" 'BEGIN { printf "%d", int(g + 0.5) }')"
    fit="$(awk -v m="$MODELS_GB" -v s="$SIZE_GB" -v a="$actual_gb" 'BEGIN {
      m += 0; s += 0; a += 0
      kit = s > 0 ? s : (a - m)
      if (kit < 199) { print "kit"; exit 0 }
      if (s > 0 && (s + m) > (a + 1)) { print "fit"; exit 0 }
      print "ok"
    }')"
    if [ "$fit" = kit ]; then refuse "The Windows drive does not leave 200 GB for the kit. Nothing was erased."; fi
    if [ "$fit" != ok ]; then refuse "Those sizes do not fit on this disk. Nothing was erased."; fi
    printf '%s\n' "Erasing the whole disk. AI-DRIVE gets ${models_g} GB for a Windows PC to store LLM models. OFFLINEAI gets the rest for the kit."
    diskutil partitionDisk "$DISK" GPT ExFAT "AI-DRIVE" "${models_g}G" ExFAT OFFLINEAI 0 || { printf '%s\n' "The erase did not finish."; exit 1; }
  else
    printf '%s\n' "Erasing the whole disk and formatting it as exFAT, named OFFLINEAI."
    if [ "$SIZE_GB" = 0 ] || awk -v s="$SIZE_GB" -v a="$actual_gb" 'BEGIN { exit !((a - s) < 1) }'; then
      diskutil partitionDisk "$DISK" GPT ExFAT OFFLINEAI 0 || { printf '%s\n' "The erase did not finish."; exit 1; }
    else
      diskutil partitionDisk "$DISK" GPT ExFAT OFFLINEAI "${size_g}G" "Free Space" gap 0 || { printf '%s\n' "The erase did not finish."; exit 1; }
    fi
  fi
fi

mount="$(find_offlineai_mount "$DISK" || true)"
if [ -z "$mount" ]; then
  printf '%s\n' "The volume was formatted, but it did not mount."
  exit 1
fi
printf 'PREPARED %s\n' "$mount"
exit 0
