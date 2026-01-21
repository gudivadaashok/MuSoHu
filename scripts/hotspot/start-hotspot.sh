#!/bin/bash

#***********************************************************************
# Start Robotixx MuSoHu WiFi Hotspot
#***********************************************************************
# This script creates and starts a WiFi hotspot on the Jetson device
# Network Details:
#   - SSID: Robotixx_MuSoHu
#   - Password: Robotixx
#   - Interface: wlP1p1s0
#   - Gateway IP: 10.42.0.1
# The script also configures DNS for hostname-based access
#***********************************************************************

#***********************************************************************
# Help function
#***********************************************************************

show_help() {
    cat << EOF
Usage: bash start-hotspot.sh [OPTIONS]

Start the Robotixx MuSoHu WiFi hotspot.

This script:
  - Creates a WiFi hotspot on the Jetson device
  - Configures DNS for hostname resolution
  - Enables access to ROS2 VNC and Web Interface

Network Details:
  SSID:          Robotixx_MuSoHu
  Password:      Robotixx
  Interface:     wlP1p1s0
  Gateway IP:    10.42.0.1
  DHCP Range:    10.42.0.10 - 10.42.0.100

Access URLs (when connected to hotspot):
  Hostname-based:
    - http://robotixx:6080 (ROS2 VNC Desktop)
    - http://robotixx:5001 (Web Interface)
  IP-based:
    - http://10.42.0.1:6080 (ROS2 VNC Desktop)
    - http://10.42.0.1:5001 (Web Interface)

Management Commands:
  Stop hotspot:  nmcli connection down Hotspot
  Check status:  nmcli connection show --active

Options:
  -h, --help     Display this help message and exit

Examples:
  bash start-hotspot.sh
  bash start-hotspot.sh --help

Prerequisites:
  - Wireless interface wlP1p1s0 must be available
  - NetworkManager (nmcli) must be installed
  - DNS should be configured (optional but recommended)

Note: If hotspot is already running, it will be restarted.

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
source "$(dirname "$SCRIPT_DIR")/utils/logging_config.sh"

log_info "Starting Robotixx_MuSoHu WiFi Hotspot..."
log_separator

#***********************************************************************
# Check for existing hotspot connection
#***********************************************************************

# Check if hotspot connection profile exists
HOTSPOT_EXISTS=false
if nmcli connection show | grep -q "Hotspot"; then
    HOTSPOT_EXISTS=true
    log_info "Hotspot connection profile found"
fi

#***********************************************************************
# Disconnect from any active Wi-Fi connections
#***********************************************************************

log_info "Checking for active Wi-Fi connections on interface wlP1p1s0..."

# Get all active connections on the wireless interface
ACTIVE_WIFI=$(nmcli -t -f NAME,DEVICE,TYPE connection show --active | grep "wlP1p1s0:802-11-wireless" | cut -d: -f1)

if [ -n "$ACTIVE_WIFI" ]; then
    log_info "Found active Wi-Fi connection(s). Disconnecting to enable hotspot mode..."
    while IFS= read -r conn_name; do
        if [ -n "$conn_name" ]; then
            log_info "Disconnecting from: $conn_name"
            nmcli connection down "$conn_name" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                log_success "Disconnected from $conn_name"
            fi
        fi
    done <<< "$ACTIVE_WIFI"
    # Wait for interface to settle after disconnection
    sleep 2
else
    log_info "No active Wi-Fi connections found on wlP1p1s0"
fi

#***********************************************************************
# Disable autoconnect on other Wi-Fi profiles
#***********************************************************************

log_info "Disabling autoconnect on other Wi-Fi profiles..."

# Get all Wi-Fi connection profiles (excluding Hotspot)
WIFI_PROFILES=$(nmcli -t -f NAME,TYPE connection show | grep ":802-11-wireless" | cut -d: -f1 | grep -v "^Hotspot$")

if [ -n "$WIFI_PROFILES" ]; then
    while IFS= read -r profile_name; do
        if [ -n "$profile_name" ]; then
            # Disable autoconnect to prevent automatic reconnection
            nmcli connection modify "$profile_name" connection.autoconnect no > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                log_info "Disabled autoconnect for: $profile_name"
            fi
        fi
    done <<< "$WIFI_PROFILES"
fi

#***********************************************************************
# Stop conflicting dnsmasq service
#***********************************************************************

log_info "Checking for conflicting dnsmasq service..."

# Check if dnsmasq service is running
if systemctl is-active --quiet dnsmasq; then
    log_info "Stopping dnsmasq service to prevent port conflicts..."
    sudo systemctl stop dnsmasq > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_success "Stopped dnsmasq service"
        # Give it a moment to release ports
        sleep 1
    fi
fi

#***********************************************************************
# Start the WiFi hotspot
#***********************************************************************

# If connection profile exists, bring it up; otherwise create new one
if [ "$HOTSPOT_EXISTS" = true ]; then
    log_info "Activating existing hotspot connection..."
    nmcli connection up Hotspot > /dev/null 2>&1
    HOTSPOT_RESULT=$?
else
    log_info "Creating new WiFi hotspot on interface wlP1p1s0..."
    nmcli dev wifi hotspot ifname wlP1p1s0 ssid Robotixx_MuSoHu password Robotixx > /dev/null 2>&1
    HOTSPOT_RESULT=$?
fi

if [ $HOTSPOT_RESULT -eq 0 ]; then
    log_success "Hotspot started successfully!"

    echo ""
    log_separator
    log_info "Network Configuration"
    log_separator
    log_info "  SSID:      Robotixx_MuSoHu"
    log_info "  Password:  Robotixx"
    log_info "  Interface: wlP1p1s0"
    log_info "  Gateway:   10.42.0.1"
    echo ""

    #***********************************************************************
    # Configure DNS for hostname resolution
    #***********************************************************************

    # Wait for interface to be ready
    log_info "Waiting for interface to initialize..."
    sleep 2

    # Configure DNS if script is available
    if [ -f "$SCRIPT_DIR/configure-dns.sh" ]; then
        log_separator
        log_info "Configuring DNS for hostname resolution..."
        bash "$SCRIPT_DIR/configure-dns.sh"
    else
        log_warning "DNS configuration script not found"
        log_info "Hotspot will work but hostname resolution may not be available"
    fi

    #***********************************************************************
    # Display access information
    #***********************************************************************

    echo ""
    log_separator
    log_success "Hotspot is ready for connections!"
    log_separator
    echo ""

    log_info "Access URLs (when connected to hotspot):"
    echo ""
    log_info "  Hostname-based URLs:"
    log_info "    - http://robotixx:6080 (ROS2 VNC Desktop)"
    log_info "    - http://robotixx:5001 (Web Interface)"
    echo ""
    log_info "  IP-based URLs (alternative):"
    log_info "    - http://10.42.0.1:6080 (ROS2 VNC Desktop)"
    log_info "    - http://10.42.0.1:5001 (Web Interface)"
    echo ""

    log_separator
    log_info "Management Commands"
    log_separator
    log_info "  Stop hotspot:  nmcli connection down Hotspot"
    log_info "  Check status:  nmcli connection show --active"
    echo ""

else
    log_error "Failed to start hotspot"
    log_error "Please check if the wireless interface wlP1p1s0 is available"
    exit 1
fi