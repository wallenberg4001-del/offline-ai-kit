#!/bin/bash
# Start the kit on Linux. If this file is not executable (exFAT), run:
#   bash "/path/to/START-OFFLINE-AI-LINUX.sh"
exec bash "$(cd "$(dirname "$0")" && pwd)/linux/start.sh" "$@"
