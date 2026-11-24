#!/bin/bash
exec bash "$(cd "$(dirname "$0")/../.." && pwd)/linux/drive-tools.sh" "$@"
