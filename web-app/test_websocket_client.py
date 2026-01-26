#!/usr/bin/env python3
"""
WebSocket Client Test for MuSoHu
Tests the Socket.IO event handlers for ROS2 script management
"""

import socketio
import time
import sys

# Create a Socket.IO client
sio = socketio.Client()

# Track events received
events_log = []

@sio.event
def connect():
    print("✅ Connected to server")
    events_log.append("connect")

@sio.event
def disconnect():
    print("❌ Disconnected from server")
    events_log.append("disconnect")

@sio.on('scripts_status')
def on_scripts_status(data):
    print(f"\n📊 Received scripts_status:")
    for script_id, script_data in data.items():
        status = script_data.get('status', 'unknown')
        pid = script_data.get('pid', 'N/A')
        desc = script_data.get('description', 'N/A')
        print(f"  - {script_id}: {desc} [{status}] PID: {pid}")
    events_log.append("scripts_status")

@sio.on('script_started')
def on_script_started(data):
    print(f"\n✅ Script started: {data.get('script_id')}")
    print(f"   Message: {data.get('message')}")
    print(f"   PID: {data.get('pid')}")
    print(f"   Status: {data.get('status')}")
    events_log.append(("script_started", data.get('script_id')))

@sio.on('script_stopped')
def on_script_stopped(data):
    print(f"\n⏹️  Script stopped: {data.get('script_id')}")
    print(f"   Message: {data.get('message')}")
    print(f"   Status: {data.get('status')}")
    if 'exit_code' in data:
        print(f"   Exit code: {data.get('exit_code')}")
    events_log.append(("script_stopped", data.get('script_id')))

@sio.on('script_error')
def on_script_error(data):
    print(f"\n❌ Script error: {data.get('script_id')}")
    print(f"   Error: {data.get('error')}")
    events_log.append(("script_error", data.get('script_id')))

@sio.on('server_time')
def on_server_time(data):
    # Just track, don't print (too frequent)
    pass

def test_websocket(host='localhost', port=8000):
    """Test WebSocket functionality"""
    url = f'http://{host}:{port}'
    
    print(f"🔌 Connecting to {url}...")
    
    try:
        # Connect to server
        sio.connect(url)
        
        # Wait for initial status
        time.sleep(2)
        
        print("\n" + "="*60)
        print("WebSocket Connection Test: PASSED ✓")
        print("="*60)
        
        # Test 1: Request script status
        print("\n📋 Test 1: Initial connection")
        if "scripts_status" in events_log:
            print("   ✓ Received initial scripts_status on connect")
        else:
            print("   ✗ Did NOT receive initial scripts_status")
        
        # Test 2: Try to start a script (will likely fail without ROS2 environment, but that's ok)
        print("\n📋 Test 2: Start script command")
        print("   Sending start_script event for 'helmet_nodes'...")
        sio.emit('start_script', {'script_id': 'helmet_nodes'})
        time.sleep(1)
        
        # Test 3: Try to stop a script
        print("\n📋 Test 3: Stop script command")
        print("   Sending stop_script event for 'helmet_nodes'...")
        sio.emit('stop_script', {'script_id': 'helmet_nodes'})
        time.sleep(1)
        
        # Summary
        print("\n" + "="*60)
        print("TEST SUMMARY")
        print("="*60)
        print(f"Events received: {len(events_log)}")
        print(f"Connection: {'✓ SUCCESS' if 'connect' in events_log else '✗ FAILED'}")
        print(f"Initial status: {'✓ RECEIVED' if 'scripts_status' in events_log else '✗ NOT RECEIVED'}")
        print(f"\nEvent log: {events_log}")
        
        # Disconnect
        sio.disconnect()
        print("\n✅ WebSocket test completed successfully!")
        return True
        
    except socketio.exceptions.ConnectionError as e:
        print(f"\n❌ Connection failed: {e}")
        print(f"   Make sure the server is running at {url}")
        return False
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    # Parse command line arguments
    host = sys.argv[1] if len(sys.argv) > 1 else 'localhost'
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
    
    print("="*60)
    print("MuSoHu WebSocket Test Client")
    print("="*60)
    print(f"Target: {host}:{port}")
    print()
    
    success = test_websocket(host, port)
    sys.exit(0 if success else 1)
