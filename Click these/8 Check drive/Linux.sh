#!/bin/bash
exec bash "$(cd "$(dirname "$0")/../.." && pwd)/linux/check-drive.sh" "$@"
