#!/bin/bash
# Removes this copy. In a terminal: bash UNINSTALL-OFFLINE-AI-LINUX.sh
exec bash "$(cd "$(dirname "$0")" && pwd)/linux/uninstall.sh" "$@"
