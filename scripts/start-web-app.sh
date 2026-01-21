#!/bin/bash
################################################################################
# Start MuSoHu Web Application
#
# This script starts the web application with proper environment setup.
# It ensures the process can access sudo for time synchronization operations.
#
# Usage:
#   bash scripts/start-web-app.sh
#   OR
#   ./scripts/start-web-app.sh
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WEB_APP_DIR="${PROJECT_ROOT}/web-app"

# Source logging config if available
if [[ -f "${SCRIPT_DIR}/utils/logging_config.sh" ]]; then
    source "${SCRIPT_DIR}/utils/logging_config.sh"
else
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
fi

log_info "Starting MuSoHu Web Application..."
log_info "Project Root: $PROJECT_ROOT"
log_info "Web App Directory: $WEB_APP_DIR"

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

# Change to web app directory
cd "$WEB_APP_DIR"

log_info "Checking Python environment..."

# Check if virtual environment exists and use it, otherwise use system Python
if [[ -f "venv/bin/python" ]]; then
    log_info "Using virtual environment Python"
    PYTHON_CMD="./venv/bin/python"
else
    log_info "Using system Python"
    PYTHON_CMD="python3"
fi

# Verify Python installation
if ! $PYTHON_CMD --version &> /dev/null; then
    log_error "Python not found"
    exit 1
fi

log_success "Python found: $($PYTHON_CMD --version)"

# Check for required packages
log_info "Checking dependencies..."
if ! $PYTHON_CMD -c "import fastapi" 2>/dev/null; then
    log_error "Required dependencies not installed. Run: pip install -r requirements.txt"
    exit 1
fi

log_success "All dependencies found"

# Set environment variables
export PYTHONUNBUFFERED=1
log_info "Starting uvicorn server on 0.0.0.0:8000..."

# Start the application
# Use exec to replace the shell process with the Python process
# This ensures proper signal handling (SIGTERM for graceful shutdown)
if [[ -f "venv/bin/uvicorn" ]]; then
    exec ./venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000
else
    exec $PYTHON_CMD -m uvicorn app:app --host 0.0.0.0 --port 8000
fi
