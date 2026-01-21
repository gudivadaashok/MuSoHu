#!/bin/bash

#***********************************************************************
# MuSoHu Project - System Information Detection Utility
#***********************************************************************
# Description:
#   This script detects Ubuntu release year and CUDA version from the host.
#   Can be sourced by other scripts or run standalone for system diagnostics.
#
# Usage:
#   ./detect_system_info.sh [OPTIONS]
#   source detect_system_info.sh  # For use in other scripts
#
# Options:
#   -h, --help          Show this help message
#   -d, --debug         Enable debug logging
#   -q, --quiet         Suppress non-error output
#
# Functions exported:
#   - detect_ubuntu_version()
#   - detect_cuda_version()
#   - display_system_info()
#   - detect_all()
#
# Examples:
#   ./detect_system_info.sh
#   source detect_system_info.sh && detect_all
#
#***********************************************************************

#***********************************************************************
# Configuration and Initialization
#***********************************************************************

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging configuration
if [ -f "${SCRIPT_DIR}/logging_config.sh" ]; then
    source "${SCRIPT_DIR}/logging_config.sh"
else
    # Fallback logging if logging_config.sh not found
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { [ "$DEBUG_ENABLED" = "true" ] && echo "[DEBUG] $1"; }
    log_warning() { echo "[WARNING] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
fi

# Global variables
QUIET_MODE=false

#***********************************************************************
# Help and Usage
#***********************************************************************

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

System Information Detection Utility for MuSoHu Project

This script detects Ubuntu release year and CUDA version from the host system.
It can be sourced by other scripts or run standalone for diagnostics.

OPTIONS:
    -h, --help          Show this help message and exit
    -d, --debug         Enable debug logging
    -q, --quiet         Suppress non-error output

FUNCTIONS (when sourced):
    detect_ubuntu_version    Detect Ubuntu version and release year
    detect_cuda_version      Detect CUDA version from nvcc or nvidia-smi
    display_system_info      Display detected system information
    detect_all               Run all detection functions

EXAMPLES:
    # Run standalone
    ./detect_system_info.sh
    
    # Run with debug output
    ./detect_system_info.sh --debug
    
    # Source in another script
    source detect_system_info.sh && detect_all

ENVIRONMENT VARIABLES SET:
    UBUNTU_RELEASE_YEAR     Ubuntu major version (e.g., 22 for 22.04)
    CUDA_MAJOR              CUDA major version
    CUDA_MINOR              CUDA minor version

NOTES:
    - Requires /etc/os-release for Ubuntu detection
    - CUDA detection requires nvcc or nvidia-smi
    - Returns "unknown" if system information cannot be detected

EOF
}

#***********************************************************************
# Utility Functions
#***********************************************************************

# Output function respecting quiet mode
output() {
    if [ "$QUIET_MODE" = false ]; then
        log_info "$1"
    else
        log_debug "$1"
    fi
}

#***********************************************************************
# System Detection Functions
#***********************************************************************

detect_ubuntu_version() {
    log_debug "Starting Ubuntu version detection..."
    
    if [ -f /etc/os-release ]; then
        # Extract Ubuntu version (e.g., "22.04" -> "22")
        UBUNTU_VERSION=$(grep "VERSION_ID=" /etc/os-release | cut -d'"' -f2)
        export UBUNTU_RELEASE_YEAR=$(echo "$UBUNTU_VERSION" | cut -d'.' -f1)
        
        log_debug "Found /etc/os-release with VERSION_ID=$UBUNTU_VERSION"
        output "Detected Ubuntu: $UBUNTU_VERSION (Release Year: $UBUNTU_RELEASE_YEAR)"
        log_success "Ubuntu version detection completed"
    else
        export UBUNTU_RELEASE_YEAR="unknown"
        log_warning "Could not detect Ubuntu version - /etc/os-release not found"
    fi
}

detect_cuda_version() {
    log_debug "Starting CUDA version detection..."
    local cuda_found=false
    
    # Try nvcc first
    log_debug "Attempting to detect CUDA via nvcc..."
    if command -v nvcc >/dev/null 2>&1; then
        CUDA_VERSION=$(nvcc --version | grep "release" | sed 's/.*release \([0-9]*\.[0-9]*\).*/\1/')
        if [ ! -z "$CUDA_VERSION" ]; then
            export CUDA_MAJOR=$(echo "$CUDA_VERSION" | cut -d'.' -f1)
            export CUDA_MINOR=$(echo "$CUDA_VERSION" | cut -d'.' -f2)
            output "Detected CUDA (nvcc): $CUDA_VERSION"
            log_debug "CUDA Major: $CUDA_MAJOR, CUDA Minor: $CUDA_MINOR"
            cuda_found=true
        fi
    else
        log_debug "nvcc command not found"
    fi
    
    # Try nvidia-smi as fallback
    if [ "$cuda_found" = false ]; then
        log_debug "Attempting to detect CUDA via nvidia-smi..."
        if command -v nvidia-smi >/dev/null 2>&1; then
            CUDA_VERSION=$(nvidia-smi | grep "CUDA Version:" | sed 's/.*CUDA Version: \([0-9]*\.[0-9]*\).*/\1/')
            if [ ! -z "$CUDA_VERSION" ]; then
                export CUDA_MAJOR=$(echo "$CUDA_VERSION" | cut -d'.' -f1)
                export CUDA_MINOR=$(echo "$CUDA_VERSION" | cut -d'.' -f2)
                output "Detected CUDA (nvidia-smi): $CUDA_VERSION"
                log_debug "CUDA Major: $CUDA_MAJOR, CUDA Minor: $CUDA_MINOR"
                cuda_found=true
            fi
        else
            log_debug "nvidia-smi command not found"
        fi
    fi
    
    # Set defaults if not found
    if [ "$cuda_found" = false ]; then
        export CUDA_MAJOR="unknown"
        export CUDA_MINOR="unknown"
        log_warning "CUDA not detected or not available"
    else
        log_success "CUDA version detection completed"
    fi
}

#***********************************************************************
# Display Functions
#***********************************************************************


display_system_info() {
    log_debug "Displaying system information summary..."
    echo "=== System Information ==="
    echo "Ubuntu Release Year: $UBUNTU_RELEASE_YEAR"
    echo "CUDA Major Version: $CUDA_MAJOR"
    echo "CUDA Minor Version: $CUDA_MINOR"
    echo "Full CUDA Version: $CUDA_MAJOR.$CUDA_MINOR"
    echo "=========================="
}

#***********************************************************************
# Main Detection Function
#***********************************************************************

# Main function to detect all system info
detect_all() {
    log_debug "Starting comprehensive system detection..."
    detect_ubuntu_version
    detect_cuda_version
    display_system_info
    log_success "System detection completed successfully"
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
            -q|--quiet)
                QUIET_MODE=true
                log_debug "Quiet mode enabled"
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
# Function Exports
#***********************************************************************

# Export the functions
export -f detect_ubuntu_version
export -f detect_cuda_version
export -f display_system_info
export -f detect_all

#***********************************************************************
# Main Execution
#***********************************************************************

# If script is run directly (not sourced), run detection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_debug "Script running in standalone mode"
    parse_arguments "$@"
    detect_all
fi