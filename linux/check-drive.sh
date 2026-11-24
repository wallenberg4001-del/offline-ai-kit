#!/bin/bash
export OFFLINE_AI_OS=linux
exec bash "$(cd "$(dirname "$0")/.." && pwd)/mac/check-drive.sh" "$@"
