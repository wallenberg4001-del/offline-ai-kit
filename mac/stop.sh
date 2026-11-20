#!/bin/bash
# Stops everything the kit started (never touches a normal Ollama on port 11434).
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_dirs
if programs_missing; then missing_program_message "$PLATFORM_ID"; fi
say "Stopping the Offline AI Kit..."
for n in kiwix ollama chat-server add-libraries add-maps wiki-download; do stop_kit "$n"; done
ok "Stopped. (A partly downloaded Wikipedia is kept and resumes next time you start.)"
pause_exit 0
