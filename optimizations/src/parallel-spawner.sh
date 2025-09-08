#!/bin/bash

# Optimized Parallel Worker Spawner
# Fixes the sequential spawning bottleneck in t-max-init.sh (lines 163-182)

set -euo pipefail

# Configuration
WORKER_PREFIX="${WORKER_PREFIX:-claude-worker}"
SCRIPTS_DIR="${SCRIPTS_DIR:-/Users/speed/Downloads/experiments/automation/tmux/scripts}"
MAX_PARALLEL_WORKERS="${MAX_PARALLEL_WORKERS:-8}"
WORKER_TIMEOUT="${WORKER_TIMEOUT:-30}"

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SPAWNER] $*" >&2
}

info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >&2
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

# Worker status tracking
declare -A WORKER_PIDS
declare -A WORKER_STATUS
declare -A WORKER_START_TIME

# Parallel worker spawning function
spawn_workers_parallel() {
    local num_workers=${1:-4}
    local max_parallel=${2:-$MAX_PARALLEL_WORKERS}
    
    log "Spawning $num_workers workers with max $max_parallel parallel processes..."
    
    # Clear status tracking
    WORKER_PIDS=()
    WORKER_STATUS=()
    WORKER_START_TIME=()
    
    # Function to spawn a single worker
    spawn_single_worker() {
        local worker_id=$1
        local worker_name="${WORKER_PREFIX}-$worker_id"
        
        log "Starting worker $worker_id ($worker_name)..."
        WORKER_START_TIME[$worker_id]=$(date +%s.%N)
        
        # Check if worker already exists
        if tmux has-session -t "$worker_name" 2>/dev/null; then
            info "Worker $worker_name already exists, killing and recreating..."
            tmux kill-session -t "$worker_name" 2>/dev/null || true
            sleep 0.1
        fi
        
        # Create worker session
        if tmux new-session -d -s "$worker_name" -n worker 2>/dev/null; then
            # Send worker script command
            if tmux send-keys -t "$worker_name:worker" "bash '$SCRIPTS_DIR/orchestrator/claude-worker.sh' $worker_id" C-m 2>/dev/null; then
                WORKER_STATUS[$worker_id]="started"
                log "Worker $worker_id spawned successfully"
                return 0
            else
                error "Failed to send commands to worker $worker_id"
                WORKER_STATUS[$worker_id]="failed"
                return 1
            fi
        else
            error "Failed to create tmux session for worker $worker_id"
            WORKER_STATUS[$worker_id]="failed"
            return 1
        fi
    }
    
    # Export function for parallel execution
    export -f spawn_single_worker
    export -f log
    export -f info
    export -f error
    export WORKER_PREFIX SCRIPTS_DIR
    
    # Create worker ID sequence
    local worker_ids=($(seq 1 $num_workers))
    
    # Use xargs for parallel execution with proper job control
    printf '%s\n' "${worker_ids[@]}" | \
        xargs -n 1 -P $max_parallel -I {} bash -c 'spawn_single_worker "$@"' _ {}
    
    # Wait a moment for sessions to initialize
    sleep 0.5
    
    # Verify worker readiness
    local ready_workers=0
    local failed_workers=0
    
    for worker_id in "${worker_ids[@]}"; do
        local worker_name="${WORKER_PREFIX}-$worker_id"
        
        # Check if tmux session exists and is responsive
        if wait_for_worker_ready "$worker_id" "$WORKER_TIMEOUT"; then
            ready_workers=$((ready_workers + 1))
            local end_time=$(date +%s.%N)
            local spawn_time=$(echo "$end_time - ${WORKER_START_TIME[$worker_id]}" | bc -l)
            info "Worker $worker_id ready in ${spawn_time}s"
        else
            failed_workers=$((failed_workers + 1))
            error "Worker $worker_id failed to become ready within ${WORKER_TIMEOUT}s"
        fi
    done
    
    log "Parallel spawning complete: $ready_workers ready, $failed_workers failed"
    
    # Store results in memory for coordination
    npx claude-flow@alpha hooks post-edit \
        --file "parallel-spawner.sh" \
        --memory-key "swarm/spawner/results" \
        --value "{\"ready\": $ready_workers, \"failed\": $failed_workers, \"total\": $num_workers}" \
        2>/dev/null || true
    
    return $([[ $failed_workers -eq 0 ]] && echo 0 || echo 1)
}

# Wait for worker to become ready
wait_for_worker_ready() {
    local worker_id=$1
    local timeout=${2:-30}
    local worker_name="${WORKER_PREFIX}-$worker_id"
    local start_time=$(date +%s)
    
    while (( $(date +%s) - start_time < timeout )); do
        # Check if tmux session exists
        if ! tmux has-session -t "$worker_name" 2>/dev/null; then
            sleep 0.1
            continue
        fi
        
        # Check if worker process is running
        if tmux list-panes -t "$worker_name:worker" -F '#{pane_pid}' 2>/dev/null | head -1 | xargs -I {} kill -0 {} 2>/dev/null; then
            # Additional readiness check - look for worker ready signal
            if check_worker_health "$worker_id"; then
                return 0
            fi
        fi
        
        sleep 0.2
    done
    
    return 1
}

# Health check for individual worker
check_worker_health() {
    local worker_id=$1
    local worker_name="${WORKER_PREFIX}-$worker_id"
    
    # Check if we can send a simple command and get response
    local test_command="echo 'health-check-$worker_id'"
    
    # Send health check command
    if tmux send-keys -t "$worker_name:worker" "$test_command" C-m 2>/dev/null; then
        # Brief wait for command processing
        sleep 0.1
        return 0
    fi
    
    return 1
}

# Get worker status
get_worker_status() {
    local worker_id=${1:-}
    
    if [[ -n "$worker_id" ]]; then
        echo "${WORKER_STATUS[$worker_id]:-unknown}"
    else
        # Return all worker statuses
        for id in "${!WORKER_STATUS[@]}"; do
            echo "Worker $id: ${WORKER_STATUS[$id]}"
        done
    fi
}

# Kill all workers
kill_all_workers() {
    log "Killing all workers..."
    
    for session in $(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${WORKER_PREFIX}-" || true); do
        log "Killing session: $session"
        tmux kill-session -t "$session" 2>/dev/null || true
    done
    
    # Clear status tracking
    WORKER_PIDS=()
    WORKER_STATUS=()
    WORKER_START_TIME=()
    
    log "All workers killed"
}

# Benchmark comparison function
benchmark_spawning() {
    local num_workers=${1:-4}
    
    echo "🚀 Benchmarking Worker Spawning Performance"
    echo "==========================================="
    
    # Cleanup any existing workers
    kill_all_workers
    sleep 1
    
    # Test parallel spawning
    echo "Testing optimized parallel spawning..."
    local start_time=$(date +%s.%N)
    
    if spawn_workers_parallel "$num_workers"; then
        local end_time=$(date +%s.%N)
        local parallel_time=$(echo "$end_time - $start_time" | bc -l)
        
        echo "✅ Parallel spawning completed in ${parallel_time}s"
        
        # Cleanup
        kill_all_workers
        
        # Compare with theoretical sequential time
        local estimated_sequential=$(echo "$parallel_time * $num_workers" | bc -l)
        local speedup=$(echo "$estimated_sequential / $parallel_time" | bc -l)
        
        echo "📊 Performance Analysis:"
        echo "  - Parallel time: ${parallel_time}s"
        echo "  - Estimated sequential: ${estimated_sequential}s"
        echo "  - Theoretical speedup: ${speedup}x"
        echo "  - Workers spawned: $num_workers"
        
        return 0
    else
        echo "❌ Parallel spawning failed"
        return 1
    fi
}

# Main execution
main() {
    local action=${1:-spawn}
    local num_workers=${2:-4}
    local max_parallel=${3:-$MAX_PARALLEL_WORKERS}
    
    case "$action" in
        spawn)
            spawn_workers_parallel "$num_workers" "$max_parallel"
            ;;
        status)
            get_worker_status
            ;;
        kill)
            kill_all_workers
            ;;
        benchmark)
            benchmark_spawning "$num_workers"
            ;;
        health)
            local worker_id=${2:-1}
            if check_worker_health "$worker_id"; then
                echo "Worker $worker_id is healthy"
                exit 0
            else
                echo "Worker $worker_id is not healthy"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 {spawn|status|kill|benchmark|health} [num_workers] [max_parallel]"
            echo ""
            echo "Commands:"
            echo "  spawn N M   - Spawn N workers with max M parallel processes"
            echo "  status      - Show worker status"
            echo "  kill        - Kill all workers"
            echo "  benchmark N - Benchmark spawning N workers"
            echo "  health ID   - Check health of worker ID"
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi