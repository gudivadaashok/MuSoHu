````markdown
# MuSoHu Web Application - Development Guide

Guide for running the MuSoHu web application in development mode.

---

## Quick Start

```bash
# 1. Navigate to web-app directory
cd /path/to/MuSoHu/web-app

# 2. Install dependencies (first time only)
source ../.venv/bin/activate
pip install -r requirements.txt

# 3. Run development server
../.venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000 --reload

# 4. Open browser
# Visit: http://localhost:8000
```

That's it! The server will auto-reload when you make changes.

---

## Prerequisites

- Python 3.8 or higher
- Virtual environment (`.venv/` in project root)
- Dependencies from `requirements.txt`

---

## Setup (First Time)

### 1. Create Virtual Environment

```bash
# Navigate to project root
cd /path/to/MuSoHu

# Create virtual environment
python3 -m venv .venv

# Activate it
source .venv/bin/activate

# Verify Python version
python --version
```

### 2. Install Dependencies

```bash
# Navigate to web-app directory
cd web-app

# Install required packages
pip install -r requirements.txt

# Verify installation
pip list | grep -E "fastapi|uvicorn|jinja2|pyyaml"
```

Expected output:
```
fastapi       0.121.1
jinja2        3.1.6
pyyaml        6.0.3
uvicorn       0.38.0
```

### 3. Verify Configuration

```bash
# Check if config.yml exists
ls -la config.yml

# View current configuration
cat config.yml
```

---

## Running the Development Server

### Method 1: Direct Command (Recommended)

```bash
cd /path/to/MuSoHu/web-app
../.venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

### Method 2: With Activated Virtual Environment

```bash
cd /path/to/MuSoHu/web-app
source ../.venv/bin/activate
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

### Method 3: Using Python Module

```bash
cd /path/to/MuSoHu/web-app
../.venv/bin/python -m uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

---

## Accessing the Application

Once the server is running, you can access:

| Resource | URL | Description |
|----------|-----|-------------|
| **Main Dashboard** | http://localhost:8000 | Scripts management interface |
| **Disk Space** | http://localhost:8000/disk-space | Disk usage monitoring |
| **Log Viewer** | http://localhost:8000/logs | View application logs |
| **API Docs (Swagger)** | http://localhost:8000/docs | Interactive API documentation |
| **API Docs (ReDoc)** | http://localhost:8000/redoc | Alternative API documentation |
| **Health Check** | http://localhost:8000/api/health | Service health status |

---

## Development Workflow

### Making Changes

1. **Edit code** in your favorite editor (VS Code, PyCharm, etc.)
2. **Save the file** - Server auto-reloads automatically
3. **Refresh browser** to see changes
4. **Check terminal** for any errors or warnings

### Example Workflow

```bash
# 1. Start server
../.venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000 --reload

# Terminal shows:
# INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
# INFO:     Started reloader process [12345] using WatchFiles
# INFO:     Successfully mounted static files from: /path/to/static
# INFO:     Started server process [12346]
# INFO:     Application startup complete.

# 2. Edit app.py, save changes

# Terminal shows:
# WARNING:  WatchFiles detected changes in 'app.py'. Reloading...
# INFO:     Shutting down
# INFO:     Application shutdown complete.
# INFO:     Started server process [12347]
# INFO:     Application startup complete.

# 3. Refresh browser to see changes
```

---

## Debugging

### Enable Debug Mode

Edit `config.yml`:

```yaml
server:
  debug: true

logging:
  app_log:
    level: DEBUG
```

### View Detailed Logs

```bash
# Watch logs in real-time
tail -f logs/musohu.log

# View last 50 lines
tail -n 50 logs/musohu.log

# Search for errors
grep -i error logs/musohu.log
```

### Check Server Output

The development server shows detailed output in the terminal:

```bash
INFO:     127.0.0.1:54199 - "GET / HTTP/1.1" 200 OK
INFO:     127.0.0.1:54199 - "GET /static/style.css HTTP/1.1" 200 OK
INFO:     127.0.0.1:54199 - "GET /api/scripts HTTP/1.1" 200 OK
ERROR:    Exception in ASGI application
```

- `200 OK` = Success
- `404 Not Found` = Resource not found
- `500 Internal Server Error` = Application error

### Common Issues

#### Port Already in Use

```bash
# Error: [Errno 48] Address already in use

# Solution: Kill process on port 8000
lsof -ti:8000 | xargs kill -9

# Or use a different port
uvicorn app:app --host 0.0.0.0 --port 8001 --reload
```

#### Module Not Found

```bash
# Error: ModuleNotFoundError: No module named 'fastapi'

# Solution: Install dependencies
pip install -r requirements.txt
```

#### Template Not Found

```bash
# Error: jinja2.exceptions.TemplateNotFound: index.html

# Solution: Check you're in the web-app directory
cd /path/to/MuSoHu/web-app
ls templates/  # Should show index.html, logs.html, disk_space.html
```

---

## Testing

### Manual Testing

```bash
# Test health endpoint
curl http://localhost:8000/api/health

# Expected output:
# {"status":"healthy","running_scripts":0,"timestamp":"2025-11-12T10:30:00"}

# Test scripts endpoint
curl http://localhost:8000/api/scripts

# Test disk space
curl http://localhost:8000/api/disk-space
```

### Test in Browser

1. Open http://localhost:8000
2. Navigate through all pages:
   - Dashboard (/)
   - Disk Space (/disk-space)
   - Logs (/logs)
3. Try starting/stopping scripts
4. Check log viewer functionality

### Check for Errors

```bash
# Check application logs
tail -f logs/musohu.log

# Check server errors in terminal
# Watch for ERROR or WARNING messages
```

---

## Development Tips

### VS Code Integration

Add to `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: FastAPI",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": [
        "app:app",
        "--host", "0.0.0.0",
        "--port", "8000",
        "--reload"
      ],
      "cwd": "${workspaceFolder}/web-app",
      "env": {
        "PYTHONPATH": "${workspaceFolder}/web-app"
      }
    }
  ]
}
```

### Hot Reload

The `--reload` flag watches for file changes and automatically restarts the server. This is enabled by default in development mode.

Files that trigger reload:
- `*.py` files
- `*.html` templates
- Configuration files

Files that DON'T trigger reload:
- Static files (CSS, JS, images)
- Log files

### Multiple Terminals

Useful terminal setup:

```bash
# Terminal 1: Run server
../.venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000 --reload

# Terminal 2: Watch logs
tail -f logs/musohu.log

# Terminal 3: Test endpoints
curl http://localhost:8000/api/health
```

---

## Development vs Production

| Feature | Development | Production |
|---------|------------|------------|
| **Port** | 8000 | 80 |
| **Sudo Required** | No | Yes |
| **Auto-reload** | Yes | No |
| **Debug Mode** | Enabled | Disabled |
| **Error Details** | Full stack traces | Minimal |
| **Service Manager** | None | Systemd |
| **Auto-restart** | Manual | Automatic |
| **Logging** | Terminal + file | Systemd journal |
| **Resource Limits** | None | CPU/Memory limits |

**Use Development Mode when:**
- Testing new features
- Debugging issues
- Making code changes
- Running locally on your machine

**Use Production Mode when:**
- Deploying to server
- Need automatic restart
- Want system integration
- Running 24/7

See [PRODUCTION_WEB_SERVICE.md](PRODUCTION_WEB_SERVICE.md) for production deployment.

---

## Stopping the Server

```bash
# Press Ctrl+C in the terminal running uvicorn

# Terminal shows:
# ^CINFO:     Shutting down
# INFO:     Waiting for application shutdown.
# INFO:     Application shutdown complete.
# INFO:     Finished server process [12346]
# INFO:     Stopping reloader process [12345]
```

If that doesn't work:

```bash
# Find and kill the process
lsof -ti:8000 | xargs kill -9
```

---

## Additional Resources

- **FastAPI Documentation**: https://fastapi.tiangolo.com/
- **Uvicorn Documentation**: https://www.uvicorn.org/
- **Jinja2 Templates**: https://jinja.palletsprojects.com/
- **Python Virtual Environments**: https://docs.python.org/3/tutorial/venv.html

### Project Documentation

- [PRODUCTION_WEB_SERVICE.md](PRODUCTION_WEB_SERVICE.md) - Production deployment
- [../web-app/README.md](../../web-app/README.md) - Application configuration
- [SCRIPTS_GUIDE.md](SCRIPTS_GUIDE.md) - Setup scripts reference

---

## Quick Reference

```bash
# Start development server
cd /path/to/MuSoHu/web-app
../.venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000 --reload

# Access application
http://localhost:8000

# API documentation
http://localhost:8000/docs

# Stop server
Ctrl+C

# View logs
tail -f logs/musohu.log

# Test health
curl http://localhost:8000/api/health

# Install/update dependencies
pip install -r requirements.txt
```

---

*Last updated: November 12, 2025*
