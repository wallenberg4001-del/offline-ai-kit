# v1.6.0 helpers. Sourced by mac/lib.sh. bash 3.2 safe.
# Pins, libzim check, book probes, computer-only delete guard, split sets, drive manifest.

PINS_FILE="$KIT/catalog/runtime-pins.txt"
PROBE_DIR="$CHECKSUMS/PROBE"
SPLIT_PART_BYTES=2097152000

pin_get() { # pin_get <component> <platform> <url|sha256|version>
  local want="$3" file="$PINS_FILE"
  [ -f "$file" ] || return 1
  awk -F'|' -v c="$1" -v p="$2" -v w="$want" '
    /^[[:space:]]*#/ { next }
    NF < 5 { next }
    {
      for (i = 1; i <= NF; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
      if ($1 == c && $2 == p) {
        if (w == "url") print $3
        else if (w == "sha256") print $4
        else print $5
        exit
      }
    }
  ' "$file"
}

libzim_from_version_text() {
  printf '%s\n' "$1" | awk '
    /libzim/ {
      for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+$/) { print $i; exit }
    }
  '
}

libzim_ge() { # libzim_ge <have> <minimum>  true when have >= minimum
  awk -v a="$1" -v b="$2" 'BEGIN {
    if (a == "" || b == "") exit 1
    split(a, A, "."); split(b, B, ".")
    for (i = 1; i <= 3; i++) {
      av = A[i] + 0; bv = B[i] + 0
      if (av > bv) exit 0
      if (av < bv) exit 1
    }
    exit 0
  }'
}

v160_accept_libzim() { # prints a refusal and returns 1 when the version is below 9.6.0
  local ver="$1"
  if libzim_ge "$ver" 9.6.0; then return 0; fi
  err "This library program is libzim ${ver:-unknown}. This kit needs libzim 9.6.0 or newer."
  return 1
}

v160_current_platform() {
  if [ "${KIT_OS:-mac}" = linux ]; then
    if [ "${LINUX_CPU:-}" = arm ]; then
      if [ "${LINUX_LIBC:-glibc}" = musl ]; then printf '%s\n' linux-arm64-musl; else printf '%s\n' linux-arm64; fi
    else
      if [ "${LINUX_LIBC:-glibc}" = musl ]; then printf '%s\n' linux-x64-musl; else printf '%s\n' linux-x64; fi
    fi
  elif [ "${MAC_ARCH:-arm64}" = x86_64 ]; then printf '%s\n' mac-x64
  else printf '%s\n' mac-arm64
  fi
}

v160_platform_from_dest() { # dest [libc]
  local dest="$1" libc="${2:-}"
  case "$dest" in
    *windows-x64*) printf '%s\n' windows-x64 ;;
    *mac-arm64*) printf '%s\n' mac-arm64 ;;
    *mac-x64*) printf '%s\n' mac-x64 ;;
    *linux-arm64*)
      if [ "$libc" = musl ] || [ "${dest#*musl}" != "$dest" ]; then printf '%s\n' linux-arm64-musl
      else printf '%s\n' linux-arm64; fi ;;
    *linux-x64*)
      if [ "$libc" = musl ] || [ "${dest#*musl}" != "$dest" ]; then printf '%s\n' linux-x64-musl
      else printf '%s\n' linux-x64; fi ;;
    *) v160_current_platform ;;
  esac
}

v160_libzim_of() {
  local bin="$1" text=""
  if [ "${OFFLINE_AI_TEST:-no}" = yes ] && [ -n "${OFFLINE_AI_LIBZIM_TEXT:-}" ]; then
    text="$OFFLINE_AI_LIBZIM_TEXT"
  elif [ -n "$bin" ] && [ -x "$bin" ]; then
    text="$("$bin" --version 2>&1 || true)"
  fi
  libzim_from_version_text "$text"
}

v160_kiwix_tool() { # v160_kiwix_tool <kiwix-search|kiwix-serve|kiwix-manage>
  local name="$1" f
  for f in "$KIWIX_DIR/$name" "$KIWIX_DIR/$name.exe" "$KIWIX_DIR"/*/"$name" "$KIWIX_DIR"/*/"$name.exe"; do
    [ -f "$f" ] || continue
    printf '%s\n' "$f"
    return 0
  done
  return 1
}

v160_rmtree() {
  [ -n "${1:-}" ] || return 0
  [ -e "$1" ] || [ -L "$1" ] || return 0
  python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)' "$1"
}

v160_realpath() {
  python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null || printf '%s\n' "$1"
}

v160_device() {
  if [ "$(uname -s)" = Darwin ]; then stat -f '%d' "$1" 2>/dev/null || true
  else stat -c '%d' "$1" 2>/dev/null || true
  fi
}

v160_kiwix_already() { # dest expected_libzim
  local dest="$1" want="$2" bin have stamp
  dir_has_kiwix "$dest" || return 1
  stamp="$dest/LIBZIM"
  [ -f "$stamp" ] && have="$(tr -d '[:space:]' < "$stamp")"
  bin="$(find "$dest" -type f \( -name 'kiwix-serve' -o -name 'kiwix-serve.exe' \) 2>/dev/null | head -1 || true)"
  if [ -n "$bin" ] && [ -x "$bin" ]; then
    local ran
    ran="$(v160_libzim_of "$bin")"
    [ -n "$ran" ] && have="$ran"
  fi
  libzim_ge "${have:-0}" 9.6.0 || return 1
  if [ -n "$want" ] && [ -n "$have" ] && [ "$have" != "$want" ] && [ "${OFFLINE_AI_TEST:-no}" != yes ]; then
    return 1
  fi
  return 0
}

v160_install_kiwix_from_pin() { # same arguments as install_kiwix_tools. 2 = no pin.
  local dest platform label libc url sha ver archive name got bin
  if [ "$#" -ge 2 ]; then
    dest="$1"; label="${3:-programs}"; libc="${4:-}"
    platform="$(v160_platform_from_dest "$dest" "$libc")"
  else
    dest="$KIWIX_DIR"
    platform="$(v160_current_platform)"
    label="$platform"
    libc=""
    [ "${KIT_OS:-mac}" = linux ] && libc="$LINUX_LIBC"
    [ "$#" -ge 2 ] || say "[1/4] Library program (kiwix-tools for $label)..."
  fi
  [ "$#" -ge 2 ] && say "  Library program (kiwix-tools for $label)..."
  url="$(pin_get kiwix-tools "$platform" url || true)"
  [ -n "$url" ] || return 2
  sha="$(pin_get kiwix-tools "$platform" sha256 || true)"
  ver="$(pin_get kiwix-tools "$platform" version || true)"
  v160_accept_libzim "$ver" || return 1
  if v160_kiwix_already "$dest" "$ver"; then ok "  Already installed."; return 0; fi
  name="$(basename "$url")"
  archive="$RUNTIME/$name"
  download_resumable "$url" "$archive" 0 "$name" no 20 || return 1
  got="$(sha256_of "$archive")"
  if [ "$got" != "$sha" ]; then
    rm -f "$archive"
    err "kiwix-tools download was damaged (checksum mismatch). Run setup again."
    return 1
  fi
  v160_rmtree "$dest"
  mkdir -p "$dest"
  unpack_archive "$archive" "$dest" || { rm -f "$archive"; return 1; }
  rm -f "$archive"
  materialize_symlinks "$dest"
  clear_quarantine "$dest"
  bin="$(find "$dest" -type f \( -name 'kiwix-serve' -o -name 'kiwix-serve.exe' \) | head -1 || true)"
  if [ -n "$bin" ] && [ -x "$bin" ]; then
    got="$(v160_libzim_of "$bin")"
    if [ -n "$got" ]; then
      v160_accept_libzim "$got" || { v160_rmtree "$dest"; return 1; }
      ver="$got"
    fi
  fi
  printf '%s\n' "$ver" > "$dest/LIBZIM"
  case "$dest" in
    *linux-x64/kiwix|*linux-arm64/kiwix|*linux-x64-musl/kiwix|*linux-arm64-musl/kiwix)
      [ -n "$libc" ] && printf '%s\n' "$libc" > "$(dirname "$dest")/LIBC" ;;
  esac
  dir_has_kiwix "$dest" || { err "kiwix-tools for $label did not unpack as expected."; return 1; }
  ok "  Installed."
  select_runtime_dirs
  return 0
}

v160_install_ollama_from_pin() { # dest asset base pinflag. 2 = no pin.
  local dest="$1" comp="ollama" platform url sha archive name tmp
  case "$dest" in
    *ollama-v0.12.9*|*"ollama-$OLLAMA_PIN_VERSION"*) comp="ollama-v0.12.9" ;;
  esac
  case "$dest" in
    *windows-x64*) platform=windows-x64 ;;
    *linux-arm64*) platform=linux-arm64 ;;
    *linux-x64*) platform=linux-x64 ;;
    *mac-x64*) platform=mac-x64 ;;
    *mac-arm64*) platform=mac-arm64 ;;
    *)
      platform="$(v160_current_platform)"
      platform="${platform%-musl}"
      [ "${OLLAMA_CHANNEL:-current}" = pinned ] && comp="ollama-v0.12.9"
      ;;
  esac
  url="$(pin_get "$comp" "$platform" url || true)"
  [ -n "$url" ] || return 2
  sha="$(pin_get "$comp" "$platform" sha256 || true)"
  if dir_has_ollama "$dest"; then ok "  Already installed."; return 0; fi
  name="$(basename "$url")"
  archive="$RUNTIME/$name"
  if [ -f "$archive" ] && [ "$(sha256_of "$archive")" = "$sha" ]; then
    say "  Using the checked download already on the drive: $name"
  else
    download_resumable "$url" "$archive" 0 "$name" no 20 || return 1
    if [ "$(sha256_of "$archive")" != "$sha" ]; then
      rm -f "$archive"
      err "Ollama download was damaged (checksum mismatch). Run setup again."
      return 1
    fi
  fi
  tmp="$RUNTIME/_unpack-$name"
  v160_rmtree "$tmp"
  mkdir -p "$tmp"
  if ! unpack_archive "$archive" "$tmp"; then
    v160_rmtree "$tmp"
    return 1
  fi
  dir_has_ollama "$tmp" || { v160_rmtree "$tmp"; err "Ollama did not unpack as expected."; return 1; }
  materialize_symlinks "$tmp"
  clear_quarantine "$tmp"
  v160_rmtree "$dest"
  mkdir -p "$(dirname "$dest")"
  mv "$tmp" "$dest" || { err "Could not put Ollama into $dest."; return 1; }
  rm -f "$archive"
  ok "  Installed."
  return 0
}

v160_install_darwin_from_pin() { # current|pinned. 2 = no pin.
  local channel="$1" comp="ollama" destname="ollama" url sha name archive tmp id dest
  if [ "$channel" = pinned ]; then comp="ollama-v0.12.9"; destname="ollama-$OLLAMA_PIN_VERSION"; fi
  url="$(pin_get "$comp" mac-arm64 url || true)"
  [ -n "$url" ] || return 2
  sha="$(pin_get "$comp" mac-arm64 sha256 || true)"
  if dir_has_ollama "$RUNTIME/mac-arm64/$destname" && dir_has_ollama "$RUNTIME/mac-x64/$destname"; then
    ok "  Mac AI program ($destname) already installed for both chips."
    return 0
  fi
  name="$(basename "$url")"
  archive="$RUNTIME/$name"
  download_resumable "$url" "$archive" 0 "Mac $name" no 20 || return 1
  if [ "$(sha256_of "$archive")" != "$sha" ]; then
    rm -f "$archive"
    err "Ollama for Mac was damaged (checksum mismatch). Run setup again."
    return 1
  fi
  tmp="$RUNTIME/_unpack-darwin-$channel"
  v160_rmtree "$tmp"
  mkdir -p "$tmp"
  unpack_archive "$archive" "$tmp" || { v160_rmtree "$tmp"; rm -f "$archive"; return 1; }
  rm -f "$archive"
  materialize_symlinks "$tmp"
  for id in mac-arm64 mac-x64; do
    dest="$RUNTIME/$id/$destname"
    if dir_has_ollama "$dest"; then ok "  Already installed: runtime/$id/$destname"; continue; fi
    v160_rmtree "$dest"
    mkdir -p "$dest"
    cp -R "$tmp/." "$dest/"
    materialize_symlinks "$dest"
    clear_quarantine "$dest"
    ok "  Installed runtime/$id/$destname"
  done
  v160_rmtree "$tmp"
  return 0
}

v160_install_musl_kiwix() {
  [ "${TEST_MODE:-no}" = yes ] && return 0
  install_kiwix_tools "$RUNTIME/linux-x64-musl/kiwix" pinned "Linux x64 musl" musl || return 1
  install_kiwix_tools "$RUNTIME/linux-arm64-musl/kiwix" pinned "Linux ARM musl" musl || return 1
}

v160_install_pinned_zstd() {
  [ "${TEST_MODE:-no}" = yes ] && return 0
  local plat url sha file dest got
  mkdir -p "$RUNTIME/_host-tools"
  for plat in darwin-arm64 darwin-amd64 linux-amd64 linux-arm64 windows-x64 windows-arm64; do
    url="$(pin_get zstd "$plat" url || true)"
    [ -n "$url" ] || continue
    sha="$(pin_get zstd "$plat" sha256 || true)"
    file="$(basename "$url")"
    dest="$RUNTIME/_host-tools/$file"
    if [ -f "$dest" ] && [ "$(sha256_of "$dest")" = "$sha" ]; then continue; fi
    download_resumable "$url" "$dest" 0 "$file" no 5 || return 1
    got="$(sha256_of "$dest")"
    if [ "$got" != "$sha" ]; then rm -f "$dest"; err "The zstd program was damaged (checksum mismatch). Run setup again."; return 1; fi
    chmod +x "$dest" 2>/dev/null || true
  done
  return 0
}

v160_rename_fn() { # oldname newname
  local body
  body="$(declare -f "$1")" || return 1
  body="${body/$1 ()/$2 ()}"
  eval "$body"
}

v160_wrap_installers() {
  v160_rename_fn install_kiwix_tools install_kiwix_tools_unpinned || return 0
  install_kiwix_tools() {
    local rc
    v160_install_kiwix_from_pin "$@"
    rc=$?
    if [ "$rc" -eq 2 ]; then install_kiwix_tools_unpinned "$@"; return $?; fi
    return "$rc"
  }
  v160_rename_fn install_one_ollama install_one_ollama_unpinned || return 0
  install_one_ollama() {
    local rc
    v160_install_ollama_from_pin "$@"
    rc=$?
    if [ "$rc" -eq 2 ]; then install_one_ollama_unpinned "$@"; return $?; fi
    return "$rc"
  }
  v160_rename_fn install_darwin_copies install_darwin_copies_unpinned || return 0
  install_darwin_copies() {
    local rc
    v160_install_darwin_from_pin "$@"
    rc=$?
    if [ "$rc" -eq 2 ]; then install_darwin_copies_unpinned "$@"; return $?; fi
    return "$rc"
  }
  v160_rename_fn install_universal_programs install_universal_programs_unpinned || return 0
  install_universal_programs() {
    local rc=0
    install_universal_programs_unpinned "$@" || rc=$?
    v160_install_musl_kiwix || rc=1
    v160_install_pinned_zstd || rc=1
    return "$rc"
  }
  v160_rename_fn select_runtime_dirs select_runtime_dirs_unpinned || return 0
  select_runtime_dirs() {
    select_runtime_dirs_unpinned "$@"
    if [ "${KIT_OS:-mac}" = linux ] && [ "${LINUX_LIBC:-glibc}" = musl ]; then
      local musl_dir="$RUNTIME/${PLATFORM_ID}-musl/kiwix"
      if dir_has_kiwix "$musl_dir"; then KIWIX_DIR="$musl_dir"; fi
    fi
  }
}

probe_classify() { # probe_classify <exit-code> <text>
  local code="$1" text="$2"
  case "$text" in
    *"Cannot create Search without FT Xapian index"*) printf '%s\n' no-index; return 0 ;;
  esac
  case "$text" in
    *"Cannot read"*|*"Invalid argument"*|*"Unable to add"*) printf '%s\n' fail; return 1 ;;
  esac
  if [ "$code" != 0 ]; then printf '%s\n' fail; return 1; fi
  printf '%s\n' ok
  return 0
}

v160_has_split() { # filename.zim
  local name="$1" base
  base="${name%.zim}"
  [ ! -f "$LIBRARY/$name" ] && [ -f "$LIBRARY/${base}.zimaa" ]
}

v160_book_file() { # path passed to kiwix, or the first part
  local p="$1"
  if [ -f "$p" ]; then printf '%s\n' "$p"; return 0; fi
  if [ -f "${p%.zim}.zimaa" ]; then printf '%s\n' "${p%.zim}.zimaa"; return 0; fi
  return 1
}

v160_book_identity() {
  local p f size mtime ver
  f="$(v160_book_file "$1" || true)"
  [ -n "$f" ] && [ -f "$f" ] || { printf '%s\n' missing; return 0; }
  size="$(file_size "$f")"
  if [ "$(uname -s)" = Darwin ]; then mtime="$(stat -f '%m' "$f" 2>/dev/null || echo 0)"
  else mtime="$(stat -c '%Y' "$f" 2>/dev/null || echo 0)"; fi
  ver="$(v160_libzim_of "$(v160_kiwix_tool kiwix-serve || true)")"
  printf '%s %s %s\n' "$size" "$mtime" "${ver:-none}"
}

v160_probe_cache() { printf '%s\n' "$PROBE_DIR/$(basename "$1")"; }

probe_book() { # prints ok, no-index, or fail
  local target="$1" bin text code=0 result ident cache first
  bin="$(v160_kiwix_tool kiwix-search || true)"
  ident="$(v160_book_identity "$target")"
  cache="$(v160_probe_cache "$target")"
  if [ -f "$cache" ]; then
    local old_id old_result
    old_id="$(sed -n '1p' "$cache")"
    old_result="$(sed -n '2p' "$cache")"
    if [ "$old_id" = "$ident" ] && [ -n "$old_result" ]; then
      printf '%s\n' "$old_result"
      return 0
    fi
  fi
  if [ -z "$bin" ]; then printf '%s\n' fail; return 1; fi
  text="$("$bin" "$target" a 2>&1)" || code=$?
  result="$(probe_classify "$code" "$text" || true)"
  first="$(printf '%s\n' "$text" | awk 'NF { print; exit }')"
  mkdir -p "$PROBE_DIR"
  printf '%s\n%s\n%s\n' "$ident" "$result" "$first" > "$cache"
  printf '%s\n' "$result"
}

v160_probe_error() {
  local cache
  cache="$(v160_probe_cache "$1")"
  if [ -f "$cache" ]; then sed -n '3p' "$cache"; else printf '%s\n' "could not open it"; fi
}

probe_search() { # 0 when at least one result line
  local target="$1" bin text
  bin="$(v160_kiwix_tool kiwix-search || true)"
  [ -n "$bin" ] || return 1
  text="$("$bin" "$target" water 2>&1 || true)"
  printf '%s\n' "$text" | awk 'NF && $0 !~ /Cannot read|Invalid argument|Unable to add|Cannot create Search/ { found=1 } END { exit found ? 0 : 1 }'
}

v160_list_books() {
  local m base
  [ -d "$VERIFIED_DIR" ] || return 0
  for m in "$VERIFIED_DIR"/*.zim; do
    [ -e "$m" ] || continue
    base="$(basename "$m")"
    if [ -f "$LIBRARY/$base" ] || v160_has_split "$base"; then
      printf '%s\n' "$LIBRARY/$base"
    fi
  done
}

v160_skip() {
  printf 'Skipped %s: this computer'\''s library program cannot open it (%s)\n' "$(basename "$1")" "$2" >&2
}

v160_status_word() { # path -> OK / OK (split...) / OK (no search index) / Skipped
  local path="$1" result name parts
  result="$(probe_book "$path")"
  name="$(basename "$path")"
  case "$result" in
    no-index) printf '%s\n' "OK (no search index)" ;;
    ok)
      if v160_has_split "$name"; then
        parts="$(find "$LIBRARY" -name "${name%.zim}.zim??" -type f 2>/dev/null | wc -l | tr -d ' ')"
        printf 'OK (split into %s parts)\n' "$parts"
      else
        printf '%s\n' OK
      fi
      ;;
    *) printf 'Skipped: %s\n' "$(v160_probe_error "$path")" ;;
  esac
}

v160_select_books() { # prints "SERVE path" or "SKIP path". Skip lines are also explained.
  local book result
  while IFS= read -r book; do
    [ -n "$book" ] || continue
    result="$(probe_book "$book" || true)"
    case "$result" in
      ok|no-index) printf 'SERVE %s\n' "$book" ;;
      *)
        v160_skip "$book" "$(v160_probe_error "$book")"
        printf 'SKIP %s\n' "$book"
        ;;
    esac
  done <<EOF
$(v160_list_books)
EOF
}

v160_start_library() { # bin address
  local bin="$1" addr="$2" book line manage count=0 xml list
  xml="$LIBRARY/library.xml"
  list="$LIBRARY/.serve-list"
  rm -f "$xml" "$list"
  : > "$list"
  while IFS= read -r line; do
    case "$line" in
      SERVE\ *) book="${line#SERVE }" ;;
      *) continue ;;
    esac
    manage="$(v160_kiwix_tool kiwix-manage || true)"
    if [ -n "$manage" ]; then
      if "$manage" "$xml" add "$book" >/dev/null 2>&1; then
        count=$((count + 1))
        printf '%s\n' "$book" >> "$list"
      else
        v160_skip "$book" "could not add it to the library"
      fi
    else
      count=$((count + 1))
      printf '%s\n' "$book" >> "$list"
    fi
  done <<EOF
$(v160_select_books)
EOF
  if [ "$count" -eq 0 ]; then warn "  No verified library files yet - the library will be empty."; return 1; fi
  local i
  for i in $(seq 1 10); do port_up "$LIBRARY_PORT" || break; sleep 0.5; done
  if port_up "$LIBRARY_PORT"; then err "  Port $LIBRARY_PORT is used by another program; the library cannot start."; return 1; fi
  if [ -f "$xml" ]; then
    # shellcheck disable=SC2086
    nohup $ARCH_CMD "$bin" --address="$addr" --port="$LIBRARY_PORT" --library "$xml" >> "$LOG_DIR/kiwix-${LOG_TAG:-mac}.log" 2>&1 < /dev/null &
  else
    # shellcheck disable=SC2086
    nohup $ARCH_CMD "$bin" --address="$addr" --port="$LIBRARY_PORT" $(cat "$list") >> "$LOG_DIR/kiwix-${LOG_TAG:-mac}.log" 2>&1 < /dev/null &
  fi
  printf '%s\n' "$!" > "$(pid_file kiwix)"
  for i in $(seq 1 30); do
    if port_up "$LIBRARY_PORT"; then say "  Library is serving ${count} collection(s)."; return 0; fi
    sleep 0.5
  done
  warn "  The library did not answer yet. See logs/kiwix-${LOG_TAG:-mac}.log"
  return 1
}

v160_part_bytes() {
  if [ -n "${OFFLINE_AI_SPLIT_BYTES:-}" ]; then printf '%s\n' "$OFFLINE_AI_SPLIT_BYTES"
  else printf '%s\n' "$SPLIT_PART_BYTES"
  fi
}

v160_split_book() { # zim-path. Prints SHA and PEAK_EXTRA. Exit 75 when stopped early on purpose.
  local zim="$1" part journal
  part="$(v160_part_bytes)"
  mkdir -p "$LIBRARY"
  journal="$LIBRARY/.split-$(basename "${zim%.zim}").json"
  OFFLINE_AI_SPLIT_DIE_AFTER="${OFFLINE_AI_SPLIT_DIE_AFTER:-0}" \
  OFFLINE_AI_SPLIT_INPLACE="${OFFLINE_AI_SPLIT_INPLACE:-no}" \
  python3 - "$zim" "$part" "$journal" <<'PY'
import hashlib, json, os, sys
src, part, journal = sys.argv[1], int(sys.argv[2]), sys.argv[3]
die = int(os.environ.get("OFFLINE_AI_SPLIT_DIE_AFTER") or "0")
inplace = os.environ.get("OFFLINE_AI_SPLIT_INPLACE") == "yes"
if part < 1:
    sys.stderr.write("part size is invalid\n")
    sys.exit(1)

def suf(i):
    return chr(ord("a") + (i // 26) % 26) + chr(ord("a") + (i % 26))

def sha_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        while True:
            block = fh.read(1024 * 1024)
            if not block:
                break
            h.update(block)
    return h.hexdigest()

base = src[:-4] if src.endswith(".zim") else src
state = {}
if os.path.isfile(journal):
    try:
        state = json.load(open(journal))
    except Exception:
        state = {}
if "sha" not in state:
    state = {"sha": sha_file(src), "original_size": os.path.getsize(src), "parts_done": [], "peak_extra": 0}
size = int(state["original_size"])
n = (size + part - 1) // part
peak = int(state.get("peak_extra") or 0)
done = set(state.get("parts_done") or [])

def save():
    state["parts_done"] = sorted(done)
    state["peak_extra"] = peak
    tmp = journal + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(state, fh)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, journal)

for i in range(n - 1, -1, -1):
    start = i * part
    length = min(part, size - start)
    dest = base + ".zim" + suf(i)
    if suf(i) in done and os.path.isfile(dest) and os.path.getsize(dest) == length:
        continue
    with open(src, "rb") as fh, open(dest, "wb") as out:
        fh.seek(start)
        left = length
        while left:
            block = fh.read(min(1024 * 1024, left))
            if not block:
                break
            out.write(block)
            left -= len(block)
        out.flush()
        os.fsync(out.fileno())
    extra = os.path.getsize(dest)
    if extra > peak:
        peak = extra
    if inplace:
        with open(src, "rb+") as fh:
            fh.truncate(start)
            fh.flush()
            os.fsync(fh.fileno())
    done.add(suf(i))
    save()
    if die and len(done) >= die and len(done) < n:
        print("SHA %s" % state["sha"])
        print("PEAK_EXTRA %s" % peak)
        sys.exit(75)

h = hashlib.sha256()
for i in range(n):
    with open(base + ".zim" + suf(i), "rb") as fh:
        while True:
            block = fh.read(1024 * 1024)
            if not block:
                break
            h.update(block)
got = h.hexdigest()
print("SHA %s" % got)
print("PEAK_EXTRA %s" % peak)
if got != state["sha"]:
    sys.stderr.write("split hash does not match the original\n")
    sys.exit(1)
PY
}

v160_finish_split() { # zim path. Deletes the original only after the probes pass.
  local zim="$1" held result search_note="no" out rc=0
  out="$(v160_split_book "$zim")" || rc=$?
  printf '%s\n' "$out"
  if [ "$rc" -eq 75 ]; then return 75; fi
  [ "$rc" -eq 0 ] || return "$rc"
  held="${zim}.held"
  if [ -f "$zim" ]; then mv -f "$zim" "$held"; fi
  result="$(probe_book "${zim}")"
  case "$result" in
    ok|no-index) ;;
    *)
      if [ -f "$held" ] && [ "$(file_size "$held")" -gt 0 ]; then
        v160_rmtree_parts "$zim"
        mv -f "$held" "$zim"
      fi
      v160_skip "$zim" "$(v160_probe_error "$zim")"
      return 1
      ;;
  esac
  if [ "$result" = ok ]; then
    if ! probe_search "$zim"; then
      printf '%s\n' "search-off"
      if [ -f "$held" ] && [ "$(file_size "$held")" -gt 0 ]; then
        v160_rmtree_parts "$zim"
        mv -f "$held" "$zim"
        return 0
      fi
    fi
  fi
  rm -f "$held"
  return 0
}

v160_rmtree_parts() {
  local zim="$1" base f
  base="${zim%.zim}"
  for f in "$base".zim??; do
    [ -f "$f" ] || continue
    rm -f "$f"
  done
}

v160_assert_space() { # selected_gb free_bytes
  local sel="$1" free="$2" need free_gb need_bytes extra=0
  if [ "${OFFLINE_AI_SPLIT_MARGIN:-no}" = yes ]; then extra=2; fi
  need="$(awk -v s="$sel" -v x="$extra" 'BEGIN { printf "%.1f", (s + 0) * 1.05 + 5 + x }')"
  free_gb="$(awk -v b="$free" 'BEGIN { printf "%.0f", (b + 0) / 1e9 }')"
  need_bytes="$(awk -v n="$need" 'BEGIN { printf "%.0f", n * 1e9 }')"
  if awk -v f="$free" -v n="$need_bytes" 'BEGIN { exit !((f + 0) < (n + 0)) }'; then
    err "Selected ${sel} GB, free ${free_gb} GB → not enough room."
    err "Drop the largest items, or pick a larger drive. Nothing was downloaded."
    return 1
  fi
  say "Selected ${sel} GB, free ${free_gb} GB → OK"
  return 0
}

ensure_kit_id() {
  local f="$KIT/kit-id.txt" id
  if [ ! -s "$f" ]; then
    id="$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
    printf '%s\n' "$id" > "$f"
  fi
  tr -d '[:space:]' < "$f"
}

receipt_path() {
  local id
  id="$(ensure_kit_id)"
  if [ "$(uname -s)" = Darwin ] && [ "${KIT_OS:-mac}" != linux ]; then
    printf '%s\n' "$HOME/Library/Application Support/offline-ai-kit/receipt-$id.txt"
  else
    printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/offline-ai-kit/receipt-$id.txt"
  fi
}

record_receipt() { # kind path
  local kind="$1" path="$2" f
  [ -n "${path:-}" ] || return 0
  [ -n "${HOME:-}" ] || return 0
  f="$(receipt_path)"
  mkdir -p "$(dirname "$f")"
  if [ -f "$f" ] && grep -F "| $path |" "$f" >/dev/null 2>&1; then return 0; fi
  printf '%s | %s | %s\n' "$kind" "$path" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$f"
}

v160_under_home_or_tmp() {
  local p="$1" h t
  h="${HOME:-}"; t="${TMPDIR:-/tmp}"
  h="${h%/}"; t="${t%/}"
  case "$p" in
    "$h"|"$h"/*|"$t"|"$t"/*|/tmp|/tmp/*|/private/tmp|/private/tmp/*|/var/folders/*) return 0 ;;
  esac
  return 1
}

v160_name_allowed() {
  local p="$1" base
  base="$(basename "$p")"
  case "$base" in
    "Offline AI.command"|"Offline AI.lnk"|offline-ai-kit.desktop|offline-ai-kit) return 0 ;;
    receipt-*.txt|offline-ai-uninstall-*.cmd|*offline-ai*) return 0 ;;
  esac
  case "$p" in
    */offline-ai-kit|*/offline-ai-kit/*) return 0 ;;
  esac
  return 1
}

safe_remove() { # prints a refusal and returns 1. Never deletes the kit drive.
  local path="$1" real kitdev bootdev dev
  [ -n "${path:-}" ] || return 1
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then return 0; fi
  real="$(v160_realpath "$path")"
  kitdev="$(v160_device "$KIT")"
  bootdev="$(v160_device /)"
  dev="$(v160_device "$real")"
  if [ "$real" = "$KIT" ] || [ "${real#"$KIT"/}" != "$real" ]; then
    printf 'Refused (on the kit drive): %s\n' "$path"
    return 1
  fi
  if [ -n "$dev" ] && [ -n "$kitdev" ] && [ "$dev" = "$kitdev" ] && [ "$kitdev" != "$bootdev" ]; then
    printf 'Refused (on the kit drive): %s\n' "$path"
    return 1
  fi
  case "$real" in
    /Volumes/*|/media/*|/mnt/*|/run/media/*)
      if [ "$dev" != "$bootdev" ]; then
        printf 'Refused (on the kit drive): %s\n' "$path"
        return 1
      fi
      ;;
  esac
  if ! v160_under_home_or_tmp "$real" || ! v160_name_allowed "$real"; then
    printf 'Refused (on the kit drive): %s\n' "$path"
    return 1
  fi
  if [ -L "$path" ]; then rm -f "$path"; return 0; fi
  if [ -d "$real" ]; then v160_rmtree "$real"; else rm -f "$real"; fi
  return 0
}

v160_file_names_folder() {
  [ -n "${1:-}" ] && [ -f "$1" ] && [ -n "${2:-}" ] || return 1
  awk -v kit="$2" '
    BEGIN { n = length(kit); found = 0; if (n < 2) exit 1 }
    {
      rest = $0
      while ((i = index(rest, kit)) > 0) {
        c = substr(rest, i + n, 1)
        if (c == "" || c == "/" || c == "\"" || c == " " || c == "\t") { found = 1; exit }
        rest = substr(rest, i + 1)
      }
    }
    END { exit (found ? 0 : 1) }
  ' "$1"
}

v160_shortcut_path() {
  if [ "${OFFLINE_AI_OS:-}" = linux ] || [ "${KIT_OS:-mac}" = linux ]; then
    printf '%s\n' "${XDG_DESKTOP_DIR:-${HOME:-}/Desktop}/offline-ai-kit.desktop"
  else
    printf '%s\n' "${HOME:-}/Desktop/Offline AI.command"
  fi
}

v160_cache_dir() {
  if [ "$(uname -s)" = Darwin ] && [ "${KIT_OS:-mac}" != linux ]; then
    printf '%s\n' "${HOME:-}/Library/Caches/offline-ai-kit"
  else
    printf '%s\n' "${XDG_CACHE_HOME:-${HOME:-}/.cache}/offline-ai-kit"
  fi
}

v160_note_item() { # dry kind path
  local dry="$1" kind="$2" path="$3"
  if [ "$dry" = yes ]; then printf 'Would remove %s: %s\n' "$kind" "$path"
  else printf 'Removed %s: %s\n' "$kind" "$path"; fi
}

v160_uninstall_computer() { # yes = dry run
  local dry="$1" shortcut cache receipt id f count=0
  if [ "$dry" != yes ]; then
    for f in kiwix ollama chat-server add-libraries add-maps wiki-download; do
      stop_kit "$f" || true
    done
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
      port_up "$LIBRARY_PORT" || port_up "$OLLAMA_PORT" || port_up "$CHAT_PORT" || break
      sleep 0.3
    done
  fi
  shortcut="$(v160_shortcut_path)"
  if v160_file_names_folder "$shortcut" "$KIT"; then
    count=$((count + 1))
    if [ "$dry" = yes ]; then v160_note_item yes shortcut "$shortcut"
    else safe_remove "$shortcut" && v160_note_item no shortcut "$shortcut" || true
    fi
  fi
  cache="$(v160_cache_dir)"
  case "$cache" in
    */offline-ai-kit) ;;
    *) cache="" ;;
  esac
  if [ -n "$cache" ] && [ -d "$cache" ]; then
    count=$((count + 1))
    if [ "$dry" = yes ]; then v160_note_item yes cache "$cache"
    else safe_remove "$cache" && v160_note_item no cache "$cache" || true
    fi
  fi
  if [ -s "$KIT/kit-id.txt" ]; then
    id="$(tr -d '[:space:]' < "$KIT/kit-id.txt")"
    if [ "$(uname -s)" = Darwin ] && [ "${KIT_OS:-mac}" != linux ]; then
      receipt="$HOME/Library/Application Support/offline-ai-kit/receipt-$id.txt"
    else
      receipt="${XDG_STATE_HOME:-$HOME/.local/state}/offline-ai-kit/receipt-$id.txt"
    fi
    if [ -f "$receipt" ]; then
      while IFS='|' read -r kind path rest; do
        path="$(printf '%s' "$path" | sed 's/^ *//; s/ *$//')"
        [ -n "$path" ] || continue
        count=$((count + 1))
        if [ "$dry" = yes ]; then v160_note_item yes "$kind" "$path"
        else safe_remove "$path" && v160_note_item no "$kind" "$path" || true
        fi
      done < "$receipt"
      count=$((count + 1))
      if [ "$dry" = yes ]; then v160_note_item yes receipt "$receipt"
      else safe_remove "$receipt" && v160_note_item no receipt "$receipt" || true
      fi
    fi
  fi
  local agent
  if [ -d "${HOME:-}/Library/LaunchAgents" ]; then
    for agent in "$HOME/Library/LaunchAgents/"*offline-ai*; do
      [ -e "$agent" ] || continue
      count=$((count + 1))
      if [ "$dry" != yes ]; then launchctl bootout "gui/$(id -u)" "$agent" >/dev/null 2>&1 || true; fi
      if [ "$dry" = yes ]; then v160_note_item yes launchagent "$agent"
      else safe_remove "$agent" && v160_note_item no launchagent "$agent" || true
      fi
    done
  fi
  local prof
  for prof in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile"; do
    [ -f "$prof" ] || continue
    if grep -q '# >>> offline-ai-kit >>>' "$prof" 2>/dev/null; then
      count=$((count + 1))
      if [ "$dry" = yes ]; then v160_note_item yes profile "$prof"
      else
        cp -f "$prof" "$prof.bak"
        python3 -c '
import sys
p=sys.argv[1]
lines=open(p).read().splitlines(True)
out=[]; skip=False
for line in lines:
    if "# >>> offline-ai-kit >>>" in line:
        skip=True; continue
    if "# <<< offline-ai-kit <<<" in line:
        skip=False; continue
    if not skip: out.append(line)
open(p,"w").write("".join(out))
' "$prof"
        v160_note_item no profile "$prof"
      fi
    fi
  done
  if [ -e "${HOME:-}/.offline-ai-kit" ]; then
    count=$((count + 1))
    if [ "$dry" = yes ]; then v160_note_item yes state "$HOME/.offline-ai-kit"
    else safe_remove "$HOME/.offline-ai-kit" && v160_note_item no state "$HOME/.offline-ai-kit" || true
    fi
  fi
  local unit_dir unit
  unit_dir="${XDG_CONFIG_HOME:-${HOME:-}/.config}/systemd/user"
  if [ -d "$unit_dir" ]; then
    for unit in "$unit_dir"/*offline-ai*; do
      [ -e "$unit" ] || continue
      count=$((count + 1))
      if [ "$dry" != yes ]; then systemctl --user disable --now "$(basename "$unit")" >/dev/null 2>&1 || true; fi
      if [ "$dry" = yes ]; then v160_note_item yes systemd "$unit"
      else safe_remove "$unit" && v160_note_item no systemd "$unit" || true
      fi
    done
  fi
  if [ -x /usr/libexec/ApplicationFirewall/socketfilterfw ]; then
    local listed
    listed="$(/usr/libexec/ApplicationFirewall/socketfilterfw --listapps 2>/dev/null || true)"
    if printf '%s\n' "$listed" | grep -F "$KIT/" >/dev/null 2>&1; then
      say "Firewall entries for this kit are still on this computer."
      say "To remove one: /usr/libexec/ApplicationFirewall/socketfilterfw --remove <path under the kit>"
    fi
  fi
  if [ "$count" -eq 0 ]; then
    say "Nothing to remove from this computer."
  fi
  if [ "$dry" != yes ]; then
    mkdir -p "$LOG_DIR"
    printf '%s computer-only uninstall\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$LOG_DIR/uninstall-${PID_TAG:-mac}.log"
    rm -f "$LOG_DIR"/*."${PID_TAG:-mac}".pid
  fi
  return 0
}

v160_ask() { # prompt default yes|no. Honour OFFLINE_AI_MIGRATE_YES / NO.
  local prompt="$1" def="$2" answer
  if [ "${OFFLINE_AI_MIGRATE_YES:-no}" = yes ]; then return 0; fi
  if [ "${OFFLINE_AI_MIGRATE_NO:-no}" = yes ]; then return 1; fi
  if [ "${EASY:-no}" = yes ] && [ "$def" = yes ]; then return 0; fi
  if [ ! -t 0 ]; then
    [ "$def" = yes ]
    return $?
  fi
  if [ "$def" = yes ]; then read -r -p "$prompt [Y/n] " answer || answer=""
  else read -r -p "$prompt [y/N] " answer || answer=""; fi
  case "$answer" in
    "") [ "$def" = yes ] ;;
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

v160_maybe_split() { # book path. 0 when the split is kept. Skips when it cannot.
  local zim="$1" free need part size prev rc=0
  part="$(v160_part_bytes)"
  need=$((part + 1000000000))
  free="$(free_bytes "$LIBRARY")"
  if [ "${free:-0}" -lt "$need" ]; then
    v160_skip "$zim" "not enough free space to split it"
    return 1
  fi
  prev="${OFFLINE_AI_SPLIT_INPLACE:-no}"
  size="$(file_size "$zim")"
  if [ "$prev" != yes ] && [ "${free:-0}" -lt $((size + 1000000000)) ]; then
    OFFLINE_AI_SPLIT_INPLACE=yes
    export OFFLINE_AI_SPLIT_INPLACE
  fi
  v160_finish_split "$zim" || rc=$?
  if [ "$prev" != yes ]; then OFFLINE_AI_SPLIT_INPLACE=no; export OFFLINE_AI_SPLIT_INPLACE; fi
  return "$rc"
}

v160_probes_ok() {
  local book result
  while IFS= read -r book; do
    [ -n "$book" ] || continue
    result="$(probe_book "$book" || true)"
    case "$result" in
      ok|no-index) ;;
      *) return 1 ;;
    esac
  done <<EOF
$(v160_list_books)
EOF
  return 0
}

migrate_v160() {
  local marker="$CHECKSUMS/MIGRATED-1.6" bin ver bundle mount src base
  [ -f "$marker" ] && return 0
  mkdir -p "$CHECKSUMS" "$LIBRARY"
  bin="$(v160_kiwix_tool kiwix-serve || true)"
  ver=""
  [ -n "$bin" ] && ver="$(v160_libzim_of "$bin")"
  if ! libzim_ge "${ver:-0}" 9.6.0; then
    if [ "${TEST_MODE:-no}" = yes ]; then
      say "Test mode: library programs were not updated. Nothing was deleted."
      return 0
    fi
    say "Update library programs (about 1 GB download)."
    if v160_ask "Update library programs now? This needs internet once." yes; then
      install_kiwix_tools || return 1
      bin="$(v160_kiwix_tool kiwix-serve || true)"
      ver="$(v160_libzim_of "$bin")"
    else
      say "Library programs were not updated. Nothing was deleted."
      return 0
    fi
  fi
  if ! libzim_ge "${ver:-0}" 9.6.0; then
    say "Library programs are still older than libzim 9.6.0. Nothing was deleted."
    return 0
  fi
  local book result bad=no
  while IFS= read -r book; do
    [ -n "$book" ] || continue
    result="$(probe_book "$book" || true)"
    case "$result" in
      ok|no-index) ;;
      *)
        if ! v160_maybe_split "$book"; then bad=yes; fi
        ;;
    esac
  done <<EOF
$(v160_list_books)
EOF
  bundle="$KIT/mac-library.sparsebundle"
  if [ -d "$bundle" ]; then
    local ok_all=yes copied=0 f name
    for f in "$bundle"/*.zim "$bundle"/*/*.zim; do
      [ -f "$f" ] || continue
      copied=$((copied + 1))
      name="$(basename "$f")"
      if [ ! -f "$LIBRARY/$name" ]; then ok_all=no; continue; fi
      result="$(probe_book "$LIBRARY/$name")"
      case "$result" in
        ok|no-index) ;;
        *) ok_all=no ;;
      esac
    done
    if [ "$ok_all" = yes ]; then
      local gb remove=no
      gb="$(du -sk "$bundle" 2>/dev/null | awk '{ printf "%.0f", $1/1000000 }')"
      say "Free up about ${gb:-0} GB: the Mac copy is no longer needed."
      if [ "${EASY:-no}" = yes ]; then remove=yes
      elif v160_ask "Remove the Mac copy?" no; then remove=yes
      fi
      if [ "$remove" = yes ]; then
        if command -v hdiutil >/dev/null 2>&1; then hdiutil detach "$bundle" -force >/dev/null 2>&1 || true; fi
        v160_rmtree "$bundle"
        say "Removed mac-library.sparsebundle. Library files were not changed."
      fi
    fi
  fi
  printf '%s\n' "1.6" > "$marker"
  return 0
}

v160_write_manifest() {
  python3 - "$KIT" "$KIT_VERSION" <<'PY'
import hashlib, json, os, sys, datetime
root, version = sys.argv[1], sys.argv[2]
skip_names = {"DRIVE-MANIFEST.json", "DRIVE-READY.txt"}
files = []
libzim = {}
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d != ".git"]
    for name in filenames:
        if name in skip_names:
            continue
        full = os.path.join(dirpath, name)
        rel = os.path.relpath(full, root).replace("\\", "/")
        if rel.startswith("logs/") or rel.startswith("logs\\"):
            continue
        if os.path.islink(full):
            continue
        h = hashlib.sha256()
        size = 0
        with open(full, "rb") as fh:
            while True:
                block = fh.read(1024 * 1024)
                if not block:
                    break
                size += len(block)
                h.update(block)
        files.append({"path": rel, "size": size, "sha256": h.hexdigest()})
        if rel.endswith("/LIBZIM") or rel.endswith("\\LIBZIM"):
            plat = rel.split("/")[1] if rel.startswith("runtime/") else ""
            if plat:
                libzim[plat] = open(full).read().strip()
files.sort(key=lambda item: item["path"])
doc = {
    "version": version,
    "created": datetime.date.today().isoformat(),
    "libzim": libzim,
    "files": files,
}
out = os.path.join(root, "DRIVE-MANIFEST.json")
with open(out, "w") as fh:
    json.dump(doc, fh, indent=2, sort_keys=True)
    fh.write("\n")
ready = os.path.join(root, "DRIVE-READY.txt")
with open(ready, "w") as fh:
    fh.write("Offline AI Kit %s\n" % version)
    fh.write("Files: %d\n" % len(files))
    fh.write("Verified: all %d files match.\n" % len(files))
    if libzim:
        fh.write("Library program: libzim %s\n" % ", ".join("%s %s" % (k, libzim[k]) for k in sorted(libzim)))
    fh.write("No user name, computer name, or network identity is stored in this file.\n")
print("MANIFEST %d" % len(files))
PY
}

v160_check_drive() { # quick|full
  local mode="${1:-quick}"
  python3 - "$KIT" "$mode" <<'PY'
import hashlib, json, os, sys
root, mode = sys.argv[1], sys.argv[2]
manifest = os.path.join(root, "DRIVE-MANIFEST.json")
if not os.path.isfile(manifest):
    print("RESULT: DRIVE INCOMPLETE")
    print("Missing DRIVE-MANIFEST.json")
    sys.exit(1)
doc = json.load(open(manifest))
progress_path = os.path.join(root, "library", "checksums", "CHECK-PROGRESS")
done = {}
if os.path.isfile(progress_path):
    for line in open(progress_path):
        parts = line.rstrip("\n").split(" ", 3)
        if len(parts) == 4:
            done[parts[3]] = (parts[0], parts[1], parts[2])
problems = []
new_lines = []
files = doc.get("files") or []
n = len(files)
for i, item in enumerate(files, 1):
    rel = item["path"]
    full = os.path.join(root, rel)
    if not os.path.isfile(full):
        problems.append("missing " + rel)
        continue
    size = os.path.getsize(full)
    if int(item.get("size") or -1) != size:
        problems.append("size " + rel)
        continue
    if mode == "full":
        mtime = str(os.stat(full).st_mtime_ns)
        cached = done.get(rel)
        if cached and cached[0] == item.get("sha256") and cached[1] == str(size) and cached[2] == mtime:
            new_lines.append("%s %s %s %s" % (item["sha256"], size, mtime, rel))
        else:
            h = hashlib.sha256()
            with open(full, "rb") as fh:
                while True:
                    block = fh.read(1024 * 1024)
                    if not block:
                        break
                    h.update(block)
            got = h.hexdigest()
            if got != item.get("sha256"):
                problems.append("hash " + rel)
            else:
                new_lines.append("%s %s %s %s" % (got, size, mtime, rel))
        if i % 20 == 0 or i == n:
            print("Checked %d of %d" % (i, n), flush=True)
if mode == "full":
    os.makedirs(os.path.dirname(progress_path), exist_ok=True)
    with open(progress_path, "w") as fh:
        fh.write("\n".join(new_lines) + ("\n" if new_lines else ""))
if problems:
    print("RESULT: DRIVE INCOMPLETE")
    for line in problems:
        print(line)
    sys.exit(1)
print("Verified: all %d files match." % n)
print("RESULT: DRIVE OK")
PY
}

v160_check_drive_run() { # quick|full. Quick also open-probes books on this computer.
  local mode="${1:-quick}" tmp rc=0
  tmp="$(mktemp)"
  v160_check_drive "$mode" > "$tmp" || rc=$?
  if [ "$rc" -ne 0 ]; then
    cat "$tmp"
    rm -f "$tmp"
    return "$rc"
  fi
  if ! v160_probes_ok; then
    grep -v '^RESULT:' "$tmp" || true
    say "A library file on this computer did not open."
    say "RESULT: DRIVE INCOMPLETE"
    rm -f "$tmp"
    return 1
  fi
  cat "$tmp"
  rm -f "$tmp"
  return 0
}

v160_finish_setup() { # pass the failure list. Empty means the downloads finished.
  local problems="${1:-}"
  if [ -n "$problems" ]; then
    say "RESULT: SETUP FINISHED WITH PROBLEMS"
    say "RESULT: DRIVE INCOMPLETE"
    return 0
  fi
  migrate_v160 || true
  ensure_kit_id >/dev/null || true
  if v160_write_manifest >/dev/null && v160_probes_ok && v160_manifest_clean; then
    say "RESULT: SETUP OK"
    say "RESULT: DRIVE READY"
  else
    say "RESULT: SETUP OK"
    say "RESULT: DRIVE INCOMPLETE"
  fi
}

v160_on_startup_disk() {
  if [ "${OFFLINE_AI_KIT_ON_STARTUP:-}" = yes ]; then return 0; fi
  if [ "${OFFLINE_AI_KIT_ON_STARTUP:-}" = no ]; then return 1; fi
  local kitdev bootdev
  kitdev="$(v160_device "$KIT")"
  bootdev="$(v160_device /)"
  [ -n "$kitdev" ] && [ "$kitdev" = "$bootdev" ]
}

v160_manifest_clean() { # 0 when the manifest has no home, user, or host identity
  local f="$KIT/DRIVE-MANIFEST.json" t="$KIT/DRIVE-READY.txt"
  [ -f "$f" ] || return 1
  if grep -E -i "${HOME:-/does-not-match}|$(hostname 2>/dev/null || echo no-host)|${USER:-nouser}" "$f" "$t" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

v160_services_running() {
  local n
  for n in kiwix ollama chat-server add-libraries add-maps wiki-download; do
    if kit_pid "$n" >/dev/null 2>&1; then return 0; fi
  done
  return 1
}

v160_other_partitions() {
  if [ -n "${OFFLINE_AI_DISK_PARTITIONS+x}" ]; then
    printf '%s\n' "$OFFLINE_AI_DISK_PARTITIONS"
    return 0
  fi
  printf '%s\n' ""
}

v160_wrap_installers
