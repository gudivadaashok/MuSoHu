#!/bin/bash

#***********************************************************************
# Stop Robotixx MuSoHu WiFi Hotspot and Restore WiFi Connection
#***********************************************************************
# This script stops the WiFi hotspot and attempts to reconnect to
# a WiFi network for internet access.
#***********************************************************************

#***********************************************************************
# Help function
#***********************************************************************

show_help() {
    cat << EOF
Usage: bash stop-hotspot.sh [OPTIONS]
   or: sudo bash stop-hotspot.sh [OPTIONS]

Stop the Robotixx MuSoHu WiFi hotspot and optionally reconnect to WiFi.

This script:
  - Stops the active WiFi hotspot
  - Re-enables autoconnect on WiFi profiles
  - Attempts to reconnect to available WiFi networks

Options:
  -h, --help         Display this help message and exit
  -s, --ssid SSID    Connect to a specific WiFi network by SSID
  -a, --auto         Automatically connect to any available saved network

Examples:
  bash stop-hotspot.sh                    # Stop hotspot, prompt for WiFi
  bash stop-hotspot.sh --auto             # Stop hotspot, auto-reconnect
  bash stop-hotspot.sh --ssid MyWiFi      # Stop hotspot, connect to MyWiFi

Management Commands:
  List saved WiFi:   nmcli connection show
  Manual connect:    sudo nmcli connection up "WiFi-Name"
  Check status:      nmcli connection show --active

Note: This script requires network management privileges. If not run with
      sudo, it will automatically re-execute itself with elevated privileges.

EOF
}

# Parse command line arguments
AUTO_CONNECT=false
SPECIFIC_SSID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--auto)
            AUTO_CONNECT=true
            shift
            ;;
        -s|--ssid)
            SPECIFIC_SSID="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Get script directory and source utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_SCRIPT="$(dirname "$SCRIPT_DIR")/utils/logging_config.sh"

if [ -f "$UTILS_SCRIPT" ]; then
    source "$UTILS_SCRIPT"
else
    # Fallback logging functions if utils not available
    log_info() { echo "ℹ️  $1"; }
    log_success() { echo "✅ $1"; }
    log_error() { echo "❌ $1"; }
    log_warning() { echo "⚠️  $1"; }
    log_separator() { echo "═══════════════════════════════════════════════════════════════"; }
fi

log_info "Stopping WiFi hotspot..."
log_separator

#***********************************************************************
# Check for required permissions
#***********************************************************************

# Check if we can control networking (need sudo or user in netdev group)
if ! nmcli general permissions | grep -q "org.freedesktop.NetworkManager.network-control.*yes"; then
    log_warning "Elevated privileges required for network management"
    log_info "Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

#***********************************************************************
# Stop the hotspot
#***********************************************************************

# Check if hotspot is running
HOTSPOT_ACTIVE=false
if nmcli connection show --active | grep -q "Hotspot"; then
    HOTSPOT_ACTIVE=true
    log_info "Active hotspot connection found"
fi

if [ "$HOTSPOT_ACTIVE" = true ]; then
    log_info "Disconnecting hotspot..."
    sudo nmcli connection down Hotspot > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "Hotspot stopped successfully"
        # Wait for interface to settle
        sleep 2
    else
        log_error "Failed to stop hotspot"
        exit 1
    fi
else
    log_info "No active hotspot found"
fi

#***********************************************************************
# Re-enable autoconnect on WiFi profiles
#***********************************************************************

log_info "Re-enabling autoconnect on WiFi profiles..."

# Get all Wi-Fi connection profiles (excluding Hotspot)
WIFI_PROFILES=$(nmcli -t -f NAME,TYPE connection show | grep ":802-11-wireless" | cut -d: -f1 | grep -v "^Hotspot$")

if [ -n "$WIFI_PROFILES" ]; then
    while IFS= read -r profile_name; do
        if [ -n "$profile_name" ]; then
            sudo nmcli connection modify "$profile_name" connection.autoconnect yes > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                log_info "Enabled autoconnect for: $profile_name"
            fi
        fi
    done <<< "$WIFI_PROFILES"
fi

#***********************************************************************
# Reconnect to WiFi
#***********************************************************************

log_separator
log_info "Attempting to reconnect to WiFi..."
log_separator

if [ -n "$SPECIFIC_SSID" ]; then
    # Connect to specific SSID
    log_info "Connecting to: $SPECIFIC_SSID"
    sudo nmcli connection up "$SPECIFIC_SSID"
    
    if [ $? -eq 0 ]; then
        log_success "Connected to $SPECIFIC_SSID"
        echo ""
        log_info "You now have internet access via WiFi"
        exit 0
    else
        log_error "Failed to connect to $SPECIFIC_SSID"
        exit 1
    fi

elif [ "$AUTO_CONNECT" = true ]; then
    # Try to auto-connect to any saved network
    log_info "Searching for available saved networks..."
    
    # Get list of saved WiFi connections
    SAVED_WIFI=$(nmcli -t -f NAME,TYPE connection show | grep ":802-11-wireless" | cut -d: -f1 | grep -v "^Hotspot$")
    
    if [ -n "$SAVED_WIFI" ]; then
        CONNECTED=false
        while IFS= read -r wifi_name; do
            if [ -n "$wifi_name" ]; then
                log_info "Trying to connect to: $wifi_name"
                sudo nmcli connection up "$wifi_name" > /dev/null 2>&1
                
                if [ $? -eq 0 ]; then
                    log_success "Connected to $wifi_name"
                    CONNECTED=true
                    break
                fi
            fi
        done <<< "$SAVED_WIFI"
        
        if [ "$CONNECTED" = true ]; then
            echo ""
            log_info "You now have internet access via WiFi"
            exit 0
        else
            log_warning "Could not connect to any saved network"
            log_info "Networks may be out of range"
        fi
    else
        log_warning "No saved WiFi networks found"
    fi

else
    # Interactive mode: show available networks and let user choose
    echo ""
    log_info "Available saved WiFi networks:"
    echo ""
    
    # Get list of saved WiFi connections with numbered list
    SAVED_WIFI=$(nmcli -t -f NAME,TYPE connection show | grep ":802-11-wireless" | cut -d: -f1 | grep -v "^Hotspot$")
    
    if [ -z "$SAVED_WIFI" ]; then
        log_warning "No saved WiFi networks found"
        log_info "To add a new network, use:"
        log_info "  nmcli dev wifi connect \"SSID\" password \"PASSWORD\""
        exit 1
    fi
    
    # Display numbered list
    i=1
    declare -a networks
    while IFS= read -r wifi_name; do
        if [ -n "$wifi_name" ]; then
            echo "  $i) $wifi_name"
            networks[$i]="$wifi_name"
            ((i++))
        fi
    done <<< "$SAVED_WIFI"
    
    echo ""
    read -p "Enter number to connect (or 'q' to quit): " choice
    
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        log_info "Exiting without connecting"
        exit 0
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
        selected_network="${networks[$choice]}"
        log_info "Connecting to: $selected_network"
        sudo nmcli connection up "$selected_network"
        
        if [ $? -eq 0 ]; then
            log_success "Connected to $selected_network"
            echo ""
            log_info "You now have internet access via WiFi"
            exit 0
        else
            log_error "Failed to connect to $selected_network"
            exit 1
        fi
    else
        log_error "Invalid selection"
        exit 1
    fi
fi

log_separator
log_info "Hotspot stopped. To manually connect to WiFi, use:"
log_info "  nmcli connection up \"WiFi-Name\""
log_separator

