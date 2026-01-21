#!/bin/bash

#***********************************************************************
# MuSoHu Project - System Detection Testing Utility
#***********************************************************************
# Description:
#   This script tests the system information detection functionality
#   and demonstrates various methods to detect and use system variables.
#   Useful for debugging and verifying system configuration detection.
#
# Usage:
#   ./test_system_detection.sh [OPTIONS]
#
# Options:
#   -h, --help          Show this help message
#   -d, --debug         Enable debug logging
#   -v, --verbose       Show detailed output
#   -e, --export        Show export commands for manual setup
#
# Test Methods:
#   1. Detection utility (automatic detection)
#   2. Manual environment variables
#   3. Current environment check
#   4. Export commands generation
#
# Examples:
#   ./test_system_detection.sh
#   ./test_system_detection.sh --debug
#   ./test_system_detection.sh --verbose --export
#
#***********************************************************************

#***********************************************************************
# Configuration and Initialization
#***********************************************************************

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging configuration
if [ -f "${SCRIPT_DIR}/../utils/logging_config.sh" ]; then
    source "${SCRIPT_DIR}/../utils/logging_config.sh"
else
    # Fallback logging
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { [ "$DEBUG_ENABLED" = "true" ] && echo "[DEBUG] $1"; }
    log_warning() { echo "[WARNING] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_separator() { echo "====================================="; }
fi

# Script options
VERBOSE_MODE=false
SHOW_EXPORTS=false

#***********************************************************************
# Help and Usage
#***********************************************************************

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

System Detection Testing Utility for MuSoHu Project

This script tests the system information detection functionality and
demonstrates various methods to detect and configure system variables.

OPTIONS:
    -h, --help          Show this help message and exit
    -d, --debug         Enable debug logging output
    -v, --verbose       Show detailed output and diagnostics
    -e, --export        Display export commands for manual setup

TEST METHODS:
    Method 1: Automatic Detection
        Uses detect_system_info.sh utility for automatic detection
        
    Method 2: Manual Variables
        Shows how to manually set environment variables
        
    Method 3: Environment Check
        Verifies current environment variable state
        
    Method 4: Export Commands
        Generates commands for manual configuration

EXAMPLES:
    # Basic test
    ./test_system_detection.sh
    
    # Debug mode with verbose output
    ./test_system_detection.sh --debug --verbose
    
    # Generate export commands
    ./test_system_detection.sh --export
    
    # Full diagnostic run
    ./test_system_detection.sh -d -v -e

ENVIRONMENT VARIABLES TESTED:
    UBUNTU_RELEASE_YEAR     Ubuntu major version number
    CUDA_MAJOR              CUDA major version number
    CUDA_MINOR              CUDA minor version number

OUTPUT:
    Console output with test results
    Log file: scripts/logs/test_system_detection_<timestamp>.log

NOTES:
    - Requires detect_system_info.sh in the same directory
    - All output is logged for debugging purposes
    - Use --export to get copy-paste ready commands

EOF
}

#***********************************************************************
# Argument Parsing
#***********************************************************************

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--debug)
                export DEBUG_ENABLED=true
                log_debug "Debug mode enabled"
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                log_debug "Verbose mode enabled"
                shift
                ;;
            -e|--export)
                SHOW_EXPORTS=true
                log_debug "Export mode enabled"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
}

#***********************************************************************
# Test Functions
#***********************************************************************

test_method_1() {
    log_separator
    log_info "=== Method 1: Using Detection Utility ==="
    log_debug "Sourcing detect_system_info.sh..."
    
    if [ -f "${SCRIPT_DIR}/detect_system_info.sh" ]; then
        source "${SCRIPT_DIR}/detect_system_info.sh"
        log_success "Detection utility loaded successfully"
        
        if [ "$VERBOSE_MODE" = true ]; then
            log_info "Available detection functions:"
            log_info "  - detect_ubuntu_version"
            log_info "  - detect_cuda_version"
            log_info "  - display_system_info"
            log_info "  - detect_all"
        fi
    else
        log_error "detect_system_info.sh not found in ${SCRIPT_DIR}"
        return 1
    fi
}

test_method_2() {
    log_separator
    log_info "=== Method 2: Manual Environment Variables ==="
    log_info "You can also set them manually:"
    echo "export UBUNTU_RELEASE_YEAR=22"
    echo "export CUDA_MAJOR=11"
    echo "export CUDA_MINOR=8"
    
    if [ "$VERBOSE_MODE" = true ]; then
        log_debug "Manual setup is useful when:"
        log_debug "  - System detection is not available"
        log_debug "  - You want to override detected values"
        log_debug "  - Running in containerized environments"
    fi
}

test_method_3() {
    log_separator
    log_info "=== Method 3: Current Environment Check ==="
    
    if [ ! -z "$UBUNTU_RELEASE_YEAR" ]; then
        log_success "UBUNTU_RELEASE_YEAR is set to: $UBUNTU_RELEASE_YEAR"
    else
        log_warning "UBUNTU_RELEASE_YEAR is not set"
    fi

    if [ ! -z "$CUDA_MAJOR" ] && [ ! -z "$CUDA_MINOR" ]; then
        log_success "CUDA version is set to: $CUDA_MAJOR.$CUDA_MINOR"
        
        if [ "$VERBOSE_MODE" = true ]; then
            log_info "  CUDA_MAJOR: $CUDA_MAJOR"
            log_info "  CUDA_MINOR: $CUDA_MINOR"
        fi
    else
        log_warning "CUDA version is not set"
        
        if [ "$VERBOSE_MODE" = true ]; then
            log_debug "  CUDA_MAJOR: ${CUDA_MAJOR:-<not set>}"
            log_debug "  CUDA_MINOR: ${CUDA_MINOR:-<not set>}"
        fi
    fi
}

test_method_4() {
    if [ "$SHOW_EXPORTS" = true ]; then
        log_separator
        log_info "=== Method 4: Export Commands for Manual Setup ==="
        echo ""
        echo "# Copy and paste these commands to set environment variables:"
        echo "export UBUNTU_RELEASE_YEAR=${UBUNTU_RELEASE_YEAR:-unknown}"
        echo "export CUDA_MAJOR=${CUDA_MAJOR:-unknown}"
        echo "export CUDA_MINOR=${CUDA_MINOR:-unknown}"
        echo ""
        
        if [ "$VERBOSE_MODE" = true ]; then
            log_debug "These commands can be added to:"
            log_debug "  - ~/.bashrc or ~/.zshrc for permanent setup"
            log_debug "  - Script headers for per-script configuration"
            log_debug "  - Docker/container environment files"
        fi
    fi
}

#***********************************************************************
# Summary Functions
#***********************************************************************

display_summary() {
    log_separator
    log_info "=== Test Summary ==="
    log_info "System detection test completed"
    log_info ""
    log_info "Detected Values:"
    log_info "  Ubuntu Release Year: ${UBUNTU_RELEASE_YEAR:-<not detected>}"
    log_info "  CUDA Major Version:  ${CUDA_MAJOR:-<not detected>}"
    log_info "  CUDA Minor Version:  ${CUDA_MINOR:-<not detected>}"
    
    if [ "$VERBOSE_MODE" = true ]; then
        log_separator
        log_info "Additional Information:"
        log_info "  Log file: $LOG_FILE"
        log_info "  Script directory: $SCRIPT_DIR"
        log_info "  Debug enabled: ${DEBUG_ENABLED:-false}"
    fi
    
    log_separator
}

#***********************************************************************
# Main Execution
#***********************************************************************

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Start testing
    log_separator
    log_info "Testing system information detection..."
    log_debug "Script started at $(date)"
    
    # Run test methods
    test_method_1
    echo ""
    
    test_method_2
    echo ""
    
    test_method_3
    echo ""
    
    test_method_4
    
    # Display summary
    display_summary
    
    log_success "All tests completed"
}

# Run main function with all arguments
main "$@"