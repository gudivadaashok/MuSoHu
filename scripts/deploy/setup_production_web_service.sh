#!/bin/bash

################################################################################
# MuSoHu Production Web Service Setup Script
#
# This script configures the MuSoHu web application as a production-ready
# systemd service with:
#   - Automatic restart on failure
#   - Resource limits (CPU, Memory)
#   - Systemd journal logging
#   - Auto-start on boot
#   - Health check endpoint
#
# Usage:
# Example usage:
#   sudo bash scripts/deploy/setup_production_web_service.sh
#
#
# Requirements:
#   - Ubuntu/Debian Linux with systemd
#   - Python 3.8+
#   - sudo privileges
################################################################################

set -e  # Exit on any error

# Save the script directory before sourcing anything (to prevent it from being overwritten)
SETUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging utilities if available
LOGGING_CONFIG="${SETUP_SCRIPT_DIR}/../utils/logging_config.sh"

if [[ -f "$LOGGING_CONFIG" ]]; then
    source "$LOGGING_CONFIG"
else
    # Fallback logging functions
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_warning() { echo "[WARNING] $*"; }
    log_error() { echo "[ERROR] $*"; }
fi

# Configuration (use SETUP_SCRIPT_DIR which won't be overwritten by logging_config.sh)
PROJECT_ROOT="$(cd "${SETUP_SCRIPT_DIR}/../.." && pwd)"
WEB_APP_DIR="${PROJECT_ROOT}/web-app"
VENV_DIR="${WEB_APP_DIR}/venv"
SERVICE_NAME="musohu-web"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TEMPLATE_FILE="${SETUP_SCRIPT_DIR}/templates/musohu-web.service.template"
SERVICE_PORT="8000"  # Port must be >= 1024 for non-root users

################################################################################
# Preflight Checks
################################################################################

check_requirements() {
    log_info "Performing preflight checks..."

    # Check if running as root/sudo
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run with sudo privileges"
        log_info "Usage: sudo bash $0"
        exit 1
    fi

    # Check if systemd is available
    if ! command -v systemctl &> /dev/null; then
        log_error "systemd is not available on this system"
        exit 1
    fi

    # Check if web app directory exists
    if [[ ! -d "$WEB_APP_DIR" ]]; then
        log_error "Web app directory not found: $WEB_APP_DIR"
        exit 1
    fi

    # Check if app.py exists
    if [[ ! -f "$WEB_APP_DIR/app.py" ]]; then
        log_error "app.py not found in $WEB_APP_DIR"
        exit 1
    fi

    # Check if service template exists
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        log_error "Service template not found: $TEMPLATE_FILE"
        exit 1
    fi

    # Check if python3-venv is installed
    if ! dpkg -l | grep -q python3-venv 2>/dev/null; then
        log_warning "python3-venv package not found, installing..."
        if command -v apt &> /dev/null; then
            apt update
            apt install -y python3-venv
            log_success "python3-venv installed successfully"
        else
            log_error "apt package manager not found. Please install python3-venv manually"
            log_info "Run: sudo apt install python3-venv"
            exit 1
        fi
    fi

    log_success "Preflight checks passed"
}

################################################################################
# Python Environment Setup
################################################################################

setup_python_environment() {
    log_info "Setting up Python virtual environment..."

    # Get the actual user who ran sudo
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_GROUP=$(id -gn "$ACTUAL_USER")

    cd "$WEB_APP_DIR"

    # Create virtual environment if it doesn't exist
    if [[ ! -d "$VENV_DIR" ]]; then
        log_info "Creating virtual environment..."
        sudo -u "$ACTUAL_USER" python3 -m venv venv
    else
        log_info "Virtual environment already exists"
    fi

    # Activate and upgrade pip (with quiet flag to reduce output)
    log_info "Upgrading pip..."
    sudo -u "$ACTUAL_USER" bash -c "source venv/bin/activate && pip install --upgrade pip -q" || {
        log_warning "Pip upgrade had issues, continuing anyway..."
    }

    # Install requirements
    if [[ -f "requirements.txt" ]]; then
        log_info "Installing Python dependencies (this may take a few minutes)..."
        log_info "Requirements file content:"
        cat requirements.txt
        
        # Try installing with verbose output on error
        if ! sudo -u "$ACTUAL_USER" bash -c "source venv/bin/activate && pip install -r requirements.txt" 2>&1 | tee /tmp/pip_install.log; then
            log_error "Failed to install requirements"
            log_info "Error details:"
            tail -20 /tmp/pip_install.log
            log_info "Attempting to continue anyway - some packages may be missing"
        else
            log_success "Python dependencies installed"
        fi
    else
        log_warning "requirements.txt not found"
    fi

    # Verify uvicorn is installed
    if sudo -u "$ACTUAL_USER" bash -c "source venv/bin/activate && python -c 'import uvicorn' 2>/dev/null"; then
        log_success "Uvicorn ASGI server is installed"
    else
        log_warning "Uvicorn not found, installing..."
        sudo -u "$ACTUAL_USER" bash -c "source venv/bin/activate && pip install uvicorn -q"
    fi

    log_success "Python environment ready"
}

################################################################################
# Service Configuration
################################################################################

create_service_file() {
    log_info "Creating systemd service file..."

    # Get the actual user who ran sudo
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_GROUP=$(id -gn "$ACTUAL_USER")

    # Read template and replace placeholders
    sed -e "s|USER_PLACEHOLDER|${ACTUAL_USER}|g" \
        -e "s|GROUP_PLACEHOLDER|${ACTUAL_GROUP}|g" \
        -e "s|WEB_APP_DIR_PLACEHOLDER|${WEB_APP_DIR}|g" \
        -e "s|PORT_PLACEHOLDER|${SERVICE_PORT}|g" \
        "$TEMPLATE_FILE" > "$SERVICE_FILE"

    # Validate that all placeholders were replaced
    if grep -q "PLACEHOLDER" "$SERVICE_FILE"; then
        log_error "Failed to replace all placeholders in service file"
        cat "$SERVICE_FILE" | grep "PLACEHOLDER"
        rm "$SERVICE_FILE"
        exit 1
    fi

    # Set proper permissions
    chmod 644 "$SERVICE_FILE"

    log_success "Service file created: $SERVICE_FILE"
}

################################################################################
# Service Installation
################################################################################

install_service() {
    log_info "Installing systemd service..."

    # Stop service if it's already running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "Stopping existing service..."
        systemctl stop "$SERVICE_NAME"
    fi

    # Reload systemd daemon
    log_info "Reloading systemd daemon..."
    systemctl daemon-reload

    # Enable service to start on boot
    log_info "Enabling service to start on boot..."
    systemctl enable "$SERVICE_NAME"

    # Start the service
    log_info "Starting service..."
    systemctl start "$SERVICE_NAME"

    # Wait for service to start (up to 30 seconds)
    log_info "Waiting for service to start..."
    local wait_count=0
    local max_wait=30
    while [[ $wait_count -lt $max_wait ]]; do
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log_success "Service is running!"
            return 0
        fi
        sleep 1
        ((wait_count++))
    done

    # Service failed to start
    log_error "Service failed to start within ${max_wait} seconds"
    log_info "Check status with: sudo systemctl status $SERVICE_NAME"
    log_info "Check logs with: sudo journalctl -u $SERVICE_NAME -n 50"
    exit 1
}

################################################################################
# Firewall Configuration (Optional)
################################################################################

configure_firewall() {
    log_info "Checking firewall configuration..."

    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_info "UFW is active, checking port ${SERVICE_PORT}..."
            
            # Check if port is already allowed (match both port number and port/tcp formats)
            if ! ufw status | grep -qE "${SERVICE_PORT}(/tcp)?"; then
                log_info "Opening port ${SERVICE_PORT}..."
                ufw allow ${SERVICE_PORT}/tcp comment "MuSoHu Web Service"
                log_success "Port ${SERVICE_PORT} opened in firewall"
            else
                log_info "Port ${SERVICE_PORT} is already open"
            fi
        else
            log_info "UFW is not active"
        fi
    else
        log_info "UFW not installed, skipping firewall configuration"
    fi
}

################################################################################
# Verification
################################################################################

verify_installation() {
    log_info "Verifying installation..."

    echo ""
    echo "=========================================="
    echo "Service Status:"
    echo "=========================================="
    systemctl status "$SERVICE_NAME" --no-pager | head -n 15
    echo ""

    # Check if service is listening on port
    log_info "Checking if service is listening on port ${SERVICE_PORT}..."
    sleep 2
    
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":${SERVICE_PORT}"; then
            log_success "Service is listening on port ${SERVICE_PORT}"
        else
            log_warning "Port ${SERVICE_PORT} not found in listening ports"
            log_info "This may be normal if the service is still starting up"
        fi
    fi

    # Try to access health endpoint
    if command -v curl &> /dev/null; then
        log_info "Testing health endpoint..."
        if curl -s "http://localhost:${SERVICE_PORT}/api/health" > /dev/null; then
            log_success "Health endpoint responding"
        else
            log_warning "Health endpoint not responding yet"
            log_info "The service may need a few more seconds to fully start"
        fi
    fi
}

################################################################################
# Display Usage Information
################################################################################

display_usage_info() {
    echo ""
    echo "=========================================="
    echo "MuSoHu Web Service - Management Commands"
    echo "=========================================="
    echo ""
    echo "Service Control:"
    echo "  Start:    sudo systemctl start $SERVICE_NAME"
    echo "  Stop:     sudo systemctl stop $SERVICE_NAME"
    echo "  Restart:  sudo systemctl restart $SERVICE_NAME"
    echo "  Status:   sudo systemctl status $SERVICE_NAME"
    echo ""
    echo "Logs:"
    echo "  View:     sudo journalctl -u $SERVICE_NAME"
    echo "  Follow:   sudo journalctl -u $SERVICE_NAME -f"
    echo "  Recent:   sudo journalctl -u $SERVICE_NAME -n 50"
    echo ""
    echo "Monitoring:"
    echo "  Health:   curl http://localhost:${SERVICE_PORT}/api/health"
    echo "  Restarts: sudo systemctl show $SERVICE_NAME -p NRestarts"
    echo ""
    echo "Boot Configuration:"
    echo "  Enable:   sudo systemctl enable $SERVICE_NAME"
    echo "  Disable:  sudo systemctl disable $SERVICE_NAME"
    echo ""
    echo "Web Interface:"
    echo "  Local:    http://localhost:${SERVICE_PORT}"
    echo "  Network:  http://$(hostname -I | awk '{print $1}'):${SERVICE_PORT}"
    echo ""
    echo "Configuration File: $SERVICE_FILE"
    echo ""
    echo "NOTE: Service runs on port ${SERVICE_PORT} (non-privileged port)"
    echo "      For port 80 access, configure a reverse proxy (nginx/Apache)"
    echo "=========================================="
}

################################################################################
# Main Execution
################################################################################

main() {
    echo "=========================================="
    echo "MuSoHu Production Web Service Setup"
    echo "=========================================="
    echo ""

    check_requirements
    setup_python_environment
    create_service_file
    install_service
    configure_firewall
    verify_installation
    display_usage_info

    echo ""
    log_success "Production web service setup completed successfully!"
    echo ""
}

# Run main function
main "$@"
