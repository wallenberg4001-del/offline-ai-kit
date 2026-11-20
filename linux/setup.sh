#!/bin/bash
# Linux setup. Based on mac/setup.sh. Keep the wizard steps in the same order.
# Downloads kiwix-tools_linux-x86_64 or kiwix-tools_linux-aarch64 (musl when ldd says musl)
# and ollama-linux-amd64.tgz or ollama-linux-arm64.tgz.
# The home-network address comes from: ip route get 1.1.1.1
export OFFLINE_AI_OS=linux
exec bash "$(cd "$(dirname "$0")/.." && pwd)/mac/setup.sh" "$@"
