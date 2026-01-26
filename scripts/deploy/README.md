# Deployment Scripts

This directory contains scripts for deploying and setting up production services.

## Scripts

- **`setup_production_web_service.sh`** - Setup production web service with systemd integration
- **`fix_ros2_environment.sh`** - Fix ROS2 environment variables for sensor detection in web service

## Templates

- **`templates/musohu-web.service.template`** - Systemd service template for web service

## Usage

### Deploy Production Web Service

```bash
sudo bash scripts/deploy/setup_production_web_service.sh
```

This will:
- Create Python virtual environment
- Install all dependencies
- Create systemd service file
- Enable auto-start on boot
- Start the service
- Configure firewall

### Fix ROS2 Environment for Sensor Detection

If the sensor status page shows 0 nodes/topics when sensors are running:

```bash
sudo bash scripts/deploy/fix_ros2_environment.sh
```

This will:
- Extract complete ROS2 environment variables
- Update systemd service with proper configuration
- Backup original service file
- Restart service with sensor detection enabled

See [FIX_SENSOR_STATUS.md](../../docs/FIX_SENSOR_STATUS.md) for details.

## Service Management

After deployment, use the utility scripts:

```bash
# Check status
bash scripts/utils/manage_web_service.sh status

# View logs
bash scripts/utils/manage_web_service.sh logs

# Restart service
sudo bash scripts/utils/manage_web_service.sh restart
```

## Testing

After deployment, verify the setup:

```bash
bash scripts/test/test_production_setup.sh
```
