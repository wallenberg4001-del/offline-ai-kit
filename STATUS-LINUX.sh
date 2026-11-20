#!/bin/bash
exec bash "$(cd "$(dirname "$0")" && pwd)/linux/status.sh" "$@"
