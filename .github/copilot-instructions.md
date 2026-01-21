# AI Coding Agent Instructions for MuSoHu

Welcome to the MuSoHu codebase! This document provides essential guidance for AI coding agents to be productive in this project. Follow these instructions to understand the architecture, workflows, and conventions specific to MuSoHu.

---

## Project Overview

MuSoHu (Multi-Modal Social Human Navigation) is a robotics research platform for collecting data on human-robot interactions in social navigation contexts. It includes:

- **ROS2-based robotics platform** for sensor data collection.
- **Web application** for managing and visualizing data.
- **Scripts** for setup, deployment, and testing.

Key components:
- **helmet_bringup/**: ROS2 launch files and configurations for sensors.
- **web-app/**: Python-based web application for data visualization.
- **scripts/**: Shell scripts for installation, deployment, and testing.

---

## Developer Workflows

### 1. Build and Run
- **ROS2 Launch**: Use launch files in `helmet_bringup/launch/` to start specific sensors.
  ```bash
  ros2 launch helmet_bringup lidar.launch.py
  ```
- **Web Application**: Start the web app locally for development.
  ```bash
  python3 web-app/app.py
  ```

### 2. Testing
- **Unit Tests**: Ensure Python dependencies are installed (`web-app/requirements.txt`) and run tests.
  ```bash
  pytest web-app/
  ```
- **System Tests**: Use scripts in `scripts/test/` to verify production setups.
  ```bash
  bash scripts/test/test_production_setup.sh
  ```

### 3. Deployment
- **Production Web Service**: Deploy using `scripts/deploy/setup_production_web_service.sh`.
  ```bash
  sudo bash scripts/deploy/setup_production_web_service.sh
  ```

---

## Conventions and Patterns

### 1. Shell Scripts
- Follow the standards in `docs/standards/SCRIPT_STANDARDS.md`.
- Use `utils/logging_config.sh` for consistent logging.

### 2. Python Code
- Web app configurations are in `web-app/config.yml`.
- Use `logging_config.py` for consistent logging.

### 3. ROS2
- Sensor configurations are in `helmet_bringup/config/`.
- Launch files are modular and named by sensor (e.g., `lidar.launch.py`).

---

## Integration Points

### 1. External Dependencies
- **ZED SDK**: Install using `scripts/install/install_zed_sdk.sh`.
- **Python Packages**: Install from `web-app/requirements.txt`.

### 2. Cross-Component Communication
- **ROS2 Topics**: Sensors publish data to ROS2 topics for real-time processing.
- **Web App**: Consumes processed data for visualization.

---

## Key References

- **[README.md](../README.md)**: Project overview.
- **[docs/](../docs/)**: Comprehensive documentation.
- **[scripts/](../scripts/)**: All setup, deployment, and testing scripts.
- **[web-app/](../web-app/)**: Web application source code.

---

For further details, explore the documentation in `docs/` and the codebase. Happy coding!