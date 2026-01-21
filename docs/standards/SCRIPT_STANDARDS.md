# MuSoHu Script Standards and Guidelines

## Overview

This document defines the coding standards, commenting conventions, and best practices for all shell scripts in the MuSoHu project. Following these standards ensures consistency, maintainability, and ease of understanding across the entire codebase.

## Table of Contents

1. [Structured Commenting](#structured-commenting)
2. [Help Functionality](#help-functionality)
3. [Logging System](#logging-system)
4. [Script Structure](#script-structure)
5. [Command-Line Arguments](#command-line-arguments)
6. [Error Handling](#error-handling)
7. [Examples](#examples)

---

## Structured Commenting

### Header Block Format

Every script MUST begin with a structured header using the star pattern:

```bash
#!/bin/bash

#***********************************************************************
# Script Title/Purpose
#***********************************************************************
# Description:
#   Detailed description of what the script does, its purpose,
#   and any important context information.
#
# Usage:
#   ./script_name.sh [OPTIONS] [ARGUMENTS]
#
# Options:
#   -h, --help    Display help message
#   -d, --debug   Enable debug mode
#
# Examples:
#   ./script_name.sh --help
#   ./script_name.sh --debug
#
# Author: MuSoHu Team
# Date: November 2025
#***********************************************************************
```

### Section Markers

Use structured comments to organize code into logical sections:

```bash
#***********************************************************************
# Section Name
#***********************************************************************

# Code for this section goes here
```

### Common Section Names

- **Configuration and Initialization** - Script variables and setup
- **Color Definitions** - Terminal color codes
- **Helper Functions** - Utility functions
- **Command Functions** - Main command implementations
- **Help / Usage** - Help text and usage information
- **Main Execution** - Main function and control flow
- **Script Execution** - Script entry point

### Subsection Markers

For smaller subsections within a major section:

```bash
#######################################################################
# Subsection Description
# Additional context or explanation
#######################################################################
```

---

## Help Functionality

### Requirements

Every script MUST provide comprehensive help functionality accessible via both `-h` and `--help` flags.

### Help Function Template

```bash
#***********************************************************************
# Help function
#***********************************************************************

show_help() {
    cat << EOF
#***********************************************************************
# Script Name - Help
#***********************************************************************

Usage: $(basename "$0") [OPTIONS] [ARGUMENTS]

DESCRIPTION:
    Detailed description of what the script does and why it exists.
    Include any important context or prerequisites.

OPTIONS:
    -h, --help          Show this help message and exit
    -d, --debug         Enable debug logging
    -q, --quiet         Suppress non-error output
    -v, --verbose       Enable verbose output

ARGUMENTS:
    file_path           Path to the input file (required)
    output_dir          Output directory (optional)

EXAMPLES:
    # Basic usage
    $(basename "$0") input.txt
    
    # With debug output
    $(basename "$0") --debug input.txt
    
    # Specify output directory
    $(basename "$0") input.txt /tmp/output

ENVIRONMENT VARIABLES:
    DEBUG_ENABLED       Set to "true" to enable debug mode
    LOG_DIR            Directory for log files

NOTES:
    - This script requires sudo privileges
    - Logs are saved to scripts/logs/
    - See SCRIPTS_GUIDE.md for more information

For more details, visit the MuSoHu documentation.
#***********************************************************************
EOF
}
```

### Help Function Best Practices

1. **Always use structured comments** in the help output
2. **Include practical examples** showing common use cases
3. **Document all options and arguments** with clear descriptions
4. **Specify prerequisites** (sudo, packages, files)
5. **Provide troubleshooting hints** when applicable
6. **Reference related documentation**

---

## Logging System

### Using the Centralized Logging Configuration

All scripts should source the centralized logging configuration:

```bash
# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging_config.sh"
```

### Available Logging Functions

```bash
log_debug "Debug message"      # Only shown when DEBUG_ENABLED=true
log_info "Information"          # General information (blue)
log_success "Success!"          # Success messages (green)
log_warning "Warning"           # Non-critical issues (yellow)
log_error "Error occurred"      # Critical errors (red)
log_separator                   # Visual separator line
```

### Logging Best Practices

1. **Use appropriate log levels**:
   - `log_debug` - Development/troubleshooting details
   - `log_info` - Normal operation messages
   - `log_success` - Successful completion
   - `log_warning` - Non-critical issues
   - `log_error` - Critical failures

2. **Log important operations**:
   ```bash
   log_info "Starting installation process..."
   sudo apt-get install package
   if [ $? -eq 0 ]; then
       log_success "Package installed successfully"
   else
       log_error "Failed to install package"
       exit 1
   fi
   ```

3. **Use separators** to organize output:
   ```bash
   log_separator
   log_info "Configuration Section"
   log_separator
   ```

4. **Enable debug mode** for detailed troubleshooting:
   ```bash
   export DEBUG_ENABLED=true
   ./script.sh
   ```

---

## Script Structure

### Standard Script Template

```bash
#!/bin/bash

#***********************************************************************
# Script Title
#***********************************************************************
# Description and metadata
#***********************************************************************

set -e  # Exit on error (optional, use with caution)

#***********************************************************************
# Configuration and Initialization
#***********************************************************************

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Other configuration variables

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

# Utility functions here

#***********************************************************************
# Help Function
#***********************************************************************

show_help() {
    # Help text
}

#***********************************************************************
# Main Functions
#***********************************************************************

# Core functionality

#***********************************************************************
# Argument Parsing
#***********************************************************************

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
        shift
    done
}

#***********************************************************************
# Main Execution
#***********************************************************************

main() {
    parse_arguments "$@"
    # Main logic
}

#***********************************************************************
# Script Execution
#***********************************************************************

# Only run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

---

## Command-Line Arguments

### Argument Parsing Pattern

```bash
#***********************************************************************
# Argument Parsing
#***********************************************************************

parse_arguments() {
    # Set defaults
    DEBUG_MODE=false
    QUIET_MODE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--debug)
                export DEBUG_ENABLED=true
                log_debug "Debug mode enabled"
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
            *)
                # Positional argument
                POSITIONAL_ARGS+=("$1")
                shift
                ;;
        esac
    done
}
```

### Best Practices

1. **Support both short and long options** (`-h` and `--help`)
2. **Provide clear error messages** for unknown options
3. **Set sensible defaults** for optional parameters
4. **Validate required arguments** before proceeding
5. **Document all options** in the help text

---

## Error Handling

### Exit on Error

Consider using `set -e` at the beginning of scripts:

```bash
set -e  # Exit immediately if a command exits with non-zero status
```

**Warning**: Use with caution and understand its implications.

### Manual Error Checking

For critical operations, manually check exit codes:

```bash
log_info "Installing package..."
sudo apt-get install package
if [ $? -eq 0 ]; then
    log_success "Package installed successfully"
else
    log_error "Failed to install package"
    exit 1
fi
```

### Checking for Prerequisites

```bash
#***********************************************************************
# Check for required commands
#***********************************************************************

if ! command -v required_command &> /dev/null; then
    log_error "required_command is not installed"
    log_info "Install with: sudo apt-get install required_command"
    exit 1
fi
```

### Checking for Sudo

```bash
#***********************************************************************
# Check if running with sudo
#***********************************************************************

if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run with sudo"
    log_info "Usage: sudo bash $(basename "$0")"
    exit 1
fi
```

---

## Examples

### Complete Example Script

See `scripts/utils/detect_system_info.sh` for a comprehensive example that demonstrates all standards.

### Minimal Script Template

```bash
#!/bin/bash

#***********************************************************************
# My Script Name
#***********************************************************************
# Brief description
#***********************************************************************

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging_config.sh"

#***********************************************************************
# Help function
#***********************************************************************

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

DESCRIPTION:
    Brief description of script functionality.

OPTIONS:
    -h, --help    Show this help message

EXAMPLES:
    $(basename "$0")
    $(basename "$0") --help

EOF
}

#***********************************************************************
# Main execution
#***********************************************************************

# Parse arguments
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

# Main logic
log_info "Starting script..."
# Your code here
log_success "Script completed successfully"
```

---

## Checklist for New Scripts

Before committing a new script, ensure it has:

- [ ] Structured header comment block with `#***********************************************************************`
- [ ] Comprehensive help function accessible via `-h` and `--help`
- [ ] Clear section markers using structured comments
- [ ] Proper logging using the centralized logging system
- [ ] Command-line argument parsing
- [ ] Error handling for critical operations
- [ ] Practical usage examples in help text
- [ ] Documentation of prerequisites and dependencies
- [ ] Proper file permissions (executable when needed)

---

## Additional Resources

- `scripts/SCRIPTS_GUIDE.md` - General guide to all scripts
- `scripts/utils/logging_config.sh` - Centralized logging documentation
- `scripts/utils/detect_system_info.sh` - Reference implementation
- `scripts/install/install_zed_sdk.sh` - Another complete example

---

## Version History

- **v1.0** (November 2025) - Initial script standards documentation
- Established structured commenting conventions
- Defined comprehensive help functionality requirements
- Standardized logging system usage
