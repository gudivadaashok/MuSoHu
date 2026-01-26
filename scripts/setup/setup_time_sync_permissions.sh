#!/bin/bash
################################################################################
# Setup Time Sync Permissions for MuSoHu Web Application
# 
# This script configures sudo permissions to allow the web application user
# to set system time without requiring a password.
# 
# Usage: sudo bash setup_time_sync_permissions.sh
################################################################################

set -e

# Source logging utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="${SCRIPT_DIR}/../utils"
if [ -f "${UTILS_DIR}/logging_config.sh" ]; then
    source "${UTILS_DIR}/logging_config.sh"
else
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_warning() { echo "[WARNING] $*"; }
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run with sudo privileges"
    exit 1
fi

log_info "Setting up time sync permissions for MuSoHu web application..."

# Get the current user (the one who ran sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"
log_info "Configuring permissions for user: $ACTUAL_USER"

# Create sudoers configuration file
SUDOERS_FILE="/etc/sudoers.d/musohu-time-sync"

log_info "Creating sudoers configuration at $SUDOERS_FILE"

cat > "$SUDOERS_FILE" << EOF
# MuSoHu Time Synchronization Permissions
# This file allows the web application to sync system time without password
# Created: $(date)

# Allow user to run time-related commands without password
$ACTUAL_USER ALL=(ALL) NOPASSWD: /usr/bin/timedatectl set-time *
$ACTUAL_USER ALL=(ALL) NOPASSWD: /usr/bin/timedatectl set-timezone *
$ACTUAL_USER ALL=(ALL) NOPASSWD: /usr/bin/timedatectl set-ntp *
$ACTUAL_USER ALL=(ALL) NOPASSWD: /usr/bin/date -u -s *
EOF

# Set correct permissions for sudoers file
chmod 0440 "$SUDOERS_FILE"

# Validate sudoers file
if visudo -c -f "$SUDOERS_FILE"; then
    log_success "Sudoers configuration created successfully"
    log_info "The following commands can now be run without password:"
    log_info "  - sudo timedatectl set-time <time>"
    log_info "  - sudo timedatectl set-timezone <timezone>"
    log_info "  - sudo timedatectl set-ntp <true|false>"
    log_info "  - sudo date -u -s <time>"
else
    log_error "Sudoers configuration validation failed"
    rm -f "$SUDOERS_FILE"
    exit 1
fi

log_success "Time sync permissions setup complete!"
log_info ""
log_info "You can now use the web application to sync server time with client time."
log_info "Note: The web application must be restarted to use the new permissions."
