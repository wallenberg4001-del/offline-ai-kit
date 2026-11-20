#!/bin/bash
# EASY INSTALL for Linux: no questions. In a terminal:
#   bash "/path/to/EASY-INSTALL (Linux).sh"
# Maps stay off unless you run SETUP-LINUX.sh and choose them.
exec bash "$(cd "$(dirname "$0")" && pwd)/linux/setup.sh" --easy "$@"
