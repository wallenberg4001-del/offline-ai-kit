#!/bin/bash
# Linux entry for the shared kit library.
# Based on mac/lib.sh. Keep the wizard steps in the same order as mac/setup.sh.
# Program downloads (glibc unless `ldd --version` says musl):
#   kiwix-tools_linux-x86_64-*.tar.gz or kiwix-tools_linux-aarch64-*.tar.gz
#   kiwix-tools_linux-x86_64-musl-*.tar.gz or kiwix-tools_linux-aarch64-musl-*.tar.gz
#   ollama-linux-amd64.tgz or ollama-linux-arm64.tgz (or .tar.zst when that is what the release ships)
# LAN address: `ip route get 1.1.1.1` and the src address (not the gateway).
export OFFLINE_AI_OS=linux
# shellcheck source=../mac/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/mac/lib.sh"
