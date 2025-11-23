#!/bin/bash

#***********************************************************************
# Toggle Between WiFi Hotspot and WiFi Client Mode
#***********************************************************************
# Quick script to switch between hosting a WiFi hotspot and connecting
# to WiFi for internet access.
#***********************************************************************

show_help() {
    cat << EOF
Usage: bash toggle-network-mode.sh [MODE] [OPTIONS]
   or: sudo bash toggle-network-mode.sh [MODE] [OPTIONS]

Switch between WiFi hotspot mode and WiFi client mode.

Modes:
  hotspot    Switch to hotspot mode (start Robotixx_MuSoHu hotspot)
  wifi       Switch to WiFi client mode (stop hotspot, connect to WiFi)
  status     Show current network status

Options for 'wifi' mode:
  --auto              Automatically connect to any saved network
  --ssid "WiFi-Name"  Connect to specific WiFi network

Examples:
  bash toggle-network-mode.sh hotspot              # Start hotspot
  bash toggle-network-mode.sh wifi                 # Stop hotspot, show WiFi list
  bash toggle-network-mode.sh wifi --auto          # Stop hotspot, auto-connect
  bash toggle-network-mode.sh wifi --ssid MyWiFi   # Stop hotspot, connect to MyWiFi
  bash toggle-network-mode.sh status               # Show current mode

Quick Reference:
  Hotspot Network:
    - SSID: Robotixx_MuSoHu
    - Password: Robotixx
    - Gateway: 10.42.0.1
  
  Access URLs when in hotspot mode:
    - http://robotixx:6080 (ROS2 VNC Desktop)
    - http://robotixx:5001 (Web Interface)
    - http://10.42.0.1:6080 (IP-based VNC)
    - http://10.42.0.1:5001 (IP-based Web)

Note: Network management commands require elevated privileges. Scripts will
      automatically request sudo when needed.

EOF
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Simple logging functions
log_info() { echo "ℹ️  $1"; }
log_success() { echo "✅ $1"; }
log_error() { echo "❌ $1"; }
log_separator() { echo "═══════════════════════════════════════════════════════════════"; }

#***********************************************************************
# Show current network status
#***********************************************************************

show_status() {
    log_separator
    log_info "Current Network Status"
    log_separator
    
    # Check for active hotspot
    if nmcli connection show --active | grep -q "Hotspot"; then
        echo "📡 Mode: HOTSPOT (Access Point)"
        echo ""
        log_info "Hotspot Details:"
        echo "  - SSID: Robotixx_MuSoHu"
        echo "  - Password: Robotixx"
        echo "  - Gateway: 10.42.0.1"
        echo ""
        log_info "Access URLs:"
        echo "  - http://robotixx:6080 (VNC)"
        echo "  - http://robotixx:5001 (Web)"
        echo ""
        log_info "To switch to WiFi client mode:"
        echo "  bash toggle-network-mode.sh wifi"
    else
        # Check for WiFi connection
        WIFI_CONN=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active | grep ":802-11-wireless:wlP1p1s0" | cut -d: -f1)
        
        if [ -n "$WIFI_CONN" ]; then
            echo "🌐 Mode: WIFI CLIENT (Internet Access)"
            echo ""
            log_info "Connected to: $WIFI_CONN"
            
            # Try to show IP address
            IP_ADDR=$(ip -4 addr show wlP1p1s0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
            if [ -n "$IP_ADDR" ]; then
                echo "  - IP Address: $IP_ADDR"
            fi
            
            # Check internet connectivity
            if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
                echo "  - Internet: Connected ✓"
            else
                echo "  - Internet: No connection"
            fi
            echo ""
            log_info "To switch to hotspot mode:"
            echo "  bash toggle-network-mode.sh hotspot"
        else
            echo "⚠️  Mode: DISCONNECTED"
            echo ""
            log_info "Not connected to any network"
            echo ""
            log_info "Options:"
            echo "  - Start hotspot: bash toggle-network-mode.sh hotspot"
            echo "  - Connect to WiFi: bash toggle-network-mode.sh wifi"
        fi
    fi
    
    log_separator
}

#***********************************************************************
# Main logic
#***********************************************************************

# Check for help flag
if [[ $1 == "-h" || $1 == "--help" || $# -eq 0 ]]; then
    show_help
    exit 0
fi

MODE="$1"
shift  # Remove first argument, keep the rest for passing to scripts

case "$MODE" in
    hotspot)
        log_info "Switching to HOTSPOT mode..."
        log_separator
        bash "$SCRIPT_DIR/start-hotspot.sh"
        exit $?
        ;;
        
    wifi)
        log_info "Switching to WIFI CLIENT mode..."
        log_separator
        bash "$SCRIPT_DIR/stop-hotspot.sh" "$@"
        exit $?
        ;;
        
    status)
        show_status
        exit 0
        ;;
        
    *)
        log_error "Unknown mode: $MODE"
        echo ""
        echo "Valid modes: hotspot, wifi, status"
        echo "Use --help for more information"
        exit 1
        ;;
esac
