#!/bin/bash
# Linux stop. Based on mac/stop.sh. Pid files are *.linux.pid so a shared USB
# does not confuse a Mac process with a Linux one.
export OFFLINE_AI_OS=linux
exec bash "$(cd "$(dirname "$0")/.." && pwd)/mac/stop.sh" "$@"
