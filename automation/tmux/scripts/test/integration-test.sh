#!/bin/bash
# Integration Test - Complete T-Max Orchestrator System Testing
# Validates all components work together in a production-like environment

set -euo pipefail

# Configuration
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGS_DIR="$BASE_DIR/logs"
PIPES_DIR="$BASE_DIR/pipes"
SESSIONS_DIR="$BASE_DIR/sessions"
SCRIPTS_DIR="$BASE_DIR/scripts"
TEST_DIR="$BASE_DIR/test"

# Create directories
mkdir -p "$LOGS_DIR" "$PIPES_DIR" "$SESSIONS_DIR" "$TEST_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Test configuration
TEST_SESSION="tmax-integration-test"
TEST_TIMEOUT=300
MAX_CONCURRENT_TESTS=5
EXPECTED_WORKERS=8

# Test state tracking
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Logging
log() {
    echo -e "${GREEN}[IntegrationTest]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGS_DIR/integration-test.log"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGS_DIR/integration-test.log" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOGS_DIR/integration-test.log"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOGS_DIR/integration-test.log"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOGS_DIR/integration-test.log"
}

# Test result tracking
pass_test() {
    local test_name="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    success "✓ $test_name"
}

fail_test() {
    local test_name="$1"
    local reason="$2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    error "✗ $test_name: $reason"
}

# Wait for condition with timeout
wait_for_condition() {
    local condition="$1"
    local timeout="${2:-30}"
    local description="$3"
    
    local count=0
    while [ $count -lt $timeout ]; do
        if eval "$condition"; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    error "Timeout waiting for: $description"
    return 1
}

# Test script existence and permissions
test_scripts_exist() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Script Files Exist"
    
    local required_scripts=(
        "$SCRIPTS_DIR/orchestrator/t-max-init.sh"
        "$SCRIPTS_DIR/orchestrator/claude-worker.sh"
        "$SCRIPTS_DIR/monitoring/claude-dashboard.sh"
        "$SCRIPTS_DIR/guardian/claude-guardian.sh"
        "$SCRIPTS_DIR/orchestrator/preserve-state.sh"
        "$SCRIPTS_DIR/orchestrator/session-backup.sh"
        "$SCRIPTS_DIR/orchestrator/task-loader.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [ ! -f "$script" ]; then
            fail_test "$test_name" "Missing script: $script"
            return 1
        fi
        
        if [ ! -x "$script" ]; then
            chmod +x "$script"
        fi
    done
    
    pass_test "$test_name"
}

# Test Claude Flow installation
test_claude_flow_available() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Claude Flow Available"
    
    if ! command -v npx >/dev/null 2>&1; then
        fail_test "$test_name" "npx not found"
        return 1
    fi
    
    if ! npx claude-flow@alpha --version >/dev/null 2>&1; then
        fail_test "$test_name" "claude-flow not available"
        return 1
    fi
    
    pass_test "$test_name"
}

# Test tmux availability
test_tmux_available() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Tmux Available"
    
    if ! command -v tmux >/dev/null 2>&1; then
        fail_test "$test_name" "tmux not installed"
        return 1
    fi
    
    # Test tmux can create sessions
    if ! tmux new-session -d -s "test-session-$$" "sleep 1"; then
        fail_test "$test_name" "Cannot create tmux sessions"
        return 1
    fi
    
    # Clean up test session
    tmux kill-session -t "test-session-$$" 2>/dev/null || true
    
    pass_test "$test_name"
}

# Test memory system initialization
test_memory_initialization() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Memory System Initialization"
    
    # Test memory store
    local test_key="integration-test/$(date +%s)"
    local test_value="{\"test\": true, \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
    
    if ! npx claude-flow@alpha memory store "$test_key" "$test_value" 2>/dev/null; then
        fail_test "$test_name" "Cannot store data"
        return 1
    fi
    
    # Test memory retrieval
    local retrieved_value=$(npx claude-flow@alpha memory get "$test_key" 2>/dev/null)
    if [ -z "$retrieved_value" ]; then
        fail_test "$test_name" "Cannot retrieve data"
        return 1
    fi
    
    # Clean up test data
    npx claude-flow@alpha memory delete "$test_key" 2>/dev/null || true
    
    pass_test "$test_name"
}

# Test orchestrator initialization
test_orchestrator_init() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Orchestrator Initialization"
    
    # Kill any existing test sessions
    tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
    
    # Test orchestrator startup (non-blocking)
    local init_log="$TEST_DIR/init-test.log"
    if ! timeout 60 bash "$SCRIPTS_DIR/orchestrator/t-max-init.sh" --session "$TEST_SESSION" --workers 3 --test-mode > "$init_log" 2>&1 & then
        fail_test "$test_name" "Orchestrator failed to start"
        return 1
    fi
    
    local init_pid=$!
    
    # Wait for session to be created
    if ! wait_for_condition "tmux has-session -t '$TEST_SESSION' 2>/dev/null" 30 "tmux session creation"; then
        kill $init_pid 2>/dev/null || true
        fail_test "$test_name" "Session not created"
        return 1
    fi
    
    # Clean up
    kill $init_pid 2>/dev/null || true
    tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
    
    pass_test "$test_name"
}

# Test named pipes creation
test_named_pipes() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Named Pipes Creation"
    
    # Clean up existing pipes
    rm -f "$PIPES_DIR"/*.pipe
    
    # Create test pipes
    local test_pipes=(
        "$PIPES_DIR/control.pipe"
        "$PIPES_DIR/tasks.pipe"
        "$PIPES_DIR/results.pipe"
    )
    
    for pipe in "${test_pipes[@]}"; do
        if ! mkfifo "$pipe" 2>/dev/null; then
            fail_test "$test_name" "Cannot create pipe: $pipe"
            return 1
        fi
    done
    
    # Test pipe communication
    echo "test-message" > "$PIPES_DIR/control.pipe" &
    local write_pid=$!
    
    local message
    if ! timeout 5 read -r message < "$PIPES_DIR/control.pipe"; then
        kill $write_pid 2>/dev/null || true
        fail_test "$test_name" "Pipe communication failed"
        return 1
    fi
    
    if [ "$message" != "test-message" ]; then
        fail_test "$test_name" "Pipe message corruption"
        return 1
    fi
    
    # Clean up
    rm -f "${test_pipes[@]}"
    
    pass_test "$test_name"
}

# Test worker spawning
test_worker_spawning() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Worker Spawning"
    
    # Create test session
    if ! tmux new-session -d -s "$TEST_SESSION" "sleep 60"; then
        fail_test "$test_name" "Cannot create test session"
        return 1
    fi
    
    # Test worker script
    if ! timeout 30 bash "$SCRIPTS_DIR/orchestrator/claude-worker.sh" 1 --test-mode > "$TEST_DIR/worker-test.log" 2>&1 & then
        tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
        fail_test "$test_name" "Worker script failed"
        return 1
    fi
    
    local worker_pid=$!
    sleep 5  # Let worker initialize
    
    # Check worker process
    if ! kill -0 $worker_pid 2>/dev/null; then
        tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
        fail_test "$test_name" "Worker process died"
        return 1
    fi
    
    # Clean up
    kill $worker_pid 2>/dev/null || true
    tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
    
    pass_test "$test_name"
}

# Test task loading system
test_task_loading() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Task Loading System"
    
    # Create test task file
    local test_tasks_file="$TEST_DIR/test-tasks.json"
    cat > "$test_tasks_file" << 'EOF'
[
    {
        "task": "Test task 1",
        "agent_type": "coder",
        "priority": "medium",
        "context": "Integration test task"
    },
    {
        "task": "Test task 2",
        "agent_type": "researcher",
        "priority": "low",
        "context": "Another test task"
    }
]
EOF
    
    # Test task loading
    if ! timeout 30 bash "$SCRIPTS_DIR/orchestrator/task-loader.sh" load-file "$test_tasks_file" json > "$TEST_DIR/task-load-test.log" 2>&1; then
        fail_test "$test_name" "Task loading failed"
        return 1
    fi
    
    # Verify tasks were loaded (check memory or logs)
    if ! grep -q "Loaded.*tasks successfully" "$TEST_DIR/task-load-test.log"; then
        fail_test "$test_name" "Tasks not loaded successfully"
        return 1
    fi
    
    # Clean up
    rm -f "$test_tasks_file"
    
    pass_test "$test_name"
}

# Test state preservation
test_state_preservation() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="State Preservation"
    
    # Create test state
    npx claude-flow@alpha memory store "test/state/data" '{"test": "preservation"}' 2>/dev/null || true
    
    # Test snapshot creation
    local snapshot_path
    if ! snapshot_path=$(timeout 60 bash "$SCRIPTS_DIR/orchestrator/preserve-state.sh" create 2>/dev/null | tail -1); then
        fail_test "$test_name" "Snapshot creation failed"
        return 1
    fi
    
    # Verify snapshot exists
    if [ ! -f "$snapshot_path" ]; then
        fail_test "$test_name" "Snapshot file not created"
        return 1
    fi
    
    # Test restore (without actually restoring)
    if ! bash "$SCRIPTS_DIR/orchestrator/preserve-state.sh" list | grep -q "claude-state"; then
        fail_test "$test_name" "Snapshot not listed"
        return 1
    fi
    
    # Clean up
    rm -f "$snapshot_path"
    npx claude-flow@alpha memory delete "test/state/data" 2>/dev/null || true
    
    pass_test "$test_name"
}

# Test guardian monitoring
test_guardian_monitoring() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Guardian Monitoring"
    
    # Test guardian startup (non-blocking)
    if ! timeout 30 bash "$SCRIPTS_DIR/guardian/claude-guardian.sh" --test-mode > "$TEST_DIR/guardian-test.log" 2>&1 &; then
        fail_test "$test_name" "Guardian failed to start"
        return 1
    fi
    
    local guardian_pid=$!
    sleep 5  # Let guardian initialize
    
    # Check guardian process
    if ! kill -0 $guardian_pid 2>/dev/null; then
        fail_test "$test_name" "Guardian process died"
        return 1
    fi
    
    # Clean up
    kill $guardian_pid 2>/dev/null || true
    
    pass_test "$test_name"
}

# Test backup system
test_backup_system() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Backup System"
    
    # Test backup creation
    if ! timeout 60 bash "$SCRIPTS_DIR/orchestrator/session-backup.sh" create --no-verify > "$TEST_DIR/backup-test.log" 2>&1; then
        fail_test "$test_name" "Backup creation failed"
        return 1
    fi
    
    # Check if backup was created
    if ! bash "$SCRIPTS_DIR/orchestrator/session-backup.sh" list | grep -q "tmux-backup"; then
        fail_test "$test_name" "Backup not created"
        return 1
    fi
    
    # Clean up test backups
    find "$BASE_DIR/backups" -name "tmux-backup-*" -type f -delete 2>/dev/null || true
    
    pass_test "$test_name"
}

# Test dashboard functionality
test_dashboard() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Dashboard Functionality"
    
    # Test dashboard startup (with timeout)
    if ! timeout 10 bash "$SCRIPTS_DIR/monitoring/claude-dashboard.sh" --test-mode > "$TEST_DIR/dashboard-test.log" 2>&1 &; then
        fail_test "$test_name" "Dashboard failed to start"
        return 1
    fi
    
    local dashboard_pid=$!
    sleep 3  # Let dashboard render once
    
    # Check dashboard process
    if ! kill -0 $dashboard_pid 2>/dev/null; then
        fail_test "$test_name" "Dashboard process died"
        return 1
    fi
    
    # Clean up
    kill $dashboard_pid 2>/dev/null || true
    
    pass_test "$test_name"
}

# Test complete integration
test_full_integration() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Full System Integration"
    
    info "Starting full integration test..."
    
    # 1. Initialize orchestrator
    local integration_session="tmax-full-test"
    tmux kill-session -t "$integration_session" 2>/dev/null || true
    
    # Start orchestrator in test mode
    timeout 120 bash "$SCRIPTS_DIR/orchestrator/t-max-init.sh" --session "$integration_session" --workers 2 --test-mode > "$TEST_DIR/full-integration.log" 2>&1 &
    local orchestrator_pid=$!
    
    # Wait for session creation
    if ! wait_for_condition "tmux has-session -t '$integration_session' 2>/dev/null" 60 "orchestrator startup"; then
        kill $orchestrator_pid 2>/dev/null || true
        fail_test "$test_name" "Orchestrator startup failed"
        return 1
    fi
    
    # 2. Load test tasks
    cat > "$TEST_DIR/integration-tasks.json" << 'EOF'
[
    {
        "task": "Analyze system performance",
        "agent_type": "analyst",
        "priority": "high",
        "context": "Full integration test"
    }
]
EOF
    
    bash "$SCRIPTS_DIR/orchestrator/task-loader.sh" load-file "$TEST_DIR/integration-tasks.json" json 2>/dev/null || true
    
    # 3. Create backup
    bash "$SCRIPTS_DIR/orchestrator/session-backup.sh" create --no-verify 2>/dev/null &
    local backup_pid=$!
    
    # 4. Start guardian
    timeout 60 bash "$SCRIPTS_DIR/guardian/claude-guardian.sh" --test-mode > "$TEST_DIR/guardian-integration.log" 2>&1 &
    local guardian_pid=$!
    
    # Let everything run for a bit
    sleep 10
    
    # Check all processes
    local all_running=true
    if ! kill -0 $orchestrator_pid 2>/dev/null; then
        warn "Orchestrator process stopped"
        all_running=false
    fi
    
    if ! kill -0 $guardian_pid 2>/dev/null; then
        warn "Guardian process stopped"
        all_running=false
    fi
    
    # Clean up
    kill $orchestrator_pid $guardian_pid $backup_pid 2>/dev/null || true
    tmux kill-session -t "$integration_session" 2>/dev/null || true
    rm -f "$TEST_DIR/integration-tasks.json"
    
    if [ "$all_running" = true ]; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Some processes failed during integration"
        return 1
    fi
}

# Performance test
test_performance() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="Performance Benchmarks"
    
    info "Running performance tests..."
    
    # Test memory operations performance
    local start_time=$(date +%s.%N)
    for i in {1..100}; do
        npx claude-flow@alpha memory store "perf/test/$i" "{\"value\": $i}" 2>/dev/null || true
    done
    local end_time=$(date +%s.%N)
    
    local duration=$(echo "$end_time - $start_time" | bc)
    local ops_per_sec=$(echo "scale=2; 100 / $duration" | bc)
    
    info "Memory operations: $ops_per_sec ops/sec"
    
    # Clean up performance test data
    for i in {1..100}; do
        npx claude-flow@alpha memory delete "perf/test/$i" 2>/dev/null || true
    done
    
    # Pass if we get reasonable performance (>10 ops/sec)
    if (( $(echo "$ops_per_sec > 10" | bc -l) )); then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Poor performance: $ops_per_sec ops/sec"
    fi
}

# Cleanup function
cleanup() {
    info "Cleaning up test environment..."
    
    # Kill any remaining test processes
    pkill -f "tmax-.*-test" 2>/dev/null || true
    
    # Remove test sessions
    tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
    tmux kill-session -t "tmax-full-test" 2>/dev/null || true
    
    # Clean up test files
    rm -f "$PIPES_DIR"/*.pipe
    rm -f "$TEST_DIR"/*.log
    rm -f "$TEST_DIR"/*.json
    
    # Clean up test memory data
    npx claude-flow@alpha memory search "integration-test/*" 2>/dev/null | while read -r key; do
        npx claude-flow@alpha memory delete "$key" 2>/dev/null || true
    done
    
    # Clean up test backups
    find "$BASE_DIR/backups" -name "tmux-backup-*" -type f -delete 2>/dev/null || true
    find "$BASE_DIR/state" -name "claude-state-*" -type f -delete 2>/dev/null || true
}

# Print test results
print_results() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║        INTEGRATION TEST RESULTS          ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    echo -e "${BLUE}Total Tests:  $TOTAL_TESTS${NC}"
    echo ""
    
    local success_rate=$(echo "scale=1; $TESTS_PASSED * 100 / $TOTAL_TESTS" | bc)
    echo -e "${CYAN}Success Rate: ${success_rate}%${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}${BOLD}🎉 ALL TESTS PASSED! T-Max Orchestrator is ready for production.${NC}"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo -e "  1. Run: ${YELLOW}bash $SCRIPTS_DIR/orchestrator/t-max-init.sh${NC}"
        echo -e "  2. Monitor: ${YELLOW}bash $SCRIPTS_DIR/monitoring/claude-dashboard.sh${NC}"
        echo -e "  3. Load tasks: ${YELLOW}bash $SCRIPTS_DIR/orchestrator/task-loader.sh interactive${NC}"
        return 0
    else
        echo -e "${RED}${BOLD}❌ SOME TESTS FAILED. Review logs before production use.${NC}"
        echo ""
        echo -e "${CYAN}Check logs in:${NC} $LOGS_DIR/"
        echo -e "${CYAN}Test outputs in:${NC} $TEST_DIR/"
        return 1
    fi
}

# Main test execution
main() {
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║     T-MAX ORCHESTRATOR INTEGRATION      ║${NC}"
    echo -e "${CYAN}${BOLD}║              TEST SUITE                  ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
    
    log "Starting T-Max Orchestrator integration test suite"
    
    # Trap for cleanup
    trap cleanup EXIT
    
    # Run all tests
    info "Running prerequisite tests..."
    test_scripts_exist
    test_claude_flow_available
    test_tmux_available
    test_memory_initialization
    
    info "Running component tests..."
    test_named_pipes
    test_orchestrator_init
    test_worker_spawning
    test_task_loading
    test_state_preservation
    test_guardian_monitoring
    test_backup_system
    test_dashboard
    
    info "Running integration tests..."
    test_full_integration
    
    info "Running performance tests..."
    test_performance
    
    # Print results
    print_results
}

# Handle command line arguments
case "${1:-run}" in
    "run")
        main
        ;;
    "quick")
        # Quick test - just essentials
        test_scripts_exist
        test_claude_flow_available
        test_tmux_available
        print_results
        ;;
    "help"|"--help"|"-h")
        echo "Usage: $0 [run|quick|help]"
        echo ""
        echo "Commands:"
        echo "  run    - Run full integration test suite (default)"
        echo "  quick  - Run quick prerequisite tests only"
        echo "  help   - Show this help message"
        ;;
    *)
        error "Unknown command: $1"
        exit 1
        ;;
esac