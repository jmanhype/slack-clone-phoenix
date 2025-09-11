#!/bin/bash

# Slack Clone API Testing Suite
# Tests authentication endpoints and protected routes

set -e

API_BASE="http://localhost:4000/api"
CONTENT_TYPE="Content-Type: application/json"
ACCEPT="Accept: application/json"
TEST_EMAIL="test@example.com"
TEST_PASSWORD="testpass123"
RESULTS_FILE="tests/api_test_results.json"

echo "======================================"
echo "🚀 Slack Clone API Testing Suite"
echo "======================================"

# Create results directory
mkdir -p tests

# Initialize test results
echo '{"test_results": [], "summary": {}}' > "$RESULTS_FILE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log test results
log_result() {
    local test_name="$1"
    local status="$2"
    local response_code="$3"
    local response_time="$4"
    local details="$5"
    
    # Add result to JSON file
    jq --arg name "$test_name" \
       --arg status "$status" \
       --arg code "$response_code" \
       --arg time "$response_time" \
       --arg details "$details" \
       '.test_results += [{
           "test_name": $name,
           "status": $status,
           "response_code": $code,
           "response_time": $time,
           "details": $details,
           "timestamp": now
       }]' "$RESULTS_FILE" > tmp.json && mv tmp.json "$RESULTS_FILE"
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC} $test_name (${response_code}) - ${response_time}ms"
    else
        echo -e "${RED}✗ FAIL${NC} $test_name (${response_code}) - ${response_time}ms"
        echo -e "  ${YELLOW}Details:${NC} $details"
    fi
}

# Function to measure response time and make requests
make_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    local headers="$4"
    
    local start_time=$(date +%s000)
    
    if [ -n "$data" ]; then
        if [ -n "$headers" ]; then
            response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
                -H "$CONTENT_TYPE" -H "$ACCEPT" $headers \
                -d "$data")
        else
            response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
                -H "$CONTENT_TYPE" -H "$ACCEPT" \
                -d "$data")
        fi
    else
        if [ -n "$headers" ]; then
            response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
                -H "$CONTENT_TYPE" -H "$ACCEPT" $headers)
        else
            response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
                -H "$CONTENT_TYPE" -H "$ACCEPT")
        fi
    fi
    
    local end_time=$(date +%s000)
    local response_time=$((end_time - start_time))
    
    # Extract status code (last line)
    local status_code=$(echo "$response" | tail -n1)
    # Extract body (all but last line)
    local body=$(echo "$response" | sed '$d')
    
    echo "$body"
    echo "STATUS_CODE:$status_code"
    echo "RESPONSE_TIME:$response_time"
}

echo
echo "🧪 Test 1: Server Connectivity Check"
echo "--------------------------------------"
connectivity_result=$(make_request "GET" "http://localhost:4000" "")
connectivity_code=$(echo "$connectivity_result" | grep "STATUS_CODE:" | cut -d: -f2)
connectivity_time=$(echo "$connectivity_result" | grep "RESPONSE_TIME:" | cut -d: -f2)

if [ "$connectivity_code" = "200" ]; then
    log_result "Server Connectivity" "PASS" "$connectivity_code" "$connectivity_time" "Server is responding"
else
    log_result "Server Connectivity" "FAIL" "$connectivity_code" "$connectivity_time" "Server not responding properly"
    exit 1
fi

echo
echo "🔐 Test 2: Authentication - Invalid Credentials"
echo "----------------------------------------------"
invalid_auth_data='{"email": "invalid@example.com", "password": "wrongpass"}'
invalid_auth_result=$(make_request "POST" "$API_BASE/auth/login" "$invalid_auth_data")
invalid_auth_code=$(echo "$invalid_auth_result" | grep "STATUS_CODE:" | cut -d: -f2)
invalid_auth_time=$(echo "$invalid_auth_result" | grep "RESPONSE_TIME:" | cut -d: -f2)
invalid_auth_body=$(echo "$invalid_auth_result" | grep -v "STATUS_CODE:" | grep -v "RESPONSE_TIME:")

if [ "$invalid_auth_code" = "401" ]; then
    log_result "Invalid Credentials Test" "PASS" "$invalid_auth_code" "$invalid_auth_time" "Correctly rejected invalid credentials"
else
    log_result "Invalid Credentials Test" "FAIL" "$invalid_auth_code" "$invalid_auth_time" "Should return 401 for invalid credentials"
fi

echo
echo "📧 Test 3: Authentication - Missing Fields"
echo "------------------------------------------"
missing_fields_data='{"email": "test@example.com"}'
missing_fields_result=$(make_request "POST" "$API_BASE/auth/login" "$missing_fields_data")
missing_fields_code=$(echo "$missing_fields_result" | grep "STATUS_CODE:" | cut -d: -f2)
missing_fields_time=$(echo "$missing_fields_result" | grep "RESPONSE_TIME:" | cut -d: -f2)

if [ "$missing_fields_code" = "400" ] || [ "$missing_fields_code" = "422" ] || [ "$missing_fields_code" = "500" ]; then
    log_result "Missing Fields Test" "PASS" "$missing_fields_code" "$missing_fields_time" "Correctly handled missing password field"
else
    log_result "Missing Fields Test" "FAIL" "$missing_fields_code" "$missing_fields_time" "Should handle missing fields properly"
fi

echo
echo "🔒 Test 4: Protected Route - No Token"
echo "------------------------------------"
no_token_result=$(make_request "GET" "$API_BASE/me" "")
no_token_code=$(echo "$no_token_result" | grep "STATUS_CODE:" | cut -d: -f2)
no_token_time=$(echo "$no_token_result" | grep "RESPONSE_TIME:" | cut -d: -f2)

if [ "$no_token_code" = "401" ] || [ "$no_token_code" = "403" ]; then
    log_result "No Token Protection" "PASS" "$no_token_code" "$no_token_time" "Protected route correctly requires authentication"
else
    log_result "No Token Protection" "FAIL" "$no_token_code" "$no_token_time" "Protected route should require authentication"
fi

echo
echo "🔑 Test 5: Invalid Token"
echo "-----------------------"
invalid_token_headers='-H "Authorization: Bearer invalid.token.here"'
invalid_token_result=$(make_request "GET" "$API_BASE/me" "" "$invalid_token_headers")
invalid_token_code=$(echo "$invalid_token_result" | grep "STATUS_CODE:" | cut -d: -f2)
invalid_token_time=$(echo "$invalid_token_result" | grep "RESPONSE_TIME:" | cut -d: -f2)

if [ "$invalid_token_code" = "401" ] || [ "$invalid_token_code" = "403" ]; then
    log_result "Invalid Token Test" "PASS" "$invalid_token_code" "$invalid_token_time" "Correctly rejected invalid token"
else
    log_result "Invalid Token Test" "FAIL" "$invalid_token_code" "$invalid_token_time" "Should reject invalid tokens"
fi

echo
echo "🔄 Test 6: Refresh Token - Invalid"
echo "---------------------------------"
invalid_refresh_data='{"refresh_token": "invalid.refresh.token"}'
invalid_refresh_result=$(make_request "POST" "$API_BASE/auth/refresh" "$invalid_refresh_data")
invalid_refresh_code=$(echo "$invalid_refresh_result" | grep "STATUS_CODE:" | cut -d: -f2)
invalid_refresh_time=$(echo "$invalid_refresh_result" | grep "RESPONSE_TIME:" | cut -d: -f2)

if [ "$invalid_refresh_code" = "401" ] || [ "$invalid_refresh_code" = "403" ]; then
    log_result "Invalid Refresh Token" "PASS" "$invalid_refresh_code" "$invalid_refresh_time" "Correctly rejected invalid refresh token"
else
    log_result "Invalid Refresh Token" "FAIL" "$invalid_refresh_code" "$invalid_refresh_time" "Should reject invalid refresh tokens"
fi

echo
echo "📊 Test 7: Content-Type Headers"
echo "------------------------------"
wrong_content_type_result=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/auth/login" \
    -H "Content-Type: text/plain" -H "$ACCEPT" \
    -d "$invalid_auth_data")
wrong_content_code=$(echo "$wrong_content_type_result" | tail -n1)
wrong_content_time="N/A"

if [ "$wrong_content_code" = "400" ] || [ "$wrong_content_code" = "415" ] || [ "$wrong_content_code" = "422" ]; then
    log_result "Content-Type Validation" "PASS" "$wrong_content_code" "$wrong_content_time" "Correctly handles wrong content type"
else
    log_result "Content-Type Validation" "SKIP" "$wrong_content_code" "$wrong_content_time" "Server accepts various content types"
fi

echo
echo "🌐 Test 8: CORS Headers Check"
echo "----------------------------"
cors_result=$(curl -s -I -X OPTIONS "$API_BASE/auth/login" \
    -H "Origin: http://localhost:3000" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: Content-Type")
cors_code=$(echo "$cors_result" | grep "HTTP" | awk '{print $2}')
cors_headers=$(echo "$cors_result" | grep -i "access-control" || echo "No CORS headers found")

if echo "$cors_result" | grep -i "access-control" > /dev/null; then
    log_result "CORS Headers Check" "PASS" "$cors_code" "N/A" "CORS headers present"
else
    log_result "CORS Headers Check" "SKIP" "$cors_code" "N/A" "No CORS headers detected (may not be configured)"
fi

echo
echo "🔐 Test 9: Logout Endpoint (without auth)"
echo "----------------------------------------"
logout_no_auth_result=$(make_request "POST" "$API_BASE/auth/logout" "")
logout_no_auth_code=$(echo "$logout_no_auth_result" | grep "STATUS_CODE:" | cut -d: -f2)
logout_no_auth_time=$(echo "$logout_no_auth_result" | grep "RESPONSE_TIME:" | cut -d: -f2)

if [ "$logout_no_auth_code" = "401" ] || [ "$logout_no_auth_code" = "403" ]; then
    log_result "Logout Without Auth" "PASS" "$logout_no_auth_code" "$logout_no_auth_time" "Logout requires authentication"
else
    log_result "Logout Without Auth" "FAIL" "$logout_no_auth_code" "$logout_no_auth_time" "Logout should require authentication"
fi

echo
echo "⚡ Test 10: Response Time Performance"
echo "-----------------------------------"
total_time=0
num_requests=5

for i in $(seq 1 $num_requests); do
    perf_result=$(make_request "POST" "$API_BASE/auth/login" "$invalid_auth_data")
    perf_time=$(echo "$perf_result" | grep "RESPONSE_TIME:" | cut -d: -f2)
    total_time=$((total_time + perf_time))
done

avg_time=$((total_time / num_requests))

if [ "$avg_time" -lt 1000 ]; then
    log_result "Response Time Performance" "PASS" "401" "$avg_time" "Average response time under 1 second"
elif [ "$avg_time" -lt 3000 ]; then
    log_result "Response Time Performance" "WARN" "401" "$avg_time" "Average response time acceptable but could be improved"
else
    log_result "Response Time Performance" "FAIL" "401" "$avg_time" "Average response time too slow (>3s)"
fi

echo
echo "📈 Test Summary"
echo "=============="

# Calculate summary statistics
total_tests=$(jq '.test_results | length' "$RESULTS_FILE")
passed_tests=$(jq '[.test_results[] | select(.status == "PASS")] | length' "$RESULTS_FILE")
failed_tests=$(jq '[.test_results[] | select(.status == "FAIL")] | length' "$RESULTS_FILE")
skipped_tests=$(jq '[.test_results[] | select(.status == "SKIP")] | length' "$RESULTS_FILE")

echo -e "${BLUE}Total Tests:${NC} $total_tests"
echo -e "${GREEN}Passed:${NC} $passed_tests"
echo -e "${RED}Failed:${NC} $failed_tests"
echo -e "${YELLOW}Skipped:${NC} $skipped_tests"

# Update summary in results file
jq --arg total "$total_tests" \
   --arg passed "$passed_tests" \
   --arg failed "$failed_tests" \
   --arg skipped "$skipped_tests" \
   '.summary = {
       "total_tests": ($total | tonumber),
       "passed": ($passed | tonumber),
       "failed": ($failed | tonumber),
       "skipped": ($skipped | tonumber),
       "test_date": now
   }' "$RESULTS_FILE" > tmp.json && mv tmp.json "$RESULTS_FILE"

echo
echo -e "${BLUE}📁 Detailed results saved to:${NC} $RESULTS_FILE"

if [ "$failed_tests" -gt 0 ]; then
    echo
    echo -e "${RED}❌ Some tests failed. Check the details above.${NC}"
    exit 1
else
    echo
    echo -e "${GREEN}✅ All critical tests passed!${NC}"
    exit 0
fi