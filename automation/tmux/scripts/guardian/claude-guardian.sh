#!/bin/bash
# Claude Guardian - Health Monitoring & Recovery System
# Ensures 24/7 operation with automatic recovery

set -euo pipefail

# Configuration
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGS_DIR="$BASE_DIR/logs"
PIPES_DIR="$BASE_DIR/pipes"
SESSIONS_DIR="$BASE_DIR/sessions"
GUARDIAN_LOG="$LOGS_DIR/guardian.log"

# Create directories
mkdir -p "$LOGS_DIR" "$SESSIONS_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Guardian state
MONITORING_INTERVAL=${MONITORING_INTERVAL:-30}
MAX_RETRIES=${MAX_RETRIES:-3}
MEMORY_THRESHOLD=${MEMORY_THRESHOLD:-80}
CPU_THRESHOLD=${CPU_THRESHOLD:-90}
RECOVERY_MODE=false

# Session configuration
MAIN_SESSION="claude-main"
WORKER_PREFIX="claude-worker"
MONITOR_SESSION="claude-monitor"
HIVE_SESSION="claude-hive"

# Logging
log() {
    echo -e "${GREEN}[Guardian]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$GUARDIAN_LOG"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$GUARDIAN_LOG" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$GUARDIAN_LOG"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$GUARDIAN_LOG"
}

critical() {
    echo -e "${MAGENTA}[CRITICAL]${NC} $1" | tee -a "$GUARDIAN_LOG"
    # Send notification (placeholder for actual notification system)
    npx claude-flow memory store "guardian/alert/$(date +%s)" "{\"level\": \"critical\", \"message\": \"$1\"}" 2>/dev/null || true
}

# Check system resources
check_system_resources() {
    local status="healthy"
    
    # CPU check
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}' 2>/dev/null || echo 0)
    if [ "$cpu_usage" -gt "$CPU_THRESHOLD" ]; then
        warn "High CPU usage: ${cpu_usage}%"
        status="degraded"
    fi
    
    # Memory check
    local mem_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}' 2>/dev/null || echo 0)
    if [ "$mem_usage" -gt "$MEMORY_THRESHOLD" ]; then
        warn "High memory usage: ${mem_usage}%"
        status="degraded"
    fi
    
    # Disk check
    local disk_usage=$(df -h . | tail -1 | awk '{print int($5)}' 2>/dev/null || echo 0)
    if [ "$disk_usage" -gt 90 ]; then
        critical "Critical disk usage: ${disk_usage}%"
        status="critical"
    fi
    
    echo "$status"
}

# Check tmux sessions
check_tmux_sessions() {
    local healthy=0
    local unhealthy=0
    
    # Check main session
    if tmux has-session -t "$MAIN_SESSION" 2>/dev/null; then
        healthy=$((healthy + 1))
    else
        error "Main session not found: $MAIN_SESSION"
        unhealthy=$((unhealthy + 1))
        recover_session "$MAIN_SESSION" "main"
    fi
    
    # Check worker sessions
    for i in {1..8}; do
        local worker_name="${WORKER_PREFIX}-$i"
        local worker_state=$(npx claude-flow memory get "worker/$i/state" 2>/dev/null | tr -d '"')
        
        if [ -n "$worker_state" ] && [ "$worker_state" != "stopped" ]; then
            if tmux has-session -t "$worker_name" 2>/dev/null; then
                healthy=$((healthy + 1))
                check_worker_health "$i"
            else
                error "Worker session missing: $worker_name"
                unhealthy=$((unhealthy + 1))
                recover_worker "$i"
            fi
        fi
    done
    
    # Check monitor session
    if tmux has-session -t "$MONITOR_SESSION" 2>/dev/null; then
        healthy=$((healthy + 1))
    else
        warn "Monitor session not found: $MONITOR_SESSION"
        recover_session "$MONITOR_SESSION" "monitor"
    fi
    
    # Check hive session
    if tmux has-session -t "$HIVE_SESSION" 2>/dev/null; then
        healthy=$((healthy + 1))
    else
        warn "Hive session not found: $HIVE_SESSION"
        recover_session "$HIVE_SESSION" "hive"
    fi
    
    info "Session health: $healthy healthy, $unhealthy unhealthy"
    
    if [ "$unhealthy" -gt 0 ]; then
        return 1
    fi
    return 0
}

# Check worker health
check_worker_health() {
    local worker_id=$1
    local worker_name="${WORKER_PREFIX}-$worker_id"
    
    # Check heartbeat
    local heartbeat=$(npx claude-flow memory get "worker/$worker_id/heartbeat" 2>/dev/null | tr -d '"')
    
    if [ -n "$heartbeat" ]; then
        local heartbeat_epoch=$(date -d "$heartbeat" +%s 2>/dev/null || echo 0)
        local current_epoch=$(date +%s)
        local diff=$((current_epoch - heartbeat_epoch))
        
        if [ $diff -gt 120 ]; then
            warn "Worker $worker_id heartbeat stale (${diff}s ago)"
            
            # Check if worker is stuck
            local state=$(npx claude-flow memory get "worker/$worker_id/state" 2>/dev/null | tr -d '"')
            if [ "$state" == "processing" ] && [ $diff -gt 300 ]; then
                error "Worker $worker_id appears stuck, attempting recovery"
                restart_worker "$worker_id"
            fi
        fi
    else
        warn "Worker $worker_id has no heartbeat"
    fi
    
    # Check memory usage
    local worker_memory=$(npx claude-flow memory get "worker/$worker_id/memory" 2>/dev/null | tr -d '"')
    if [ -n "$worker_memory" ] && [ "${worker_memory%.*}" -gt 50 ]; then
        warn "Worker $worker_id high memory usage: ${worker_memory}%"
    fi
}

# Check swarm health
check_swarm_health() {
    local swarm_status=$(npx claude-flow swarm status 2>/dev/null | head -1)
    
    if [ -z "$swarm_status" ]; then
        error "Swarm not responding"
        recover_swarm
        return 1
    fi
    
    # Check agent metrics
    local agent_count=$(npx claude-flow agent list 2>/dev/null | wc -l)
    if [ "$agent_count" -lt 1 ]; then
        warn "No active agents in swarm"
        npx claude-flow swarm init mesh --max-agents 8 2>/dev/null || true
    fi
    
    return 0
}

# Check memory database
check_memory_health() {
    local db_file=".swarm/memory.db"
    
    if [ ! -f "$db_file" ]; then
        error "Memory database not found"
        npx claude-flow memory store "guardian/recovery" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 2>/dev/null || true
        return 1
    fi
    
    # Check database integrity
    if ! sqlite3 "$db_file" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
        critical "Memory database corrupted!"
        backup_and_recover_database
        return 1
    fi
    
    # Check database size
    local db_size=$(du -m "$db_file" | cut -f1)
    if [ "$db_size" -gt 500 ]; then
        warn "Memory database large: ${db_size}MB"
        archive_old_memories
    fi
    
    return 0
}

# Recover session
recover_session() {
    local session_name=$1
    local session_type=$2
    
    log "Recovering session: $session_name"
    
    case "$session_type" in
        "main")
            tmux new-session -d -s "$session_name" -n orchestrator
            tmux send-keys -t "$session_name:orchestrator" "cd $BASE_DIR/../.." C-m
            tmux send-keys -t "$session_name:orchestrator" "echo '🔄 Session recovered by Guardian'" C-m
            ;;
        "monitor")
            tmux new-session -d -s "$session_name" -n dashboard
            tmux send-keys -t "$session_name:dashboard" "bash $BASE_DIR/scripts/monitoring/claude-dashboard.sh" C-m
            ;;
        "hive")
            tmux new-session -d -s "$session_name" -n hive
            tmux send-keys -t "$session_name:hive" "npx claude-flow hive-mind spawn --auto-spawn" C-m
            ;;
    esac
    
    log "Session recovered: $session_name"
}

# Recover worker
recover_worker() {
    local worker_id=$1
    local worker_name="${WORKER_PREFIX}-$worker_id"
    
    log "Recovering worker: $worker_name"
    
    # Kill existing session if stuck
    tmux kill-session -t "$worker_name" 2>/dev/null || true
    
    # Create new worker session
    tmux new-session -d -s "$worker_name" -n worker
    tmux send-keys -t "$worker_name:worker" "bash $BASE_DIR/scripts/orchestrator/claude-worker.sh $worker_id" C-m
    
    # Update state
    npx claude-flow memory store "worker/$worker_id/state" "recovering" 2>/dev/null || true
    npx claude-flow memory store "worker/$worker_id/recovered" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 2>/dev/null || true
    
    log "Worker recovered: $worker_name"
}

# Restart worker
restart_worker() {
    local worker_id=$1
    local worker_name="${WORKER_PREFIX}-$worker_id"
    
    log "Restarting worker: $worker_name"
    
    # Send reload command
    echo "worker-$worker_id:reload" > "$PIPES_DIR/control.pipe" 2>/dev/null || true
    
    sleep 2
    
    # If still stuck, force restart
    if ! tmux send-keys -t "$worker_name:worker" "C-c" 2>/dev/null; then
        recover_worker "$worker_id"
    fi
}

# Recover swarm
recover_swarm() {
    log "Recovering swarm..."
    
    # Re-initialize swarm
    npx claude-flow swarm init mesh --max-agents 8 --strategy balanced 2>/dev/null || true
    
    # Restore agents
    for agent_type in coordinator analyst optimizer; do
        npx claude-flow agent spawn --type "$agent_type" 2>/dev/null || true
    done
    
    log "Swarm recovery complete"
}

# Backup and recover database
backup_and_recover_database() {
    local db_file=".swarm/memory.db"
    local backup_file=".swarm/memory.db.backup.$(date +%Y%m%d%H%M%S)"
    
    critical "Backing up corrupted database to: $backup_file"
    cp "$db_file" "$backup_file" 2>/dev/null || true
    
    # Try to recover what we can
    sqlite3 "$db_file" ".dump" > ".swarm/memory.sql" 2>/dev/null || true
    
    # Create new database
    rm -f "$db_file"
    npx claude-flow memory store "guardian/database_recovered" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" 2>/dev/null || true
    
    # Try to restore from dump
    if [ -f ".swarm/memory.sql" ]; then
        sqlite3 "$db_file" < ".swarm/memory.sql" 2>/dev/null || true
        rm -f ".swarm/memory.sql"
    fi
    
    log "Database recovery complete"
}

# Archive old memories
archive_old_memories() {
    log "Archiving old memories..."
    
    local archive_dir=".swarm/archives"
    mkdir -p "$archive_dir"
    
    local archive_file="$archive_dir/memory-$(date +%Y%m%d%H%M%S).db"
    
    # Export old data
    sqlite3 ".swarm/memory.db" "
        ATTACH DATABASE '$archive_file' AS archive;
        CREATE TABLE archive.memory_store AS 
        SELECT * FROM main.memory_store 
        WHERE created_at < datetime('now', '-7 days');
        DELETE FROM main.memory_store 
        WHERE created_at < datetime('now', '-7 days');
        VACUUM;
    " 2>/dev/null || true
    
    log "Archived old memories to: $archive_file"
}

# Display status
display_status() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    CLAUDE GUARDIAN                            ║${NC}"
    echo -e "${CYAN}║               Health Monitoring & Recovery                     ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Monitoring Interval:${NC} ${MONITORING_INTERVAL}s"
    echo -e "${YELLOW}Recovery Mode:${NC} $([ "$RECOVERY_MODE" = true ] && echo "${RED}ACTIVE${NC}" || echo "${GREEN}STANDBY${NC}")"
    echo ""
    echo -e "${GREEN}System Resources:${NC} $(check_system_resources)"
    echo ""
    echo -e "${GREEN}Active Sessions:${NC}"
    tmux list-sessions 2>/dev/null | sed 's/^/  /' || echo "  No sessions"
    echo ""
    echo -e "${GREEN}Last Check:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop guardian${NC}"
}

# Signal handlers
trap 'log "Guardian shutting down..."; exit 0' INT TERM

# Main monitoring loop
main() {
    log "Guardian starting - Monitoring interval: ${MONITORING_INTERVAL}s"
    
    # Initial status display
    display_status
    
    local check_counter=0
    local failure_count=0
    
    while true; do
        check_counter=$((check_counter + 1))
        
        # System resource check
        local system_status=$(check_system_resources)
        
        # Session health check
        if ! check_tmux_sessions; then
            failure_count=$((failure_count + 1))
            RECOVERY_MODE=true
        else
            RECOVERY_MODE=false
        fi
        
        # Swarm health check (every 5 cycles)
        if [ $((check_counter % 5)) -eq 0 ]; then
            check_swarm_health
        fi
        
        # Memory health check (every 10 cycles)
        if [ $((check_counter % 10)) -eq 0 ]; then
            check_memory_health
        fi
        
        # Store health status
        npx claude-flow memory store "guardian/health/$(date +%s)" "{
            \"system\": \"$system_status\",
            \"sessions\": $(tmux list-sessions 2>/dev/null | wc -l || echo 0),
            \"recovery_mode\": $RECOVERY_MODE,
            \"failures\": $failure_count,
            \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
        }" 2>/dev/null || true
        
        # Reset failure count if healthy
        if [ "$RECOVERY_MODE" = false ] && [ "$system_status" = "healthy" ]; then
            failure_count=0
        fi
        
        # Critical failure threshold
        if [ "$failure_count" -gt "$MAX_RETRIES" ]; then
            critical "Max failures reached! Manual intervention required."
            failure_count=0  # Reset to continue monitoring
        fi
        
        # Update display
        if [ $((check_counter % 2)) -eq 0 ]; then
            display_status
        fi
        
        # Sleep for monitoring interval
        sleep "$MONITORING_INTERVAL"
    done
}

# Start guardian
main "$@"