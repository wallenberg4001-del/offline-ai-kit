#!/bin/bash
# Double-click in Finder (first time: right-click > Open), or run in Terminal:  bash STOP-OFFLINE-AI-MAC.command
exec bash "$(cd "$(dirname "$0")" && pwd)/mac/stop.sh" "$@"
