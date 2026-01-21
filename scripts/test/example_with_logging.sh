#!/bin/bash

#***********************************************************************
# MuSoHu Project - Logging Configuration Example Script
#***********************************************************************
# Description:
#   This script demonstrates the proper usage of the MuSoHu logging
#   configuration system. It shows all logging levels and best practices
#   for implementing logging in your scripts.
#
# Usage:
#   ./example_with_logging.sh [OPTIONS]
#
# Options:
#   -h, --help          Show this help message
#   -d, --debug         Enable debug logging output
#   -s, --skip-sleep    Skip sleep delays for faster execution
#
# Features Demonstrated:
#   - Log separators for visual organization
#   - Info messages for general information
#   - Debug messages for detailed diagnostics
#   - Success messages for completed operations
#   - Warning messages for non-critical issues
#   - Error messages for failures
#   - Log file location and access
#
# Examples:
#   ./example_with_logging.sh
#   ./example_with_logging.sh --debug
#   ./example_with_logging.sh --debug --skip-sleep
#
#
#***********************************************************************

#***********************************************************************
# Configuration and Initialization
#***********************************************************************

# Source the logging configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/logging_config.sh"

# Script configuration
SKIP_SLEEP=false

#***********************************************************************
# Help and Usage
#***********************************************************************

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Logging Configuration Example Script for MuSoHu Project

This script demonstrates the proper usage of the logging system including
all logging levels, separators, and best practices for script development.

OPTIONS:
    -h, --help          Show this help message and exit
    -d, --debug         Enable debug logging output
    -s, --skip-sleep    Skip sleep delays for faster execution

LOGGING LEVELS DEMONSTRATED:
    log_debug           Detailed diagnostic information
    log_info            General informational messages
    log_success         Successful operation completion
    log_warning         Non-critical issues and warnings
    log_error           Error conditions and failures
    log_separator       Visual section dividers

EXAMPLES:
    # Run with default settings
    ./example_with_logging.sh
    
    # Enable debug output
    ./example_with_logging.sh --debug
    
    # Run quickly without delays
    ./example_with_logging.sh --skip-sleep
    
    # Debug mode with no delays
    ./example_with_logging.sh -d -s

OUTPUT:
    Console output with color-coded messages
    Log file: scripts/logs/example_with_logging_<timestamp>.log

NOTES:
    - Debug messages only appear in console when --debug is enabled
    - All messages are always written to the log file
    - Log files are timestamped and stored in scripts/logs/

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
                log_debug "Debug mode enabled via command line"
                shift
                ;;
            -s|--skip-sleep)
                SKIP_SLEEP=true
                log_debug "Sleep delays disabled"
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
# Utility Functions
#***********************************************************************

# Conditional sleep based on skip flag
do_sleep() {
    if [ "$SKIP_SLEEP" = false ]; then
        sleep "$1"
    else
        log_debug "Skipping sleep delay"
    fi
}

#***********************************************************************
# Example Operations
#***********************************************************************

operation_1() {
    log_debug "Beginning operation 1: Successful operation demo"
    log_info "Performing operation 1..."
    do_sleep 1
    log_debug "Operation 1 processing... simulating successful execution"
    log_success "Operation 1 completed successfully"
}

operation_2() {
    log_debug "Beginning operation 2: Warning condition demo"
    log_info "Performing operation 2..."
    do_sleep 1
    log_debug "Operation 2 encountered minor issues (simulated)"
    log_warning "Operation 2 completed with warnings"
}

operation_3() {
    log_debug "Beginning operation 3: Error condition demo"
    log_info "Performing operation 3..."
    do_sleep 1
    log_debug "Operation 3 failed due to missing dependency (simulated)"
    log_error "Operation 3 failed - this is a demonstration error"
}

#***********************************************************************
# Main Execution
#***********************************************************************

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Start script execution
    log_separator
    log_info "Starting logging example script..."
    log_debug "Script initialization complete"
    log_debug "Log file location: $LOG_FILE"
    log_debug "Debug enabled: $DEBUG_ENABLED"
    
    # Execute example operations
    log_separator
    operation_1
    
    log_separator
    operation_2
    
    log_separator
    operation_3
    
    # Cleanup and completion
    log_separator
    log_debug "Cleaning up resources (simulated)"
    log_info "Script execution completed"
    log_info "Log file: $LOG_FILE"
    log_debug "All operations demonstrated successfully"
}

# Run main function with all arguments
main "$@"