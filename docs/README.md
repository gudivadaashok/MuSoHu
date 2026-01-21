````markdown
# MuSoHu Documentation

Documentation for the MuSoHu Multi-Modal Social Human Navigation platform.

---

## Documentation Index

### Setup and Deployment

| Document | Description |
|----------|-------------|
| [PRODUCTION_WEB_SERVICE.md](guides/PRODUCTION_WEB_SERVICE.md) | Production web service setup with automatic restart |
| [PRODUCTION_SETUP.md](guides/PRODUCTION_SETUP.md) | Detailed systemd configuration and monitoring |
| [INSTALLATION_SUMMARY.md](guides/INSTALLATION_SUMMARY.md) | Installation overview and next steps |

### Web Application

| Document | Description |
|----------|-------------|
| [WEB_LOG_VIEWER.md](guides/WEB_LOG_VIEWER.md) | Lightweight web-based log viewer with search and live tail |

### Reference

| Document | Description |
|----------|-------------|
| [QUICK_REFERENCE.md](reference/QUICK_REFERENCE.md) | Quick command reference for service management |

### Development

| Document | Description |
|----------|-------------|
| [SCRIPT_STANDARDS.md](standards/SCRIPT_STANDARDS.md) | Coding standards and conventions for shell scripts |
| [SCRIPTS_GUIDE.md](guides/SCRIPTS_GUIDE.md) | Complete guide to all project scripts |

---

## Quick Links

### For New Users

1. Start with the main [README.md](../README.md) in the project root
2. Follow [PRODUCTION_WEB_SERVICE.md](guides/PRODUCTION_WEB_SERVICE.md) for quick deployment
3. Check [WEB_LOG_VIEWER.md](guides/WEB_LOG_VIEWER.md) for log viewing and monitoring
4. Check [QUICK_REFERENCE.md](reference/QUICK_REFERENCE.md) for common commands
5. See [SCRIPTS_GUIDE.md](guides/SCRIPTS_GUIDE.md) for available scripts

### For Developers

1. Review [SCRIPT_STANDARDS.md](standards/SCRIPT_STANDARDS.md) for coding conventions
2. Follow the templates and examples in existing scripts
3. Use the verification tool: `bash scripts/verify_standards.sh`

### For System Administrators

1. Deploy using [PRODUCTION_WEB_SERVICE.md](guides/PRODUCTION_WEB_SERVICE.md)
2. Configure systemd following [PRODUCTION_SETUP.md](guides/PRODUCTION_SETUP.md)
3. Monitor using the management scripts in `scripts/utils/`

---

## Documentation Organization

### Production Guides (guides/)

**[PRODUCTION_WEB_SERVICE.md](guides/PRODUCTION_WEB_SERVICE.md)**
- Quick start deployment
- Feature overview
- Service management commands
- Troubleshooting guide

**[PRODUCTION_SETUP.md](guides/PRODUCTION_SETUP.md)**
- Detailed systemd configuration
- Resource limits and security
- Monitoring and logging
- Advanced configuration

**[SCRIPTS_GUIDE.md](guides/SCRIPTS_GUIDE.md)**
- Directory structure
- Script categories (setup, utils, hotspot, udev)
- Usage examples
- Logging system
- Adding new scripts
- Verification tools

**[WEB_LOG_VIEWER.md](guides/WEB_LOG_VIEWER.md)**
- Web-based log viewer features
- YAML configuration guide
- API endpoints and usage
- Search and live tail functionality
- File discovery and metadata
- Troubleshooting tips

### Development Standards (standards/)

**[SCRIPT_STANDARDS.md](standards/SCRIPT_STANDARDS.md)**
- Header format and structured comments
- Help functionality requirements
- Logging system usage
- Command-line argument parsing
- Error handling patterns
- Complete templates and examples

---

## Common Tasks

### Deploy Production Service

```bash
sudo bash scripts/deploy/setup_production_web_service.sh
```

### Manage Web Service

```bash
# Start service
sudo bash scripts/utils/manage_web_service.sh start

# Check status
sudo bash scripts/utils/manage_web_service.sh status

# View logs
sudo bash scripts/utils/manage_web_service.sh logs
```

### Create New Script

```bash
# Copy template
cp scripts/SCRIPT_STANDARDS.md template_example

# Verify standards
bash scripts/verify_standards.sh
```

### Troubleshoot Issues

```bash
# View service logs
sudo journalctl -u musohu-web -n 100

# Check system info
bash scripts/utils/detect_system_info.sh

# Test production setup
bash scripts/test/test_production_setup.sh

# Access web log viewer
# Open browser: http://localhost:8000/logs
```

---

## Additional Resources

- **Project Website**: [https://cs.gmu.edu/~xiao/Research/MuSoHu/](https://cs.gmu.edu/~xiao/Research/MuSoHu/)
- **Main README**: [../README.md](../README.md)
- **Scripts Directory**: [../scripts/](../scripts/)
- **Web Application**: [../web-app/](../web-app/)

---

## Documentation Standards

All documentation in this directory follows these principles:

1. **Clear Structure**: Organized by user type and task
2. **Practical Examples**: Real commands that users can run
3. **Cross-References**: Links between related documents
4. **Progressive Disclosure**: Quick start first, details later
5. **Maintenance**: Keep documentation in sync with code

For questions or improvements to documentation, please contribute via pull requests.
