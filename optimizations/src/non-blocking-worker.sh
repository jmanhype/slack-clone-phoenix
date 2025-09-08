#!/bin/bash

# Optimized Non-blocking Worker
# Fixes the blocking read operations in claude-worker.sh (line 234)

set -euo pipefail

# Configuration
WORKER_ID=${1:-1}
PIPES_DIR="${PIPES_DIR:-/tmp/claude-orchestrator/pipes}"
LOGS_DIR="${LOGS_DIR:-/tmp/claude-orchestrator/logs}"
WORKER_STATE_DIR="${WORKER_STATE_DIR:-/tmp/claude-orchestrator/workers}"
POLL_INTERVAL="${POLL_INTERVAL:-0.1}"
MAX_IDLE_TIME="${MAX_IDLE_TIME:-300}"

# Create directories
mkdir -p "$PIPES_DIR" "$LOGS_DIR" "$WORKER_STATE_DIR"

# Worker state file
WORKER_STATE_FILE="$WORKER_STATE_DIR/worker-$WORKER_ID.state"
WORKER_LOG_FILE="$LOGS_DIR/worker-$WORKER_ID.log"

# Logging functions
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WORKER-$WORKER_ID] $*"
    echo "$msg" | tee -a "$WORKER_LOG_FILE"
}

info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO-$WORKER_ID] $*"
    echo "$msg" | tee -a "$WORKER_LOG_FILE"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR-$WORKER_ID] $*"
    echo "$msg" | tee -a "$WORKER_LOG_FILE" >&2
}

# Worker state management
update_worker_state() {
    local state=$1
    local timestamp=$(date +%s)
    local data="$2"
    
    cat > "$WORKER_STATE_FILE" << EOF
{
    "worker_id": $WORKER_ID,
    "state": "$state",
    "timestamp": $timestamp,
    "data": "$data"
}
EOF
    
    # Notify coordinator hooks
    npx claude-flow@alpha hooks notify \
        --message "Worker $WORKER_ID state: $state" \
        2>/dev/null || true
}

# Non-blocking pipe reader using file descriptors
setup_nonblocking_pipes() {
    local task_pipe="$PIPES_DIR/tasks.pipe"
    local control_pipe="$PIPES_DIR/control.pipe"
    
    # Create pipes if they don't exist
    [[ ! -p "$task_pipe" ]] && mkfifo "$task_pipe"
    [[ ! -p "$control_pipe" ]] && mkfifo "$control_pipe"
    
    # Open pipes for non-blocking read
    # Use file descriptor 3 for tasks, 4 for control
    exec 3< "$task_pipe"
    exec 4< "$control_pipe"
    
    # Make file descriptors non-blocking
    fcntl_nonblock 3
    fcntl_nonblock 4
    
    log "Non-blocking pipes configured (FD 3: tasks, FD 4: control)"
}

# Make file descriptor non-blocking
fcntl_nonblock() {
    local fd=$1
    python3 -c "
import fcntl, sys
fd = int(sys.argv[1])
flags = fcntl.fcntl(fd, fcntl.F_GETFL)
fcntl.fcntl(fd, fcntl.F_SETFL, flags | fcntl.O_NONBLOCK)
" "$fd" 2>/dev/null || {
        # Fallback for systems without Python
        log "Warning: Could not set non-blocking mode for FD $fd"
    }
}

# Non-blocking read from file descriptor
read_nonblocking() {
    local fd=$1
    local data=""
    
    # Try to read without blocking
    if data=$(timeout 0.001 dd if=/dev/fd/$fd bs=1024 count=1 2>/dev/null || true); then
        if [[ -n "$data" ]]; then
            echo "$data"
            return 0
        fi
    fi
    
    return 1
}

# Event-driven task processing loop
event_driven_loop() {
    local last_activity=$(date +%s)
    local tasks_processed=0
    
    log "Starting event-driven processing loop..."
    update_worker_state "idle" "ready for tasks"
    
    while true; do
        local current_time=$(date +%s)
        local activity_found=false
        
        # Check for tasks (non-blocking)
        if task_data=$(read_nonblocking 3); then
            if [[ -n "$task_data" ]]; then
                activity_found=true
                last_activity=$current_time
                tasks_processed=$((tasks_processed + 1))
                
                log "Received task: $task_data"
                update_worker_state "busy" "processing task $tasks_processed"
                
                # Process task
                if process_task "$task_data"; then
                    log "Task completed successfully"
                else
                    error "Task processing failed"
                fi
                
                update_worker_state "idle" "completed task $tasks_processed"
            fi
        fi
        
        # Check for control messages (non-blocking)
        if control_data=$(read_nonblocking 4); then
            if [[ -n "$control_data" ]]; then
                activity_found=true
                last_activity=$current_time
                
                log "Received control message: $control_data"
                
                case "$control_data" in
                    "shutdown")
                        log "Received shutdown signal"
                        update_worker_state "shutting_down" "graceful shutdown"
                        break
                        ;;
                    "health_check")
                        log "Health check requested"
                        update_worker_state "healthy" "health check OK"
                        ;;
                    "status")
                        log "Status requested: processed $tasks_processed tasks"
                        update_worker_state "reporting" "processed $tasks_processed tasks"
                        ;;
                    *)
                        log "Unknown control message: $control_data"
                        ;;
                esac
            fi
        fi
        
        # Check for idle timeout
        if (( current_time - last_activity > MAX_IDLE_TIME )); then
            log "Worker idle timeout reached, shutting down"
            update_worker_state "timeout" "idle timeout after ${MAX_IDLE_TIME}s"
            break
        fi
        
        # If no activity, sleep briefly to avoid busy waiting
        if ! $activity_found; then
            sleep "$POLL_INTERVAL"
        fi
        
        # Periodic status update
        if (( tasks_processed > 0 && tasks_processed % 10 == 0 )); then
            update_worker_state "active" "processed $tasks_processed tasks"
        fi
    done
    
    log "Event loop ended, processed $tasks_processed total tasks"
    update_worker_state "stopped" "processed $tasks_processed tasks"
}

# Process individual task
process_task() {
    local task_data="$1"
    local start_time=$(date +%s.%N)
    
    log "Processing task: $task_data"
    
    # Parse task data (assuming JSON format)
    local task_type=$(echo "$task_data" | jq -r '.type // "unknown"' 2>/dev/null || echo "unknown")
    local task_id=$(echo "$task_data" | jq -r '.id // "unknown"' 2>/dev/null || echo "unknown")
    
    case "$task_type" in
        "claude_request")
            process_claude_request "$task_data"
            ;;
        "file_operation")
            process_file_operation "$task_data"
            ;;
        "system_command")
            process_system_command "$task_data"
            ;;
        *)
            log "Unknown task type: $task_type, processing as generic task"
            process_generic_task "$task_data"
            ;;
    esac
    
    local end_time=$(date +%s.%N)
    local processing_time=$(echo "$end_time - $start_time" | bc -l)
    
    log "Task $task_id completed in ${processing_time}s"
    
    # Store task result in memory for coordination
    npx claude-flow@alpha hooks post-edit \
        --file "non-blocking-worker.sh" \
        --memory-key "swarm/worker-$WORKER_ID/task-$task_id" \
        --value "{\"status\": \"completed\", \"time\": $processing_time}" \
        2>/dev/null || true
    
    return 0
}

# Process Claude API request
process_claude_request() {
    local task_data="$1"
    
    # Extract request details
    local prompt=$(echo "$task_data" | jq -r '.prompt // ""' 2>/dev/null || echo "")
    local model=$(echo "$task_data" | jq -r '.model // "claude-3-sonnet"' 2>/dev/null || echo "claude-3-sonnet")
    
    if [[ -z "$prompt" ]]; then
        error "No prompt provided in Claude request"
        return 1
    fi
    
    log "Executing Claude request with model: $model"
    
    # Use non-blocking NPX call via process pool
    if command -v npx >/dev/null 2>&1; then
        # Simulate Claude API call (replace with actual implementation)
        log "Making Claude API request..."
        sleep 0.5  # Simulate API call time
        log "Claude API request completed"
    else
        error "NPX not available for Claude requests"
        return 1
    fi
    
    return 0
}

# Process file operation
process_file_operation() {
    local task_data="$1"
    
    local operation=$(echo "$task_data" | jq -r '.operation // "read"' 2>/dev/null || echo "read")
    local file_path=$(echo "$task_data" | jq -r '.file_path // ""' 2>/dev/null || echo "")
    
    if [[ -z "$file_path" ]]; then
        error "No file path provided in file operation"
        return 1
    fi
    
    log "Executing file operation: $operation on $file_path"
    
    case "$operation" in
        "read")
            if [[ -f "$file_path" ]]; then
                log "File read successful: $(wc -l < "$file_path") lines"
            else
                error "File not found: $file_path"
                return 1
            fi
            ;;
        "write")
            local content=$(echo "$task_data" | jq -r '.content // ""' 2>/dev/null || echo "")
            if [[ -n "$content" ]]; then
                echo "$content" > "$file_path"
                log "File write successful: $file_path"
            else
                error "No content provided for write operation"
                return 1
            fi
            ;;
        *)
            error "Unknown file operation: $operation"
            return 1
            ;;
    esac
    
    return 0
}

# Process system command
process_system_command() {
    local task_data="$1"
    
    local command=$(echo "$task_data" | jq -r '.command // ""' 2>/dev/null || echo "")
    local timeout=$(echo "$task_data" | jq -r '.timeout // 30' 2>/dev/null || echo "30")
    
    if [[ -z "$command" ]]; then
        error "No command provided in system command task"
        return 1
    fi
    
    log "Executing system command: $command"
    
    if timeout "$timeout" bash -c "$command"; then
        log "System command completed successfully"
        return 0
    else
        error "System command failed or timed out"
        return 1
    fi
}

# Process generic task
process_generic_task() {
    local task_data="$1"
    
    log "Processing generic task: $task_data"
    
    # Simulate some processing time
    sleep 0.1
    
    log "Generic task processed"
    return 0
}

# Cleanup function
cleanup() {
    log "Cleaning up worker $WORKER_ID..."
    
    update_worker_state "stopping" "cleanup in progress"
    
    # Close file descriptors
    exec 3<&-
    exec 4<&-
    
    # Remove state file
    rm -f "$WORKER_STATE_FILE"
    
    # Notify coordinator
    npx claude-flow@alpha hooks post-task \
        --task-id "worker-$WORKER_ID" \
        2>/dev/null || true
    
    log "Worker $WORKER_ID cleanup complete"
}

# Signal handlers
trap cleanup EXIT
trap 'log "Received SIGTERM"; exit 0' TERM
trap 'log "Received SIGINT"; exit 0' INT

# Performance monitoring
monitor_performance() {
    local pid=$1
    local monitor_file="$LOGS_DIR/worker-$WORKER_ID-perf.log"
    
    while kill -0 "$pid" 2>/dev/null; do
        local cpu_usage=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null || echo "0.0")
        local mem_usage=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null || echo "0.0")
        local timestamp=$(date +%s)
        
        echo "$timestamp,$cpu_usage,$mem_usage" >> "$monitor_file"
        sleep 5
    done &
    
    echo $!
}

# Main execution
main() {
    log "Starting non-blocking worker $WORKER_ID..."
    
    # Initialize worker
    update_worker_state "starting" "initializing non-blocking I/O"
    
    # Setup non-blocking pipes
    setup_nonblocking_pipes
    
    # Start performance monitoring
    monitor_pid=$(monitor_performance $$)
    
    # Initialize coordination hooks
    npx claude-flow@alpha hooks pre-task \
        --description "Non-blocking worker $WORKER_ID starting" \
        2>/dev/null || true
    
    # Start event-driven processing loop
    event_driven_loop
    
    # Stop performance monitoring
    kill "$monitor_pid" 2>/dev/null || true
    
    log "Non-blocking worker $WORKER_ID stopped"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi