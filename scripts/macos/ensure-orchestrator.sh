#!/usr/bin/env bash
# 24/7 Claude Flow/Code orchestrator for macOS via launchd + tmux
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SESSION="${SESSION:-CLAUDE_MAIN}"
ORCH="automation/tmux/scripts/orchestrator/t-max-init.sh"
GUARD="automation/tmux/scripts/guardian/claude-guardian.sh"

# keep the Mac awake while this agent runs
# (caffeinate exits when this script exits)
if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -dimsu -w $$ &
fi

# sanity
command -v tmux >/dev/null 2>&1 || { echo "[ERR] tmux missing"; exit 2; }

# heal if session exists; then ensure orchestrator is up
[ -x "$GUARD" ] && bash "$GUARD" || true
bash "$ORCH"

# optional: tail orchestrator logs for visibility (non-fatal if missing)
[ -f automation/tmux/logs/orchestrator.log ] && tail -F automation/tmux/logs/orchestrator.log || sleep infinity