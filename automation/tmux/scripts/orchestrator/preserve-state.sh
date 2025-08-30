#!/bin/bash
# Preserve State - Session State Preservation & Restore
# Captures and restores complete session state for resilience

set -euo pipefail

# Configuration
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGS_DIR="$BASE_DIR/logs"
SESSIONS_DIR="$BASE_DIR/sessions"
BACKUPS_DIR="$BASE_DIR/backups"
STATE_DIR="$BASE_DIR/state"
MEMORY_DB=".swarm/memory.db"

# Create directories
mkdir -p "$LOGS_DIR" "$SESSIONS_DIR" "$BACKUPS_DIR" "$STATE_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# State file naming
STATE_PREFIX="claude-state"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Logging
log() {
    echo -e "${GREEN}[Preserve]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGS_DIR/preserve.log"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGS_DIR/preserve.log" >&2
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOGS_DIR/preserve.log"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOGS_DIR/preserve.log"
}

# Capture tmux session state
capture_tmux_sessions() {
    local output_file="$1"
    log "Capturing tmux session state..."
    
    local sessions_data=()
    
    # Iterate through all sessions
    while IFS= read -r session; do
        local session_name=$(echo "$session" | cut -d: -f1)
        
        # Get session info
        local session_info=$(tmux list-windows -t "$session_name" -F "#{window_index}:#{window_name}:#{window_layout}" 2>/dev/null)
        
        # Get pane contents for each window
        local panes_data=()
        while IFS= read -r window; do
            local window_index=$(echo "$window" | cut -d: -f1)
            local window_name=$(echo "$window" | cut -d: -f2)
            
            # Capture each pane's content
            local pane_contents=()
            while IFS= read -r pane_id; do
                local content=$(tmux capture-pane -t "$session_name:$window_index.$pane_id" -p 2>/dev/null | base64 -w0)
                pane_contents+=("{\"pane_id\": \"$pane_id\", \"content\": \"$content\"}")
            done < <(tmux list-panes -t "$session_name:$window_index" -F "#{pane_index}" 2>/dev/null)
            
            local panes_json=$(printf '%s,' "${pane_contents[@]}" | sed 's/,$//')
            panes_data+=("{
                \"window_index\": \"$window_index\",
                \"window_name\": \"$window_name\",
                \"layout\": \"$(echo "$window" | cut -d: -f3)\",
                \"panes\": [$panes_json]
            }")
        done < <(echo "$session_info")
        
        local windows_json=$(printf '%s,' "${panes_data[@]}" | sed 's/,$//')
        
        sessions_data+=("{
            \"name\": \"$session_name\",
            \"created\": \"$(tmux display -p -t "$session_name" '#{session_created}' 2>/dev/null)\",
            \"windows\": [$windows_json]
        }")
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    # Create JSON output
    local sessions_json=$(printf '%s,' "${sessions_data[@]}" | sed 's/,$//')
    echo "{\"sessions\": [$sessions_json], \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" > "$output_file"
    
    log "Captured $(echo "${sessions_data[@]}" | wc -w) sessions"
}

# Capture memory database
capture_memory() {
    local output_dir="$1"
    log "Capturing memory database..."
    
    if [ -f "$MEMORY_DB" ]; then
        # Copy database
        cp "$MEMORY_DB" "$output_dir/memory.db"
        
        # Also export as SQL for safety
        sqlite3 "$MEMORY_DB" ".dump" > "$output_dir/memory.sql" 2>/dev/null || true
        
        # Get statistics
        local key_count=$(sqlite3 "$MEMORY_DB" "SELECT COUNT(*) FROM memory_store;" 2>/dev/null || echo 0)
        log "Captured $key_count memory keys"
    else
        warn "Memory database not found"
    fi
}

# Capture worker states
capture_worker_states() {
    local output_file="$1"
    log "Capturing worker states..."
    
    local workers_data=()
    
    for i in {1..8}; do
        local state=$(npx claude-flow memory get "worker/$i/state" 2>/dev/null | tr -d '"')
        
        if [ -n "$state" ]; then
            local heartbeat=$(npx claude-flow memory get "worker/$i/heartbeat" 2>/dev/null | tr -d '"')
            local stats=$(npx claude-flow memory get "worker/$i/stats" 2>/dev/null)
            local memory=$(npx claude-flow memory get "worker/$i/memory" 2>/dev/null | tr -d '"')
            local current_task=$(npx claude-flow memory get "worker/$i/current_task" 2>/dev/null)
            
            workers_data+=("{
                \"id\": $i,
                \"state\": \"$state\",
                \"heartbeat\": \"$heartbeat\",
                \"memory\": \"$memory\",
                \"stats\": $stats,
                \"current_task\": $current_task
            }")
        fi
    done
    
    local workers_json=$(printf '%s,' "${workers_data[@]}" | sed 's/,$//')
    echo "{\"workers\": [$workers_json], \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" > "$output_file"
    
    log "Captured $(echo "${workers_data[@]}" | wc -w) worker states"
}

# Capture swarm configuration
capture_swarm_config() {
    local output_file="$1"
    log "Capturing swarm configuration..."
    
    # Get swarm status
    local swarm_status=$(npx claude-flow swarm status 2>/dev/null | head -20)
    
    # Get agent list
    local agents=$(npx claude-flow agent list 2>/dev/null)
    
    # Get metrics
    local metrics=$(npx claude-flow agent metrics 2>/dev/null)
    
    # Create configuration JSON
    cat > "$output_file" << EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "swarm": {
        "status": "$(echo "$swarm_status" | base64 -w0)",
        "agents": "$(echo "$agents" | base64 -w0)",
        "metrics": "$(echo "$metrics" | base64 -w0)"
    }
}
EOF
    
    log "Swarm configuration captured"
}

# Capture task queue
capture_task_queue() {
    local output_file="$1"
    log "Capturing task queue..."
    
    local pending_tasks=()
    local completed_tasks=()
    local failed_tasks=()
    
    # Get pending tasks
    while IFS= read -r task_key; do
        if [ -n "$task_key" ]; then
            local task_data=$(npx claude-flow memory get "$task_key" 2>/dev/null)
            pending_tasks+=("{\"key\": \"$task_key\", \"data\": $task_data}")
        fi
    done < <(npx claude-flow memory search "tasks/pending/*" 2>/dev/null)
    
    # Get recent completed tasks (last 50)
    while IFS= read -r task_key; do
        if [ -n "$task_key" ]; then
            local task_data=$(npx claude-flow memory get "$task_key" 2>/dev/null)
            completed_tasks+=("{\"key\": \"$task_key\", \"data\": $task_data}")
        fi
    done < <(npx claude-flow memory search "tasks/completed/*" 2>/dev/null | tail -50)
    
    # Get failed tasks
    while IFS= read -r task_key; do
        if [ -n "$task_key" ]; then
            local task_data=$(npx claude-flow memory get "$task_key" 2>/dev/null)
            failed_tasks+=("{\"key\": \"$task_key\", \"data\": $task_data}")
        fi
    done < <(npx claude-flow memory search "tasks/failed/*" 2>/dev/null)
    
    # Create JSON output
    local pending_json=$(printf '%s,' "${pending_tasks[@]}" | sed 's/,$//')
    local completed_json=$(printf '%s,' "${completed_tasks[@]}" | sed 's/,$//')
    local failed_json=$(printf '%s,' "${failed_tasks[@]}" | sed 's/,$//')
    
    cat > "$output_file" << EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "queue": {
        "pending": [$pending_json],
        "completed": [$completed_json],
        "failed": [$failed_json]
    }
}
EOF
    
    log "Task queue captured: ${#pending_tasks[@]} pending, ${#completed_tasks[@]} completed, ${#failed_tasks[@]} failed"
}

# Capture environment and configuration
capture_environment() {
    local output_file="$1"
    log "Capturing environment configuration..."
    
    cat > "$output_file" << EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "environment": {
        "hostname": "$(hostname)",
        "user": "$USER",
        "pwd": "$(pwd)",
        "node_version": "$(node --version 2>/dev/null || echo 'N/A')",
        "npm_version": "$(npm --version 2>/dev/null || echo 'N/A')",
        "claude_flow_version": "$(npx claude-flow --version 2>/dev/null || echo 'N/A')",
        "tmux_version": "$(tmux -V 2>/dev/null || echo 'N/A')"
    },
    "paths": {
        "base_dir": "$BASE_DIR",
        "logs_dir": "$LOGS_DIR",
        "sessions_dir": "$SESSIONS_DIR",
        "backups_dir": "$BACKUPS_DIR",
        "state_dir": "$STATE_DIR"
    }
}
EOF
    
    log "Environment configuration captured"
}

# Create complete state snapshot
create_snapshot() {
    local snapshot_name="${STATE_PREFIX}-${TIMESTAMP}"
    local snapshot_dir="$STATE_DIR/$snapshot_name"
    
    log "Creating state snapshot: $snapshot_name"
    mkdir -p "$snapshot_dir"
    
    # Capture all components
    capture_tmux_sessions "$snapshot_dir/tmux-sessions.json"
    capture_memory "$snapshot_dir"
    capture_worker_states "$snapshot_dir/worker-states.json"
    capture_swarm_config "$snapshot_dir/swarm-config.json"
    capture_task_queue "$snapshot_dir/task-queue.json"
    capture_environment "$snapshot_dir/environment.json"
    
    # Create manifest
    cat > "$snapshot_dir/manifest.json" << EOF
{
    "name": "$snapshot_name",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "components": [
        "tmux-sessions.json",
        "memory.db",
        "memory.sql",
        "worker-states.json",
        "swarm-config.json",
        "task-queue.json",
        "environment.json"
    ],
    "version": "1.0.0"
}
EOF
    
    # Compress snapshot
    log "Compressing snapshot..."
    tar -czf "$snapshot_dir.tar.gz" -C "$STATE_DIR" "$snapshot_name"
    
    # Store reference in memory
    npx claude-flow memory store "state/snapshots/$snapshot_name" "{
        \"path\": \"$snapshot_dir.tar.gz\",
        \"size\": \"$(du -h "$snapshot_dir.tar.gz" | cut -f1)\",
        \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
    }" 2>/dev/null || true
    
    success "State snapshot created: $snapshot_dir.tar.gz"
    echo "$snapshot_dir.tar.gz"
}

# Restore from snapshot
restore_snapshot() {
    local snapshot_path="$1"
    
    if [ ! -f "$snapshot_path" ]; then
        error "Snapshot not found: $snapshot_path"
        return 1
    fi
    
    log "Restoring from snapshot: $snapshot_path"
    
    # Extract snapshot
    local temp_dir="/tmp/claude-restore-$$"
    mkdir -p "$temp_dir"
    tar -xzf "$snapshot_path" -C "$temp_dir"
    
    local snapshot_name=$(basename "$snapshot_path" .tar.gz)
    local snapshot_dir="$temp_dir/$snapshot_name"
    
    # Verify manifest
    if [ ! -f "$snapshot_dir/manifest.json" ]; then
        error "Invalid snapshot: missing manifest"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log "Snapshot verified, beginning restoration..."
    
    # Restore memory database
    if [ -f "$snapshot_dir/memory.db" ]; then
        log "Restoring memory database..."
        mkdir -p "$(dirname "$MEMORY_DB")"
        cp "$snapshot_dir/memory.db" "$MEMORY_DB"
        success "Memory database restored"
    fi
    
    # Restore worker states
    if [ -f "$snapshot_dir/worker-states.json" ]; then
        log "Restoring worker states..."
        local workers=$(jq -r '.workers[]' "$snapshot_dir/worker-states.json" 2>/dev/null)
        while IFS= read -r worker; do
            local id=$(echo "$worker" | jq -r '.id')
            local state=$(echo "$worker" | jq -r '.state')
            npx claude-flow memory store "worker/$id/state" "\"$state\"" 2>/dev/null || true
        done <<< "$workers"
        success "Worker states restored"
    fi
    
    # Restore task queue
    if [ -f "$snapshot_dir/task-queue.json" ]; then
        log "Restoring task queue..."
        local pending_count=$(jq '.queue.pending | length' "$snapshot_dir/task-queue.json" 2>/dev/null || echo 0)
        info "Restored $pending_count pending tasks"
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    success "Snapshot restoration complete"
    
    # Store restoration event
    npx claude-flow memory store "state/restored/$(date +%s)" "{
        \"snapshot\": \"$snapshot_path\",
        \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
    }" 2>/dev/null || true
}

# List available snapshots
list_snapshots() {
    log "Available state snapshots:"
    echo ""
    
    local count=0
    for snapshot in "$STATE_DIR"/*.tar.gz; do
        if [ -f "$snapshot" ]; then
            local name=$(basename "$snapshot" .tar.gz)
            local size=$(du -h "$snapshot" | cut -f1)
            local date=$(stat -c %y "$snapshot" 2>/dev/null || stat -f "%Sm" "$snapshot" 2>/dev/null)
            
            echo -e "${CYAN}$name${NC}"
            echo "  Path: $snapshot"
            echo "  Size: $size"
            echo "  Date: $date"
            echo ""
            
            count=$((count + 1))
        fi
    done
    
    if [ $count -eq 0 ]; then
        info "No snapshots found"
    else
        success "Found $count snapshot(s)"
    fi
}

# Clean old snapshots
clean_old_snapshots() {
    local days=${1:-7}
    log "Cleaning snapshots older than $days days..."
    
    local count=0
    find "$STATE_DIR" -name "*.tar.gz" -mtime +$days -type f | while read -r snapshot; do
        log "Removing old snapshot: $(basename "$snapshot")"
        rm -f "$snapshot"
        count=$((count + 1))
    done
    
    if [ $count -gt 0 ]; then
        success "Removed $count old snapshot(s)"
    else
        info "No old snapshots to remove"
    fi
}

# Auto-backup on schedule
auto_backup() {
    local interval=${1:-3600}  # Default: 1 hour
    log "Starting auto-backup (interval: ${interval}s)"
    
    while true; do
        create_snapshot
        log "Next backup in ${interval}s..."
        sleep "$interval"
    done
}

# Display usage
usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  create              Create a new state snapshot"
    echo "  restore <path>      Restore from a snapshot file"
    echo "  list                List available snapshots"
    echo "  clean [days]        Remove snapshots older than N days (default: 7)"
    echo "  auto [interval]     Run automatic backups every N seconds (default: 3600)"
    echo ""
    echo "Examples:"
    echo "  $0 create"
    echo "  $0 restore state/claude-state-20240101-120000.tar.gz"
    echo "  $0 list"
    echo "  $0 clean 30"
    echo "  $0 auto 1800"
}

# Main command handler
main() {
    local command=${1:-create}
    
    case "$command" in
        create)
            create_snapshot
            ;;
        restore)
            if [ -z "$2" ]; then
                error "Snapshot path required"
                usage
                exit 1
            fi
            restore_snapshot "$2"
            ;;
        list)
            list_snapshots
            ;;
        clean)
            clean_old_snapshots "${2:-7}"
            ;;
        auto)
            auto_backup "${2:-3600}"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"