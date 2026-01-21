# Test Scripts

This directory contains scripts for testing and verifying system setup.

## Scripts

- **`test_production_setup.sh`** - Comprehensive production setup verification
- **`test_system_detection.sh`** - Test system information detection
- **`example_with_logging.sh`** - Example script demonstrating logging functionality

## Usage

### Run Production Tests

```bash
bash scripts/test/test_production_setup.sh
```

This will verify:
- Python environment
- Virtual environment setup
- Dependencies installation
- Service configuration
- Service status
- Network connectivity
- Health endpoint
- Firewall rules

### Run System Detection Test

```bash
bash scripts/test/test_system_detection.sh
```

### Run Logging Example

```bash
bash scripts/test/example_with_logging.sh
```

## Test Output

Tests display:
- ✓ [PASS] - Test passed successfully
- ✗ [FAIL] - Test failed with reason
- ⚠ [WARN] - Non-critical issue detected
- ⊘ [SKIP] - Test skipped (not applicable)

A summary is displayed at the end showing pass/fail counts and percentage.
