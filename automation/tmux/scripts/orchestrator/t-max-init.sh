#!/bin/bash
# T-Max Orchestrator Initialization Script
# Main entry point for 24/7 Claude Code automation

set -euo pipefail

# Color output for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$BASE_DIR/configs"
SCRIPTS_DIR="$BASE_DIR/scripts"
SESSIONS_DIR="$BASE_DIR/sessions"
LOGS_DIR="$BASE_DIR/logs"
PIPES_DIR="$BASE_DIR/pipes"

# Session configuration
MAIN_SESSION="claude-main"
WORKER_PREFIX="claude-worker"
MONITOR_SESSION="claude-monitor"
HIVE_SESSION="claude-hive"

# Create required directories
mkdir -p "$SESSIONS_DIR" "$LOGS_DIR" "$PIPES_DIR"

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOGS_DIR/orchestrator.log"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGS_DIR/orchestrator.log" >&2
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOGS_DIR/orchestrator.log"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOGS_DIR/orchestrator.log"
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    # Check tmux
    if ! command -v tmux &> /dev/null; then
        error "tmux is not installed"
        exit 1
    fi
    
    # Check Claude Flow
    if ! npx claude-flow --version &> /dev/null; then
        warn "Claude Flow not installed. Installing..."
        npm install -g claude-flow@alpha
    fi
    
    # Check Claude Code
    if ! command -v claude &> /dev/null; then
        error "Claude Code CLI not found. Please install Claude Code"
        exit 1
    fi
    
    log "All dependencies satisfied ✓"
}

# Initialize Claude Flow swarm
init_swarm() {
    log "Initializing Claude Flow swarm..."
    
    # Check if swarm already exists
    if npx claude-flow swarm status &> /dev/null; then
        info "Swarm already initialized"
    else
        npx claude-flow swarm init mesh --max-agents 8 --strategy balanced
        log "Swarm initialized with mesh topology"
    fi
    
    # Initialize memory if needed
    if [ ! -f ".swarm/memory.db" ]; then
        npx claude-flow memory store "orchestrator/initialized" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        log "Memory database initialized"
    fi
}

# Create named pipes for IPC
setup_ipc() {
    log "Setting up inter-process communication..."
    
    # Create control pipe
    CONTROL_PIPE="$PIPES_DIR/control.pipe"
    if [ ! -p "$CONTROL_PIPE" ]; then
        mkfifo "$CONTROL_PIPE"
        log "Control pipe created: $CONTROL_PIPE"
    fi
    
    # Create task distribution pipe
    TASK_PIPE="$PIPES_DIR/tasks.pipe"
    if [ ! -p "$TASK_PIPE" ]; then
        mkfifo "$TASK_PIPE"
        log "Task pipe created: $TASK_PIPE"
    fi
    
    # Create results collection pipe
    RESULTS_PIPE="$PIPES_DIR/results.pipe"
    if [ ! -p "$RESULTS_PIPE" ]; then
        mkfifo "$RESULTS_PIPE"
        log "Results pipe created: $RESULTS_PIPE"
    fi
}

# Load tmux configuration
load_tmux_config() {
    log "Loading tmux configuration..."
    
    TMUX_CONFIG="$CONFIG_DIR/.tmux.claude.conf"
    if [ -f "$TMUX_CONFIG" ]; then
        tmux source-file "$TMUX_CONFIG"
        log "Tmux configuration loaded"
    else
        warn "Tmux config not found at $TMUX_CONFIG"
    fi
}

# Create main orchestrator session
create_main_session() {
    log "Creating main orchestrator session..."
    
    # Check if session exists
    if tmux has-session -t "$MAIN_SESSION" 2>/dev/null; then
        warn "Session $MAIN_SESSION already exists"
        return
    fi
    
    # Create new session with orchestrator
    tmux new-session -d -s "$MAIN_SESSION" -n orchestrator
    
    # Set up orchestrator pane
    tmux send-keys -t "$MAIN_SESSION:orchestrator" "cd $BASE_DIR/../.." C-m
    tmux send-keys -t "$MAIN_SESSION:orchestrator" "clear" C-m
    tmux send-keys -t "$MAIN_SESSION:orchestrator" "echo '🤖 T-Max Orchestrator Ready'" C-m
    tmux send-keys -t "$MAIN_SESSION:orchestrator" "echo 'Session: $MAIN_SESSION'" C-m
    tmux send-keys -t "$MAIN_SESSION:orchestrator" "echo 'Waiting for commands...'" C-m
    
    # Split for monitoring
    tmux split-window -t "$MAIN_SESSION:orchestrator" -h -p 30
    tmux send-keys -t "$MAIN_SESSION:orchestrator.1" "watch -n 1 'npx claude-flow swarm status'" C-m
    
    # Split for logs
    tmux split-window -t "$MAIN_SESSION:orchestrator.1" -v
    tmux send-keys -t "$MAIN_SESSION:orchestrator.2" "tail -f $LOGS_DIR/orchestrator.log" C-m
    
    log "Main orchestrator session created"
}

# Spawn worker sessions
spawn_workers() {
    local num_workers=${1:-4}
    log "Spawning $num_workers worker sessions..."
    
    for i in $(seq 1 $num_workers); do
        local worker_name="${WORKER_PREFIX}-$i"
        
        # Check if worker exists
        if tmux has-session -t "$worker_name" 2>/dev/null; then
            info "Worker $worker_name already exists"
            continue
        fi
        
        # Create worker session
        tmux new-session -d -s "$worker_name" -n worker
        tmux send-keys -t "$worker_name:worker" "bash $SCRIPTS_DIR/orchestrator/claude-worker.sh $i" C-m
        
        log "Worker $i spawned: $worker_name"
    done
}

# Create monitoring dashboard
create_monitor() {
    log "Creating monitoring dashboard..."
    
    if tmux has-session -t "$MONITOR_SESSION" 2>/dev/null; then
        warn "Monitor session already exists"
        return
    fi
    
    tmux new-session -d -s "$MONITOR_SESSION" -n dashboard
    tmux send-keys -t "$MONITOR_SESSION:dashboard" "bash $SCRIPTS_DIR/monitoring/claude-dashboard.sh" C-m
    
    log "Monitoring dashboard created"
}

# Initialize hive mind
init_hive_mind() {
    log "Initializing hive mind coordination..."
    
    if tmux has-session -t "$HIVE_SESSION" 2>/dev/null; then
        warn "Hive session already exists"
        return
    fi
    
    tmux new-session -d -s "$HIVE_SESSION" -n hive
    tmux send-keys -t "$HIVE_SESSION:hive" "npx claude-flow hive-mind spawn --auto-spawn --verbose" C-m
    
    # Split for status monitoring
    tmux split-window -t "$HIVE_SESSION:hive" -h -p 30
    tmux send-keys -t "$HIVE_SESSION:hive.1" "watch -n 1 'npx claude-flow hive-mind status'" C-m
    
    log "Hive mind coordination initialized"
}

# Store session state
store_session_state() {
    log "Storing session state..."
    
    local state_file="$SESSIONS_DIR/state-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$state_file" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "main_session": "$MAIN_SESSION",
  "workers": $(tmux list-sessions -F '#{session_name}' | grep "^$WORKER_PREFIX" | jq -R . | jq -s .),
  "monitor": "$MONITOR_SESSION",
  "hive": "$HIVE_SESSION",
  "pipes": {
    "control": "$PIPES_DIR/control.pipe",
    "tasks": "$PIPES_DIR/tasks.pipe",
    "results": "$PIPES_DIR/results.pipe"
  }
}
EOF
    
    # Store in memory
    npx claude-flow memory store "orchestrator/session/current" "$(cat "$state_file")"
    
    log "Session state stored: $state_file"
}

# Display status
show_status() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}       T-Max Orchestrator Initialization Complete       ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Sessions:${NC}"
    tmux list-sessions 2>/dev/null | sed 's/^/  /'
    echo ""
    echo -e "${BLUE}Quick Commands:${NC}"
    echo "  Attach to main:     tmux attach -t $MAIN_SESSION"
    echo "  View monitor:       tmux attach -t $MONITOR_SESSION"
    echo "  View hive mind:     tmux attach -t $HIVE_SESSION"
    echo "  List all sessions:  tmux ls"
    echo ""
    echo -e "${BLUE}Control:${NC}"
    echo "  Send command:       echo 'command' > $PIPES_DIR/control.pipe"
    echo "  Queue task:         echo 'task' > $PIPES_DIR/tasks.pipe"
    echo "  View logs:          tail -f $LOGS_DIR/orchestrator.log"
    echo ""
    echo -e "${GREEN}System ready for 24/7 operation!${NC}"
    echo ""
}

# Main initialization sequence
main() {
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         T-Max Orchestrator Initialization            ║${NC}"
    echo -e "${GREEN}║       Claude Code 24/7 Automation System             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_dependencies
    init_swarm
    setup_ipc
    load_tmux_config
    create_main_session
    spawn_workers 4
    create_monitor
    init_hive_mind
    store_session_state
    show_status
    
    log "T-Max Orchestrator initialization complete!"
    
    # Optionally attach to main session
    read -p "Attach to main orchestrator session? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tmux attach -t "$MAIN_SESSION"
    fi
}

# Run main function
main "$@"