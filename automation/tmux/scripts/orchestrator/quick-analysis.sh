#!/bin/bash
# Quick Performance Analysis for T-Max Orchestrator
# Rapid bottleneck identification and metrics collection

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔍 Quick Performance Analysis - T-Max Orchestrator${NC}"
echo "================================================"

# 1. NPX Call Overhead Analysis
echo -e "\n${YELLOW}📊 NPX Call Overhead Analysis:${NC}"

measure_npx_call() {
    local command="$1"
    local start_time=$(date +%s.%N)
    npx claude-flow $command >/dev/null 2>&1 || true
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    printf "  %-25s: %6.3fs\n" "$command" "$duration"
    echo "$duration"
}

# Test key NPX operations
echo -e "${BLUE}Testing NPX command overhead:${NC}"
version_time=$(measure_npx_call "--version")
swarm_time=$(measure_npx_call "swarm status")
memory_time=$(measure_npx_call "memory store test-key test-value")
agent_time=$(measure_npx_call "agent list")

# Calculate average
avg_npx_time=$(echo "scale=3; ($version_time + $swarm_time + $memory_time + $agent_time) / 4" | bc -l 2>/dev/null || echo "0.5")
echo -e "${GREEN}Average NPX call time: ${avg_npx_time}s${NC}"

# 2. Tmux Session Creation Performance
echo -e "\n${YELLOW}🖥️  Tmux Session Performance:${NC}"

test_session_creation() {
    local session_name="perf-test-$(date +%s)"
    local start_time=$(date +%s.%N)
    
    tmux new-session -d -s "$session_name" "echo 'Test session'; sleep 1"
    tmux split-window -t "$session_name" -h "echo 'Split pane'; sleep 1"
    tmux split-window -t "$session_name" -v "echo 'Another split'; sleep 1"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    # Cleanup
    tmux kill-session -t "$session_name" 2>/dev/null || true
    
    echo "$duration"
}

session_time=$(test_session_creation)
echo -e "${BLUE}Tmux session (3-pane) creation:${NC} ${session_time}s"

# 3. Named Pipe Performance Test
echo -e "\n${YELLOW}📡 Named Pipe Performance:${NC}"

test_pipe_performance() {
    local pipe_file="/tmp/perf-test-pipe-$$"
    mkfifo "$pipe_file"
    
    local message_count=100
    
    # Background reader
    (
        local count=0
        local start_time=$(date +%s.%N)
        while [ $count -lt $message_count ]; do
            if read line < "$pipe_file" 2>/dev/null; then
                count=$((count + 1))
            fi
        done
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
        local throughput=$(echo "scale=1; $message_count / $duration" | bc -l 2>/dev/null || echo "100")
        echo "$throughput" > "/tmp/pipe-throughput-$$"
    ) &
    
    local reader_pid=$!
    sleep 0.1
    
    # Writer
    local write_start=$(date +%s.%N)
    for i in $(seq 1 $message_count); do
        echo "Test message $i" > "$pipe_file"
    done
    local write_end=$(date +%s.%N)
    
    wait $reader_pid 2>/dev/null || true
    
    local write_duration=$(echo "$write_end - $write_start" | bc -l 2>/dev/null || echo "1")
    local write_throughput=$(echo "scale=1; $message_count / $write_duration" | bc -l 2>/dev/null || echo "100")
    
    local read_throughput="100"
    if [ -f "/tmp/pipe-throughput-$$" ]; then
        read_throughput=$(cat "/tmp/pipe-throughput-$$")
        rm -f "/tmp/pipe-throughput-$$"
    fi
    
    echo -e "${BLUE}Pipe write throughput:${NC} ${write_throughput} msg/s"
    echo -e "${BLUE}Pipe read throughput:${NC}  ${read_throughput} msg/s"
    
    rm -f "$pipe_file"
    
    echo "$write_throughput,$read_throughput"
}

pipe_results=$(test_pipe_performance)
pipe_write=$(echo "$pipe_results" | cut -d, -f1)
pipe_read=$(echo "$pipe_results" | cut -d, -f2)

# 4. Memory Usage Snapshot
echo -e "\n${YELLOW}💾 Memory Usage Analysis:${NC}"

get_memory_usage() {
    local process_pattern="$1"
    local memory=$(ps aux | grep -E "$process_pattern" | grep -v grep | awk '{sum += $6} END {print (sum ? sum/1024 : 0)}')
    echo "$memory"
}

baseline_mem=$(get_memory_usage "bash")
tmux_mem=$(get_memory_usage "tmux")
node_mem=$(get_memory_usage "(node|npx)")

echo -e "${BLUE}Current memory usage:${NC}"
printf "  %-15s: %8.1fMB\n" "Baseline (bash)" "$baseline_mem"
printf "  %-15s: %8.1fMB\n" "Tmux processes" "$tmux_mem" 
printf "  %-15s: %8.1fMB\n" "Node/NPX" "$node_mem"

total_mem=$(echo "$baseline_mem + $tmux_mem + $node_mem" | bc -l 2>/dev/null || echo "100")
echo -e "${BLUE}Total tracked:${NC} ${total_mem}MB"

# 5. Worker Loop Simulation
echo -e "\n${YELLOW}🔄 Worker Loop Performance:${NC}"

simulate_worker_loop() {
    local iterations=100
    local start_time=$(date +%s.%N)
    
    local pipe_file="/tmp/worker-sim-$$"
    mkfifo "$pipe_file"
    
    # Simulate main worker loop
    for i in $(seq 1 $iterations); do
        # Non-blocking read attempt (simulate control check)
        read -t 0.01 dummy < "$pipe_file" 2>/dev/null || true
        
        # Simulate memory operation every 10 iterations
        if [ $((i % 10)) -eq 0 ]; then
            npx claude-flow memory store "test-key-$i" "test-value-$i" >/dev/null 2>&1 || true
        fi
        
        # Simulate task check
        read -t 0.01 dummy < "$pipe_file" 2>/dev/null || true
        
        # Small sleep (like real worker)
        usleep 1000  # 1ms
    done
    
    local end_time=$(date +%s.%N)
    local total_duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
    local avg_iteration=$(echo "scale=6; $total_duration / $iterations" | bc -l 2>/dev/null || echo "0.01")
    local max_throughput=$(echo "scale=1; 1 / $avg_iteration" | bc -l 2>/dev/null || echo "100")
    
    rm -f "$pipe_file"
    
    echo -e "${BLUE}Worker loop simulation (${iterations} iterations):${NC}"
    echo -e "  Total time: ${total_duration}s"
    echo -e "  Avg/iteration: ${avg_iteration}s"  
    echo -e "  Max throughput: ${max_throughput} ops/s"
    
    echo "$avg_iteration"
}

loop_time=$(simulate_worker_loop)

# 6. Bottleneck Analysis Summary
echo -e "\n${YELLOW}🚨 Bottleneck Analysis:${NC}"

# Identify the slowest operations
bottlenecks=()

if (( $(echo "$avg_npx_time > 0.5" | bc -l 2>/dev/null) )); then
    bottlenecks+=("NPX calls are slow (${avg_npx_time}s avg)")
fi

if (( $(echo "$session_time > 1.0" | bc -l 2>/dev/null) )); then
    bottlenecks+=("Tmux session creation is slow (${session_time}s)")
fi

if (( $(echo "$pipe_write < 1000" | bc -l 2>/dev/null) )); then
    bottlenecks+=("Named pipe throughput is low (${pipe_write} msg/s)")
fi

if (( $(echo "$total_mem > 1000" | bc -l 2>/dev/null) )); then
    bottlenecks+=("High memory usage (${total_mem}MB)")
fi

if (( $(echo "$loop_time > 0.01" | bc -l 2>/dev/null) )); then
    bottlenecks+=("Worker loop is slow (${loop_time}s/iteration)")
fi

if [ ${#bottlenecks[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ No major bottlenecks detected!${NC}"
else
    echo -e "${RED}⚠️  Bottlenecks identified:${NC}"
    for bottleneck in "${bottlenecks[@]}"; do
        echo -e "  - $bottleneck"
    done
fi

# 7. Optimization Recommendations
echo -e "\n${YELLOW}🎯 Optimization Recommendations:${NC}"

recommendations=()

if (( $(echo "$avg_npx_time > 0.3" | bc -l 2>/dev/null) )); then
    recommendations+=("Cache NPX results and batch operations")
fi

if (( $(echo "$pipe_write < 2000" | bc -l 2>/dev/null) )); then
    recommendations+=("Optimize pipe I/O with non-blocking reads and larger buffers")
fi

if (( $(echo "$session_time > 0.5" | bc -l 2>/dev/null) )); then
    recommendations+=("Pre-create tmux session templates for faster spawning")
fi

if (( $(echo "$loop_time > 0.005" | bc -l 2>/dev/null) )); then
    recommendations+=("Optimize worker loop with better polling strategy")
fi

if [ ${#recommendations[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ Performance looks good!${NC}"
else
    for rec in "${recommendations[@]}"; do
        echo -e "  💡 $rec"
    done
fi

# 8. Generate JSON Report
echo -e "\n${YELLOW}📄 Generating Performance Report...${NC}"

report_file="/tmp/tmax-performance-$(date +%s).json"

cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "performance_metrics": {
    "npx_call_average": $avg_npx_time,
    "tmux_session_creation": $session_time,
    "pipe_write_throughput": $pipe_write,
    "pipe_read_throughput": $pipe_read,
    "worker_loop_iteration": $loop_time,
    "memory_usage": {
      "baseline": $baseline_mem,
      "tmux": $tmux_mem,
      "node": $node_mem,
      "total": $total_mem
    }
  },
  "bottlenecks": [
$(printf '    "%s"' "${bottlenecks[@]}" | sed 's/$/,/' | sed '$s/,$//')
  ],
  "recommendations": [
$(printf '    "%s"' "${recommendations[@]}" | sed 's/$/,/' | sed '$s/,$//')
  ]
}
EOF

echo -e "${GREEN}✅ Report saved to: ${report_file}${NC}"

# Store in Claude Flow memory
findings_json=$(cat "$report_file")
npx claude-flow memory store "perf-analysis/orchestrator" "$findings_json" 2>/dev/null || true

echo -e "\n${GREEN}🎯 Quick performance analysis complete!${NC}"
echo -e "${CYAN}Key findings stored in Claude Flow memory.${NC}"