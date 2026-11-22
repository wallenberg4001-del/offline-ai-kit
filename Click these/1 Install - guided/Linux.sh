#!/bin/bash
# Guided installer. Opens a browser and explains every choice before anything downloads.
cd "$(dirname "$0")/../.." || exit 1
export OFFLINE_AI_OS=linux
exec perl "$(pwd)/mac/install-gui.pl"
