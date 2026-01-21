# MuSoHu Production Web Service - Quick Reference

## INSTALLATION

```bash
sudo bash scripts/deploy/setup_production_web_service.sh
```

## SERVICE CONTROL (Recommended - Easy to use)

```bash
sudo bash scripts/utils/manage_web_service.sh start
sudo bash scripts/utils/manage_web_service.sh stop
sudo bash scripts/utils/manage_web_service.sh restart
bash scripts/utils/manage_web_service.sh status
bash scripts/utils/manage_web_service.sh health
bash scripts/utils/manage_web_service.sh test
```

## SYSTEMCTL COMMANDS (Direct systemd control)

```bash
sudo systemctl start musohu-web       # Start service
sudo systemctl stop musohu-web        # Stop service
sudo systemctl restart musohu-web     # Restart service
sudo systemctl status musohu-web      # Check status
sudo systemctl enable musohu-web      # Auto-start on boot
sudo systemctl disable musohu-web     # Disable auto-start
```

## MONITORING & LOGS

```bash
bash scripts/utils/manage_web_service.sh logs       # Last 50 lines
bash scripts/utils/manage_web_service.sh logs 200   # Last 200 lines
bash scripts/utils/manage_web_service.sh follow     # Stream logs
bash scripts/utils/manage_web_service.sh stats      # Statistics

sudo journalctl -u musohu-web -n 100                # Last 100 lines
sudo journalctl -u musohu-web -f                    # Follow logs
sudo journalctl -u musohu-web --since "1 hour ago"  # Last hour
sudo systemctl show musohu-web -p NRestarts         # Restart count
```

## HEALTH CHECKS

```bash
curl http://localhost:5001/health
curl http://localhost:5001/
```

## ACCESS WEB INTERFACE

- **Local:** http://localhost:5001
- **Network:** http://\<your-ip\>:5001

## AUTO-RESTART FEATURES

- **Restart=always** → Always restart on failure
- **StartLimitBurst=0** → Unlimited restart attempts
- **RestartSec=10** → 10 second delay between restarts
- **Auto-start on boot** → Service starts when system boots

## RESOURCE LIMITS

- **MemoryMax=1G** → Maximum 1GB RAM
- **MemoryHigh=800M** → Soft limit 800MB
- **CPUQuota=50%** → Maximum 50% CPU

## PRODUCTION FEATURES

- **Waitress WSGI Server** → Production-ready server
- **Multi-threaded (4 threads)** → Concurrent request handling
- **Systemd Integration** → Centralized logging & management
- **Resource Limits** → Prevents runaway processes
- **Health Check Endpoint** → /health for monitoring

## TROUBLESHOOTING

### Service won't start
```bash
sudo journalctl -u musohu-web -n 50
sudo systemctl status musohu-web
```

### Check if port is in use
```bash
sudo ss -tuln | grep 5001
```

### View Python errors
```bash
sudo journalctl -u musohu-web | grep -i error
```

### Check restart count
```bash
sudo systemctl show musohu-web -p NRestarts
```

### Run connectivity tests
```bash
bash scripts/utils/manage_web_service.sh test
```

## CONFIGURATION FILES

- **Service:** `/etc/systemd/system/musohu-web.service`
- **App Config:** `web-app/config.yml`
- **Template:** `scripts/deploy/templates/musohu-web.service.template`

### After editing service file:
```bash
sudo systemctl daemon-reload
sudo systemctl restart musohu-web
```

## DOCUMENTATION

- **Full Guide:** [docs/PRODUCTION_SETUP.md](PRODUCTION_SETUP.md)
- **For help:** `bash scripts/utils/manage_web_service.sh --help`

---

**Need help?** Check logs first: `sudo journalctl -u musohu-web -n 100`
