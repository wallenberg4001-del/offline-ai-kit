#!/bin/bash
exec bash "$(cd "$(dirname "$0")/../.." && pwd)/mac/drive-tools.sh" "$@"
