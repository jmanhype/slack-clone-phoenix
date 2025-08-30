#!/bin/bash

# Quick status commute script

echo "🔍 SYSTEM STATUS $(date)"
echo "==============================="

# Check MCP servers
echo -e "\n📡 MCP SERVERS:"
ps aux | grep -E "(claude-flow|ruv-swarm|flow-nexus|zen-mcp|task-master)" | grep mcp | grep -v grep | while IFS= read -r line; do
    echo "  ✅ $(echo "$line" | awk '{print $11}' | xargs basename)"
done

# Check ports
echo -e "\n🌐 ACTIVE PORTS:"
lsof -i :3000,8000,8080,9000 2>/dev/null | tail -n +2 | while IFS= read -r line; do
    echo "  🔌 $(echo "$line" | awk '{print $1 " on port " $9}')"
done

# Check git status
echo -e "\n📝 GIT STATUS:"
cd /Users/speed/Downloads/experiments
if git status --porcelain | head -5; then
    echo "  📊 $(git status --porcelain | wc -l | xargs) files modified"
else
    echo "  ✅ Clean working directory"
fi

# Check disk usage
echo -e "\n💾 DISK USAGE:"
df -h . | tail -1 | awk '{print "  📊 " $5 " used (" $4 " available)"}'

# Check memory
echo -e "\n🧠 MEMORY:"
vm_stat | head -4 | while IFS= read -r line; do
    echo "  📊 $line"
done

echo -e "\n✅ Status check complete"