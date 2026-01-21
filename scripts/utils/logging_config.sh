#!/bin/bash

#***********************************************************************
# MuSoHu Project - Logging Configuration System
#***********************************************************************
# Description:
#   Central logging configuration for all MuSoHu scripts. Provides
#   consistent logging functions, color-coded output, and automatic
#   log file management with timestamps.
#
# Usage:
#   source /path/to/logging_config.sh
#
# Functions Provided:
#   log_debug       Debug-level messages (only shown if DEBUG_ENABLED=true)
#   log_info        Informational messages
#   log_success     Success messages (green)
#   log_warning     Warning messages (yellow)
#   log_error       Error messages (red)
#   log_separator   Visual separator line
#
# Environment Variables:
#   DEBUG_ENABLED   Set to "true" to enable debug output (default: false)
#   LOG_DIR         Directory for log files (auto-created)
#   LOG_FILE        Full path to current log file
#
# Features:
#   - Automatic log directory creation (scripts/logs)
#   - Timestamped log files per script
#   - Color-coded terminal output
#   - Dual output (console and file)
#   - Debug mode control
#
# Examples:
#   # In your script
#   source "$(dirname "$0")/logging_config.sh"
#   log_info "Starting process..."
#   log_success "Process completed"
#
#   # Enable debug mode
#   export DEBUG_ENABLED=true
#   source logging_config.sh
#
#***********************************************************************

#***********************************************************************
# Directory and File Configuration
#***********************************************************************

# Log directory - always use scripts/logs regardless of where script is run from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
mkdir -p "$LOG_DIR"

# Get the name of the calling script (without path and extension)
CALLING_SCRIPT=$(basename "${0}" .sh)

# Log file with script name and timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/${CALLING_SCRIPT}_${TIMESTAMP}.log"

#***********************************************************************
# Color Definitions
#***********************************************************************

# Terminal colors for different log levels
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

#***********************************************************************
# Configuration Variables
#***********************************************************************

# Debug logging control (can be overridden by setting DEBUG_ENABLED before sourcing)
DEBUG_ENABLED=${DEBUG_ENABLED:-false}

# Common logging variables
LOG_TO_FILE="tee -a \"$LOG_FILE\""

#***********************************************************************
# Helper Functions
#***********************************************************************

# Generate timestamp for log messages
get_timestamp_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

#***********************************************************************
# Logging Functions
#***********************************************************************

# Debug level logging - only shown when DEBUG_ENABLED=true
log_debug() {
    local message="$(get_timestamp_message "$1")"
    if [[ "$DEBUG_ENABLED" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $message" | eval "$LOG_TO_FILE"
    else
        # Only write to log file, not to terminal
        echo "[DEBUG] $message" >> "$LOG_FILE"
    fi
}

# Informational messages - always shown
log_info() {
    local message="$(get_timestamp_message "$1")"
    echo -e "${BLUE}[INFO]${NC} $message" | eval "$LOG_TO_FILE"
}

# Success messages - operations completed successfully
log_success() {
    local message="$(get_timestamp_message "$1")"
    echo -e "${GREEN}[SUCCESS]${NC} $message" | eval "$LOG_TO_FILE"
}

# Warning messages - non-critical issues
log_warning() {
    local message="$(get_timestamp_message "$1")"
    echo -e "${YELLOW}[WARNING]${NC} $message" | eval "$LOG_TO_FILE"
}

# Error messages - critical issues and failures
log_error() {
    local message="$(get_timestamp_message "$1")"
    echo -e "${RED}[ERROR]${NC} $message" | eval "$LOG_TO_FILE"
}

# Visual separator for log organization
log_separator() {
    echo "_______________________*******_______________________" | eval "$LOG_TO_FILE"
}

#***********************************************************************
# Function and Variable Exports
#***********************************************************************

# Export configuration variables
export DEBUG_ENABLED
export LOG_DIR
export LOG_FILE
export LOG_TO_FILE

# Export logging functions for use in other scripts
export -f get_timestamp_message
export -f log_debug
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_separator

#***********************************************************************
# Initialization Message
#***********************************************************************

# Log initialization (debug only)
if [[ "$DEBUG_ENABLED" == "true" ]]; then
    log_debug "Logging system initialized"
    log_debug "Log file: $LOG_FILE"
fi