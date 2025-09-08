# 24/7 Claude Flow / Claude Code Orchestration (tmux-based)
# Drop this Makefile into your repo root.

REPO_ROOT := $(shell pwd)

# Paths inside the repo
ORCH := automation/tmux/scripts/orchestrator/t-max-init.sh
GUARD := automation/tmux/scripts/guardian/claude-guardian.sh
DASH  := automation/tmux/scripts/monitoring/claude-dashboard.sh

# Primary tmux session name used by t-max-init.sh
SESSION ?= CLAUDE_MAIN

.PHONY: up down attach status dashboard logs guard mac-load mac-unload

up:
	@bash $(ORCH)

down:
	@-tmux kill-session -t $(SESSION) 2>/dev/null || true
	@echo "Stopped tmux session $(SESSION)."

attach:
	@tmux attach -t $(SESSION) || (echo "No session $(SESSION). Run 'make up' first." && exit 1)

status:
	@tmux list-sessions || echo "No tmux sessions."

dashboard:
	@bash $(DASH)

guard:
	@bash $(GUARD)

logs:
	@ls -lah automation/tmux/logs || true

# macOS launchd helpers
mac-load:
	@echo "Loading macOS LaunchAgent..."
	@launchctl unload ~/Library/LaunchAgents/com.cybernetic.claude-orchestrator.plist 2>/dev/null || true
	@launchctl load ~/Library/LaunchAgents/com.cybernetic.claude-orchestrator.plist
	@launchctl start com.cybernetic.claude-orchestrator
	@echo "Orchestrator loaded and started."

mac-unload:
	@echo "Unloading macOS LaunchAgent..."
	@launchctl stop com.cybernetic.claude-orchestrator 2>/dev/null || true
	@launchctl unload ~/Library/LaunchAgents/com.cybernetic.claude-orchestrator.plist 2>/dev/null || true
	@echo "Orchestrator stopped and unloaded."

mac-status:
	@launchctl list | grep claude-orchestrator || echo "LaunchAgent not loaded"
	@echo "--- Output Log ---"
	@tail -10 /tmp/claude-orchestrator.out.log 2>/dev/null || echo "No output log"
	@echo "--- Error Log ---"
	@tail -10 /tmp/claude-orchestrator.err.log 2>/dev/null || echo "No error log"