#!/bin/bash
# Linux status. Based on mac/status.sh.
# LAN address: ip route get 1.1.1.1 (the src address).
export OFFLINE_AI_OS=linux
exec bash "$(cd "$(dirname "$0")/.." && pwd)/mac/status.sh" "$@"
