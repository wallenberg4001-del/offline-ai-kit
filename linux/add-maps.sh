#!/bin/bash
# Offline maps on Linux. Same catalog and SHA-256 flow as Mac and Windows.
export OFFLINE_AI_OS=linux
exec bash "$(cd "$(dirname "$0")/.." && pwd)/mac/add-maps.sh" "$@"
