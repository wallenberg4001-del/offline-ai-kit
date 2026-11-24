#!/bin/bash
# Linux drive tools. The drive is changed only by the actions in this menu.
export OFFLINE_AI_OS=linux
exec bash "$(cd "$(dirname "$0")/.." && pwd)/mac/drive-tools.sh" "$@"
