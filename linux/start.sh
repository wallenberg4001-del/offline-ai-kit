#!/bin/bash
# Linux start. Based on mac/start.sh. Chat page server is mac/serve-chat.py.
# LAN address: ip route get 1.1.1.1 (the src address).
export OFFLINE_AI_OS=linux
exec bash "$(cd "$(dirname "$0")/.." && pwd)/mac/start.sh" "$@"
