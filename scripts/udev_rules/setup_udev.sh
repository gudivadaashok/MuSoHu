#!/bin/bash

#***********************************************************************
# Setup udev Rules for MuSoHu Devices
#***********************************************************************
# This script copies udev rules to the host system for:
# - ReSpeaker USB devices
# - CH340/CH341 serial converters (IMU)
# - ZED Camera 
#***********************************************************************

# Source logging configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UDEV_RULES_DIR="/etc/udev/rules.d"
RULES_SOURCE_DIR="$SCRIPT_DIR/rules"

#######################################################################
# Source the logging configuration from the scripts/utils directory
# This uses $SCRIPT_DIR to navigate to the correct logging_config.sh file
# The path goes up one level (../) from scripts/udev_rules to reach scripts/utils
#######################################################################
source "$SCRIPT_DIR/../utils/logging_config.sh"

log_debug "Script directory: $SCRIPT_DIR"
log_info "Setting up udev rules for MuSoHu devices..."
log_info "Using rules source directory: $RULES_SOURCE_DIR"
log_info "Using udev rules directory: $UDEV_RULES_DIR"
log_separator

log_debug "Looking for rules in: $RULES_SOURCE_DIR"

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run with sudo"
    log_info "Usage: sudo bash setup_udev.sh"
    exit 1
fi

#***********************************************************************
# Copy ReSpeaker udev rules
#***********************************************************************

log_info "Copying ReSpeaker udev rules..."
RESPEAKER_RULES="$RULES_SOURCE_DIR/40-respeaker.rules"
log_debug "Checking for ReSpeaker rules at: $RESPEAKER_RULES"

if [ -f "$RESPEAKER_RULES" ]; then
    cp "$RESPEAKER_RULES" "$UDEV_RULES_DIR/"
    if [ $? -eq 0 ]; then
        log_success "ReSpeaker rules copied to $UDEV_RULES_DIR/"
    else
        log_error "Failed to copy ReSpeaker rules"
    fi
else
    log_warning "ReSpeaker rules file not found: $RESPEAKER_RULES"
    log_debug "Available files in rules directory:"
    if [ -d "$RULES_SOURCE_DIR" ]; then
        ls -la "$RULES_SOURCE_DIR" 2>/dev/null || log_debug "Cannot list rules directory contents"
    else
        log_debug "Rules directory does not exist: $RULES_SOURCE_DIR"
    fi
fi

#***********************************************************************
# Copy CH340/CH341 udev rules (for IMU)
#***********************************************************************

log_info "Copying CH340/CH341 udev rules..."
CH340_RULES="$RULES_SOURCE_DIR/99-imu.rules"
log_debug "Checking for CH340 rules at: $CH340_RULES"

if [ -f "$CH340_RULES" ]; then
    cp "$CH340_RULES" "$UDEV_RULES_DIR/"
    if [ $? -eq 0 ]; then
        log_success "CH340 rules copied to $UDEV_RULES_DIR/"
    else
        log_error "Failed to copy CH340 rules"
    fi
else
    log_warning "CH340 rules file not found: $CH340_RULES"
fi

#***********************************************************************
# Copy ZED Camera udev rules
#***********************************************************************

log_info "Copying ZED Camera udev rules..."
ZED_RULES="$RULES_SOURCE_DIR/40-zed.rules"
log_debug "Checking for ZED rules at: $ZED_RULES"

if [ -f "$ZED_RULES" ]; then
    cp "$ZED_RULES" "$UDEV_RULES_DIR/"
    if [ $? -eq 0 ]; then
        log_success "ZED Camera rules copied to $UDEV_RULES_DIR/"
    else
        log_error "Failed to copy ZED Camera rules"
    fi
else
    log_warning "ZED Camera rules file not found: $ZED_RULES"
fi

#***********************************************************************
# Reload udev rules
#***********************************************************************

log_info "Reloading udev rules..."
udevadm control --reload-rules
if [ $? -eq 0 ]; then
    log_success "udev rules reloaded"
else
    log_error "Failed to reload udev rules"
fi

log_info "Triggering udev events..."
udevadm trigger
if [ $? -eq 0 ]; then
    log_success "udev events triggered"
else
    log_error "Failed to trigger udev events"
fi

#***********************************************************************
# Verify rules installation
#***********************************************************************

log_separator
log_info "Verifying installed udev rules..."

if [ -f "$UDEV_RULES_DIR/40-respeaker.rules" ]; then
    log_success "ReSpeaker rules installed"
else
    log_warning "ReSpeaker rules not found"
fi

if [ -f "$UDEV_RULES_DIR/99-imu.rules" ]; then
    log_success "CH340/IMU rules installed"
else
    log_warning "CH340/IMU rules not found"
fi

if [ -f "$UDEV_RULES_DIR/40-zed.rules" ]; then
    log_success "ZED Camera rules installed"
else
    log_warning "ZED Camera rules not found"
fi

log_separator
log_success "udev setup complete!"
log_info "Please reconnect USB devices for rules to take effect"
log_info "Logs saved to: $LOG_FILE"