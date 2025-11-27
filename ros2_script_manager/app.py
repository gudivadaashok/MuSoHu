from flask import Flask, render_template, jsonify, request, redirect, url_for, flash
from flask_cors import CORS
import subprocess
import os
import signal
from logging_config import setup_logging
import datetime
import logging

app = Flask(__name__)
CORS(app)

# Setup logging
logger = setup_logging(app)

# Sync time logger
sync_logger = logging.getLogger("sync_time")
sync_handler = logging.FileHandler("conlog.log")
sync_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s: %(message)s'))
sync_logger.addHandler(sync_handler)
sync_logger.setLevel(logging.INFO)

# Store running processes
running_processes = {}

# Docker container name
DOCKER_CONTAINER = 'ros2_vnc'

# Define available ROS2 scripts
ROS2_SCRIPTS = {
    'turtlesim': {
        'command': f'docker exec --user ubuntu -e DISPLAY=:1 {DOCKER_CONTAINER} bash -c "source /opt/ros/humble/setup.bash && ros2 run turtlesim turtlesim_node"',
        'description': 'TurtleSim Node',
        'status': 'stopped',
        'pid': None
    },
    'rviz2': {
        'command': f'docker exec --user ubuntu -e DISPLAY=:1 {DOCKER_CONTAINER} bash -c "source /opt/ros/humble/setup.bash && rviz2"',
        'description': 'RViz2 Visualization',
        'status': 'stopped',
        'pid': None
    }
}

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/scripts', methods=['GET'])
def get_scripts():
    # Update status based on actual process state
    for script_id in running_processes.copy():
        process = running_processes[script_id]
        if process.poll() is not None:
            # Process has terminated
            del running_processes[script_id]
            ROS2_SCRIPTS[script_id]['status'] = 'stopped'
            ROS2_SCRIPTS[script_id]['pid'] = None
    
    return jsonify(ROS2_SCRIPTS)

@app.route('/api/scripts/<script_id>/start', methods=['POST'])
def start_script(script_id):
    logger.info(f'Attempting to start script: {script_id}')
    
    if script_id not in ROS2_SCRIPTS:
        logger.error(f'Script not found: {script_id}')
        return jsonify({'error': 'Script not found'}), 404
    
    if script_id in running_processes:
        logger.warning(f'Script already running: {script_id}')
        return jsonify({'error': 'Script already running'}), 400
    
    try:
        command = ROS2_SCRIPTS[script_id]['command']
        process = subprocess.Popen(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            preexec_fn=os.setsid
        )
        running_processes[script_id] = process
        ROS2_SCRIPTS[script_id]['status'] = 'running'
        ROS2_SCRIPTS[script_id]['pid'] = process.pid
        
        script_name = ROS2_SCRIPTS[script_id]['description']
        logger.info(f'Successfully started {script_id} with PID: {process.pid}')
        return jsonify({'message': f'✓ Started {script_name} (PID: {process.pid})', 'pid': process.pid})
    except Exception as e:
        logger.error(f'Failed to start {script_id}: {str(e)}')
        return jsonify({'error': str(e)}), 500

@app.route('/api/scripts/<script_id>/stop', methods=['POST'])
def stop_script(script_id):
    logger.info(f'Attempting to stop script: {script_id}')
    
    script_name = ROS2_SCRIPTS[script_id]['description']
    
    # Always ensure status is set to stopped
    ROS2_SCRIPTS[script_id]['status'] = 'stopped'
    ROS2_SCRIPTS[script_id]['pid'] = None
    
    if script_id not in running_processes:
        logger.warning(f'{script_id} is already stopped')
        return jsonify({'message': f'✓ {script_name} is already stopped'})
    
    try:
        process = running_processes[script_id]
        pid = process.pid
        
        # Check if process is still alive
        if process.poll() is not None:
            # Process already terminated
            del running_processes[script_id]
            return jsonify({'message': f'✓ Stopped {script_name} (PID: {pid})'})
        
        # Kill the process inside the Docker container
        # Find and kill the actual ROS2 process by name
        process_name = 'turtlesim_node' if script_id == 'turtlesim' else 'rviz2'
        kill_command = f'docker exec {DOCKER_CONTAINER} bash -c "pkill -f {process_name}"'
        subprocess.run(kill_command, shell=True, timeout=5)
        
        # Try to kill the local docker exec process group
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
            process.wait(timeout=5)
        except ProcessLookupError:
            # Process doesn't exist anymore
            pass
        except Exception as e:
            # If termination fails, try SIGKILL
            try:
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)
            except:
                pass
        
        del running_processes[script_id]
        
        return jsonify({'message': f'✓ Stopped {script_name} (PID: {pid})'})
    except Exception as e:
        # Clean up even on error
        if script_id in running_processes:
            del running_processes[script_id]
        return jsonify({'message': f'✓ Stopped {script_name}'})

@app.route('/sync_time', methods=['POST'])
def sync_time():
    try:
        client_time = request.form.get('client_time')
        if not client_time:
            client_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
        try:
            dt = datetime.datetime.fromisoformat(client_time.replace('Z', '+00:00'))
        except Exception:
            dt = datetime.datetime.now(datetime.timezone.utc)
        formatted = dt.strftime('%Y-%m-%d %H:%M:%S')
        subprocess.run(['sudo', 'date', '-u', '-s', formatted], check=True)
        sync_logger.info(f"Time sync requested: {client_time} (UTC parsed: {formatted})")
        # Also log to conlog.html
        with open("conlog.html", "a") as html_log:
            html_log.write(f"<div>Time sync: <b>{client_time}</b> (UTC: {formatted}) at {datetime.datetime.now().isoformat()}</div>\n")
        return jsonify({'success': True, 'message': 'Time synced successfully!'})
    except Exception as e:
        sync_logger.error(f"Failed to sync time: {e}")
        with open("conlog.html", "a") as html_log:
            html_log.write(f"<div style='color:red'>Sync error: {e} at {datetime.datetime.now().isoformat()}</div>\n")
        return jsonify({'success': False, 'message': f'Failed to sync time: {e}'})

if __name__ == '__main__':
    logger.info('Starting MuSoHu ROS2 Script Manager')
    logger.info(f'Available scripts: {", ".join(ROS2_SCRIPTS.keys())}')
    app.run(host='0.0.0.0', port=5001, debug=True)
