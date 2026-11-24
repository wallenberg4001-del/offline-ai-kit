#!/bin/bash
# Linux uninstall. Removes this copy from this computer. The drive is not changed.
export OFFLINE_AI_OS=linux
exec bash "$(cd "$(dirname "$0")/.." && pwd)/mac/uninstall.sh" "$@"
