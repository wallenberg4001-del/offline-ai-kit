#!/bin/bash
exec bash "$(cd "$(dirname "$0")/../.." && pwd)/STATUS-MAC.command" "$@"
