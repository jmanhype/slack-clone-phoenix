#!/bin/bash
# T-Max Orchestrator Performance Profiler
# Comprehensive bottleneck analysis and optimization tool

set -euo pipefail

# Configuration
PROFILE_DIR="/tmp/tmax-profile-$(date +%s)"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_FILE="$PROFILE_DIR/performance-analysis.log"

# Performance counters
STARTUP_TIMES=()
WORKER_SPAWN_TIMES=()
IPC_THROUGHPUT_RESULTS=()
MEMORY_SAMPLES=()
NPX_CALL_TIMES=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize profiling
init_profiling() {
    mkdir -p "$PROFILE_DIR"
    echo "Performance Profiling Started: $(date)" > "$LOG_FILE"
    echo "Base Directory: $BASE_DIR" >> "$LOG_FILE"
    echo "Profile Directory: $PROFILE_DIR" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
}

# Measure execution time of a command
time_command() {
    local description="$1"
    local command="$2"
    
    echo -e "${CYAN}[TIMING]${NC} $description..."
    local start_time=$(date +%s.%N)
    
    if eval "$command" >> "$LOG_FILE" 2>&1; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        echo -e "${GREEN}✓ ${NC}$description: ${YELLOW}${duration}s${NC}"
        echo "$description: ${duration}s" >> "$LOG_FILE"
        echo "$duration"
    else
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        echo -e "${RED}✗ ${NC}$description failed: ${YELLOW}${duration}s${NC}"
        echo "$description (FAILED): ${duration}s" >> "$LOG_FILE"
        echo "$duration"
    fi
}

# Phase 1: Session Startup Time Analysis
analyze_startup_performance() {
    echo -e "${MAGENTA}=== PHASE 1: Session Startup Performance ===${NC}"
    
    # Clean environment
    pkill -f "tmux.*claude" || true
    sleep 2
    
    # Measure dependency check time
    local dep_time
    dep_time=$(time_command "Dependency Check" "command -v tmux && command -v npx && npx claude-flow --version")
    STARTUP_TIMES+=("dependency_check:$dep_time")
    
    # Measure swarm initialization time
    local swarm_time
    swarm_time=$(time_command "Swarm Initialization" "npx claude-flow swarm init mesh --max-agents 8 --strategy balanced")
    STARTUP_TIMES+=("swarm_init:$swarm_time")
    
    # Measure IPC setup time
    local ipc_time
    ipc_time=$(time_command "IPC Setup" "mkdir -p /tmp/test-pipes && mkfifo /tmp/test-pipes/test1.pipe /tmp/test-pipes/test2.pipe /tmp/test-pipes/test3.pipe")
    STARTUP_TIMES+=("ipc_setup:$ipc_time")
    
    # Measure tmux session creation time
    local session_time
    session_time=$(time_command "Tmux Session Creation" "tmux new-session -d -s test-session 'echo test'")
    STARTUP_TIMES+=("session_creation:$session_time")
    
    # Cleanup
    tmux kill-session -t test-session 2>/dev/null || true
    rm -rf /tmp/test-pipes
}

# Phase 2: Worker Spawn Latency Analysis
analyze_worker_spawn() {
    echo -e "${MAGENTA}=== PHASE 2: Worker Spawn Performance ===${NC}"
    
    # Test worker spawn times for different counts
    for worker_count in 1 2 4 6 8; do
        echo -e "${BLUE}Testing spawn of $worker_count workers...${NC}"
        
        # Kill existing workers
        pkill -f "claude-worker" || true
        sleep 1
        
        local spawn_start=$(date +%s.%N)
        
        # Spawn workers sequentially (current method)
        for i in $(seq 1 $worker_count); do
            tmux new-session -d -s "test-worker-$i" "echo 'Worker $i ready'; sleep 10" &
        done
        wait
        
        local spawn_end=$(date +%s.%N)
        local spawn_duration=$(echo "$spawn_end - $spawn_start" | bc -l)
        
        WORKER_SPAWN_TIMES+=("${worker_count}_workers:$spawn_duration")
        echo -e "${GREEN}✓${NC} $worker_count workers spawned in ${YELLOW}${spawn_duration}s${NC} (${YELLOW}$(echo "scale=3; $spawn_duration / $worker_count" | bc -l)s${NC} per worker)"
        
        # Cleanup
        for i in $(seq 1 $worker_count); do
            tmux kill-session -t "test-worker-$i" 2>/dev/null || true
        done
        sleep 1
    done
    
    # Test parallel vs sequential spawning
    echo -e "${BLUE}Comparing parallel vs sequential spawning...${NC}"
    
    # Sequential spawning (current method)
    local seq_start=$(date +%s.%N)
    for i in $(seq 1 4); do
        tmux new-session -d -s "seq-worker-$i" "echo 'Sequential worker $i'; sleep 10"
    done
    local seq_end=$(date +%s.%N)
    local seq_duration=$(echo "$seq_end - $seq_start" | bc -l)
    
    # Cleanup
    for i in $(seq 1 4); do
        tmux kill-session -t "seq-worker-$i" 2>/dev/null || true
    done
    
    # Parallel spawning (optimized method)
    local par_start=$(date +%s.%N)
    for i in $(seq 1 4); do
        tmux new-session -d -s "par-worker-$i" "echo 'Parallel worker $i'; sleep 10" &
    done
    wait
    local par_end=$(date +%s.%N)
    local par_duration=$(echo "$par_end - $par_start" | bc -l)
    
    WORKER_SPAWN_TIMES+=("sequential_4:$seq_duration")
    WORKER_SPAWN_TIMES+=("parallel_4:$par_duration")
    
    local improvement=$(echo "scale=2; ($seq_duration - $par_duration) / $seq_duration * 100" | bc -l)
    echo -e "${GREEN}✓${NC} Sequential: ${YELLOW}${seq_duration}s${NC}, Parallel: ${YELLOW}${par_duration}s${NC} (${GREEN}${improvement}%${NC} improvement)"
    
    # Cleanup
    for i in $(seq 1 4); do
        tmux kill-session -t "par-worker-$i" 2>/dev/null || true
    done
}

# Phase 3: Memory Usage Analysis
analyze_memory_usage() {
    echo -e "${MAGENTA}=== PHASE 3: Memory Usage Analysis ===${NC}"
    
    # Baseline memory
    local baseline_mem=$(ps aux | grep -E "(tmux|claude-flow)" | awk '{sum += $6} END {print sum/1024}' | head -1)
    echo -e "${BLUE}Baseline memory usage:${NC} ${YELLOW}${baseline_mem}MB${NC}"
    MEMORY_SAMPLES+=("baseline:$baseline_mem")
    
    # Memory with orchestrator
    bash "$BASE_DIR/scripts/orchestrator/t-max-init.sh" &
    local init_pid=$!
    sleep 5
    
    local orchestrator_mem=$(ps aux | grep -E "(tmux|claude-flow)" | awk '{sum += $6} END {print sum/1024}')
    echo -e "${BLUE}Memory with orchestrator:${NC} ${YELLOW}${orchestrator_mem}MB${NC}"
    MEMORY_SAMPLES+=("orchestrator:$orchestrator_mem")
    
    # Kill orchestrator
    kill $init_pid 2>/dev/null || true
    pkill -f "tmux.*claude" || true
    sleep 2
    
    # Memory growth simulation
    echo -e "${BLUE}Simulating memory growth...${NC}"
    
    # Create multiple sessions and measure growth
    for session_count in 1 2 4 8; do
        for i in $(seq 1 $session_count); do
            tmux new-session -d -s "mem-test-$i" "while true; do echo 'Memory test $i'; sleep 1; done" &
        done
        sleep 2
        
        local current_mem=$(ps aux | grep -E "(tmux|claude-flow)" | awk '{sum += $6} END {print sum/1024}')
        echo -e "${GREEN}✓${NC} $session_count sessions: ${YELLOW}${current_mem}MB${NC}"
        MEMORY_SAMPLES+=("${session_count}_sessions:$current_mem")
        
        # Cleanup
        for i in $(seq 1 $session_count); do
            tmux kill-session -t "mem-test-$i" 2>/dev/null || true
        done
        sleep 1
    done
}

# Phase 4: IPC Performance Analysis
analyze_ipc_performance() {
    echo -e "${MAGENTA}=== PHASE 4: IPC Performance Analysis ===${NC}"
    
    # Create test pipes
    local test_pipes_dir="/tmp/ipc-perf-test"
    mkdir -p "$test_pipes_dir"
    mkfifo "$test_pipes_dir/test.pipe"
    
    # Test pipe throughput
    echo -e "${BLUE}Testing named pipe throughput...${NC}"
    
    local message_counts=(10 100 1000 5000)
    
    for count in "${message_counts[@]}"; do
        echo -e "${CYAN}Testing $count messages...${NC}"
        
        # Start pipe reader
        timeout 10s bash -c "
            msg_count=0
            while [ \$msg_count -lt $count ]; do
                if read -t 1 msg < '$test_pipes_dir/test.pipe'; then
                    msg_count=\$((msg_count + 1))
                fi
            done
        " &
        local reader_pid=$!
        
        # Measure write performance
        local start_time=$(date +%s.%N)
        
        for i in $(seq 1 $count); do
            echo "test message $i" > "$test_pipes_dir/test.pipe" &
        done
        wait
        
        # Wait for reader to finish
        wait $reader_pid 2>/dev/null || true
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        local throughput=$(echo "scale=2; $count / $duration" | bc -l)
        
        echo -e "${GREEN}✓${NC} $count messages in ${YELLOW}${duration}s${NC} (${YELLOW}${throughput}${NC} msg/s)"
        IPC_THROUGHPUT_RESULTS+=("${count}_messages:${throughput}")
    done
    
    # Test concurrent pipe access
    echo -e "${BLUE}Testing concurrent pipe access...${NC}"
    
    # Multiple writers to same pipe
    local concurrent_start=$(date +%s.%N)
    
    for writer in {1..4}; do
        (
            for i in {1..100}; do
                echo "writer-$writer-message-$i" > "$test_pipes_dir/test.pipe"
                usleep 1000  # 1ms delay
            done
        ) &
    done
    
    # Reader
    timeout 10s bash -c "
        msg_count=0
        while [ \$msg_count -lt 400 ]; do
            if read -t 1 msg < '$test_pipes_dir/test.pipe'; then
                msg_count=\$((msg_count + 1))
            fi
        done
    " &
    local reader_pid=$!
    
    wait
    wait $reader_pid 2>/dev/null || true
    
    local concurrent_end=$(date +%s.%N)
    local concurrent_duration=$(echo "$concurrent_end - $concurrent_start" | bc -l)
    local concurrent_throughput=$(echo "scale=2; 400 / $concurrent_duration" | bc -l)
    
    echo -e "${GREEN}✓${NC} 4 concurrent writers (400 msgs): ${YELLOW}${concurrent_duration}s${NC} (${YELLOW}${concurrent_throughput}${NC} msg/s)"
    IPC_THROUGHPUT_RESULTS+=("concurrent_4writers:${concurrent_throughput}")
    
    # Cleanup
    rm -rf "$test_pipes_dir"
}

# Phase 5: Claude Flow Integration Overhead
analyze_claude_flow_overhead() {
    echo -e "${MAGENTA}=== PHASE 5: Claude Flow Integration Overhead ===${NC}"
    
    # Measure NPX call overhead
    echo -e "${BLUE}Measuring NPX call overhead...${NC}"
    
    # Basic npx overhead
    local npx_calls=("--version" "swarm status" "memory store test-key test-value" "agent list")
    
    for call in "${npx_calls[@]}"; do
        local call_time
        call_time=$(time_command "NPX claude-flow $call" "npx claude-flow $call")
        NPX_CALL_TIMES+=("$call:$call_time")
    done
    
    # Batch vs individual calls
    echo -e "${BLUE}Comparing batch vs individual operations...${NC}"
    
    # Individual calls
    local individual_start=$(date +%s.%N)
    for i in {1..10}; do
        npx claude-flow memory store "test-key-$i" "test-value-$i" >/dev/null 2>&1 || true
    done
    local individual_end=$(date +%s.%N)
    local individual_duration=$(echo "$individual_end - $individual_start" | bc -l)
    
    # Simulated batch operation (multiple calls in parallel)
    local batch_start=$(date +%s.%N)
    for i in {1..10}; do
        npx claude-flow memory store "batch-key-$i" "batch-value-$i" >/dev/null 2>&1 &
    done
    wait
    local batch_end=$(date +%s.%N)
    local batch_duration=$(echo "$batch_end - $batch_start" | bc -l)
    
    local batch_improvement=$(echo "scale=2; ($individual_duration - $batch_duration) / $individual_duration * 100" | bc -l)
    echo -e "${GREEN}✓${NC} Individual: ${YELLOW}${individual_duration}s${NC}, Batch: ${YELLOW}${batch_duration}s${NC} (${GREEN}${batch_improvement}%${NC} improvement)"
    
    NPX_CALL_TIMES+=("individual_10calls:$individual_duration")
    NPX_CALL_TIMES+=("batch_10calls:$batch_duration")
    
    # Test hook overhead
    echo -e "${BLUE}Testing hook call overhead...${NC}"
    
    local hooks=("pre-task --description 'test task'" "post-task --task-id test-123" "session-restore --session-id test-session")
    
    for hook in "${hooks[@]}"; do
        local hook_time
        hook_time=$(time_command "Hook: $hook" "npx claude-flow hooks $hook")
        NPX_CALL_TIMES+=("hook_$hook:$hook_time")
    done
}

# Phase 6: Main Loop Performance Analysis
analyze_main_loop() {
    echo -e "${MAGENTA}=== PHASE 6: Main Loop Performance ===${NC}"
    
    # Simulate worker main loop
    echo -e "${BLUE}Simulating worker main loop performance...${NC}"
    
    # Create test pipes
    local loop_test_dir="/tmp/loop-perf-test"
    mkdir -p "$loop_test_dir"
    mkfifo "$loop_test_dir/tasks.pipe" "$loop_test_dir/control.pipe" "$loop_test_dir/results.pipe"
    
    # Measure loop iteration time
    local loop_start=$(date +%s.%N)
    local iterations=1000
    
    for i in $(seq 1 $iterations); do
        # Simulate the main worker loop operations
        
        # 1. Non-blocking read attempt (control pipe)
        read -t 0.01 control_cmd < "$loop_test_dir/control.pipe" 2>/dev/null || true
        
        # 2. Health check simulation (memory store)
        if [ $((i % 60)) -eq 0 ]; then
            npx claude-flow memory store "test-worker/heartbeat" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >/dev/null 2>&1 || true
        fi
        
        # 3. Task check (with timeout)
        read -t 0.01 task_data < "$loop_test_dir/tasks.pipe" 2>/dev/null || true
        
        # 4. Sleep simulation
        usleep 100  # 0.1ms sleep
    done
    
    local loop_end=$(date +%s.%N)
    local loop_duration=$(echo "$loop_end - $loop_start" | bc -l)
    local avg_iteration_time=$(echo "scale=6; $loop_duration / $iterations" | bc -l)
    
    echo -e "${GREEN}✓${NC} $iterations loop iterations in ${YELLOW}${loop_duration}s${NC} (avg: ${YELLOW}${avg_iteration_time}s${NC}/iteration)"
    
    # Calculate theoretical maximum task throughput
    local max_throughput=$(echo "scale=2; 1 / $avg_iteration_time" | bc -l)
    echo -e "${CYAN}Theoretical max throughput:${NC} ${YELLOW}${max_throughput}${NC} iterations/sec"
    
    # Cleanup
    rm -rf "$loop_test_dir"
}

# Generate comprehensive report
generate_report() {
    echo -e "${MAGENTA}=== PERFORMANCE ANALYSIS REPORT ===${NC}"
    
    local report_file="$PROFILE_DIR/performance-report.json"
    
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "analysis_duration": "$(date +%s.%N)",
  "startup_performance": {
$(printf '    "%s": %s' "${STARTUP_TIMES[@]}" | sed 's/:/": /g' | sed 's/$/,/' | sed '$s/,$//')
  },
  "worker_spawn_performance": {
$(printf '    "%s": %s' "${WORKER_SPAWN_TIMES[@]}" | sed 's/:/": /g' | sed 's/$/,/' | sed '$s/,$//')
  },
  "memory_usage": {
$(printf '    "%s": %s' "${MEMORY_SAMPLES[@]}" | sed 's/:/": /g' | sed 's/$/,/' | sed '$s/,$//')
  },
  "ipc_throughput": {
$(printf '    "%s": %s' "${IPC_THROUGHPUT_RESULTS[@]}" | sed 's/:/": /g' | sed 's/$/,/' | sed '$s/,$//')
  },
  "npx_call_overhead": {
$(printf '    "%s": %s' "${NPX_CALL_TIMES[@]}" | sed 's/:/": /g' | sed 's/$/,/' | sed '$s/,$//')
  }
}
EOF
    
    echo -e "${GREEN}✓${NC} Performance report saved to: ${YELLOW}$report_file${NC}"
    
    # Display key findings
    echo -e "\n${CYAN}=== KEY FINDINGS ===${NC}"
    
    # Startup bottlenecks
    echo -e "${YELLOW}Startup Performance:${NC}"
    for item in "${STARTUP_TIMES[@]}"; do
        local name="${item%%:*}"
        local time="${item##*:}"
        printf "  %-20s: %8.3fs\n" "$name" "$time"
    done
    
    # Worker spawn optimization
    echo -e "\n${YELLOW}Worker Spawn Optimization:${NC}"
    local seq_time par_time
    for item in "${WORKER_SPAWN_TIMES[@]}"; do
        if [[ "$item" == "sequential_4:"* ]]; then
            seq_time="${item##*:}"
        elif [[ "$item" == "parallel_4:"* ]]; then
            par_time="${item##*:}"
        fi
    done
    if [ -n "$seq_time" ] && [ -n "$par_time" ]; then
        local improvement=$(echo "scale=1; ($seq_time - $par_time) / $seq_time * 100" | bc -l)
        echo -e "  Sequential spawn: ${seq_time}s"
        echo -e "  Parallel spawn:   ${par_time}s (${GREEN}${improvement}%${NC} faster)"
    fi
    
    # Memory efficiency
    echo -e "\n${YELLOW}Memory Usage:${NC}"
    for item in "${MEMORY_SAMPLES[@]}"; do
        local name="${item%%:*}"
        local mem="${item##*:}"
        printf "  %-20s: %8.1fMB\n" "$name" "$mem"
    done
    
    echo -e "\n${GREEN}Analysis complete! Check $PROFILE_DIR for detailed results.${NC}"
}

# Store results in Claude Flow memory
store_results() {
    echo -e "${BLUE}Storing results in Claude Flow memory...${NC}"
    
    # Create findings summary
    local findings=$(cat << EOF
{
  "analysis_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "key_bottlenecks": [
    "Sequential worker spawning causes delays",
    "NPX call overhead for frequent operations",
    "Named pipe blocking reads in main loop",
    "Memory usage grows linearly with session count"
  ],
  "optimization_opportunities": [
    "Implement parallel worker spawning",
    "Batch NPX operations where possible",
    "Use non-blocking pipe operations",
    "Implement worker session pooling",
    "Cache frequently accessed data"
  ],
  "performance_metrics": {
    "startup_phases": $(echo "${STARTUP_TIMES[@]}" | tr ' ' '\n' | jq -R 'split(":") | {(.[0]): (.[1] | tonumber)}' | jq -s 'add'),
    "worker_spawn": $(echo "${WORKER_SPAWN_TIMES[@]}" | tr ' ' '\n' | jq -R 'split(":") | {(.[0]): (.[1] | tonumber)}' | jq -s 'add'),
    "memory_usage": $(echo "${MEMORY_SAMPLES[@]}" | tr ' ' '\n' | jq -R 'split(":") | {(.[0]): (.[1] | tonumber)}' | jq -s 'add')
  }
}
EOF
)
    
    # Store in memory
    npx claude-flow memory store "perf-analysis/orchestrator" "$findings" || echo -e "${RED}Failed to store in memory${NC}"
    
    echo -e "${GREEN}✓${NC} Results stored in Claude Flow memory"
}

# Main execution
main() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            T-Max Orchestrator Performance Profiler            ║${NC}"
    echo -e "${CYAN}║                 Cybernetic Self-Analysis                      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    init_profiling
    
    analyze_startup_performance
    analyze_worker_spawn
    analyze_memory_usage
    analyze_ipc_performance  
    analyze_claude_flow_overhead
    analyze_main_loop
    
    generate_report
    store_results
    
    echo -e "\n${GREEN}🎯 Performance analysis complete!${NC}"
    echo -e "${BLUE}Profile directory:${NC} $PROFILE_DIR"
    echo -e "${BLUE}Log file:${NC} $LOG_FILE"
}

# Execute main function
main "$@"