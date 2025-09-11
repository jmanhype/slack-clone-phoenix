#!/bin/bash

# Comprehensive test runner script for Slack Clone
# Run with: ./scripts/run_tests.sh [options]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
RUN_UNIT=true
RUN_INTEGRATION=false
RUN_BENCHMARKS=false
RUN_COVERAGE=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --unit)
      RUN_UNIT=true
      shift
      ;;
    --integration)
      RUN_INTEGRATION=true
      shift
      ;;
    --benchmarks)
      RUN_BENCHMARKS=true
      shift
      ;;
    --all)
      RUN_UNIT=true
      RUN_INTEGRATION=true
      RUN_BENCHMARKS=true
      shift
      ;;
    --coverage)
      RUN_COVERAGE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      echo "Slack Clone Test Runner"
      echo ""
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --unit         Run unit tests (default)"
      echo "  --integration  Run integration tests"
      echo "  --benchmarks   Run performance benchmarks"
      echo "  --all          Run all test suites"
      echo "  --coverage     Generate test coverage report"
      echo "  --verbose      Verbose output"
      echo "  --help         Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                    # Run unit tests only"
      echo "  $0 --all --coverage   # Run all tests with coverage"
      echo "  $0 --benchmarks       # Run benchmarks only"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}🚀 Slack Clone Test Suite Runner${NC}"
echo "=================================="

# Check if we're in the right directory
if [ ! -f "mix.exs" ]; then
    echo -e "${RED}❌ Error: mix.exs not found. Please run from the project root directory.${NC}"
    exit 1
fi

# Pre-test hooks
echo -e "${YELLOW}🔧 Running pre-test hooks...${NC}"

# Start hooks if available
if command -v npx &> /dev/null && [ -f "package.json" ]; then
    echo "📋 Initializing test session with hooks..."
    npx claude-flow@alpha hooks pre-task --description "Running comprehensive test suite" || true
fi

# Environment setup
echo -e "${YELLOW}🌍 Setting up test environment...${NC}"
export MIX_ENV=test
export ELIXIR_ASSERT_TIMEOUT=10000

# Database setup
echo "🗃️  Setting up test database..."
mix ecto.create --quiet 2>/dev/null || true
mix ecto.migrate --quiet

# Compile test code
echo "⚙️  Compiling test code..."
if [ "$VERBOSE" = true ]; then
    mix compile
else
    mix compile --quiet
fi

# Test execution tracking
TESTS_PASSED=0
TESTS_FAILED=0
START_TIME=$(date +%s)

# Function to run tests with error handling
run_test_suite() {
    local suite_name=$1
    local test_command=$2
    
    echo -e "\n${BLUE}🧪 Running $suite_name...${NC}"
    echo "Command: $test_command"
    echo "----------------------------------------"
    
    if eval $test_command; then
        echo -e "${GREEN}✅ $suite_name passed${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        # Post-test hook for success
        if command -v npx &> /dev/null; then
            npx claude-flow@alpha hooks post-task --task-id "test-$suite_name" --status "success" || true
        fi
    else
        echo -e "${RED}❌ $suite_name failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        
        # Post-test hook for failure
        if command -v npx &> /dev/null; then
            npx claude-flow@alpha hooks post-task --task-id "test-$suite_name" --status "failed" || true
        fi
    fi
}

# Unit Tests
if [ "$RUN_UNIT" = true ]; then
    if [ "$RUN_COVERAGE" = true ]; then
        run_test_suite "Unit Tests with Coverage" "COVERAGE=true mix coveralls.html"
    else
        if [ "$VERBOSE" = true ]; then
            run_test_suite "Unit Tests" "mix test --trace"
        else
            run_test_suite "Unit Tests" "mix test"
        fi
    fi
fi

# Integration Tests
if [ "$RUN_INTEGRATION" = true ]; then
    if [ "$VERBOSE" = true ]; then
        run_test_suite "Integration Tests" "INTEGRATION_TESTS=true mix test --trace --include integration"
    else
        run_test_suite "Integration Tests" "INTEGRATION_TESTS=true mix test --include integration"
    fi
fi

# Performance Benchmarks
if [ "$RUN_BENCHMARKS" = true ]; then
    echo -e "\n${BLUE}⚡ Performance Benchmarks${NC}"
    echo "----------------------------------------"
    
    # Warmup
    echo "🔥 Warming up system..."
    WARMUP_TESTS=true mix test test/performance/benchmarks_test.exs --include benchmark --max-cases 1 > /dev/null 2>&1 || true
    
    if [ "$VERBOSE" = true ]; then
        run_test_suite "Performance Benchmarks" "BENCHMARK_TESTS=true mix test --include benchmark --trace"
    else
        run_test_suite "Performance Benchmarks" "BENCHMARK_TESTS=true mix test --include benchmark"
    fi
fi

# Test Results Summary
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "========================================"
echo -e "${BLUE}📊 Test Results Summary${NC}"
echo "========================================"
echo -e "⏱️  Total duration: ${DURATION}s"
echo -e "${GREEN}✅ Passed: $TESTS_PASSED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${RED}❌ Failed: $TESTS_FAILED${NC}"
    echo -e "\n${GREEN}🎉 All tests passed! 🚀${NC}"
    OVERALL_STATUS="success"
else
    echo -e "${RED}❌ Failed: $TESTS_FAILED${NC}"
    echo -e "\n${RED}💥 Some tests failed. Please check the output above.${NC}"
    OVERALL_STATUS="failed"
fi

# Coverage Report Information
if [ "$RUN_COVERAGE" = true ]; then
    echo ""
    echo "📋 Coverage report generated at: cover/excoveralls.html"
    if command -v open &> /dev/null; then
        echo "💻 Opening coverage report..."
        open cover/excoveralls.html
    fi
fi

# System Information
echo ""
echo "========================================"
echo -e "${BLUE}🔍 System Information${NC}"
echo "========================================"
echo "🔧 Elixir version: $(elixir --version | head -n1)"
echo "🎯 Mix environment: $MIX_ENV"
echo "💾 Memory usage: $(ps -o pid,vsz,rss,comm -p $$ | tail -1 | awk '{print $2/1024"MB VSZ, "$3/1024"MB RSS"}')"

# Test file counts
UNIT_TEST_COUNT=$(find test -name "*_test.exs" ! -path "test/integration/*" ! -path "test/performance/*" | wc -l | tr -d ' ')
INTEGRATION_TEST_COUNT=$(find test/integration -name "*_test.exs" 2>/dev/null | wc -l | tr -d ' ')
BENCHMARK_TEST_COUNT=$(find test/performance -name "*_test.exs" 2>/dev/null | wc -l | tr -d ' ')

echo "📁 Unit test files: $UNIT_TEST_COUNT"
echo "🔗 Integration test files: $INTEGRATION_TEST_COUNT"
echo "⚡ Benchmark test files: $BENCHMARK_TEST_COUNT"

# Database information
echo "🗃️  Database: $(mix ecto.migrations | tail -1 || echo 'No migrations')"

# Post-test hooks and cleanup
echo ""
echo -e "${YELLOW}🧹 Running cleanup and post-test hooks...${NC}"

# Final hook with overall status
if command -v npx &> /dev/null; then
    npx claude-flow@alpha hooks post-task --task-id "test-suite-complete" --status "$OVERALL_STATUS" || true
    npx claude-flow@alpha hooks session-end --export-metrics true || true
fi

# Clean up any test artifacts
echo "🗑️  Cleaning up test artifacts..."
mix clean --quiet > /dev/null 2>&1 || true

# Final status
echo ""
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✨ Test suite completed successfully! ✨${NC}"
    exit 0
else
    echo -e "${RED}💥 Test suite completed with failures. Check the logs above.${NC}"
    exit 1
fi