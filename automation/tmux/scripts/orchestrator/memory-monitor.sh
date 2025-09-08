#!/bin/bash
# Memory Usage Monitor for T-Max Orchestrator
# Real-time memory profiling and leak detection

set -euo pipefail

MONITOR_DURATION=${1:-60}  # Duration in seconds
SAMPLE_INTERVAL=${2:-1}    # Sample interval in seconds
OUTPUT_DIR="/tmp/memory-monitor-$(date +%s)"

mkdir -p "$OUTPUT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m' 
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Memory Monitor Starting...${NC}"
echo -e "${YELLOW}Duration: ${MONITOR_DURATION}s, Interval: ${SAMPLE_INTERVAL}s${NC}"
echo -e "${YELLOW}Output: $OUTPUT_DIR${NC}"

# CSV header
echo "timestamp,total_memory,tmux_memory,node_memory,process_count,tmux_sessions" > "$OUTPUT_DIR/memory-usage.csv"

# Monitor loop
for ((i=0; i<MONITOR_DURATION; i+=SAMPLE_INTERVAL)); do
    timestamp=$(date +%s)
    
    # Total system memory usage (MB)
    total_mem=$(ps aux | awk 'NR>1 {sum += $6} END {print sum/1024}')
    
    # Tmux memory usage (MB)
    tmux_mem=$(ps aux | grep tmux | grep -v grep | awk '{sum += $6} END {print (sum ? sum/1024 : 0)}')
    
    # Node/NPX memory usage (MB)  
    node_mem=$(ps aux | grep -E "(node|npx)" | grep -v grep | awk '{sum += $6} END {print (sum ? sum/1024 : 0)}')
    
    # Process count
    process_count=$(ps aux | grep -E "(tmux|claude|node|npx)" | grep -v grep | wc -l)
    
    # Tmux session count
    session_count=$(tmux list-sessions 2>/dev/null | wc -l || echo "0")
    
    # Log to CSV
    echo "$timestamp,$total_mem,$tmux_mem,$node_mem,$process_count,$session_count" >> "$OUTPUT_DIR/memory-usage.csv"
    
    # Display current stats
    printf "\r${GREEN}[%3ds]${NC} Total: %6.1fMB | Tmux: %6.1fMB | Node: %6.1fMB | Procs: %3d | Sessions: %2d" \
           $i "$total_mem" "$tmux_mem" "$node_mem" "$process_count" "$session_count"
    
    sleep $SAMPLE_INTERVAL
done

echo -e "\n${GREEN}✓ Memory monitoring complete${NC}"
echo -e "${BLUE}Results saved to: $OUTPUT_DIR/memory-usage.csv${NC}"

# Generate summary
python3 << EOF
import csv
import statistics

data = []
with open('$OUTPUT_DIR/memory-usage.csv', 'r') as f:
    reader = csv.DictReader(f)
    data = list(reader)

if data:
    total_mem = [float(row['total_memory']) for row in data]
    tmux_mem = [float(row['tmux_memory']) for row in data]
    node_mem = [float(row['node_memory']) for row in data]
    
    print(f"\n${YELLOW}Memory Usage Summary:${NC}")
    print(f"  Total Memory - Avg: {statistics.mean(total_mem):.1f}MB, Max: {max(total_mem):.1f}MB")
    print(f"  Tmux Memory  - Avg: {statistics.mean(tmux_mem):.1f}MB, Max: {max(tmux_mem):.1f}MB") 
    print(f"  Node Memory  - Avg: {statistics.mean(node_mem):.1f}MB, Max: {max(node_mem):.1f}MB")
    
    # Check for memory growth (potential leak)
    if len(total_mem) > 10:
        first_half_avg = statistics.mean(total_mem[:len(total_mem)//2])
        second_half_avg = statistics.mean(total_mem[len(total_mem)//2:])
        growth_rate = ((second_half_avg - first_half_avg) / first_half_avg) * 100
        
        if growth_rate > 5:
            print(f"  ${RED}⚠️  Potential memory leak detected: {growth_rate:.1f}% growth${NC}")
        else:
            print(f"  ${GREEN}✓ Memory usage stable (growth: {growth_rate:.1f}%)${NC}")
EOF