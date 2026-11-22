#!/bin/bash
exec bash "$(cd "$(dirname "$0")/../.." && pwd)/STATUS-LINUX.sh" "$@"
