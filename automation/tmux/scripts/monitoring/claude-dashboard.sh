#!/bin/bash
# Claude Dashboard - Real-time Monitoring Dashboard
# Displays system metrics, worker status, and task progress

set -euo pipefail

# Configuration
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGS_DIR="$BASE_DIR/logs"
PIPES_DIR="$BASE_DIR/pipes"
SESSIONS_DIR="$BASE_DIR/sessions"

# Color scheme
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# Dashboard state
REFRESH_RATE=1
CURRENT_VIEW="overview"
AUTO_REFRESH=true

# Clear screen and move cursor
clear_screen() {
    clear
    tput cup 0 0
}

# Draw a box
draw_box() {
    local width=$1
    local title="$2"
    local color=${3:-$CYAN}
    
    echo -ne "${color}"
    printf '┌'
    printf '─%.0s' $(seq 1 $((width - 2)))
    printf '┐\n'
    
    if [ -n "$title" ]; then
        local padding=$(( (width - ${#title} - 2) / 2 ))
        printf '│'
        printf ' %.0s' $(seq 1 $padding)
        echo -ne "${BOLD}$title${NC}${color}"
        printf ' %.0s' $(seq 1 $((width - padding - ${#title} - 2)))
        printf '│\n'
    fi
    echo -ne "${NC}"
}

# Get swarm status
get_swarm_status() {
    local status=$(npx claude-flow swarm status 2>/dev/null | head -20)
    if [ -z "$status" ]; then
        echo "Swarm not initialized"
    else
        echo "$status"
    fi
}

# Get worker statuses
get_worker_status() {
    local workers=""
    for i in {1..8}; do
        local state=$(npx claude-flow memory get "worker/$i/state" 2>/dev/null | tr -d '"')
        local heartbeat=$(npx claude-flow memory get "worker/$i/heartbeat" 2>/dev/null | tr -d '"')
        
        if [ -n "$state" ]; then
            local color=$GREEN
            local icon="✓"
            
            case "$state" in
                "processing") color=$YELLOW; icon="⌛" ;;
                "paused") color=$GRAY; icon="⏸" ;;
                "error") color=$RED; icon="✗" ;;
                "stopped") color=$GRAY; icon="■" ;;
                "idle") color=$GREEN; icon="•" ;;
            esac
            
            workers="${workers}${color}[$icon Worker-$i: $state]${NC} "
            
            # Check if heartbeat is recent (within 60 seconds)
            if [ -n "$heartbeat" ]; then
                local heartbeat_epoch=$(date -d "$heartbeat" +%s 2>/dev/null || echo 0)
                local current_epoch=$(date +%s)
                local diff=$((current_epoch - heartbeat_epoch))
                
                if [ $diff -gt 60 ]; then
                    workers="${workers}${RED}(stale)${NC} "
                fi
            fi
            
            workers="${workers}\n"
        fi
    done
    
    if [ -z "$workers" ]; then
        echo "No active workers"
    else
        echo -e "$workers"
    fi
}

# Get task statistics
get_task_stats() {
    local pending=$(npx claude-flow memory search "tasks/pending/*" 2>/dev/null | wc -l)
    local completed=$(npx claude-flow memory search "tasks/completed/*" 2>/dev/null | wc -l)
    local failed=$(npx claude-flow memory search "tasks/failed/*" 2>/dev/null | wc -l)
    
    echo -e "${GREEN}Completed: $completed${NC} | ${YELLOW}Pending: $pending${NC} | ${RED}Failed: $failed${NC}"
}

# Get recent tasks
get_recent_tasks() {
    local tasks=$(npx claude-flow memory search "tasks/completed/*" 2>/dev/null | tail -5)
    if [ -z "$tasks" ]; then
        echo "No recent tasks"
    else
        echo "$tasks" | while read -r task; do
            local task_data=$(npx claude-flow memory get "$task" 2>/dev/null)
            if [ -n "$task_data" ]; then
                echo "  • ${task##*/}: $(echo "$task_data" | jq -r '.task' 2>/dev/null || echo "Unknown")"
            fi
        done
    fi
}

# Get memory usage
get_memory_stats() {
    local total_keys=$(npx claude-flow memory list 2>/dev/null | wc -l)
    local db_size="Unknown"
    
    if [ -f ".swarm/memory.db" ]; then
        db_size=$(du -h ".swarm/memory.db" | cut -f1)
    fi
    
    echo "Keys: $total_keys | Database: $db_size"
}

# Get system metrics
get_system_metrics() {
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
    
    # Memory usage
    local mem_info=$(free -h 2>/dev/null | grep "^Mem:" || echo "Mem: 0 0 0")
    local mem_used=$(echo "$mem_info" | awk '{print $3}')
    local mem_total=$(echo "$mem_info" | awk '{print $2}')
    
    # Disk usage
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' 2>/dev/null || echo "0%")
    
    # Tmux sessions
    local tmux_sessions=$(tmux list-sessions 2>/dev/null | wc -l || echo "0")
    
    echo -e "CPU: ${cpu_usage}% | Memory: $mem_used/$mem_total | Disk: $disk_usage | Sessions: $tmux_sessions"
}

# Get agent metrics
get_agent_metrics() {
    local metrics=$(npx claude-flow agent metrics 2>/dev/null | head -10)
    if [ -z "$metrics" ]; then
        echo "No agent metrics available"
    else
        echo "$metrics"
    fi
}

# Draw the main dashboard
draw_dashboard() {
    clear_screen
    
    # Header
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║        CLAUDE FLOW MONITORING DASHBOARD              ║${NC}"
    echo -e "${CYAN}${BOLD}║               $(date '+%Y-%m-%d %H:%M:%S')                    ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # System Metrics
    draw_box 60 "System Metrics" $GREEN
    echo -e "  $(get_system_metrics)"
    echo ""
    
    # Swarm Status
    draw_box 60 "Swarm Status" $BLUE
    echo "$(get_swarm_status)" | head -5 | sed 's/^/  /'
    echo ""
    
    # Worker Status
    draw_box 60 "Worker Status" $YELLOW
    echo "$(get_worker_status)" | sed 's/^/  /'
    echo ""
    
    # Task Statistics
    draw_box 60 "Task Statistics" $MAGENTA
    echo -e "  $(get_task_stats)"
    echo ""
    echo "  Recent Tasks:"
    echo "$(get_recent_tasks)"
    echo ""
    
    # Memory Statistics
    draw_box 60 "Memory Store" $CYAN
    echo -e "  $(get_memory_stats)"
    echo ""
    
    # Agent Metrics
    draw_box 60 "Agent Metrics" $GREEN
    echo "$(get_agent_metrics)" | head -5 | sed 's/^/  /'
    echo ""
    
    # Footer with controls
    echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}Controls:${NC} [r]efresh | [p]ause | [w]orkers | [t]asks | [q]uit"
    echo -e "${WHITE}Auto-refresh:${NC} $([ "$AUTO_REFRESH" = true ] && echo "${GREEN}ON${NC}" || echo "${RED}OFF${NC}") | ${WHITE}Interval:${NC} ${REFRESH_RATE}s"
}

# Draw workers view
draw_workers_view() {
    clear_screen
    
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                  WORKER DETAILS                      ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    for i in {1..8}; do
        local state=$(npx claude-flow memory get "worker/$i/state" 2>/dev/null | tr -d '"')
        
        if [ -n "$state" ]; then
            local stats=$(npx claude-flow memory get "worker/$i/stats" 2>/dev/null)
            local heartbeat=$(npx claude-flow memory get "worker/$i/heartbeat" 2>/dev/null | tr -d '"')
            local memory=$(npx claude-flow memory get "worker/$i/memory" 2>/dev/null | tr -d '"')
            
            draw_box 60 "Worker $i" $YELLOW
            echo "  State: $state"
            
            if [ -n "$stats" ]; then
                local completed=$(echo "$stats" | jq -r '.completed' 2>/dev/null || echo "0")
                local failed=$(echo "$stats" | jq -r '.failed' 2>/dev/null || echo "0")
                echo "  Tasks: Completed: $completed | Failed: $failed"
            fi
            
            if [ -n "$heartbeat" ]; then
                echo "  Last Heartbeat: $heartbeat"
            fi
            
            if [ -n "$memory" ]; then
                echo "  Memory Usage: ${memory}%"
            fi
            
            echo ""
        fi
    done
    
    echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}[b]ack to overview | [q]uit${NC}"
}

# Draw tasks view
draw_tasks_view() {
    clear_screen
    
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                    TASK QUEUE                        ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Pending tasks
    draw_box 60 "Pending Tasks" $YELLOW
    local pending_tasks=$(npx claude-flow memory search "tasks/pending/*" 2>/dev/null | head -10)
    if [ -z "$pending_tasks" ]; then
        echo "  No pending tasks"
    else
        echo "$pending_tasks" | while read -r task; do
            echo "  • ${task##*/}"
        done
    fi
    echo ""
    
    # Completed tasks
    draw_box 60 "Recent Completed Tasks" $GREEN
    local completed_tasks=$(npx claude-flow memory search "tasks/completed/*" 2>/dev/null | tail -10)
    if [ -z "$completed_tasks" ]; then
        echo "  No completed tasks"
    else
        echo "$completed_tasks" | while read -r task; do
            local task_data=$(npx claude-flow memory get "$task" 2>/dev/null)
            if [ -n "$task_data" ]; then
                local task_desc=$(echo "$task_data" | jq -r '.task' 2>/dev/null || echo "Unknown")
                local worker=$(echo "$task_data" | jq -r '.worker' 2>/dev/null || echo "?")
                echo "  ✓ [W$worker] $task_desc"
            fi
        done
    fi
    echo ""
    
    # Failed tasks
    draw_box 60 "Failed Tasks" $RED
    local failed_tasks=$(npx claude-flow memory search "tasks/failed/*" 2>/dev/null | tail -5)
    if [ -z "$failed_tasks" ]; then
        echo "  No failed tasks"
    else
        echo "$failed_tasks" | while read -r task; do
            local task_data=$(npx claude-flow memory get "$task" 2>/dev/null)
            if [ -n "$task_data" ]; then
                local task_desc=$(echo "$task_data" | jq -r '.task' 2>/dev/null || echo "Unknown")
                local error=$(echo "$task_data" | jq -r '.error' 2>/dev/null || echo "Unknown error")
                echo "  ✗ $task_desc"
                echo "    Error: $error"
            fi
        done
    fi
    echo ""
    
    echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}[b]ack to overview | [q]uit${NC}"
}

# Handle user input
handle_input() {
    read -t 0.1 -n 1 key
    
    case "$key" in
        q|Q)
            echo -e "\n${GREEN}Exiting dashboard...${NC}"
            exit 0
            ;;
        r|R)
            draw_dashboard
            ;;
        p|P)
            AUTO_REFRESH=$([ "$AUTO_REFRESH" = true ] && echo false || echo true)
            ;;
        w|W)
            CURRENT_VIEW="workers"
            draw_workers_view
            ;;
        t|T)
            CURRENT_VIEW="tasks"
            draw_tasks_view
            ;;
        b|B)
            CURRENT_VIEW="overview"
            draw_dashboard
            ;;
        +)
            REFRESH_RATE=$((REFRESH_RATE + 1))
            [ $REFRESH_RATE -gt 10 ] && REFRESH_RATE=10
            ;;
        -)
            REFRESH_RATE=$((REFRESH_RATE - 1))
            [ $REFRESH_RATE -lt 1 ] && REFRESH_RATE=1
            ;;
    esac
}

# Main dashboard loop
main() {
    # Set terminal to non-canonical mode
    stty -echo -icanon time 0 min 0
    
    # Trap to restore terminal on exit
    trap 'stty sane; clear' EXIT
    
    # Initial draw
    draw_dashboard
    
    # Main loop
    local counter=0
    while true; do
        # Handle input
        handle_input
        
        # Auto-refresh
        if [ "$AUTO_REFRESH" = true ]; then
            counter=$((counter + 1))
            if [ $counter -ge $((REFRESH_RATE * 10)) ]; then
                case "$CURRENT_VIEW" in
                    "overview")
                        draw_dashboard
                        ;;
                    "workers")
                        draw_workers_view
                        ;;
                    "tasks")
                        draw_tasks_view
                        ;;
                esac
                counter=0
            fi
        fi
        
        # Small sleep to prevent CPU spinning
        sleep 0.1
    done
}

# Start dashboard
main "$@"