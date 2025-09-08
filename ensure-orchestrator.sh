#!/usr/bin/env bash
set -euo pipefail

ORCH="automation/tmux/scripts/orchestrator/t-max-init.sh"
GUARD="automation/tmux/scripts/guardian/claude-guardian.sh"

if ! command -v tmux >/dev/null 2>&1 ; then
  echo "[ERROR] tmux not installed."
  exit 2
fi

[ -x "$GUARD" ] && bash "$GUARD" || true
bash "$ORCH"