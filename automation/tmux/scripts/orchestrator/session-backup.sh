#!/bin/bash
# Session Backup - Automated Backup System for T-Max Orchestrator
# Provides scheduled backups with rotation and verification

set -euo pipefail

# Configuration
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGS_DIR="$BASE_DIR/logs"
BACKUPS_DIR="$BASE_DIR/backups"
STATE_DIR="$BASE_DIR/state"
SESSIONS_DIR="$BASE_DIR/sessions"
MEMORY_DB=".swarm/memory.db"

# Backup configuration
BACKUP_PREFIX="tmux-backup"
MAX_BACKUPS=${MAX_BACKUPS:-10}
BACKUP_INTERVAL=${BACKUP_INTERVAL:-3600}  # Default: 1 hour
COMPRESS_BACKUPS=${COMPRESS_BACKUPS:-true}
VERIFY_BACKUPS=${VERIFY_BACKUPS:-true}

# Create directories
mkdir -p "$LOGS_DIR" "$BACKUPS_DIR" "$STATE_DIR" "$SESSIONS_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[Backup]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGS_DIR/backup.log"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGS_DIR/backup.log" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOGS_DIR/backup.log"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOGS_DIR/backup.log"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOGS_DIR/backup.log"
}

# Create backup manifest
create_manifest() {
    local backup_dir="$1"
    local manifest_file="$backup_dir/manifest.json"
    
    cat > "$manifest_file" << EOF
{
    "version": "1.0.0",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "hostname": "$(hostname)",
    "user": "$USER",
    "components": {
        "tmux_sessions": $(tmux list-sessions 2>/dev/null | wc -l || echo 0),
        "memory_keys": $(npx claude-flow memory list 2>/dev/null | wc -l || echo 0),
        "workers": $(ls -1 "$SESSIONS_DIR"/worker-*.state 2>/dev/null | wc -l || echo 0),
        "tasks_pending": $(npx claude-flow memory search "tasks/pending/*" 2>/dev/null | wc -l || echo 0),
        "tasks_completed": $(npx claude-flow memory search "tasks/completed/*" 2>/dev/null | wc -l || echo 0)
    },
    "sizes": {
        "memory_db": "$(du -h "$MEMORY_DB" 2>/dev/null | cut -f1 || echo "N/A")",
        "logs": "$(du -sh "$LOGS_DIR" 2>/dev/null | cut -f1 || echo "N/A")",
        "total": "$(du -sh "$backup_dir" 2>/dev/null | cut -f1 || echo "N/A")"
    }
}
EOF
    
    log "Created backup manifest"
}

# Backup tmux sessions
backup_tmux_sessions() {
    local backup_dir="$1"
    local sessions_dir="$backup_dir/tmux-sessions"
    mkdir -p "$sessions_dir"
    
    log "Backing up tmux sessions..."
    
    # List all sessions
    tmux list-sessions -F "#{session_name}" 2>/dev/null | while read -r session; do
        if [ -n "$session" ]; then
            # Save session layout
            tmux list-windows -t "$session" -F "#{window_index}:#{window_name}:#{window_layout}" \
                > "$sessions_dir/${session}.layout" 2>/dev/null || true
            
            # Save pane contents
            tmux list-panes -t "$session" -F "#{pane_index}" 2>/dev/null | while read -r pane; do
                tmux capture-pane -t "$session:$pane" -p \
                    > "$sessions_dir/${session}-pane-${pane}.txt" 2>/dev/null || true
            done
            
            # Save session history
            tmux show-buffer -t "$session" \
                > "$sessions_dir/${session}.history" 2>/dev/null || true
        fi
    done
    
    local session_count=$(ls -1 "$sessions_dir"/*.layout 2>/dev/null | wc -l || echo 0)
    log "Backed up $session_count tmux sessions"
}

# Backup memory database
backup_memory() {
    local backup_dir="$1"
    local memory_dir="$backup_dir/memory"
    mkdir -p "$memory_dir"
    
    log "Backing up memory database..."
    
    if [ -f "$MEMORY_DB" ]; then
        # Binary backup
        cp "$MEMORY_DB" "$memory_dir/memory.db"
        
        # SQL dump for safety
        sqlite3 "$MEMORY_DB" ".dump" > "$memory_dir/memory.sql" 2>/dev/null || true
        
        # Export critical keys as JSON
        npx claude-flow memory list 2>/dev/null | while read -r key; do
            if [ -n "$key" ]; then
                local value=$(npx claude-flow memory get "$key" 2>/dev/null)
                echo "{\"key\": \"$key\", \"value\": $value}" >> "$memory_dir/memory-export.jsonl"
            fi
        done
        
        success "Memory database backed up"
    else
        warn "Memory database not found"
    fi
}

# Backup worker states
backup_worker_states() {
    local backup_dir="$1"
    local workers_dir="$backup_dir/workers"
    mkdir -p "$workers_dir"
    
    log "Backing up worker states..."
    
    for i in {1..8}; do
        local state_file="$SESSIONS_DIR/worker-$i.state"
        if [ -f "$state_file" ]; then
            cp "$state_file" "$workers_dir/"
        fi
        
        # Backup worker memory
        local worker_data=$(npx claude-flow memory search "worker/$i/*" 2>/dev/null)
        if [ -n "$worker_data" ]; then
            echo "$worker_data" > "$workers_dir/worker-$i-memory.txt"
        fi
    done
    
    local worker_count=$(ls -1 "$workers_dir"/*.state 2>/dev/null | wc -l || echo 0)
    log "Backed up $worker_count worker states"
}

# Backup logs
backup_logs() {
    local backup_dir="$1"
    local logs_backup="$backup_dir/logs"
    mkdir -p "$logs_backup"
    
    log "Backing up logs..."
    
    # Copy recent logs (last 1000 lines of each)
    for logfile in "$LOGS_DIR"/*.log; do
        if [ -f "$logfile" ]; then
            local basename=$(basename "$logfile")
            tail -1000 "$logfile" > "$logs_backup/$basename" 2>/dev/null || true
        fi
    done
    
    log "Logs backed up"
}

# Backup configurations
backup_configs() {
    local backup_dir="$1"
    local configs_dir="$backup_dir/configs"
    mkdir -p "$configs_dir"
    
    log "Backing up configurations..."
    
    # Backup Claude settings
    if [ -f ".claude/settings.json" ]; then
        cp ".claude/settings.json" "$configs_dir/"
    fi
    
    # Backup swarm configuration
    local swarm_config=$(npx claude-flow swarm status 2>/dev/null | head -20)
    echo "$swarm_config" > "$configs_dir/swarm-config.txt"
    
    # Backup environment
    env | grep -E "^(CLAUDE|SWARM|MCP)" > "$configs_dir/environment.txt" 2>/dev/null || true
    
    log "Configurations backed up"
}

# Verify backup integrity
verify_backup() {
    local backup_path="$1"
    
    log "Verifying backup integrity..."
    
    local errors=0
    
    # Check manifest exists
    if [ ! -f "$backup_path/manifest.json" ]; then
        error "Missing manifest.json"
        errors=$((errors + 1))
    fi
    
    # Check critical directories
    for dir in tmux-sessions memory workers logs configs; do
        if [ ! -d "$backup_path/$dir" ]; then
            warn "Missing directory: $dir"
            errors=$((errors + 1))
        fi
    done
    
    # Check memory database
    if [ -f "$backup_path/memory/memory.db" ]; then
        if ! sqlite3 "$backup_path/memory/memory.db" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
            error "Memory database corrupt in backup"
            errors=$((errors + 1))
        fi
    fi
    
    if [ $errors -eq 0 ]; then
        success "Backup verification passed"
        return 0
    else
        error "Backup verification failed with $errors errors"
        return 1
    fi
}

# Compress backup
compress_backup() {
    local backup_dir="$1"
    local backup_name=$(basename "$backup_dir")
    local compressed_path="$backup_dir.tar.gz"
    
    log "Compressing backup..."
    
    tar -czf "$compressed_path" -C "$BACKUPS_DIR" "$backup_name" 2>/dev/null
    
    if [ -f "$compressed_path" ]; then
        # Remove uncompressed directory
        rm -rf "$backup_dir"
        
        local size=$(du -h "$compressed_path" | cut -f1)
        success "Backup compressed: $compressed_path ($size)"
        echo "$compressed_path"
    else
        error "Compression failed"
        echo "$backup_dir"
    fi
}

# Rotate old backups
rotate_backups() {
    log "Rotating old backups (keeping last $MAX_BACKUPS)..."
    
    # Count existing backups
    local backup_count=$(ls -1 "$BACKUPS_DIR"/${BACKUP_PREFIX}-*.tar.gz 2>/dev/null | wc -l || echo 0)
    
    if [ "$backup_count" -gt "$MAX_BACKUPS" ]; then
        local remove_count=$((backup_count - MAX_BACKUPS))
        
        # Remove oldest backups
        ls -1t "$BACKUPS_DIR"/${BACKUP_PREFIX}-*.tar.gz 2>/dev/null | tail -n "$remove_count" | while read -r old_backup; do
            log "Removing old backup: $(basename "$old_backup")"
            rm -f "$old_backup"
        done
        
        success "Removed $remove_count old backup(s)"
    fi
}

# Create full backup
create_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="${BACKUP_PREFIX}-${timestamp}"
    local backup_dir="$BACKUPS_DIR/$backup_name"
    
    log "Creating backup: $backup_name"
    mkdir -p "$backup_dir"
    
    # Store backup start in memory
    npx claude-flow memory store "backup/running/$timestamp" "{
        \"status\": \"running\",
        \"started\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
    }" 2>/dev/null || true
    
    # Perform backups
    backup_tmux_sessions "$backup_dir"
    backup_memory "$backup_dir"
    backup_worker_states "$backup_dir"
    backup_logs "$backup_dir"
    backup_configs "$backup_dir"
    
    # Create manifest
    create_manifest "$backup_dir"
    
    # Verify backup
    if [ "$VERIFY_BACKUPS" = true ]; then
        if ! verify_backup "$backup_dir"; then
            error "Backup verification failed, keeping unverified backup"
        fi
    fi
    
    # Compress if enabled
    local final_path="$backup_dir"
    if [ "$COMPRESS_BACKUPS" = true ]; then
        final_path=$(compress_backup "$backup_dir")
    fi
    
    # Rotate old backups
    rotate_backups
    
    # Store backup completion in memory
    npx claude-flow memory store "backup/completed/$timestamp" "{
        \"status\": \"completed\",
        \"path\": \"$final_path\",
        \"size\": \"$(du -h "$final_path" | cut -f1)\",
        \"completed\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
    }" 2>/dev/null || true
    
    # Remove running status
    npx claude-flow memory delete "backup/running/$timestamp" 2>/dev/null || true
    
    success "Backup completed: $final_path"
    return 0
}

# Restore from backup
restore_backup() {
    local backup_path="$1"
    
    if [ ! -f "$backup_path" ] && [ ! -d "$backup_path" ]; then
        error "Backup not found: $backup_path"
        return 1
    fi
    
    log "Restoring from backup: $backup_path"
    
    # Extract if compressed
    local restore_dir="$backup_path"
    if [[ "$backup_path" == *.tar.gz ]]; then
        restore_dir="/tmp/restore-$$"
        mkdir -p "$restore_dir"
        tar -xzf "$backup_path" -C "$restore_dir"
        restore_dir="$restore_dir/$(ls -1 "$restore_dir" | head -1)"
    fi
    
    # Verify backup before restore
    if ! verify_backup "$restore_dir"; then
        error "Backup verification failed, aborting restore"
        [ -d "/tmp/restore-$$" ] && rm -rf "/tmp/restore-$$"
        return 1
    fi
    
    # Restore memory database
    if [ -f "$restore_dir/memory/memory.db" ]; then
        log "Restoring memory database..."
        mkdir -p "$(dirname "$MEMORY_DB")"
        cp "$restore_dir/memory/memory.db" "$MEMORY_DB"
        success "Memory database restored"
    fi
    
    # Restore worker states
    if [ -d "$restore_dir/workers" ]; then
        log "Restoring worker states..."
        cp "$restore_dir/workers"/*.state "$SESSIONS_DIR/" 2>/dev/null || true
        success "Worker states restored"
    fi
    
    # Restore configurations
    if [ -d "$restore_dir/configs" ]; then
        log "Restoring configurations..."
        [ -f "$restore_dir/configs/settings.json" ] && \
            cp "$restore_dir/configs/settings.json" ".claude/"
        success "Configurations restored"
    fi
    
    # Clean up temp directory
    [ -d "/tmp/restore-$$" ] && rm -rf "/tmp/restore-$$"
    
    success "Backup restoration complete"
    
    # Log restoration event
    npx claude-flow memory store "backup/restored/$(date +%s)" "{
        \"backup\": \"$backup_path\",
        \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
    }" 2>/dev/null || true
}

# List available backups
list_backups() {
    log "Available backups:"
    echo ""
    
    local count=0
    for backup in "$BACKUPS_DIR"/${BACKUP_PREFIX}-*.tar.gz "$BACKUPS_DIR"/${BACKUP_PREFIX}-*/; do
        if [ -e "$backup" ]; then
            local name=$(basename "$backup" .tar.gz)
            local size=$(du -h "$backup" | cut -f1)
            local date=$(stat -c %y "$backup" 2>/dev/null || stat -f "%Sm" "$backup" 2>/dev/null)
            
            echo -e "${CYAN}$name${NC}"
            echo "  Path: $backup"
            echo "  Size: $size"
            echo "  Date: $date"
            
            # Check if manifest exists
            if [ -f "$backup" ]; then
                # Compressed backup - extract manifest
                local manifest=$(tar -xzOf "$backup" "*/manifest.json" 2>/dev/null | head -20)
            else
                # Uncompressed backup
                local manifest=$(cat "$backup/manifest.json" 2>/dev/null | head -20)
            fi
            
            if [ -n "$manifest" ]; then
                echo "  Sessions: $(echo "$manifest" | jq -r '.components.tmux_sessions' 2>/dev/null || echo "N/A")"
                echo "  Memory Keys: $(echo "$manifest" | jq -r '.components.memory_keys' 2>/dev/null || echo "N/A")"
            fi
            echo ""
            
            count=$((count + 1))
        fi
    done
    
    if [ $count -eq 0 ]; then
        info "No backups found"
    else
        success "Found $count backup(s)"
    fi
}

# Automated backup daemon
backup_daemon() {
    log "Starting backup daemon (interval: ${BACKUP_INTERVAL}s)"
    
    # Store daemon PID
    echo $$ > "$BASE_DIR/backup-daemon.pid"
    
    # Trap signals for clean shutdown
    trap 'log "Backup daemon shutting down..."; rm -f "$BASE_DIR/backup-daemon.pid"; exit 0' INT TERM
    
    while true; do
        # Create backup
        if create_backup; then
            log "Scheduled backup completed"
        else
            error "Scheduled backup failed"
        fi
        
        # Update daemon status in memory
        npx claude-flow memory store "backup/daemon/status" "{
            \"pid\": $$,
            \"interval\": $BACKUP_INTERVAL,
            \"last_backup\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
            \"next_backup\": \"$(date -u -d "+$BACKUP_INTERVAL seconds" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")\"
        }" 2>/dev/null || true
        
        # Sleep until next backup
        log "Next backup in ${BACKUP_INTERVAL}s..."
        sleep "$BACKUP_INTERVAL"
    done
}

# Stop backup daemon
stop_daemon() {
    if [ -f "$BASE_DIR/backup-daemon.pid" ]; then
        local pid=$(cat "$BASE_DIR/backup-daemon.pid")
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping backup daemon (PID: $pid)"
            kill "$pid"
            rm -f "$BASE_DIR/backup-daemon.pid"
            success "Backup daemon stopped"
        else
            warn "Daemon not running (stale PID file)"
            rm -f "$BASE_DIR/backup-daemon.pid"
        fi
    else
        info "No backup daemon running"
    fi
}

# Display usage
usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  create              Create a new backup"
    echo "  restore <path>      Restore from backup file"
    echo "  list                List available backups"
    echo "  daemon              Start backup daemon"
    echo "  stop                Stop backup daemon"
    echo "  rotate              Manually rotate old backups"
    echo ""
    echo "Options:"
    echo "  --interval <sec>    Backup interval for daemon (default: 3600)"
    echo "  --max-backups <n>   Maximum backups to keep (default: 10)"
    echo "  --no-compress       Don't compress backups"
    echo "  --no-verify         Skip backup verification"
    echo ""
    echo "Examples:"
    echo "  $0 create"
    echo "  $0 restore backups/tmux-backup-20240101-120000.tar.gz"
    echo "  $0 daemon --interval 1800"
    echo "  $0 list"
}

# Parse command line options
parse_options() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interval)
                BACKUP_INTERVAL="$2"
                shift 2
                ;;
            --max-backups)
                MAX_BACKUPS="$2"
                shift 2
                ;;
            --no-compress)
                COMPRESS_BACKUPS=false
                shift
                ;;
            --no-verify)
                VERIFY_BACKUPS=false
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
}

# Main command handler
main() {
    local command=${1:-create}
    shift
    
    # Parse additional options
    parse_options "$@"
    
    case "$command" in
        create)
            create_backup
            ;;
        restore)
            if [ -z "$1" ]; then
                error "Backup path required"
                usage
                exit 1
            fi
            restore_backup "$1"
            ;;
        list)
            list_backups
            ;;
        daemon)
            backup_daemon
            ;;
        stop)
            stop_daemon
            ;;
        rotate)
            rotate_backups
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