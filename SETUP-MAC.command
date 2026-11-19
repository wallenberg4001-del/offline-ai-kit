#!/bin/bash
# Double-click in Finder (first time: right-click > Open), or run in Terminal:  bash SETUP-MAC.command
exec bash "$(cd "$(dirname "$0")" && pwd)/mac/setup.sh" "$@"
