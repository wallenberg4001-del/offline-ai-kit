#!/bin/bash
# Prints one JSON object describing this computer for the guided installer.
# No downloads. Safe to run any time. Linux launchers set OFFLINE_AI_OS=linux first.
KIT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib.sh
. "$KIT/mac/lib.sh"

RAM="$(ram_gb)"
FREE_B="$(free_bytes "$KIT")"
FREE_GB="$(awk -v b="${FREE_B:-0}" 'BEGIN { printf "%.1f", b / 1e9 }')"
PROFILE="$(profile_for_ram "$RAM")"
case "$(profile_tier "$PROFILE")" in essentials) TIER=1 ;; *) TIER=2 ;; esac
if awk -v f="$FREE_GB" 'BEGIN { exit !(f >= 170) }'; then WIKI=true; else WIKI=false; fi
if [ "$AI_AVAILABLE" = yes ]; then AI=true; else AI=false; fi
EXTRA="$(universal_extra_gb)"
INTEL=""

if [ "${KIT_OS:-mac}" = linux ]; then
  OS=linux
  FAMILY=linux
  PROGRAMS=1
  if [ "$MAC_ARCH" = x86_64 ]; then
    if [ "$RAM" -ge 16 ]; then SUGGEST=8; else SUGGEST=lite; fi
  else
    case "$PROFILE" in lite) SUGGEST=lite ;; standard) SUGGEST=16 ;; large) SUGGEST=24 ;; *) SUGGEST=32 ;; esac
  fi
  COMP="Linux ($(uname -m)), ${RAM} GB memory, ${FREE_GB} GB free on this drive"
elif [ "$MAC_ARCH" = x86_64 ]; then
  OS=mac
  FAMILY=intel
  PROGRAMS=1
  INTEL="$(intel_models | tr ' ' ',')"
  SUGGEST="$INTEL"
  COMP="Intel Mac, ${RAM} GB memory, macOS ${MACOS_VER}, ${FREE_GB} GB free on this drive"
else
  OS=mac
  FAMILY=apple
  PROGRAMS=1
  case "$PROFILE" in lite) SUGGEST=lite ;; standard) SUGGEST=16 ;; large) SUGGEST=24 ;; *) SUGGEST=32 ;; esac
  COMP="Mac with an Apple chip, ${RAM} GB memory, macOS ${MACOS_VER}, ${FREE_GB} GB free on this drive"
fi

printf '{"os":"%s","family":"%s","ramGB":%s,"freeGB":%s,"suggestedModels":"%s","suggestedTier":"%s","suggestedWikipedia":%s,"universalExtraGB":%s,"programsGB":%s,"aiAvailable":%s,"intelModels":"%s","computer":"%s","folder":"%s"}\n' \
  "$OS" "$FAMILY" "$RAM" "$FREE_GB" "$(json_escape "$SUGGEST")" "$TIER" "$WIKI" "$EXTRA" "$PROGRAMS" "$AI" \
  "$(json_escape "$INTEL")" "$(json_escape "$COMP")" "$(json_escape "$KIT")"
