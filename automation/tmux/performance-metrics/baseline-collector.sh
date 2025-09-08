#!/bin/bash
# Performance Baseline Collector for Cybernetic Self-Optimization
# Collects metrics before and after optimizations

set -euo pipefail

METRICS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$METRICS_DIR/.." && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BASELINE_FILE="$METRICS_DIR/baseline-${TIMESTAMP}.json"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[Baseline]${NC} $1"
}

info() {
    echo -e "${BLUE}[Info]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[Warn]${NC} $1"
}

error() {
    echo -e "${RED}[Error]${NC} $1"
}

# Measure orchestrator startup time
measure_startup_time() {
    log "Measuring orchestrator startup time..."
    
    local start_time=$(date +%s.%3N)
    
    # Kill any existing sessions
    tmux kill-server 2>/dev/null || true
    
    # Start orchestrator and wait for readiness
    timeout 60s bash "$BASE_DIR/scripts/orchestrator/t-max-init.sh" &
    local init_pid=$!
    
    # Wait for main session to be created
    local timeout=60
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if tmux has-session -t "claude-main" 2>/dev/null; then
            break
        fi
        sleep 0.1
        elapsed=$(echo "$elapsed + 0.1" | bc)
    done
    
    local end_time=$(date +%s.%3N)
    local startup_time=$(echo "$end_time - $start_time" | bc)
    
    # Clean up
    kill $init_pid 2>/dev/null || true
    
    echo "$startup_time"
}

# Measure worker spawn latency
measure_worker_spawn_latency() {
    log "Measuring worker spawn latency..."
    
    local total_latency=0
    local worker_count=4
    
    for i in $(seq 1 $worker_count); do
        local start_time=$(date +%s.%3N)
        
        # Spawn single worker
        tmux new-session -d -s "test-worker-$i" -n worker
        tmux send-keys -t "test-worker-$i:worker" "echo 'Worker $i ready'" C-m
        
        # Wait for worker to be ready
        local timeout=10
        local elapsed=0
        while [ $elapsed -lt $timeout ]; do
            if tmux capture-pane -t "test-worker-$i:worker" -p | grep -q "Worker $i ready"; then
                break
            fi
            sleep 0.1
            elapsed=$(echo "$elapsed + 0.1" | bc)
        done
        
        local end_time=$(date +%s.%3N)
        local spawn_time=$(echo "$end_time - $start_time" | bc)
        
        total_latency=$(echo "$total_latency + $spawn_time" | bc)
        
        # Clean up
        tmux kill-session -t "test-worker-$i" 2>/dev/null || true
    done
    
    local avg_latency=$(echo "scale=3; $total_latency / $worker_count" | bc)
    echo "$avg_latency"
}

# Measure memory usage patterns
measure_memory_usage() {
    log "Measuring memory usage patterns..."
    
    # Start orchestrator
    bash "$BASE_DIR/scripts/orchestrator/t-max-init.sh" &
    local init_pid=$!
    
    # Wait for startup
    sleep 10
    
    # Collect memory snapshots
    local memory_samples=()
    for i in {1..10}; do
        local memory_mb=$(ps aux | grep -E "(tmux|claude-worker|npx)" | awk '{sum += $6} END {print sum/1024}')
        memory_samples+=($memory_mb)
        sleep 1
    done
    
    # Calculate average
    local total_memory=0
    for mem in "${memory_samples[@]}"; do
        total_memory=$(echo "$total_memory + $mem" | bc)
    done
    local avg_memory=$(echo "scale=2; $total_memory / ${#memory_samples[@]}" | bc)
    
    # Clean up
    kill $init_pid 2>/dev/null || true
    tmux kill-server 2>/dev/null || true
    
    echo "$avg_memory"
}

# Measure CPU utilization
measure_cpu_usage() {
    log "Measuring CPU utilization..."
    
    # Start orchestrator
    bash "$BASE_DIR/scripts/orchestrator/t-max-init.sh" &
    local init_pid=$!
    
    # Wait for startup
    sleep 10
    
    # Collect CPU samples
    local cpu_samples=()
    for i in {1..10}; do
        local cpu_percent=$(ps aux | grep -E "(tmux|claude-worker|npx)" | awk '{sum += $3} END {print sum}')
        cpu_samples+=($cpu_percent)
        sleep 1
    done
    
    # Calculate average
    local total_cpu=0
    for cpu in "${cpu_samples[@]}"; do
        total_cpu=$(echo "$total_cpu + $cpu" | bc)
    done
    local avg_cpu=$(echo "scale=2; $total_cpu / ${#cpu_samples[@]}" | bc)
    
    # Clean up
    kill $init_pid 2>/dev/null || true
    tmux kill-server 2>/dev/null || true
    
    echo "$avg_cpu"
}

# Measure IPC throughput
measure_ipc_throughput() {
    log "Measuring IPC throughput..."
    
    local pipes_dir="$BASE_DIR/pipes"
    mkdir -p "$pipes_dir"
    
    # Create test pipe
    local test_pipe="$pipes_dir/test.pipe"
    [ ! -p "$test_pipe" ] && mkfifo "$test_pipe"
    
    # Start consumer
    (
        local count=0
        while read -r message < "$test_pipe"; do
            count=$((count + 1))
            if [ "$message" = "END" ]; then
                echo "$count" > "$pipes_dir/throughput_result"
                break
            fi
        done
    ) &
    local consumer_pid=$!
    
    # Send messages
    local start_time=$(date +%s)
    for i in {1..1000}; do
        echo "test_message_$i" > "$test_pipe"
    done
    echo "END" > "$test_pipe"
    
    # Wait for completion
    wait $consumer_pid
    local end_time=$(date +%s)
    
    local duration=$((end_time - start_time))
    local throughput=$(cat "$pipes_dir/throughput_result")
    local messages_per_sec=$(echo "scale=2; $throughput / $duration" | bc)
    
    # Clean up
    rm -f "$test_pipe" "$pipes_dir/throughput_result"
    
    echo "$messages_per_sec"
}

# Measure npx call overhead
measure_npx_overhead() {
    log "Measuring npx call overhead..."
    
    local samples=10
    local total_time=0
    
    for i in $(seq 1 $samples); do
        local start_time=$(date +%s.%3N)
        npx claude-flow --version >/dev/null 2>&1 || true
        local end_time=$(date +%s.%3N)
        
        local call_time=$(echo "$end_time - $start_time" | bc)
        total_time=$(echo "$total_time + $call_time" | bc)
    done
    
    local avg_time=$(echo "scale=3; $total_time / $samples" | bc)
    echo "$avg_time"
}

# Main collection function
collect_baseline() {
    log "Starting performance baseline collection..."
    
    info "Phase 1: Orchestrator startup time"
    local startup_time=$(measure_startup_time)
    
    info "Phase 2: Worker spawn latency"  
    local worker_latency=$(measure_worker_spawn_latency)
    
    info "Phase 3: Memory usage patterns"
    local memory_usage=$(measure_memory_usage)
    
    info "Phase 4: CPU utilization"
    local cpu_usage=$(measure_cpu_usage)
    
    info "Phase 5: IPC throughput"
    local ipc_throughput=$(measure_ipc_throughput)
    
    info "Phase 6: NPX call overhead"
    local npx_overhead=$(measure_npx_overhead)
    
    # Create JSON baseline file
    cat > "$BASELINE_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "baseline",
  "metrics": {
    "startup_time_seconds": $startup_time,
    "worker_spawn_latency_seconds": $worker_latency,
    "memory_usage_mb": $memory_usage,
    "cpu_usage_percent": $cpu_usage,
    "ipc_throughput_msgs_per_sec": $ipc_throughput,
    "npx_call_overhead_seconds": $npx_overhead
  },
  "system_info": {
    "hostname": "$(hostname)",
    "os": "$(uname -s)",
    "os_version": "$(uname -r)",
    "cpu_cores": "$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 'unknown')",
    "memory_gb": "$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || system_profiler SPHardwareDataType | awk '/Memory:/{print $2}' | cut -d' ' -f1 || echo 'unknown')"
  }
}
EOF
    
    log "Baseline collection complete!"
    log "Results saved to: $BASELINE_FILE"
    
    # Display results
    echo ""
    info "Performance Baseline Summary:"
    echo "  Startup Time: ${startup_time}s"
    echo "  Worker Latency: ${worker_latency}s"  
    echo "  Memory Usage: ${memory_usage}MB"
    echo "  CPU Usage: ${cpu_usage}%"
    echo "  IPC Throughput: ${ipc_throughput} msg/s"
    echo "  NPX Overhead: ${npx_overhead}s"
    echo ""
}

# Store in Claude Flow memory
store_in_memory() {
    if [ -f "$BASELINE_FILE" ]; then
        log "Storing baseline in Claude Flow memory..."
        npx claude-flow memory store "performance/baseline/$(date +%s)" "$(cat "$BASELINE_FILE")" 2>/dev/null || true
        npx claude-flow memory store "performance/baseline/latest" "$(cat "$BASELINE_FILE")" 2>/dev/null || true
    fi
}

# Main execution
main() {
    collect_baseline
    store_in_memory
    
    log "Cybernetic performance baseline established! 🚀"
    log "Ready for self-optimization phase."
}

# Check for required tools
check_dependencies() {
    local missing=()
    
    command -v bc >/dev/null || missing+=("bc")
    command -v tmux >/dev/null || missing+=("tmux")
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}"
        error "Install with: brew install ${missing[*]}"
        exit 1
    fi
}

# Run baseline collection
check_dependencies
main "$@"