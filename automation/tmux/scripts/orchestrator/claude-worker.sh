#!/bin/bash
# Claude Worker - Continuous Task Processing
# Autonomous worker that processes tasks from queue

set -euo pipefail

# Worker configuration
WORKER_ID=${1:-1}
WORKER_NAME="claude-worker-$WORKER_ID"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGS_DIR="$BASE_DIR/logs"
PIPES_DIR="$BASE_DIR/pipes"
WORKER_LOG="$LOGS_DIR/worker-$WORKER_ID.log"

# Create log file
mkdir -p "$LOGS_DIR"
touch "$WORKER_LOG"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[Worker-$WORKER_ID]${NC} $(date '+%H:%M:%S') - $1" | tee -a "$WORKER_LOG"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$WORKER_LOG" >&2
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$WORKER_LOG"
}

task() {
    echo -e "${CYAN}[TASK]${NC} $1" | tee -a "$WORKER_LOG"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$WORKER_LOG"
}

# Worker state
WORKER_STATE="idle"
TASKS_COMPLETED=0
TASKS_FAILED=0
CURRENT_TASK=""

# Store worker state in memory
update_state() {
    local state=$1
    WORKER_STATE="$state"
    npx claude-flow memory store "worker/$WORKER_ID/state" "$state" 2>/dev/null || true
    npx claude-flow memory store "worker/$WORKER_ID/stats" "{\"completed\": $TASKS_COMPLETED, \"failed\": $TASKS_FAILED}" 2>/dev/null || true
}

# Process a task using Claude Flow
process_task() {
    local task_description="$1"
    local task_id="task-$(date +%s)-$WORKER_ID"
    
    task "Processing: $task_description"
    CURRENT_TASK="$task_description"
    update_state "processing"
    
    # Pre-task hook
    npx claude-flow hooks pre-task --description "$task_description" 2>/dev/null || true
    
    # Determine task type and select appropriate agent
    local agent_type="coder"
    if [[ "$task_description" == *"test"* ]]; then
        agent_type="tester"
    elif [[ "$task_description" == *"review"* ]]; then
        agent_type="reviewer"
    elif [[ "$task_description" == *"design"* ]] || [[ "$task_description" == *"architect"* ]]; then
        agent_type="system-architect"
    elif [[ "$task_description" == *"api"* ]]; then
        agent_type="backend-dev"
    elif [[ "$task_description" == *"mobile"* ]]; then
        agent_type="mobile-dev"
    elif [[ "$task_description" == *"performance"* ]]; then
        agent_type="perf-analyzer"
    elif [[ "$task_description" == *"security"* ]]; then
        agent_type="security-manager"
    fi
    
    info "Assigned to agent: $agent_type"
    
    # Execute task with appropriate SPARC mode
    local result
    if [[ "$task_description" == *"tdd"* ]] || [[ "$task_description" == *"test-driven"* ]]; then
        # Use TDD workflow
        result=$(npx claude-flow sparc tdd "$task_description" 2>&1)
    elif [[ "$task_description" == *"architecture"* ]] || [[ "$task_description" == *"design"* ]]; then
        # Use architecture mode
        result=$(npx claude-flow sparc run architect "$task_description" 2>&1)
    else
        # Use general pipeline
        result=$(npx claude-flow sparc pipeline "$task_description" 2>&1)
    fi
    
    # Check result
    if [ $? -eq 0 ]; then
        success "Task completed successfully"
        TASKS_COMPLETED=$((TASKS_COMPLETED + 1))
        
        # Store result in memory
        npx claude-flow memory store "tasks/completed/$task_id" "{\"task\": \"$task_description\", \"worker\": $WORKER_ID, \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" 2>/dev/null || true
        
        # Post-task hook
        npx claude-flow hooks post-task --task-id "$task_id" 2>/dev/null || true
        
        # Send result to results pipe
        echo "SUCCESS:$WORKER_ID:$task_id:$task_description" > "$PIPES_DIR/results.pipe" 2>/dev/null || true
    else
        error "Task failed"
        TASKS_FAILED=$((TASKS_FAILED + 1))
        
        # Store failure in memory
        npx claude-flow memory store "tasks/failed/$task_id" "{\"task\": \"$task_description\", \"worker\": $WORKER_ID, \"error\": \"Task execution failed\"}" 2>/dev/null || true
        
        # Send failure to results pipe
        echo "FAILED:$WORKER_ID:$task_id:$task_description" > "$PIPES_DIR/results.pipe" 2>/dev/null || true
    fi
    
    CURRENT_TASK=""
    update_state "idle"
}

# Health check
health_check() {
    # Update heartbeat
    npx claude-flow memory store "worker/$WORKER_ID/heartbeat" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 2>/dev/null || true
    
    # Check memory usage
    local mem_usage=$(ps aux | grep "worker-$WORKER_ID" | awk '{print $4}' | head -1)
    npx claude-flow memory store "worker/$WORKER_ID/memory" "$mem_usage" 2>/dev/null || true
}

# Handle control commands
handle_control() {
    local command="$1"
    
    case "$command" in
        "pause")
            log "Worker paused"
            update_state "paused"
            ;;
        "resume")
            log "Worker resumed"
            update_state "idle"
            ;;
        "status")
            echo "Worker $WORKER_ID: $WORKER_STATE | Completed: $TASKS_COMPLETED | Failed: $TASKS_FAILED"
            ;;
        "reload")
            log "Reloading configuration..."
            exec "$0" "$WORKER_ID"
            ;;
        "stop")
            log "Worker stopping..."
            update_state "stopped"
            exit 0
            ;;
        *)
            info "Unknown command: $command"
            ;;
    esac
}

# Signal handlers
trap 'log "Worker interrupted"; update_state "stopped"; exit 0' INT TERM
trap 'error "Worker error"; update_state "error"; exit 1' ERR

# Worker header
show_header() {
    clear
    echo -e "${CYAN}╔═════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Claude Worker $WORKER_ID                    ║${NC}"
    echo -e "${CYAN}║         Continuous Task Processor                ║${NC}"
    echo -e "${CYAN}╚═════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Status:${NC} Starting..."
    echo -e "${YELLOW}Tasks Pipe:${NC} $PIPES_DIR/tasks.pipe"
    echo -e "${YELLOW}Control Pipe:${NC} $PIPES_DIR/control.pipe"
    echo -e "${YELLOW}Log File:${NC} $WORKER_LOG"
    echo ""
    echo -e "${GREEN}Waiting for tasks...${NC}"
    echo ""
}

# Main worker loop
main() {
    show_header
    log "Worker $WORKER_ID starting"
    update_state "starting"
    
    # Initialize worker in swarm
    npx claude-flow agent spawn --type coordinator --name "$WORKER_NAME" 2>/dev/null || true
    
    # Restore session if exists
    npx claude-flow hooks session-restore --session-id "worker-$WORKER_ID" 2>/dev/null || true
    
    update_state "idle"
    log "Worker ready for tasks"
    
    # Main processing loop
    local health_counter=0
    
    while true; do
        # Check for control commands (non-blocking)
        if [ -p "$PIPES_DIR/control.pipe" ]; then
            if read -t 0.1 control_cmd < "$PIPES_DIR/control.pipe" 2>/dev/null; then
                if [[ "$control_cmd" == *"worker-$WORKER_ID"* ]] || [[ "$control_cmd" == *"all-workers"* ]]; then
                    handle_control "${control_cmd#*:}"
                fi
            fi
        fi
        
        # Skip task processing if paused
        if [ "$WORKER_STATE" == "paused" ]; then
            sleep 1
            continue
        fi
        
        # Check for tasks (blocking with timeout)
        if [ -p "$PIPES_DIR/tasks.pipe" ]; then
            if read -t 5 task_data < "$PIPES_DIR/tasks.pipe" 2>/dev/null; then
                if [ -n "$task_data" ]; then
                    process_task "$task_data"
                fi
            fi
        else
            # Create pipe if it doesn't exist
            mkdir -p "$PIPES_DIR"
            [ ! -p "$PIPES_DIR/tasks.pipe" ] && mkfifo "$PIPES_DIR/tasks.pipe"
        fi
        
        # Periodic health check
        health_counter=$((health_counter + 1))
        if [ $health_counter -ge 60 ]; then
            health_check
            health_counter=0
            
            # Display status
            echo -e "\r${GREEN}[♥]${NC} Worker $WORKER_ID | State: $WORKER_STATE | Completed: $TASKS_COMPLETED | Failed: $TASKS_FAILED | $(date '+%H:%M:%S')\c"
        fi
        
        # Small sleep to prevent CPU spinning
        sleep 0.1
    done
}

# Start worker
main "$@"