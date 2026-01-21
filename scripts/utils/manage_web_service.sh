#!/bin/bash

#***********************************************************************
# MuSoHu Web Service Management Script
#***********************************************************************
# Description:
#   Easy-to-use wrapper for managing the MuSoHu web service.
#   Provides comprehensive service management, monitoring, and
#   diagnostic capabilities for the MuSoHu web interface.
#
# Usage:
#   bash scripts/utils/manage_web_service.sh [command] [options]
#
# Commands:
#   start     - Start the service
#   stop      - Stop the service
#   restart   - Restart the service
#   status    - Show service status
#   logs      - View recent logs
#   follow    - Follow logs in real-time
#   health    - Check health endpoint
#   enable    - Enable auto-start on boot
#   disable   - Disable auto-start on boot
#   stats     - Show service statistics
#   test      - Test service connectivity
#
#***********************************************************************

set -e

#***********************************************************************
# Configuration
#***********************************************************************

SERVICE_NAME="musohu-web"
# Default port should match the production service (see setup_production_web_service.sh)
PORT="8000"

#***********************************************************************
# Color Definitions
#***********************************************************************

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#***********************************************************************
# Helper Functions
#***********************************************************************

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This command requires sudo privileges"
        echo "Usage: sudo bash $0 $1"
        exit 1
    fi
}

#***********************************************************************
# Command Functions
#***********************************************************************

cmd_start() {
    check_sudo
    log_info "Starting $SERVICE_NAME service..."
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_warning "Service is already running"
        systemctl status "$SERVICE_NAME" --no-pager | head -n 5
    else
        systemctl start "$SERVICE_NAME"
        sleep 2
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log_success "Service started successfully"
            systemctl status "$SERVICE_NAME" --no-pager | head -n 10
        else
            log_error "Service failed to start"
            echo "Check logs with: sudo journalctl -u $SERVICE_NAME -n 50"
            exit 1
        fi
    fi
}

cmd_stop() {
    check_sudo
    log_info "Stopping $SERVICE_NAME service..."
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        sleep 1
        log_success "Service stopped"
    else
        log_warning "Service is not running"
    fi
}

cmd_restart() {
    check_sudo
    log_info "Restarting $SERVICE_NAME service..."
    
    systemctl restart "$SERVICE_NAME"
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "Service restarted successfully"
        systemctl status "$SERVICE_NAME" --no-pager | head -n 10
    else
        log_error "Service failed to restart"
        echo "Check logs with: sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
}

cmd_status() {
    log_info "Checking $SERVICE_NAME service status..."
    echo ""
    
    systemctl status "$SERVICE_NAME" --no-pager
    
    echo ""
    echo "=========================================="
    
    # Check if service is enabled
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        log_success "Auto-start on boot: ENABLED"
    else
        log_warning "Auto-start on boot: DISABLED"
    fi
    
    # Show restart count
    RESTART_COUNT=$(systemctl show "$SERVICE_NAME" -p NRestarts --value)
    echo "Restart count: $RESTART_COUNT"
    
    # Show uptime
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        ACTIVE_TIME=$(systemctl show "$SERVICE_NAME" -p ActiveEnterTimestamp --value)
        echo "Running since: $ACTIVE_TIME"
    fi
    
    echo "=========================================="
}

#***********************************************************************
# Logs Command - View Recent Logs
#***********************************************************************

cmd_logs() {
    log_info "Showing recent logs for $SERVICE_NAME..."
    echo ""
    
    # Default to 50 lines if no argument provided
    LINES="${1:-50}"
    
    journalctl -u "$SERVICE_NAME" -n "$LINES" --no-pager
}

#***********************************************************************
# Follow Command - Follow Logs in Real-time
#***********************************************************************

cmd_follow() {
    log_info "Following logs for $SERVICE_NAME (Ctrl+C to stop)..."
    echo ""
    
    journalctl -u "$SERVICE_NAME" -f
}

#***********************************************************************
# Health Command - Check Health Endpoint
#***********************************************************************

cmd_health() {
    log_info "Checking health endpoint..."
    echo ""
    
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed"
        exit 1
    fi
    
    RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:$PORT/api/health 2>/dev/null)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | head -n -1)
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        log_success "Service is healthy (HTTP $HTTP_CODE)"
        echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    else
        log_error "Health check failed (HTTP $HTTP_CODE)"
        exit 1
    fi
}

#***********************************************************************
# Enable Command - Enable Auto-start on Boot
#***********************************************************************

cmd_enable() {
    check_sudo
    log_info "Enabling auto-start on boot..."
    
    systemctl enable "$SERVICE_NAME"
    log_success "Service will start automatically on boot"
}

#***********************************************************************
# Disable Command - Disable Auto-start on Boot
#***********************************************************************

cmd_disable() {
    check_sudo
    log_info "Disabling auto-start on boot..."
    
    systemctl disable "$SERVICE_NAME"
    log_warning "Service will NOT start automatically on boot"
}

#***********************************************************************
# Stats Command - Show Service Statistics
#***********************************************************************

cmd_stats() {
    log_info "Service statistics for $SERVICE_NAME..."
    echo ""
    
    echo "=========================================="
    echo "Service Information"
    echo "=========================================="
    
    # Basic status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "Status: ${GREEN}ACTIVE${NC}"
    else
        echo -e "Status: ${RED}INACTIVE${NC}"
    fi
    
    # Enabled status
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        echo -e "Boot: ${GREEN}ENABLED${NC}"
    else
        echo -e "Boot: ${YELLOW}DISABLED${NC}"
    fi
    
    # Restart information
    RESTART_COUNT=$(systemctl show "$SERVICE_NAME" -p NRestarts --value)
    echo "Restart count: $RESTART_COUNT"
    
    # Memory usage
    MEMORY=$(systemctl show "$SERVICE_NAME" -p MemoryCurrent --value)
    if [[ "$MEMORY" != "[not set]" && "$MEMORY" -gt 0 ]]; then
        MEMORY_MB=$((MEMORY / 1024 / 1024))
        echo "Memory usage: ${MEMORY_MB} MB"
    fi
    
    # Process info
    MAIN_PID=$(systemctl show "$SERVICE_NAME" -p MainPID --value)
    if [[ "$MAIN_PID" != "0" ]]; then
        echo "Main PID: $MAIN_PID"
    fi
    
    echo "=========================================="
    
    # Port status
    if command -v ss &> /dev/null; then
        echo ""
        echo "Port $PORT status:"
        if ss -tuln | grep -q ":$PORT"; then
            log_success "Listening on port $PORT"
            ss -tuln | grep ":$PORT"
        else
            log_warning "Not listening on port $PORT"
        fi
    fi
    
    # Recent logs
    echo ""
    echo "=========================================="
    echo "Recent logs (last 5 lines):"
    echo "=========================================="
    journalctl -u "$SERVICE_NAME" -n 5 --no-pager
}

#***********************************************************************
# Test Command - Test Service Connectivity
#***********************************************************************

cmd_test() {
    log_info "Testing service connectivity..."
    echo ""
    
    # Check if service is running
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        log_error "Service is not running"
        exit 1
    fi
    
    log_success " Service is running"
    
    # Check if port is listening
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$PORT"; then
            log_success " Port $PORT is listening"
        else
            log_error "[FAIL] Port $PORT is not listening"
            exit 1
        fi
    fi
    
    # Check health endpoint
    if command -v curl &> /dev/null; then
        if curl -s http://localhost:$PORT/api/health > /dev/null; then
            log_success " Health endpoint responding"
        else
            log_error "[FAIL] Health endpoint not responding"
            exit 1
        fi
        
        # Try to access main page
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/ | grep -q "200"; then
            log_success " Web interface accessible"
        else
            log_warning "[FAIL] Web interface returned non-200 status"
        fi
    fi
    
    echo ""
    log_success "All tests passed!"
    echo ""
    echo "Access the web interface at:"
    echo "  Local:    http://localhost:$PORT"
    echo "  Network:  http://$(hostname -I | awk '{print $1}'):$PORT"
}

#***********************************************************************
# Help / Usage
#***********************************************************************

show_help() {
    cat << EOF
#***********************************************************************
# MuSoHu Web Service Management Script - Help
#***********************************************************************

Usage: $(basename "$0") [command] [options]

DESCRIPTION:
    Comprehensive management utility for the MuSoHu web service.
    Controls systemd service, monitors health, and provides diagnostics.

COMMANDS:
    start         Start the service
    stop          Stop the service
    restart       Restart the service
    status        Show detailed service status
    logs [N]      View recent logs (default: 50 lines)
    follow        Follow logs in real-time
    health        Check health endpoint
    enable        Enable auto-start on boot
    disable       Disable auto-start on boot
    stats         Show service statistics and metrics
    test          Test service connectivity
    -h, --help    Display this help message

OPTIONS (for logs command):
    N             Number of log lines to display (default: 50)

EXAMPLES:
    # Start the service
    sudo $(basename "$0") start
    
    # View last 100 log lines
    $(basename "$0") logs 100
    
    # Stream logs in real-time
    $(basename "$0") follow
    
    # Check status
    $(basename "$0") status
    
    # Run connectivity tests
    $(basename "$0") test
    
    # Enable auto-start on boot
    sudo $(basename "$0") enable

SERVICE INFORMATION:
    Name:     $SERVICE_NAME
    Port:     $PORT
    Type:     Systemd service
    
MANAGEMENT:
    Direct systemd commands can also be used:
    - systemctl start $SERVICE_NAME
    - systemctl stop $SERVICE_NAME
    - systemctl status $SERVICE_NAME
    - journalctl -u $SERVICE_NAME

NOTES:
    - Start/stop/restart/enable/disable require sudo privileges
    - Health and test commands check http://localhost:$PORT
    - Logs can be viewed without sudo privileges

For more information, visit the MuSoHu documentation.
#***********************************************************************
EOF
}

show_usage() {
    cat << EOF
MuSoHu Web Service Management Script

Usage: $(basename "$0") [command] [options]

Commands:
  start         Start the service
  stop          Stop the service
  restart       Restart the service
  status        Show detailed service status
  logs [N]      View recent logs (default: 50 lines)
  follow        Follow logs in real-time
  health        Check health endpoint
  enable        Enable auto-start on boot
  disable       Disable auto-start on boot
  stats         Show service statistics and metrics
  test          Test service connectivity

Examples:
  $(basename "$0") start           # Start the service
  $(basename "$0") logs 100        # View last 100 log lines
  $(basename "$0") follow          # Stream logs in real-time
  $(basename "$0") status          # Check status
  $(basename "$0") test            # Run connectivity tests

Service: $SERVICE_NAME
Port: $PORT
EOF
}

#***********************************************************************
# Main Function
#***********************************************************************

main() {
    local command="${1:-help}"
    
    case "$command" in
        start)
            cmd_start
            ;;
        stop)
            cmd_stop
            ;;
        restart)
            cmd_restart
            ;;
        status)
            cmd_status
            ;;
        logs)
            cmd_logs "${2:-50}"
            ;;
        follow)
            cmd_follow
            ;;
        health)
            cmd_health
            ;;
        enable)
            cmd_enable
            ;;
        disable)
            cmd_disable
            ;;
        stats)
            cmd_stats
            ;;
        test)
            cmd_test
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

#***********************************************************************
# Script Execution
#***********************************************************************

main "$@"
