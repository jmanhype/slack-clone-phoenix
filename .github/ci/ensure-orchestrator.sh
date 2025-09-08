#!/usr/bin/env bash
set -euo pipefail

# Ensures the tmux-based orchestrator is up on a runner.
# Intended to run from repo root (CI checkout dir).

ORCH="automation/tmux/scripts/orchestrator/t-max-init.sh"
GUARD="automation/tmux/scripts/guardian/claude-guardian.sh"

if ! command -v tmux >/dev/null 2>&1 ; then
  echo "[ERROR] tmux not installed on this runner."
  exit 2
fi

# Try guardian first (session recovery), then init if nothing exists.
if [ -x "$GUARD" ]; then
  echo "[INFO] Running guardian (session recovery)…"
  bash "$GUARD" || true
fi

echo "[INFO] Ensuring orchestrator is up…"
bash "$ORCH"
echo "[OK] Orchestrator ensured."