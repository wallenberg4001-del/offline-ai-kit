#!/bin/bash
exec bash "$(cd "$(dirname "$0")/../.." && pwd)/mac/check-drive.sh" "$@"
