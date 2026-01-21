"""
MuSoHu Web Application
Manages ROS2 scripts, displays logs, and monitors system resources
"""
from fastapi import FastAPI, Request, Query, Form
from fastapi.responses import JSONResponse, FileResponse, HTMLResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
import socketio
import subprocess
import os
import shutil
import logging
from datetime import datetime, timezone
import yaml
import pytz
from file_discovery import FileDiscoveryService
import asyncio

# Get the base directory of this file
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Setup logger first
logger = logging.getLogger("uvicorn")

# Setup sync time logger
sync_logger = logging.getLogger("sync_time")
sync_handler = logging.FileHandler(os.path.join(BASE_DIR, "conlog.log"))
sync_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s: %(message)s'))
sync_logger.addHandler(sync_handler)
sync_logger.setLevel(logging.INFO)

# Prepare paths
static_dir = os.path.join(BASE_DIR, "static")
templates_dir = os.path.join(BASE_DIR, "templates")

if not os.path.exists(static_dir):
    logger.error(f"Static directory not found: {static_dir}")
if not os.path.exists(templates_dir):
    logger.error(f"Templates directory not found: {templates_dir}")

# Initialize FastAPI app
app = FastAPI()

# Initialize Socket.IO
sio = socketio.AsyncServer(async_mode='asgi', cors_allowed_origins='*')
socket_app = socketio.ASGIApp(sio, app)

# Add middleware FIRST
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Setup templates
templates = Jinja2Templates(directory=templates_dir)
logger.info(f"Templates directory: {templates_dir}")

# Mount static files LAST - this is critical for proper route registration
try:
    app.mount("/static", StaticFiles(directory=static_dir), name="static")
    logger.info(f"Successfully mounted static files from: {static_dir}")
except Exception as e:
    logger.error(f"Failed to mount static files: {e}")

# Load configuration
def load_config():
    """Load configuration from config.yml"""
    config_path = os.path.join(BASE_DIR, 'config.yml')
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            logger.error(f"Error loading config.yml: {e}")
            return get_default_config()
    else:
        logger.warning("config.yml not found, using default configuration")
        return get_default_config()

def get_default_config():
    """Return default configuration"""
    return {
        'log_viewer': {
            'max_lines': 100,
            'scan_directories': [],
            'sources': [],
            'allowed_extensions': ['.log', '.txt']
        },
        'server': {
            'host': '0.0.0.0',
            'port': 8000
        },
        'refresh_intervals': {
            'scripts': 5,
            'disk_space': 10,
            'logs': 5
        }
    }

# Load configuration
config = load_config()

# Initialize file discovery service
file_discovery = FileDiscoveryService(config)

# Define available ROS2 scripts
ROS2_SCRIPTS = {
    'helmet_nodes': {
        # Updated command to properly source the ROS2 workspace before launching sensors
        # Uses bash -c to ensure sourcing takes effect in the same shell invocation
        'command': 'bash -c "cd /home/jetson/ros2_musohu_ws && source install/setup.bash && ros2 launch helmet_bringup helmet_sensors.launch.py"',
        'description': 'Launch Helmet Sensors',
        'status': 'stopped',
        'pid': None
    },
    'record_bag': {
        # Records all ROS2 topics into /home/jetson/helmet_bags
        # Creates the directory if missing and uses a timestamped bag name
        'command': 'bash -c "mkdir -p /home/jetson/helmet_bags && cd /home/jetson/ros2_musohu_ws && source install/setup.bash && ros2 bag record -a -o /home/jetson/helmet_bags/helmet_bag_$(date +%Y%m%d_%H%M%S)"',
        'description': 'Record all ROS2 topics to /home/jetson/helmet_bags',
        'status': 'stopped',
        'pid': None
    }
}

running_processes = {}

# ---------------------------- Page Routes -----------------------------

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    """Main page - Scripts management"""
    refresh_interval = config.get('refresh_intervals', {}).get('scripts', 5)
    return templates.TemplateResponse("index.html", {
        "request": request,
        "refresh_interval": refresh_interval
    })


@app.get("/disk-space", response_class=HTMLResponse)
async def disk_space(request: Request):
    """Disk space monitoring page"""
    refresh_interval = config.get('refresh_intervals', {}).get('disk_space', 10)
    return templates.TemplateResponse("disk_space.html", {
        "request": request,
        "refresh_interval": refresh_interval
    })


@app.get("/logs", response_class=HTMLResponse)
async def logs(request: Request):
    """Log viewer page"""
    refresh_interval = config.get('refresh_intervals', {}).get('logs', 5)
    return templates.TemplateResponse("logs.html", {
        "request": request,
        "refresh_interval": refresh_interval
    })


@app.get("/sensor-check", response_class=HTMLResponse)
async def sensor_check(request: Request):
    """Sensor check guide page"""
    return templates.TemplateResponse("sensor_check.html", {
        "request": request
    })


# ============================================================================
# API Routes - Health Check
# ----------------------- API Routes - Health Check --------------------------
@app.get("/api/health")
async def health_check():
    """Health check endpoint for monitoring"""
    return JSONResponse(content={
        'status': 'healthy',
        'running_scripts': len(running_processes),
        'timestamp': datetime.now().isoformat()
    })


@app.get("/api/sensors")
async def get_sensor_status():
    """Get status of all helmet sensors"""
    try:
        # Kill any stuck ros2 processes first (they pile up and cause hangs)
        subprocess.run(['pkill', '-9', '-f', 'ros2 node list'], capture_output=True, timeout=1)
        subprocess.run(['pkill', '-9', '-f', 'ros2 topic list'], capture_output=True, timeout=1)
        
        # Source ROS2 and get node list
        ros_env = os.environ.copy()
        ros_env['ROS_DOMAIN_ID'] = '0'
        
        # Use timeout command as additional safety net
        result = subprocess.run(
            ['timeout', '3', 'bash', '-c', 'source /home/jetson/ros2_musohu_ws/install/setup.bash && ros2 node list 2>/dev/null || echo ""'],
            capture_output=True,
            text=True,
            timeout=4,  # Python timeout slightly longer than bash timeout
            env=ros_env
        )
        
        nodes = result.stdout.strip().split('\n') if result.stdout.strip() else []
        
        # Get topics
        result_topics = subprocess.run(
            ['timeout', '3', 'bash', '-c', 'source /home/jetson/ros2_musohu_ws/install/setup.bash && ros2 topic list 2>/dev/null || echo ""'],
            capture_output=True,
            text=True,
            timeout=4,
            env=ros_env
        )
        
        topics = result_topics.stdout.strip().split('\n') if result_topics.stdout.strip() else []
        
        # Check each sensor
        sensors = {
            'imu': {
                'name': 'IMU',
                'icon': '📍',
                'node': '/imu_node',
                'topics': ['/imu_node/cali'],
                'status': 'stopped',
                'node_found': False,
                'topics_found': []
            },
            'lidar': {
                'name': 'LiDAR',
                'icon': '🔦',
                'node': '/lidar_node',
                'topics': ['/rslidar_points'],
                'status': 'stopped',
                'node_found': False,
                'topics_found': []
            },
            'audio': {
                'name': 'Audio (ReSpeaker)',
                'icon': '🎤',
                'node': '/respeaker_node',
                'topics': ['/audio', '/doa', '/speech_audio'],
                'status': 'stopped',
                'node_found': False,
                'topics_found': []
            },
            'zed': {
                'name': 'ZED Camera',
                'icon': '📷',
                'node': '/zed2i/zed_node',
                'topics': ['/zed2i/zed_node/rgb/image_rect_color', '/zed2i/zed_node/depth/depth_registered'],
                'status': 'stopped',
                'node_found': False,
                'topics_found': []
            }
        }
        
        # Check which sensors are active
        for sensor_id, sensor in sensors.items():
            # Check if node exists
            if sensor['node'] in nodes:
                sensor['node_found'] = True
            
            # Check which topics exist
            for topic in sensor['topics']:
                if topic in topics:
                    sensor['topics_found'].append(topic)
            
            # Determine status
            if sensor['node_found'] and len(sensor['topics_found']) > 0:
                sensor['status'] = 'running'
            elif sensor['node_found']:
                sensor['status'] = 'partial'
            else:
                sensor['status'] = 'stopped'
        
        return JSONResponse(content={
            'sensors': sensors,
            'total_nodes': len(nodes),
            'total_topics': len(topics),
            'timestamp': datetime.now().isoformat()
        })
        
    except subprocess.TimeoutExpired as e:
        logger.error(f"ROS2 command timeout: {e}")
        # Kill any remaining stuck processes
        subprocess.run(['pkill', '-9', '-f', 'ros2 node list'], capture_output=True, timeout=1)
        subprocess.run(['pkill', '-9', '-f', 'ros2 topic list'], capture_output=True, timeout=1)
        return JSONResponse(content={
            'error': 'ROS2 command timeout - daemon may be unresponsive. Try restarting ROS2 nodes.',
            'sensors': {},
            'total_nodes': 0,
            'total_topics': 0
        }, status_code=500)
    except Exception as e:
        logger.error(f"Error getting sensor status: {e}")
        return JSONResponse(content={
            'error': str(e),
            'sensors': {},
            'total_nodes': 0,
            'total_topics': 0
        }, status_code=500)


# ============================================================================
# API Routes - Scripts
# ============================================================================

# ------------------------- API Routes - Scripts -----------------------------

@app.get("/api/scripts")
async def list_scripts():
    """List all available ROS2 scripts and their status"""
    # Update status based on actual process state
    for script_id in list(running_processes):
        process = running_processes[script_id]
        if process.poll() is not None:
            # Process has terminated
            del running_processes[script_id]
            ROS2_SCRIPTS[script_id]['status'] = 'stopped'
            ROS2_SCRIPTS[script_id]['pid'] = None

    return JSONResponse(content=ROS2_SCRIPTS)


# -------------------- API Routes - System Monitoring -----------------------

@app.get("/api/disk-space")
async def get_disk_space():
    """Get disk space information"""
    try:
        # Use df command to get accurate disk usage (matches df -h output)
        # This accounts for filesystem overhead and reserved blocks
        result = subprocess.run(
            ['df', '-h', '/'],
            capture_output=True,
            text=True,
            check=True
        )
        
        # Parse df output
        # Output format: Filesystem Size Used Avail Use% Mounted
        lines = result.stdout.strip().split('\n')
        if len(lines) < 2:
            raise Exception("Unexpected df output format")
        
        # Get the data line (skip header)
        data_line = lines[1].split()
        
        # Extract values (handling different df output formats)
        if len(data_line) >= 5:
            total = data_line[1]      # Size
            used = data_line[2]       # Used
            free = data_line[3]       # Available
            percent_used = data_line[4]  # Use%
            
            disk_info = {
                'total': total,
                'used': used,
                'free': free,
                'percent_used': percent_used
            }
            
            return JSONResponse(content=disk_info)
        else:
            raise Exception("Could not parse df output")
            
    except subprocess.CalledProcessError as e:
        logger.error(f"df command failed: {e}")
        return JSONResponse(content={'error': 'Failed to get disk space information'}, status_code=500)
    except Exception as e:
        logger.error(f"Error getting disk space: {e}")
        return JSONResponse(content={'error': str(e)}, status_code=500)

@app.get("/api/logs")
async def get_logs(source: str = Query(default="musohu", alias="source")):
    """Legacy logs endpoint: return last N lines from a selected log source.

    Supports:
    - File-based logs discovered from configured scan directories or explicit sources
    - System journal logs when log_dirs entry has type: journalctl
    """
    try:
        log_source = source
        log_viewer_config = config.get('log_viewer', {})
        max_lines = int(log_viewer_config.get('max_lines', 100))

        # Check if this is a journalctl source via log_dirs config
        log_dirs = config.get('log_dirs', [])
        journal_entry = next((d for d in log_dirs if d.get('key') == log_source and d.get('type') == 'journalctl'), None)
        if journal_entry is not None:
            try:
                result = subprocess.run(
                    ['journalctl', '-n', str(max_lines), '--no-pager', '--output=short-iso'],
                    capture_output=True, text=True, check=True
                )
                lines = [ln for ln in result.stdout.strip().split('\n') if ln]
                logs = []
                for line in lines:
                    parts = line.split(' ', 2)
                    if len(parts) == 3:
                        timestamp, _host, rest = parts
                        logs.append({'timestamp': timestamp, 'level': 'INFO', 'message': rest})
                    else:
                        logs.append({'timestamp': '', 'level': 'INFO', 'message': line})
                return JSONResponse(content={'logs': logs, 'source': log_source})
            except Exception as e:
                logger.error(f'Error reading journalctl logs: {str(e)}')
                return JSONResponse(content={'logs': [], 'error': f'Error reading journalctl logs: {str(e)}'}, status_code=500)

        # Build file-based sources mapping
        log_files = {}

        # 1) Scan configured directories
        for dir_config in log_viewer_config.get('scan_directories', []):
            if not dir_config.get('enabled', True):
                continue
            dir_path = dir_config.get('path', '')
            if os.path.exists(dir_path) and os.path.isdir(dir_path):
                try:
                    for filename in os.listdir(dir_path):
                        file_path = os.path.join(dir_path, filename)
                        if os.path.isfile(file_path):
                            log_id = filename.replace('.', '_')
                            if log_id in log_files:
                                log_id = f"{os.path.basename(dir_path.rstrip('/'))}_{log_id}"
                            log_files[log_id] = file_path
                except Exception as e:
                    logger.error(f"Error scanning directory {dir_path}: {e}")

        # 2) Explicit sources (optional)
        for src in log_viewer_config.get('sources', []):
            if src.get('enabled', True):
                log_files[src['id']] = src['path']

        # 3) Fallback to local logs/ directory
        if not log_files:
            logs_dir = os.path.join(BASE_DIR, 'logs')
            if os.path.exists(logs_dir) and os.path.isdir(logs_dir):
                for filename in os.listdir(logs_dir):
                    file_path = os.path.join(logs_dir, filename)
                    if os.path.isfile(file_path):
                        log_id = filename.replace('.', '_')
                        log_files[log_id] = file_path

        # Resolve desired file path
        log_file = log_files.get(log_source)
        if not log_file:
            # Default to a common app log file
            candidate = os.path.join(BASE_DIR, 'logs', 'musohu.log')
            log_file = candidate if os.path.exists(candidate) else None

        if not log_file:
            return JSONResponse(content={'logs': [], 'error': 'Log file not found'}, status_code=404)

        # Validate extension
        allowed_extensions = log_viewer_config.get('allowed_extensions', ['.log', '.txt'])
        if os.path.splitext(log_file)[1] not in allowed_extensions:
            return JSONResponse(content={
                'logs': [],
                'error': f'Unable to display this file type. Only {", ".join(allowed_extensions)} files can be displayed.'
            }, status_code=400)

        # Read file and return last N lines
        logs = []
        try:
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                lines = lines[-max_lines:] if max_lines > 0 else lines
                for line in lines:
                    line = line.rstrip('\n')
                    if not line:
                        continue
                    # Try to parse "[timestamp] LEVEL: message" format; fall back otherwise
                    if '] ' in line:
                        parts = line.split('] ', 1)
                        timestamp = parts[0].replace('[', '')
                        rest = parts[1]
                        level = 'INFO'
                        message = rest
                        if ': ' in rest:
                            lvl, msg = rest.split(': ', 1)
                            level, message = lvl, msg
                        logs.append({'timestamp': timestamp, 'level': level, 'message': message})
                    else:
                        logs.append({'timestamp': '', 'level': 'INFO', 'message': line})
        except UnicodeDecodeError:
            return JSONResponse(content={
                'logs': [],
                'error': 'Unable to display this file. The file contains non-text or binary data.'
            }, status_code=400)
        except Exception as read_error:
            logger.error(f'Error reading file {log_file}: {str(read_error)}')
            return JSONResponse(content={'logs': [], 'error': f'Error reading file: {str(read_error)}'}, status_code=500)

        return JSONResponse(content={'logs': logs, 'source': log_source})
    except Exception as e:
        logger.error(f'Failed to read logs: {str(e)}')
        return JSONResponse(content={'error': str(e)}, status_code=500)


# --------------------- API Routes - Log Management -------------------------

@app.get("/api/logs/sources")
async def get_log_sources():
    """Get all available log sources"""
    sources = {}
    # Get scan directories from config
    log_viewer_config = config.get('log_viewer', {})
    scan_directories = log_viewer_config.get('scan_directories', [])

    # Scan each configured directory for ALL files
    for dir_config in scan_directories:
        if not dir_config.get('enabled', True):
            continue

        dir_path = dir_config.get('path', '')
        name_prefix = dir_config.get('name_prefix', '')

        if os.path.exists(dir_path) and os.path.isdir(dir_path):
            try:
                for filename in sorted(os.listdir(dir_path)):
                    file_path = os.path.join(dir_path, filename)
                    # Skip directories, only include files
                    if os.path.isfile(file_path):
                        # Create unique ID from filename
                        log_id = filename.replace('.', '_')
                        # If there's a collision, add directory name to make it unique
                        if log_id in sources:
                            log_id = f"{os.path.basename(dir_path.rstrip('/'))}_{log_id}"

                        # Create display name
                        display_name = f"{name_prefix}{filename}"

                        sources[log_id] = {
                            'name': display_name,
                            'path': file_path,
                            'exists': True
                        }
            except Exception as e:
                logger.error(f"Error scanning directory {dir_path}: {e}")

    # Add individual sources from config (for files outside scan directories)
    sources_config = log_viewer_config.get('sources', [])
    for source in sources_config:
        if source.get('enabled', True):
            sources[source['id']] = {
                'name': source['name'],
                'path': source['path'],
                'exists': os.path.exists(source['path'])
            }

    # Fallback: scan logs/ folder if no config
    if not sources:
        logs_dir = 'logs'
        if os.path.exists(logs_dir) and os.path.isdir(logs_dir):
            for filename in sorted(os.listdir(logs_dir)):
                file_path = os.path.join(logs_dir, filename)
                if os.path.isfile(file_path):
                    log_id = filename.replace('.', '_')
                    sources[log_id] = {
                        'name': filename,
                        'path': file_path,
                        'exists': True
                    }

    return JSONResponse(content=sources)

@app.get("/api/logs/download")
async def download_log(source: str = Query(default="", alias="source")):
    """Download a log file"""
    try:
        log_source = source
        log_viewer_config = config.get('log_viewer', {})

        # Build log files mapping by scanning directories
        log_files = {}
        scan_directories = log_viewer_config.get('scan_directories', [])

        for dir_config in scan_directories:
            if not dir_config.get('enabled', True):
                continue

            dir_path = dir_config.get('path', '')

            if os.path.exists(dir_path) and os.path.isdir(dir_path):
                try:
                    for filename in os.listdir(dir_path):
                        file_path = os.path.join(dir_path, filename)
                        # Only include files, not directories
                        if os.path.isfile(file_path):
                            log_id = filename.replace('.', '_')
                            # Handle ID collisions
                            if log_id in log_files:
                                log_id = f"{os.path.basename(dir_path.rstrip('/'))}_{log_id}"
                            log_files[log_id] = (file_path, filename)
                except Exception as e:
                    logger.error(f"Error scanning directory {dir_path}: {e}")

        # Add individual sources from config
        sources = log_viewer_config.get('sources', [])
        for source in sources:
            if source.get('enabled', True):
                log_files[source['id']] = (source['path'], os.path.basename(source['path']))

        if log_source not in log_files:
            return JSONResponse(content={'error': 'Log file not found'}, status_code=404)

        log_file_path, original_filename = log_files[log_source]

        if not os.path.exists(log_file_path):
            return JSONResponse(content={'error': 'Log file not found on disk'}, status_code=404)

        logger.info(f'Downloading log file: {original_filename}')
        return FileResponse(
            log_file_path,
            media_type='application/octet-stream',
            filename=original_filename
        )
    except Exception as e:
        logger.error(f'Failed to download log: {str(e)}')
        return JSONResponse(content={'error': str(e)}, status_code=500)


# ============================================================================
# NEW API Routes - Enhanced Log Viewer
# ============================================================================

@app.get("/api/files")
async def list_files():
    """
    List all available log files with metadata
    Returns files grouped by directory
    """
    try:
        files_by_dir = file_discovery.get_files_by_directory()

        # Convert to response format
        response = {}
        for dir_key, files in files_by_dir.items():
            # Get directory description from first file
            dir_description = files[0].dir_description if files else dir_key

            response[dir_key] = {
                'description': dir_description,
                'files': [
                    {
                        'id': f"{file.dir_key}/{file.name}",
                        **file.to_dict()
                    }
                    for file in files
                ]
            }

        # Add virtual entries for journalctl sources so they appear in the UI
        log_dirs = config.get('log_dirs', [])
        for entry in log_dirs:
            if entry.get('type') == 'journalctl':
                dir_key = entry.get('key', 'system')
                dir_description = entry.get('description', 'Systemd Journal Logs')
                if dir_key not in response:
                    response[dir_key] = {
                        'description': dir_description,
                        'files': []
                    }
                # Add a pseudo-file representing journalctl output
                response[dir_key]['files'].append({
                    'id': f"{dir_key}/journalctl",
                    'name': 'journalctl',
                    'path': 'journalctl',
                    'dir_key': dir_key,
                    'dir_description': dir_description,
                    'size': 0,
                    'size_human': 'stream',
                    'modified_time': None,
                    'modified_time_human': None,
                    'exists': True,
                    'extension': '.log'
                })
        
        return JSONResponse(content=response)
    except Exception as e:
        logger.error(f'Failed to list files: {str(e)}')
        return JSONResponse(content={'error': str(e)}, status_code=500)


@app.get("/api/file")
async def get_file(
    file_id: str = Query(..., description="File ID in format: dir_key/filename"),
    lines: int = Query(None, description="Number of lines to return"),
    tail: bool = Query(True, description="Return last N lines (True) or first N lines (False)"),
    search: str = Query(None, description="Search term to filter lines")
):
    """
    Get file contents with optional search
    
    Query parameters:
    - file_id: Unique file identifier (dir_key/filename)
    - lines: Max number of lines to return (default from config)
    - tail: If true, return last N lines; else first N lines
    - search: Optional search term to filter results
    """
    try:
        # Handle virtual journalctl files: <dir_key>/journalctl
        try:
            dir_key, file_name = file_id.split('/', 1)
        except ValueError:
            dir_key, file_name = None, None

        if file_name == 'journalctl':
            # Determine default lines
            default_lines = config.get('server', {}).get('default_lines', 500)
            n = default_lines if lines is None else (lines if lines > 0 else default_lines)
            # Build journalctl command (tail or head equivalent by limiting lines)
            cmd = ['journalctl', '--no-pager', '--output=short-iso', '-n', str(n)]
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, check=True)
                raw_lines = result.stdout.splitlines()
                if not tail and len(raw_lines) > n:
                    raw_lines = raw_lines[:n]
                return JSONResponse(content={
                    'file_id': file_id,
                    'metadata': {
                        'name': 'journalctl',
                        'path': 'journalctl',
                        'dir_key': dir_key or 'system',
                        'dir_description': 'Systemd Journal Logs',
                        'size_human': 'stream',
                        'exists': True
                    },
                    'lines': raw_lines,
                    'total_lines': len(raw_lines)
                })
            except Exception as e:
                logger.error(f'Failed to read journalctl: {e}')
                return JSONResponse(content={'error': f'Failed to read journalctl: {str(e)}'}, status_code=500)

        # If search is provided, use search functionality
        if search:
            search_config = config.get('log_viewer', {}).get('search', {})
            case_sensitive = search_config.get('case_sensitive', False)
            max_results = search_config.get('max_results', 1000)
            
            results = file_discovery.search_in_file(
                file_id, 
                search, 
                case_sensitive=case_sensitive,
                max_results=max_results
            )
            
            return JSONResponse(content={
                'file_id': file_id,
                'search_term': search,
                'results': results,
                'total_matches': len(results)
            })
        
        # Otherwise, return file contents
        file_lines = file_discovery.read_file_lines(file_id, max_lines=lines, tail=tail)
        
        if file_lines is None:
            return JSONResponse(
                content={'error': 'File not found'},
                status_code=404
            )
        
        # Get file metadata
        metadata = file_discovery.get_file_by_id(file_id)
        
        return JSONResponse(content={
            'file_id': file_id,
            'metadata': metadata.to_dict() if metadata else None,
            'lines': [line.rstrip('\n') for line in file_lines],
            'total_lines': len(file_lines)
        })
        
    except Exception as e:
        logger.error(f'Failed to get file {file_id}: {str(e)}')
        return JSONResponse(content={'error': str(e)}, status_code=500)


@app.get("/api/file/download")
async def download_file(
    file_id: str = Query(..., description="File ID in format: dir_key/filename")
):
    """Download a log file"""
    try:
        # Block downloads for journalctl virtual file
        if file_id.endswith('/journalctl'):
            return JSONResponse(content={'error': 'Download not supported for journalctl stream'}, status_code=400)
        metadata = file_discovery.get_file_by_id(file_id)
        
        if not metadata:
            return JSONResponse(
                content={'error': 'File not found'},
                status_code=404
            )
        
        if not metadata.exists:
            return JSONResponse(
                content={'error': 'File does not exist on disk'},
                status_code=404
            )
        
        logger.info(f'Downloading file: {metadata.name} from {metadata.dir_key}')
        return FileResponse(
            metadata.path,
            media_type='application/octet-stream',
            filename=metadata.name
        )
    except Exception as e:
        logger.error(f'Failed to download file {file_id}: {str(e)}')
        return JSONResponse(content={'error': str(e)}, status_code=500)


@app.get("/api/file/stream")
async def stream_file(
    file_id: str = Query(..., description="File ID in format: dir_key/filename")
):
    """
    Stream file contents (useful for large files)
    Returns file as a streaming response
    """
    try:
        # Block streaming for journalctl virtual file (use get_file instead)
        if file_id.endswith('/journalctl'):
            return JSONResponse(content={'error': 'Use /api/file for journalctl content'}, status_code=400)
        metadata = file_discovery.get_file_by_id(file_id)
        
        if not metadata or not metadata.exists:
            return JSONResponse(
                content={'error': 'File not found'},
                status_code=404
            )
        
        def generate():
            try:
                with open(metadata.path, 'r', encoding='utf-8', errors='ignore') as f:
                    for line in f:
                        yield line
            except Exception as e:
                logger.error(f"Error streaming file {metadata.path}: {e}")
        
        return StreamingResponse(
            generate(),
            media_type='text/plain',
            headers={'Content-Disposition': f'inline; filename="{metadata.name}"'}
        )
    except Exception as e:
        logger.error(f'Failed to stream file {file_id}: {str(e)}')
        return JSONResponse(content={'error': str(e)}, status_code=500)


# ============================================================================
# API Routes - Scripts
# ============================================================================
@app.post("/api/scripts/{script_id}/start")
async def start_script(script_id: str):
    """Start a ROS2 script"""
    logger.info(f'Attempting to start script: {script_id}')
    # Backward compatibility: accept old id 'rviz2' and map to new 'record_bag'
    if script_id == 'rviz2':
        script_id = 'record_bag'
    
    if script_id not in ROS2_SCRIPTS:
        logger.error(f'Script not found: {script_id}')
        return JSONResponse(content={'error': 'Script not found'}, status_code=404)

    if script_id in running_processes:
        logger.warning(f'Script already running: {script_id}')
        return JSONResponse(content={'error': 'Script already running'}, status_code=400)

    try:
        command = ROS2_SCRIPTS[script_id]['command']
        script_name = ROS2_SCRIPTS[script_id]['description']

        # Start the process
        process = subprocess.Popen(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            preexec_fn=os.setsid  # Create new process group
        )

        # Update tracking
        running_processes[script_id] = process
        ROS2_SCRIPTS[script_id]['status'] = 'running'
        ROS2_SCRIPTS[script_id]['pid'] = str(process.pid)  # Fix type mismatch

        logger.info(f'Successfully started {script_id} with PID: {process.pid}')
        return JSONResponse(content={
            'message': f'Started {script_name} (PID: {process.pid})',
            'pid': process.pid
        })
    except Exception as e:
        logger.error(f'Failed to start {script_id}: {str(e)}')
        return JSONResponse(content={'error': str(e)}, status_code=500)


@app.post("/api/scripts/{script_id}/stop")
async def stop_script(script_id: str):
    """Stop a running ROS2 script"""
    if script_id == 'rviz2':
        script_id = 'record_bag'
    if script_id not in ROS2_SCRIPTS:
        return JSONResponse(content={'error': 'Invalid script ID'}, status_code=400)

    logger.info(f'Attempting to stop script: {script_id}')
    
    script_name = ROS2_SCRIPTS[script_id]['description']
    
    # Always ensure status is set to stopped
    ROS2_SCRIPTS[script_id]['status'] = 'stopped'
    ROS2_SCRIPTS[script_id]['pid'] = None
    
    if script_id not in running_processes:
        logger.warning(f'{script_id} is already stopped')
        return JSONResponse(content={'message': f'{script_name} is already stopped'})

    try:
        process = running_processes[script_id]
        pid = process.pid
        
        # Check if process is still alive
        if process.poll() is not None:
            # Process already terminated
            del running_processes[script_id]
            return JSONResponse(content={'message': f'Stopped {script_name} (PID: {pid})'})

        # Terminate the process gracefully
        try:
            process.terminate()
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            # Force kill if termination times out
            process.kill()
            process.wait()
        except ProcessLookupError:
            # Process doesn't exist anymore
            pass

        del running_processes[script_id]
        
        logger.info(f"Successfully stopped {script_id} (PID: {pid})")
        return JSONResponse(content={'message': f'Stopped {script_name} (PID: {pid})'})
    except Exception as e:
        logger.error(f'Error stopping {script_id}: {str(e)}')
        # Clean up even on error
        if script_id in running_processes:
            del running_processes[script_id]
        return JSONResponse(content={'message': f'Stopped {script_name}'})


# ----------------------------- Time Sync -----------------------------

@app.post("/sync_time")
async def sync_time(
    client_time: str = Form(...),
    client_timezone: str = Form(default="UTC")
):
    """Sync server time with client time"""
    try:
        if not client_time:
            client_time = datetime.now(timezone.utc).isoformat()
        
        # Parse the client time (which is in ISO format, UTC)
        try:
            dt_utc = datetime.fromisoformat(client_time.replace('Z', '+00:00'))
        except Exception:
            dt_utc = datetime.now(timezone.utc)
        
        sync_logger.info(f"Time sync requested - Client UTC time: {client_time}, Parsed: {dt_utc}, Target timezone: {client_timezone}")
        
        # First, set timezone if provided and valid (must be done before setting time)
        timezone_set = False
        if client_timezone and client_timezone != "UTC":
            try:
                tz_result = subprocess.run(
                    ['sudo', 'timedatectl', 'set-timezone', client_timezone],
                    check=True,
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                sync_logger.info(f"Timezone set to: {client_timezone}")
                timezone_set = True
                # Give system a moment to apply timezone change
                import time
                time.sleep(0.5)
            except Exception as e:
                sync_logger.warning(f"Could not set timezone to {client_timezone}: {e}")
        
        # Disable NTP to allow manual time setting
        try:
            subprocess.run(
                ['sudo', 'timedatectl', 'set-ntp', 'false'],
                check=True,
                capture_output=True,
                text=True,
                timeout=5
            )
            sync_logger.info("NTP disabled successfully")
        except Exception as e:
            sync_logger.warning(f"Could not disable NTP: {e}")
        
        # IMPORTANT: timedatectl set-time interprets time in LOCAL timezone
        # Client sends UTC time, but we need to convert it to local time for timedatectl
        # Example: Client at 04:47 EST sends 09:47 UTC
        # We need to set local time to 04:47, not 09:47
        
        # Convert UTC to local time for the target timezone
        import pytz
        if timezone_set and client_timezone:
            try:
                target_tz = pytz.timezone(client_timezone)
                dt_local = dt_utc.astimezone(target_tz)
                formatted_local = dt_local.strftime('%Y-%m-%d %H:%M:%S')
                sync_logger.info(f"Converted UTC {dt_utc} to local {formatted_local} ({client_timezone})")
            except Exception as e:
                sync_logger.error(f"Failed to convert timezone: {e}. Using UTC.")
                formatted_local = dt_utc.strftime('%Y-%m-%d %H:%M:%S')
        else:
            formatted_local = dt_utc.strftime('%Y-%m-%d %H:%M:%S')
        
        sync_logger.info(f"Setting system time to: {formatted_local} (will be interpreted as local time)")
        
        # Set system time using timedatectl (interprets as LOCAL time)
        result = subprocess.run(
            ['sudo', 'timedatectl', 'set-time', formatted_local],
            check=True,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        # Verify the time was set
        verify_result = subprocess.run(
            ['timedatectl', 'status'],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        sync_logger.info(f"Time sync completed. Verification:\n{verify_result.stdout}")
        
        # Get the new system time in local timezone
        new_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')
        
        # Log to HTML file
        html_log_path = os.path.join(BASE_DIR, "conlog.html")
        with open(html_log_path, "a") as html_log:
            html_log.write(
                f"<div style='color:green;font-weight:bold'>✓ Time sync SUCCESS: Client UTC <b>{client_time}</b> "
                f"→ Server local time now: <b>{new_time}</b> (Timezone: {client_timezone if timezone_set else 'unchanged'})</div>\n"
            )
        
        return JSONResponse(content={
            'success': True,
            'message': f'✓ Server synced! Local time: {new_time}'
        })
    except subprocess.CalledProcessError as e:
        error_msg = f"Failed to sync time: {e.stderr}. Note: This requires sudo permissions."
        sync_logger.error(error_msg)
        html_log_path = os.path.join(BASE_DIR, "conlog.html")
        with open(html_log_path, "a") as html_log:
            html_log.write(
                f"<div style='color:red'>Sync error: {error_msg} at {datetime.now().isoformat()}</div>\n"
            )
        return JSONResponse(content={
            'success': False,
            'message': error_msg
        }, status_code=500)
    except subprocess.TimeoutExpired:
        error_msg = "Time sync command timed out"
        sync_logger.error(error_msg)
        html_log_path = os.path.join(BASE_DIR, "conlog.html")
        with open(html_log_path, "a") as html_log:
            html_log.write(
                f"<div style='color:red'>Sync timeout: {error_msg} at {datetime.now().isoformat()}</div>\n"
            )
        return JSONResponse(content={
            'success': False,
            'message': error_msg
        }, status_code=500)
    except Exception as e:
        error_msg = f"Failed to sync time: {str(e)}"
        sync_logger.error(error_msg)
        html_log_path = os.path.join(BASE_DIR, "conlog.html")
        with open(html_log_path, "a") as html_log:
            html_log.write(
                f"<div style='color:red'>Sync error: {error_msg} at {datetime.now().isoformat()}</div>\n"
            )
        return JSONResponse(content={
            'success': False,
            'message': error_msg
        }, status_code=500)


# ----------------------------- WebSocket Events -----------------------------

@sio.event
async def connect(sid, environ):
    """Handle WebSocket connection"""
    logger.info(f"WebSocket client connected: {sid}")


@sio.event
async def disconnect(sid):
    """Handle WebSocket disconnection"""
    logger.info(f"WebSocket client disconnected: {sid}")


async def background_time_sender():
    """Background task to send server time via WebSocket"""
    while True:
        await asyncio.sleep(1)
        now = datetime.now().astimezone()
        # Format: 01/21/2026, 12:06:02 EST (America/New_York)
        time_str = now.strftime('%m/%d/%Y, %H:%M:%S')
        # Get timezone abbreviation (EST, PST, etc.)
        tz_abbr = now.strftime('%Z')
        # Get IANA timezone name from /etc/timezone (Linux) or tzinfo
        try:
            with open('/etc/timezone', 'r') as f:
                tz_name = f.read().strip()
        except:
            tz_name = str(now.tzinfo)
        server_time = f"{time_str} {tz_abbr} ({tz_name})"
        try:
            await sio.emit('server_time', {'time': server_time})
        except Exception as e:
            # Ignore errors if no client connected
            pass


@app.on_event("startup")
async def startup_event():
    """Start background tasks on app startup"""
    asyncio.create_task(background_time_sender())
    logger.info("Background time sender started")


if __name__ == "__main__":
    import uvicorn
    server_config = config.get('server', {})
    host = server_config.get('host', '0.0.0.0')
    port = server_config.get('port', 8000)
    # Use socket_app to include Socket.IO
    uvicorn.run(socket_app, host=host, port=port)

