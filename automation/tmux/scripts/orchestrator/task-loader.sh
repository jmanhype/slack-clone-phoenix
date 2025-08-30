#!/bin/bash
# Task Loader - Bulk Task Loading and Queue Management
# Loads tasks from files, APIs, or manual input into the orchestrator

set -euo pipefail

# Configuration
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGS_DIR="$BASE_DIR/logs"
PIPES_DIR="$BASE_DIR/pipes"
SESSIONS_DIR="$BASE_DIR/sessions"
TEMPLATES_DIR="$BASE_DIR/templates"

# Create directories
mkdir -p "$LOGS_DIR" "$PIPES_DIR" "$SESSIONS_DIR" "$TEMPLATES_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Task loading configuration
MAX_BATCH_SIZE=${MAX_BATCH_SIZE:-50}
TASK_TIMEOUT=${TASK_TIMEOUT:-300}
PRIORITY_LEVELS=("low" "medium" "high" "critical")
AGENT_TYPES=("researcher" "coder" "analyst" "optimizer" "coordinator" "tester" "reviewer")

# Logging
log() {
    echo -e "${GREEN}[TaskLoader]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGS_DIR/task-loader.log"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGS_DIR/task-loader.log" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOGS_DIR/task-loader.log"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOGS_DIR/task-loader.log"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOGS_DIR/task-loader.log"
}

# Generate unique task ID
generate_task_id() {
    echo "task-$(date +%s)-$(shuf -i 1000-9999 -n 1)"
}

# Validate task format
validate_task() {
    local task_json="$1"
    
    # Check required fields
    local required_fields=("task" "agent_type" "priority")
    for field in "${required_fields[@]}"; do
        if ! echo "$task_json" | jq -e ".$field" >/dev/null 2>&1; then
            error "Missing required field: $field"
            return 1
        fi
    done
    
    # Validate agent type
    local agent_type=$(echo "$task_json" | jq -r '.agent_type')
    if [[ ! " ${AGENT_TYPES[*]} " =~ " $agent_type " ]]; then
        error "Invalid agent type: $agent_type"
        return 1
    fi
    
    # Validate priority
    local priority=$(echo "$task_json" | jq -r '.priority')
    if [[ ! " ${PRIORITY_LEVELS[*]} " =~ " $priority " ]]; then
        error "Invalid priority: $priority"
        return 1
    fi
    
    return 0
}

# Load task from JSON
load_json_task() {
    local task_data="$1"
    
    if ! validate_task "$task_data"; then
        return 1
    fi
    
    local task_id=$(generate_task_id)
    local task=$(echo "$task_data" | jq -r '.task')
    local agent_type=$(echo "$task_data" | jq -r '.agent_type')
    local priority=$(echo "$task_data" | jq -r '.priority')
    local dependencies=$(echo "$task_data" | jq -r '.dependencies // []')
    local timeout=$(echo "$task_data" | jq -r '.timeout // 300')
    local context=$(echo "$task_data" | jq -r '.context // ""')
    
    # Create full task object
    local full_task=$(cat << EOF
{
    "id": "$task_id",
    "task": "$task",
    "agent_type": "$agent_type",
    "priority": "$priority",
    "dependencies": $dependencies,
    "timeout": $timeout,
    "context": "$context",
    "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "status": "pending"
}
EOF
    )
    
    # Store in memory
    npx claude-flow memory store "tasks/pending/$task_id" "$full_task" 2>/dev/null || true
    
    # Send to task queue via pipe
    if [ -p "$PIPES_DIR/tasks.pipe" ]; then
        echo "$task_id" > "$PIPES_DIR/tasks.pipe" &
    fi
    
    log "Loaded task: $task_id [$agent_type] - $task"
    echo "$task_id"
}

# Load tasks from file
load_from_file() {
    local file_path="$1"
    local format="${2:-json}"
    
    if [ ! -f "$file_path" ]; then
        error "File not found: $file_path"
        return 1
    fi
    
    log "Loading tasks from file: $file_path"
    
    local loaded_count=0
    local failed_count=0
    
    case "$format" in
        "json")
            # JSON array of tasks
            if jq -e 'type == "array"' "$file_path" >/dev/null 2>&1; then
                local task_count=$(jq 'length' "$file_path")
                log "Found $task_count tasks in JSON file"
                
                for i in $(seq 0 $((task_count - 1))); do
                    local task_data=$(jq -c ".[$i]" "$file_path")
                    
                    if load_json_task "$task_data"; then
                        loaded_count=$((loaded_count + 1))
                    else
                        failed_count=$((failed_count + 1))
                    fi
                done
            else
                # Single JSON task
                local task_data=$(jq -c '.' "$file_path")
                if load_json_task "$task_data"; then
                    loaded_count=1
                else
                    failed_count=1
                fi
            fi
            ;;
        "csv")
            # CSV format: task,agent_type,priority,context
            {
                read -r header  # Skip header line
                while IFS=',' read -r task agent_type priority context dependencies; do
                    # Remove quotes if present
                    task=$(echo "$task" | sed 's/^"//;s/"$//')
                    agent_type=$(echo "$agent_type" | sed 's/^"//;s/"$//')
                    priority=$(echo "$priority" | sed 's/^"//;s/"$//')
                    context=$(echo "$context" | sed 's/^"//;s/"$//')
                    dependencies=$(echo "$dependencies" | sed 's/^"//;s/"$//')
                    
                    # Create JSON task
                    local task_json=$(cat << EOF
{
    "task": "$task",
    "agent_type": "$agent_type",
    "priority": "$priority",
    "context": "$context",
    "dependencies": ${dependencies:-"[]"}
}
EOF
                    )
                    
                    if load_json_task "$task_json"; then
                        loaded_count=$((loaded_count + 1))
                    else
                        failed_count=$((failed_count + 1))
                    fi
                done
            } < "$file_path"
            ;;
        "txt")
            # Simple text format: one task per line
            while IFS= read -r line; do
                if [ -n "$line" ] && [[ ! "$line" =~ ^# ]]; then
                    # Default to medium priority coder task
                    local task_json=$(cat << EOF
{
    "task": "$line",
    "agent_type": "coder",
    "priority": "medium",
    "context": "Loaded from text file"
}
EOF
                    )
                    
                    if load_json_task "$task_json"; then
                        loaded_count=$((loaded_count + 1))
                    else
                        failed_count=$((failed_count + 1))
                    fi
                fi
            done < "$file_path"
            ;;
        *)
            error "Unsupported format: $format"
            return 1
            ;;
    esac
    
    success "Loaded $loaded_count tasks successfully"
    if [ $failed_count -gt 0 ]; then
        warn "Failed to load $failed_count tasks"
    fi
    
    # Update memory with load statistics
    npx claude-flow memory store "task-loader/stats/$(date +%s)" "{
        \"file\": \"$file_path\",
        \"format\": \"$format\",
        \"loaded\": $loaded_count,
        \"failed\": $failed_count,
        \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
    }" 2>/dev/null || true
}

# Load tasks from API endpoint
load_from_api() {
    local api_url="$1"
    local auth_header="${2:-}"
    
    log "Loading tasks from API: $api_url"
    
    local temp_file=$(mktemp)
    local http_code
    
    if [ -n "$auth_header" ]; then
        http_code=$(curl -s -w "%{http_code}" -H "$auth_header" "$api_url" -o "$temp_file")
    else
        http_code=$(curl -s -w "%{http_code}" "$api_url" -o "$temp_file")
    fi
    
    if [ "$http_code" -ne 200 ]; then
        error "API request failed with code: $http_code"
        rm -f "$temp_file"
        return 1
    fi
    
    # Load from the downloaded file
    load_from_file "$temp_file" "json"
    
    rm -f "$temp_file"
}

# Interactive task creation
interactive_task_creation() {
    echo -e "${CYAN}Interactive Task Creation${NC}"
    echo ""
    
    local tasks=()
    local continue_adding=true
    
    while [ "$continue_adding" = true ]; do
        echo -e "${YELLOW}Enter task details:${NC}"
        
        # Task description
        read -p "Task description: " task_desc
        if [ -z "$task_desc" ]; then
            error "Task description cannot be empty"
            continue
        fi
        
        # Agent type
        echo "Available agent types: ${AGENT_TYPES[*]}"
        read -p "Agent type [coder]: " agent_type
        agent_type=${agent_type:-coder}
        
        if [[ ! " ${AGENT_TYPES[*]} " =~ " $agent_type " ]]; then
            error "Invalid agent type. Using 'coder'."
            agent_type="coder"
        fi
        
        # Priority
        echo "Priority levels: ${PRIORITY_LEVELS[*]}"
        read -p "Priority [medium]: " priority
        priority=${priority:-medium}
        
        if [[ ! " ${PRIORITY_LEVELS[*]} " =~ " $priority " ]]; then
            error "Invalid priority. Using 'medium'."
            priority="medium"
        fi
        
        # Context
        read -p "Context (optional): " context
        
        # Dependencies
        read -p "Dependencies (comma-separated task IDs, optional): " deps_input
        local dependencies="[]"
        if [ -n "$deps_input" ]; then
            # Convert comma-separated to JSON array
            dependencies=$(echo "$deps_input" | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/')
        fi
        
        # Create task JSON
        local task_json=$(cat << EOF
{
    "task": "$task_desc",
    "agent_type": "$agent_type",
    "priority": "$priority",
    "context": "$context",
    "dependencies": $dependencies
}
EOF
        )
        
        # Load the task
        local task_id=$(load_json_task "$task_json")
        success "Created task: $task_id"
        
        echo ""
        read -p "Add another task? (y/N): " add_more
        if [[ ! "$add_more" =~ ^[Yy] ]]; then
            continue_adding=false
        fi
        echo ""
    done
}

# Load from template
load_from_template() {
    local template_name="$1"
    local template_file="$TEMPLATES_DIR/$template_name.json"
    
    if [ ! -f "$template_file" ]; then
        error "Template not found: $template_name"
        list_templates
        return 1
    fi
    
    log "Loading tasks from template: $template_name"
    load_from_file "$template_file" "json"
}

# Create task template
create_template() {
    local template_name="$1"
    local template_file="$TEMPLATES_DIR/$template_name.json"
    
    echo -e "${CYAN}Creating Task Template: $template_name${NC}"
    echo ""
    
    local tasks=[]
    local task_array=""
    
    while true; do
        echo "Enter task for template:"
        read -p "Task description: " task_desc
        [ -z "$task_desc" ] && break
        
        read -p "Agent type [coder]: " agent_type
        agent_type=${agent_type:-coder}
        
        read -p "Priority [medium]: " priority
        priority=${priority:-medium}
        
        read -p "Context: " context
        
        local task_obj=$(cat << EOF
{
    "task": "$task_desc",
    "agent_type": "$agent_type",
    "priority": "$priority",
    "context": "$context",
    "dependencies": []
}
EOF
        )
        
        if [ -z "$task_array" ]; then
            task_array="$task_obj"
        else
            task_array="$task_array,$task_obj"
        fi
        
        read -p "Add another task? (y/N): " add_more
        [[ ! "$add_more" =~ ^[Yy] ]] && break
    done
    
    # Create template file
    echo "[$task_array]" | jq '.' > "$template_file"
    success "Template created: $template_file"
}

# List templates
list_templates() {
    echo -e "${CYAN}Available Templates:${NC}"
    
    if [ ! -d "$TEMPLATES_DIR" ] || [ -z "$(ls -A "$TEMPLATES_DIR")" ]; then
        info "No templates found in $TEMPLATES_DIR"
        return
    fi
    
    for template in "$TEMPLATES_DIR"/*.json; do
        if [ -f "$template" ]; then
            local name=$(basename "$template" .json)
            local task_count=$(jq 'length' "$template" 2>/dev/null || echo "0")
            echo "  • $name ($task_count tasks)"
            
            # Show first task as preview
            local first_task=$(jq -r '.[0].task // "No tasks"' "$template" 2>/dev/null)
            echo "    Preview: $first_task"
        fi
    done
}

# Clear pending tasks
clear_pending_tasks() {
    read -p "Are you sure you want to clear all pending tasks? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
        log "Clearing all pending tasks..."
        
        # Get all pending task keys
        local pending_tasks=$(npx claude-flow memory search "tasks/pending/*" 2>/dev/null)
        local count=0
        
        if [ -n "$pending_tasks" ]; then
            while IFS= read -r task_key; do
                npx claude-flow memory delete "$task_key" 2>/dev/null || true
                count=$((count + 1))
            done <<< "$pending_tasks"
        fi
        
        success "Cleared $count pending tasks"
    else
        info "Operation cancelled"
    fi
}

# Show task queue status
show_queue_status() {
    echo -e "${CYAN}Task Queue Status${NC}"
    echo ""
    
    # Count tasks by status
    local pending=$(npx claude-flow memory search "tasks/pending/*" 2>/dev/null | wc -l)
    local processing=$(npx claude-flow memory search "tasks/processing/*" 2>/dev/null | wc -l)
    local completed=$(npx claude-flow memory search "tasks/completed/*" 2>/dev/null | wc -l)
    local failed=$(npx claude-flow memory search "tasks/failed/*" 2>/dev/null | wc -l)
    
    echo -e "${GREEN}Pending:${NC} $pending"
    echo -e "${YELLOW}Processing:${NC} $processing"
    echo -e "${GREEN}Completed:${NC} $completed"
    echo -e "${RED}Failed:${NC} $failed"
    echo ""
    
    # Show recent pending tasks
    if [ "$pending" -gt 0 ]; then
        echo -e "${CYAN}Recent Pending Tasks:${NC}"
        npx claude-flow memory search "tasks/pending/*" 2>/dev/null | head -5 | while read -r task_key; do
            local task_data=$(npx claude-flow memory get "$task_key" 2>/dev/null)
            if [ -n "$task_data" ]; then
                local task_desc=$(echo "$task_data" | jq -r '.task')
                local agent_type=$(echo "$task_data" | jq -r '.agent_type')
                local priority=$(echo "$task_data" | jq -r '.priority')
                echo "  • [$agent_type:$priority] $task_desc"
            fi
        done
    fi
}

# Monitor task processing
monitor_tasks() {
    local refresh_interval=${1:-5}
    
    echo -e "${CYAN}Task Processing Monitor (Ctrl+C to stop)${NC}"
    echo "Refresh interval: ${refresh_interval}s"
    echo ""
    
    # Trap for clean exit
    trap 'echo -e "\nMonitoring stopped."; exit 0' INT
    
    while true; do
        clear
        echo -e "${CYAN}Task Processing Monitor - $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo ""
        
        show_queue_status
        
        echo ""
        echo -e "${GRAY}Press Ctrl+C to stop monitoring${NC}"
        
        sleep "$refresh_interval"
    done
}

# Bulk operations
bulk_operation() {
    local operation="$1"
    local pattern="${2:-tasks/pending/*}"
    
    case "$operation" in
        "priority")
            local new_priority="$3"
            if [[ ! " ${PRIORITY_LEVELS[*]} " =~ " $new_priority " ]]; then
                error "Invalid priority: $new_priority"
                return 1
            fi
            
            log "Updating priority to '$new_priority' for tasks matching: $pattern"
            local count=0
            
            npx claude-flow memory search "$pattern" 2>/dev/null | while read -r task_key; do
                local task_data=$(npx claude-flow memory get "$task_key" 2>/dev/null)
                if [ -n "$task_data" ]; then
                    local updated_task=$(echo "$task_data" | jq ".priority = \"$new_priority\"")
                    npx claude-flow memory store "$task_key" "$updated_task" 2>/dev/null || true
                    count=$((count + 1))
                fi
            done
            
            success "Updated priority for $count tasks"
            ;;
        "delete")
            read -p "Delete all tasks matching '$pattern'? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy] ]]; then
                local count=0
                npx claude-flow memory search "$pattern" 2>/dev/null | while read -r task_key; do
                    npx claude-flow memory delete "$task_key" 2>/dev/null || true
                    count=$((count + 1))
                done
                success "Deleted $count tasks"
            fi
            ;;
        *)
            error "Unknown bulk operation: $operation"
            return 1
            ;;
    esac
}

# Display usage
usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  load-file <file> [format]    Load tasks from file (json, csv, txt)"
    echo "  load-api <url> [auth]        Load tasks from API endpoint"
    echo "  interactive                  Create tasks interactively"
    echo "  template <name>              Load tasks from template"
    echo "  create-template <name>       Create new task template"
    echo "  list-templates               List available templates"
    echo "  status                       Show task queue status"
    echo "  monitor [interval]           Monitor task processing"
    echo "  clear                        Clear all pending tasks"
    echo "  bulk <op> <pattern> [args]   Bulk operations on tasks"
    echo ""
    echo "Examples:"
    echo "  $0 load-file tasks.json"
    echo "  $0 load-file tasks.csv csv"
    echo "  $0 load-api https://api.example.com/tasks \"Authorization: Bearer token\""
    echo "  $0 interactive"
    echo "  $0 template web-development"
    echo "  $0 monitor 10"
    echo "  $0 bulk priority \"tasks/pending/*\" high"
}

# Main command handler
main() {
    local command=${1:-status}
    
    case "$command" in
        "load-file")
            if [ -z "$2" ]; then
                error "File path required"
                usage
                exit 1
            fi
            load_from_file "$2" "${3:-json}"
            ;;
        "load-api")
            if [ -z "$2" ]; then
                error "API URL required"
                usage
                exit 1
            fi
            load_from_api "$2" "$3"
            ;;
        "interactive")
            interactive_task_creation
            ;;
        "template")
            if [ -z "$2" ]; then
                error "Template name required"
                list_templates
                exit 1
            fi
            load_from_template "$2"
            ;;
        "create-template")
            if [ -z "$2" ]; then
                error "Template name required"
                usage
                exit 1
            fi
            create_template "$2"
            ;;
        "list-templates")
            list_templates
            ;;
        "status")
            show_queue_status
            ;;
        "monitor")
            monitor_tasks "${2:-5}"
            ;;
        "clear")
            clear_pending_tasks
            ;;
        "bulk")
            if [ -z "$2" ] || [ -z "$3" ]; then
                error "Bulk operation and pattern required"
                usage
                exit 1
            fi
            bulk_operation "$2" "$3" "$4"
            ;;
        "help"|"--help"|"-h")
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