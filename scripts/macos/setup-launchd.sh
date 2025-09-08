#!/usr/bin/env bash
# Setup script for macOS LaunchAgent
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLIST_SRC="$REPO_ROOT/config/launchd/com.cybernetic.claude-orchestrator.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.cybernetic.claude-orchestrator.plist"

echo "Setting up Claude Orchestrator LaunchAgent..."

# Ensure LaunchAgents directory exists
mkdir -p "$HOME/Library/LaunchAgents"

# Copy plist to LaunchAgents directory
cp "$PLIST_SRC" "$PLIST_DST"

# Update working directory in plist to absolute path
sed -i '' "s|/Users/speed/Downloads/experiments|$REPO_ROOT|g" "$PLIST_DST"

echo "LaunchAgent plist copied to: $PLIST_DST"
echo ""
echo "To start the orchestrator:"
echo "  make mac-load"
echo ""
echo "To stop the orchestrator:"
echo "  make mac-unload"
echo ""
echo "To check status:"
echo "  make mac-status"