#!/bin/bash

################################################################################
# Fix ROS2 Environment for MuSoHu Web Service
#
# This script updates the systemd service to include complete ROS2 environment
# variables needed for sensor status detection.
################################################################################

set -e

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGGING_CONFIG="${SCRIPT_DIR}/../utils/logging_config.sh"

if [[ -f "$LOGGING_CONFIG" ]]; then
    source "$LOGGING_CONFIG"
else
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_error() { echo "[ERROR] $*"; }
    log_warning() { echo "[WARNING] $*"; }
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run with sudo privileges"
    exit 1
fi

# Configuration
SERVICE_NAME="musohu-web"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
BACKUP_FILE="${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Get actual user
ACTUAL_USER="${SUDO_USER:-$USER}"

log_info "Fixing ROS2 environment for MuSoHu web service..."

# Check if service exists
if [[ ! -f "$SERVICE_FILE" ]]; then
    log_error "Service file not found: $SERVICE_FILE"
    log_info "Please run setup_production_web_service.sh first"
    exit 1
fi

# Backup existing service file
log_info "Creating backup: $BACKUP_FILE"
cp "$SERVICE_FILE" "$BACKUP_FILE"

# Source ROS2 environment as the user and extract variables
log_info "Extracting ROS2 environment variables..."

# Create a temporary script to source ROS2 and output environment
TMP_SCRIPT="/tmp/ros2_env_extract.sh"
cat > "$TMP_SCRIPT" << 'EOF'
#!/bin/bash
# Source ROS2 environment
if [[ -f /opt/ros/humble/setup.bash ]]; then
    source /opt/ros/humble/setup.bash
fi
if [[ -f ~/ros2_musohu_ws/install/setup.bash ]]; then
    source ~/ros2_musohu_ws/install/setup.bash
fi

# Export specific variables we need
echo "AMENT_PREFIX_PATH=${AMENT_PREFIX_PATH}"
echo "CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}"
echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"
echo "PYTHONPATH=${PYTHONPATH}"
echo "PATH=${PATH}"
echo "ROS_VERSION=${ROS_VERSION}"
echo "ROS_DISTRO=${ROS_DISTRO}"
echo "ROS_PYTHON_VERSION=${ROS_PYTHON_VERSION}"
echo "ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY}"
echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}"
EOF

chmod +x "$TMP_SCRIPT"

# Run as the actual user and capture output
ENV_VARS=$(sudo -u "$ACTUAL_USER" bash "$TMP_SCRIPT")
rm "$TMP_SCRIPT"

# Extract each variable
AMENT_PREFIX_PATH=$(echo "$ENV_VARS" | grep "^AMENT_PREFIX_PATH=" | cut -d= -f2-)
CMAKE_PREFIX_PATH=$(echo "$ENV_VARS" | grep "^CMAKE_PREFIX_PATH=" | cut -d= -f2-)
LD_LIBRARY_PATH=$(echo "$ENV_VARS" | grep "^LD_LIBRARY_PATH=" | cut -d= -f2-)
PYTHONPATH=$(echo "$ENV_VARS" | grep "^PYTHONPATH=" | cut -d= -f2-)
PATH_VAR=$(echo "$ENV_VARS" | grep "^PATH=" | cut -d= -f2-)
ROS_VERSION=$(echo "$ENV_VARS" | grep "^ROS_VERSION=" | cut -d= -f2-)
ROS_DISTRO=$(echo "$ENV_VARS" | grep "^ROS_DISTRO=" | cut -d= -f2-)
ROS_PYTHON_VERSION=$(echo "$ENV_VARS" | grep "^ROS_PYTHON_VERSION=" | cut -d= -f2-)
ROS_LOCALHOST_ONLY=$(echo "$ENV_VARS" | grep "^ROS_LOCALHOST_ONLY=" | cut -d= -f2-)
ROS_DOMAIN_ID=$(echo "$ENV_VARS" | grep "^ROS_DOMAIN_ID=" | cut -d= -f2-)

# Verify we got the variables
if [[ -z "$AMENT_PREFIX_PATH" ]] || [[ -z "$CMAKE_PREFIX_PATH" ]]; then
    log_error "Failed to extract ROS2 environment variables"
    log_info "Make sure ROS2 is properly installed and sourced"
    exit 1
fi

log_success "ROS2 environment variables extracted successfully"

# Create new service file with ROS2 environment
log_info "Updating service file with ROS2 environment..."

# Read the current service file and find the [Service] section
# We'll insert our environment variables after the existing Environment lines
TMP_SERVICE="/tmp/${SERVICE_NAME}.service.tmp"

# Process the file: add/replace ROS2 environment variables
awk -v ament="$AMENT_PREFIX_PATH" \
    -v cmake="$CMAKE_PREFIX_PATH" \
    -v ld="$LD_LIBRARY_PATH" \
    -v pypath="$PYTHONPATH" \
    -v path="$PATH_VAR" \
    -v ros_ver="$ROS_VERSION" \
    -v ros_dist="$ROS_DISTRO" \
    -v ros_py="$ROS_PYTHON_VERSION" \
    -v ros_local="$ROS_LOCALHOST_ONLY" \
    -v ros_domain="$ROS_DOMAIN_ID" \
    '
    BEGIN { in_service=0; env_added=0; }
    
    # Detect [Service] section
    /^\[Service\]/ { 
        in_service=1; 
        print; 
        next; 
    }
    
    # Detect next section (end of [Service])
    /^\[.*\]/ && in_service && !env_added { 
        # Before starting new section, add our environment if not already done
        print "Environment=\"AMENT_PREFIX_PATH=" ament "\""
        print "Environment=\"CMAKE_PREFIX_PATH=" cmake "\""
        print "Environment=\"LD_LIBRARY_PATH=" ld "\""
        print "Environment=\"PYTHONPATH=" pypath "\""
        print "Environment=\"PATH=" path "\""
        print "Environment=\"ROS_VERSION=" ros_ver "\""
        print "Environment=\"ROS_DISTRO=" ros_dist "\""
        print "Environment=\"ROS_PYTHON_VERSION=" ros_py "\""
        print "Environment=\"ROS_LOCALHOST_ONLY=" ros_local "\""
        print "Environment=\"ROS_DOMAIN_ID=" ros_domain "\""
        env_added=1;
        in_service=0;
        print;
        next;
    }
    
    # Skip existing ROS2 environment lines
    in_service && /^Environment=.*ROS_/ { next; }
    in_service && /^Environment=.*AMENT_PREFIX_PATH/ { next; }
    in_service && /^Environment=.*CMAKE_PREFIX_PATH/ { next; }
    in_service && /^Environment=.*LD_LIBRARY_PATH/ { next; }
    
    # For PATH and PYTHONPATH, we want to use the ROS2-sourced versions
    in_service && /^Environment=.*PATH=/ { 
        if (!env_added) {
            print "Environment=\"AMENT_PREFIX_PATH=" ament "\""
            print "Environment=\"CMAKE_PREFIX_PATH=" cmake "\""
            print "Environment=\"LD_LIBRARY_PATH=" ld "\""
            print "Environment=\"PYTHONPATH=" pypath "\""
            print "Environment=\"PATH=" path "\""
            print "Environment=\"ROS_VERSION=" ros_ver "\""
            print "Environment=\"ROS_DISTRO=" ros_dist "\""
            print "Environment=\"ROS_PYTHON_VERSION=" ros_py "\""
            print "Environment=\"ROS_LOCALHOST_ONLY=" ros_local "\""
            print "Environment=\"ROS_DOMAIN_ID=" ros_domain "\""
            env_added=1;
        }
        next;
    }
    in_service && /^Environment=.*PYTHONPATH=/ { next; }
    
    # Print all other lines
    { print }
    
    # At end of file, if we are still in service section and havent added env
    END {
        if (in_service && !env_added) {
            print "Environment=\"AMENT_PREFIX_PATH=" ament "\""
            print "Environment=\"CMAKE_PREFIX_PATH=" cmake "\""
            print "Environment=\"LD_LIBRARY_PATH=" ld "\""
            print "Environment=\"PYTHONPATH=" pypath "\""
            print "Environment=\"PATH=" path "\""
            print "Environment=\"ROS_VERSION=" ros_ver "\""
            print "Environment=\"ROS_DISTRO=" ros_dist "\""
            print "Environment=\"ROS_PYTHON_VERSION=" ros_py "\""
            print "Environment=\"ROS_LOCALHOST_ONLY=" ros_local "\""
            print "Environment=\"ROS_DOMAIN_ID=" ros_domain "\""
        }
    }
    ' "$SERVICE_FILE" > "$TMP_SERVICE"

# Replace the service file
mv "$TMP_SERVICE" "$SERVICE_FILE"
chmod 644 "$SERVICE_FILE"

log_success "Service file updated"

# Reload systemd and restart service
log_info "Reloading systemd daemon..."
systemctl daemon-reload

log_info "Restarting ${SERVICE_NAME} service..."
systemctl restart "$SERVICE_NAME"

# Wait for service to start
sleep 3

if systemctl is-active --quiet "$SERVICE_NAME"; then
    log_success "Service restarted successfully!"
else
    log_error "Service failed to restart"
    log_info "Check status: sudo systemctl status $SERVICE_NAME"
    log_info "Check logs: sudo journalctl -u $SERVICE_NAME -n 50"
    log_info "Backup available at: $BACKUP_FILE"
    exit 1
fi

# Show status
echo ""
log_success "ROS2 environment fix completed!"
echo ""
echo "Service status:"
systemctl status "$SERVICE_NAME" --no-pager | head -n 10
echo ""
log_info "Test the sensor check page: http://localhost:8000/sensor-check"
echo ""
log_info "Backup of previous service file: $BACKUP_FILE"
