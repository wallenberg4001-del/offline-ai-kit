#!/bin/bash
# Setup Wizard for Linux. Questions are the same as SETUP-MAC.command, including optional maps.
exec bash "$(cd "$(dirname "$0")" && pwd)/linux/setup.sh" "$@"
