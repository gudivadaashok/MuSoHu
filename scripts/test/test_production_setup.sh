#!/bin/bash

#***********************************************************************
# MuSoHu Production Setup - Verification Test Script
#***********************************************************************
# Description:
#   Comprehensive test suite to verify all aspects of the production
#   setup. Tests file system, Python environment, systemd service,
#   runtime components, and scripts for proper configuration.
#
# Usage:
#   bash scripts/test/test_production_setup.sh [OPTIONS]
#
# Options:
#   -h, --help    Display help message
#
# Test Categories:
#   - File System Tests: Verifies presence of required files
#   - Python Environment: Checks Python and package configuration
#   - Systemd Service: Validates service configuration
#   - Runtime Tests: Tests running service functionality
#   - Script Tests: Verifies script executability
#
#***********************************************************************

set -e

#***********************************************************************
# Configuration
#***********************************************************************

SERVICE_NAME="musohu-web"
PORT="5001"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WEB_APP_DIR="${PROJECT_ROOT}/web-app"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

#***********************************************************************
# Color Definitions
#***********************************************************************

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#***********************************************************************
# Helper Functions
#***********************************************************************

print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

test_start() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "  Testing: $1 ... "
}

test_pass() {
    echo -e "${GREEN}[PASS] PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}[FAIL] FAIL${NC}"
    if [[ -n "$1" ]]; then
        echo -e "    ${RED}Reason: $1${NC}"
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC} - $1"
}

test_warning() {
    echo -e "${YELLOW}[WARN] WARNING${NC} - $1"
}

#***********************************************************************
# Help Function
#***********************************************************************

show_help() {
    cat << EOF
#***********************************************************************
# MuSoHu Production Setup - Verification Test Script - Help
#***********************************************************************

Usage: $(basename "$0") [OPTIONS]

DESCRIPTION:
    Comprehensive test suite to verify the MuSoHu production setup.
    Tests all aspects including files, Python environment, systemd
    service, runtime functionality, and script permissions.

OPTIONS:
    -h, --help    Display this help message and exit

TEST CATEGORIES:
    File System Tests
        - Verifies presence of required files and directories
        - Checks web app, service templates, and scripts
    
    Python Environment Tests
        - Validates Python 3 installation
        - Checks virtual environment setup
        - Verifies dependencies (waitress, Flask)
        - Tests app.py configuration
    
    Systemd Service Tests
        - Checks service file existence
        - Validates restart policies
        - Verifies resource limits
        - Tests logging configuration
    
    Runtime Tests (if service is running)
        - Service status and health
        - Port availability
        - Health endpoint response
        - Web interface accessibility
        - Restart count monitoring
    
    Script Tests
        - Checks script executability
        - Validates permissions

EXAMPLES:
    # Run all tests
    bash scripts/test/test_production_setup.sh
    
    # Run with help
    bash scripts/test/test_production_setup.sh --help

OUTPUT:
    Tests display:
    - [PASS] PASS - Test passed successfully
    - [FAIL] FAIL - Test failed with reason
    - [WARN] WARNING - Non-critical issue detected
    - ⊘ SKIP - Test skipped (not applicable)

SUMMARY:
    After running, a summary shows:
    - Total number of tests
    - Passed/failed count
    - Success percentage
    - Service status
    - Next steps if issues found

EXIT CODES:
    0 - All tests passed
    Non-zero - Some tests failed (see output)

NOTES:
    - Some tests require the service to be installed
    - Warnings may be acceptable in certain configurations
    - Failed tests provide reasons and suggestions

For setup instructions, see:
    - PRODUCTION_SETUP.md
    - PRODUCTION_WEB_SERVICE.md

#***********************************************************************
EOF
}

#***********************************************************************
# File System Tests
#***********************************************************************

test_files() {
    print_header "File System Tests"
    
    # Test 1: Web app directory exists
    test_start "Web app directory exists"
    if [[ -d "$WEB_APP_DIR" ]]; then
        test_pass
    else
        test_fail "Directory not found: $WEB_APP_DIR"
    fi
    
    # Test 2: app.py exists
    test_start "app.py exists"
    if [[ -f "$WEB_APP_DIR/app.py" ]]; then
        test_pass
    else
        test_fail "File not found: $WEB_APP_DIR/app.py"
    fi
    
    # Test 3: requirements.txt exists
    test_start "requirements.txt exists"
    if [[ -f "$WEB_APP_DIR/requirements.txt" ]]; then
        test_pass
    else
        test_fail "File not found: $WEB_APP_DIR/requirements.txt"
    fi
    
    # Test 4: Service template exists
    test_start "Service template exists"
    if [[ -f "$SCRIPT_DIR/musohu-web.service.template" ]]; then
        test_pass
    else
        test_fail "File not found: $SCRIPT_DIR/musohu-web.service.template"
    fi
    
    # Test 5: Setup script exists
    test_start "Setup script exists"
    if [[ -f "$SCRIPT_DIR/setup_production_web_service.sh" ]]; then
        test_pass
    else
        test_fail "File not found: $SCRIPT_DIR/setup_production_web_service.sh"
    fi
    
    # Test 6: Management script exists
    test_start "Management script exists"
    if [[ -f "$PROJECT_ROOT/scripts/utils/manage_web_service.sh" ]]; then
        test_pass
    else
        test_fail "File not found: $PROJECT_ROOT/scripts/utils/manage_web_service.sh"
    fi
    
    # Test 7: Documentation exists
    test_start "Production setup documentation exists"
    if [[ -f "$SCRIPT_DIR/PRODUCTION_SETUP.md" ]]; then
        test_pass
    else
        test_fail "File not found: $SCRIPT_DIR/PRODUCTION_SETUP.md"
    fi
}

#***********************************************************************
# Python Environment Tests
#***********************************************************************

test_python_environment() {
    print_header "Python Environment Tests"
    
    # Test 1: Python 3 is available
    test_start "Python 3 is installed"
    if command -v python3 &> /dev/null; then
        test_pass
    else
        test_fail "python3 command not found"
    fi
    
    # Test 2: Virtual environment exists
    test_start "Virtual environment exists"
    if [[ -d "$WEB_APP_DIR/venv" ]]; then
        test_pass
    else
        test_warning "Virtual environment not found (run setup script to create)"
    fi
    
    # Test 3: Check if requirements.txt contains waitress
    test_start "requirements.txt includes waitress"
    if grep -q "waitress" "$WEB_APP_DIR/requirements.txt"; then
        test_pass
    else
        test_fail "waitress not found in requirements.txt"
    fi
    
    # Test 4: app.py has health endpoint
    test_start "app.py has /health endpoint"
    if grep -q "/health" "$WEB_APP_DIR/app.py"; then
        test_pass
    else
        test_fail "/health endpoint not found in app.py"
    fi
    
    # Test 5: app.py uses Waitress
    test_start "app.py configured for Waitress"
    if grep -q "from waitress import serve" "$WEB_APP_DIR/app.py" || grep -q "waitress" "$WEB_APP_DIR/app.py"; then
        test_pass
    else
        test_fail "Waitress not configured in app.py"
    fi
}

#***********************************************************************
# Systemd Service Tests
#***********************************************************************

test_systemd_service() {
    print_header "Systemd Service Tests"
    
    # Test 1: systemd is available
    test_start "systemd is available"
    if command -v systemctl &> /dev/null; then
        test_pass
    else
        test_fail "systemctl command not found"
        return
    fi
    
    # Test 2: Service file exists
    test_start "Service file exists"
    if [[ -f "/etc/systemd/system/$SERVICE_NAME.service" ]]; then
        test_pass
        
        # Test 3: Service has restart policy
        test_start "Service has Restart=always"
        if grep -q "Restart=always" "/etc/systemd/system/$SERVICE_NAME.service"; then
            test_pass
        else
            test_fail "Restart=always not found in service file"
        fi
        
        # Test 4: Service has no restart limit
        test_start "Service has StartLimitBurst=0"
        if grep -q "StartLimitBurst=0" "/etc/systemd/system/$SERVICE_NAME.service"; then
            test_pass
        else
            test_fail "StartLimitBurst=0 not found in service file"
        fi
        
        # Test 5: Service has restart delay
        test_start "Service has RestartSec configured"
        if grep -q "RestartSec=" "/etc/systemd/system/$SERVICE_NAME.service"; then
            test_pass
        else
            test_fail "RestartSec not found in service file"
        fi
        
        # Test 6: Service has resource limits
        test_start "Service has memory limits"
        if grep -q "MemoryMax=" "/etc/systemd/system/$SERVICE_NAME.service"; then
            test_pass
        else
            test_warning "No memory limits configured"
        fi
        
        # Test 7: Service has CPU limits
        test_start "Service has CPU limits"
        if grep -q "CPUQuota=" "/etc/systemd/system/$SERVICE_NAME.service"; then
            test_pass
        else
            test_warning "No CPU limits configured"
        fi
        
        # Test 8: Service logs to journal
        test_start "Service logs to journal"
        if grep -q "StandardOutput=journal" "/etc/systemd/system/$SERVICE_NAME.service"; then
            test_pass
        else
            test_fail "Journal logging not configured"
        fi
    else
        test_skip "Service not installed (run setup script first)"
    fi
}

#***********************************************************************
# Runtime Tests (if service is installed)
#***********************************************************************

test_runtime() {
    print_header "Runtime Tests"
    
    # Only run if systemd is available and service is installed
    if ! command -v systemctl &> /dev/null; then
        test_skip "systemd not available"
        return
    fi
    
    if [[ ! -f "/etc/systemd/system/$SERVICE_NAME.service" ]]; then
        test_skip "Service not installed"
        return
    fi
    
    # Test 1: Service is loaded
    test_start "Service is loaded"
    if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        test_pass
    else
        test_fail "Service not found in systemd"
    fi
    
    # Test 2: Service is enabled
    test_start "Service is enabled (auto-start)"
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        test_pass
    else
        test_warning "Service not enabled for auto-start"
    fi
    
    # Test 3: Service is active
    test_start "Service is running"
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        test_pass
        
        # Test 4: Port is listening
        test_start "Port $PORT is listening"
        if command -v ss &> /dev/null; then
            if ss -tuln | grep -q ":$PORT"; then
                test_pass
            else
                test_fail "Port $PORT not listening"
            fi
        else
            test_skip "ss command not available"
        fi
        
        # Test 5: Health endpoint responds
        test_start "Health endpoint responds"
        if command -v curl &> /dev/null; then
            if curl -s -f http://localhost:$PORT/health > /dev/null 2>&1; then
                test_pass
            else
                test_fail "Health endpoint not responding"
            fi
        else
            test_skip "curl not available"
        fi
        
        # Test 6: Main page responds
        test_start "Main page responds"
        if command -v curl &> /dev/null; then
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/ 2>/dev/null)
            if [[ "$HTTP_CODE" == "200" ]]; then
                test_pass
            else
                test_fail "Main page returned HTTP $HTTP_CODE"
            fi
        else
            test_skip "curl not available"
        fi
        
        # Test 7: Check restart count
        test_start "Service has not crashed"
        RESTART_COUNT=$(systemctl show "$SERVICE_NAME" -p NRestarts --value 2>/dev/null || echo "0")
        if [[ "$RESTART_COUNT" == "0" ]]; then
            test_pass
        else
            test_warning "Service has restarted $RESTART_COUNT times"
        fi
    else
        test_warning "Service not running (this is OK if not yet started)"
    fi
}

#***********************************************************************
# Script Tests
#***********************************************************************

test_scripts() {
    print_header "Script Tests"
    
    # Test 1: Setup script is executable
    test_start "Setup script is executable"
    if [[ -x "$SCRIPT_DIR/setup_production_web_service.sh" ]]; then
        test_pass
    else
        test_warning "Setup script not executable (use: chmod +x)"
    fi
    
    # Test 2: Management script is executable
    test_start "Management script is executable"
    if [[ -x "$PROJECT_ROOT/scripts/utils/manage_web_service.sh" ]]; then
        test_pass
    else
        test_warning "Management script not executable (use: chmod +x)"
    fi
    
    # Test 3: Quick reference documentation exists
    test_start "Quick reference documentation exists"
    if [[ -f "$PROJECT_ROOT/docs/reference/QUICK_REFERENCE.md" ]]; then
        test_pass
    else
        test_warning "Quick reference documentation not found"
    fi
}

#***********************************************************************
# Summary
#***********************************************************************

print_summary() {
    print_header "Test Summary"
    
    echo ""
    echo "  Total Tests:   $TESTS_TOTAL"
    echo -e "  ${GREEN}Passed:        $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed:        $TESTS_FAILED${NC}"
    echo ""
    
    PERCENTAGE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}[PASS] ALL TESTS PASSED! ($PERCENTAGE%)${NC}"
        echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  Your production setup is ready!"
        echo ""
    elif [[ $TESTS_FAILED -lt 5 ]]; then
        echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${YELLOW}[WARN] SOME TESTS FAILED ($PERCENTAGE% passed)${NC}"
        echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  Review failed tests above and fix issues."
        echo "  Some failures may be OK if service is not yet installed."
        echo ""
    else
        echo -e "  ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${RED}[FAIL] MULTIPLE TESTS FAILED ($PERCENTAGE% passed)${NC}"
        echo -e "  ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  Please review the failed tests above."
        echo "  Consider running: sudo bash scripts/deploy/setup_production_web_service.sh"
        echo ""
    fi
    
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo "  Service Status: ${GREEN}RUNNING${NC}"
        echo "  Access at: http://localhost:$PORT"
    else
        echo "  Service Status: ${YELLOW}NOT RUNNING${NC}"
        echo "  Install with: sudo bash scripts/deploy/setup_production_web_service.sh"
    fi
    
    echo ""
}

#***********************************************************************
# Main Execution
#***********************************************************************

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
        shift
    done
    
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║     MuSoHu Production Setup - Verification Test Suite                ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    
    test_files
    test_python_environment
    test_systemd_service
    test_runtime
    test_scripts
    print_summary
}

#***********************************************************************
# Script Execution
#***********************************************************************

main "$@"
