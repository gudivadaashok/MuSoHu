# Deployment Scripts

This directory contains scripts for deploying and setting up production services.

## Scripts

- **`setup_production_web_service.sh`** - Setup production web service with systemd integration

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
