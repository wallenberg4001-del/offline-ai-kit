#!/bin/bash
# Double-click in Finder, or: bash "CHECK-DRIVE (Mac).command" --quick
exec bash "$(cd "$(dirname "$0")" && pwd)/mac/check-drive.sh" "$@"
