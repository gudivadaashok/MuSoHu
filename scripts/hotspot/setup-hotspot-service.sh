#!/bin/bash

#***********************************************************************
# Setup Hotspot Systemd Service
#***********************************************************************
# This script configures the hotspot to start automatically on boot
# It installs a systemd service that manages the hotspot lifecycle
# and ensures the hotspot is available immediately after system startup
#***********************************************************************

#***********************************************************************
# Help function
#***********************************************************************

show_help() {
    cat << EOF
Usage: sudo bash setup-hotspot-service.sh [OPTIONS]

Install and enable the hotspot systemd service for automatic startup.

This script:
  - Installs the hotspot.service file to /etc/systemd/system/
  - Reloads the systemd daemon
  - Enables the service to start automatically on boot

Service Management Commands:
  Start now:        sudo systemctl start hotspot.service
  Stop:             sudo systemctl stop hotspot.service
  Restart:          sudo systemctl restart hotspot.service
  Check status:     sudo systemctl status hotspot.service
  Disable on boot:  sudo systemctl disable hotspot.service
  View logs:        journalctl -u hotspot.service

Options:
  -h, --help     Display this help message and exit

Examples:
  sudo bash setup-hotspot-service.sh
  sudo bash setup-hotspot-service.sh --help

Prerequisites:
  - DNS must be configured first using setup-hotspot-dns.sh
  - hotspot.service file must exist in the same directory

Note: This script requires root privileges to install systemd services.

EOF
}

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

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Service_Service_File="$SCRIPT_DIR/hotspot.service"
source "$(dirname "$SCRIPT_DIR")/utils/logging_config.sh"

log_info "Starting hotspot service setup..."
log_separator

#***********************************************************************
# Install systemd service
#***********************************************************************

# Copy service file to systemd directory
log_info "Installing hotspot systemd service..."
sudo cp "$Service_Service_File" /etc/systemd/system/

if [ $? -eq 0 ]; then
    log_success "Service file copied to /etc/systemd/system/"
else
    log_error "Failed to copy service file"
    exit 1
fi

#***********************************************************************
# Configure systemd to recognize the service
#***********************************************************************

# Reload systemd daemon to recognize new service
log_info "Reloading systemd daemon..."
sudo systemctl daemon-reload

if [ $? -eq 0 ]; then
    log_success "Systemd daemon reloaded successfully"
else
    log_error "Failed to reload systemd daemon"
    exit 1
fi

#***********************************************************************
# Enable service for automatic startup
#***********************************************************************

# Enable the service to start on boot
log_info "Enabling hotspot service to start on boot..."
sudo systemctl enable hotspot.service

if [ $? -eq 0 ]; then
    log_success "Hotspot service enabled for automatic startup"
else
    log_error "Failed to enable hotspot service"
    exit 1
fi

#***********************************************************************
# Service setup complete
#***********************************************************************

log_separator
log_success "Hotspot service installed and enabled successfully"
log_separator

echo ""
log_info "Service Management Commands:"
log_info "  Start now:        sudo systemctl start hotspot.service"
log_info "  Stop:             sudo systemctl stop hotspot.service"
log_info "  Restart:          sudo systemctl restart hotspot.service"
log_info "  Check status:     sudo systemctl status hotspot.service"
log_info "  Disable on boot:  sudo systemctl disable hotspot.service"
log_info "  View logs:        journalctl -u hotspot.service"
echo ""

log_separator
log_info "The hotspot will start automatically on next boot"
log_separator