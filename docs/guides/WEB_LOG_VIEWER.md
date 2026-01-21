# Web Log Viewer

A web-based log viewer built with FastAPI and vanilla JavaScript. This application provides functionality for viewing, searching, and managing `.log` and `.txt` files from multiple configured directories.

## Features

### Core Features

- **Multi-Directory Support**: Configure multiple log directories via YAML
- **Full-Text Search**: Search within files with case-sensitive/insensitive options
- **File Metadata**: Display file size, modification time, and directory info
- **Download Support**: Download individual log files
- **Live Tail**: Auto-refresh file contents every 2 seconds
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Modern UI**: Clean sidebar navigation with file grouping by directory

### Advanced Features

- **Duplicate Handling**: Files with same names in different directories are uniquely identified
- **Lazy Loading**: Files are loaded on-demand to minimize memory usage
- **Caching**: File lists are cached briefly to reduce I/O operations
- **Streaming Support**: Large files can be streamed to avoid memory issues
- **Line Limiting**: Configure how many lines to display (100, 250, 500, 1000, or all)
- **File Filtering**: Filter files by name in the sidebar
- **Extension Filtering**: Only configured file extensions are displayed

---

## Quick Start

### Prerequisites

- Python 3.8+
- FastAPI, Uvicorn, PyYAML (see `requirements.txt`)

### Installation

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Configure directories in `config.yml`:
   ```yaml
   log_dirs:
     - key: webapp
       path: logs/
       description: "Web Application Logs"
     - key: ros2
       path: ../helmet_logs/
       description: "ROS2 Helmet Logs"
   ```

3. Run the server:
   ```bash
   python app.py
   ```

4. Open browser:
   ```
   http://localhost:8000/logs
   ```

---

## Configuration

### `config.yml` Structure

```yaml
# Log Directories Configuration
log_dirs:
  - key: webapp              # Unique identifier for this directory
    path: logs/              # Absolute or relative path
    description: "Web App"   # Display name in UI

# Server Configuration
server:
  host: 0.0.0.0
  port: 8000
  default_lines: 500        # Default number of lines to show

# Log Viewer Settings
log_viewer:
  max_lines: 500            # Maximum lines to display
  cache_ttl: 30             # Cache file list for 30 seconds
  allowed_extensions:
    - .log
    - .txt
  search:
    enabled: true
    max_results: 1000
    case_sensitive: false
```

### Directory Configuration

Each directory entry requires:
- **key**: Unique identifier (used in file IDs like `webapp/error.log`)
- **path**: Directory path (relative to `web-app/` or absolute)
- **description**: Human-readable name shown in the UI

---

## Architecture

### Backend (FastAPI + Python)

#### File Discovery Service (`file_discovery.py`)
- Scans configured directories for allowed file types
- Collects metadata (size, modified time, etc.)
- Handles duplicate filenames across directories
- Implements caching to reduce I/O

#### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/files` | GET | List all files grouped by directory |
| `/api/file` | GET | Get file contents or search results |
| `/api/file/download` | GET | Download a file |
| `/api/file/stream` | GET | Stream large files |

**Example API Calls:**

```bash
# List all files
curl http://localhost:8000/api/files

# View file (last 500 lines)
curl "http://localhost:8000/api/file?file_id=webapp/app.log"

# Search in file
curl "http://localhost:8000/api/file?file_id=webapp/app.log&search=error"

# Get specific number of lines
curl "http://localhost:8000/api/file?file_id=webapp/app.log&lines=100"

# Download file
curl "http://localhost:8000/api/file/download?file_id=webapp/app.log" -o app.log
```

### Frontend (Vanilla JavaScript + CSS)

#### UI Components

1. **Sidebar**
   - Directory sections (collapsible)
   - File list with icons and sizes
   - Search/filter input
   - Navigation links

2. **Main Viewer**
   - File title and metadata
   - Search bar with options
   - Log content display with line numbers
   - Action buttons (Download, Live Tail)

3. **Search Results**
   - Highlighted matches
   - Line numbers
   - Match count

---

## Usage Guide

### Viewing Logs

1. **Select a File**: Click any file in the sidebar
2. **Browse Content**: Scroll through the log content
3. **Change Lines**: Use the dropdown to show more/fewer lines

### Searching

1. **Enter Search Term**: Type in the search box
2. **Optional**: Check "Case sensitive" if needed
3. **Click Search**: Or press Enter
4. **View Results**: Matching lines are highlighted
5. **Clear Search**: Click "Clear" to return to normal view

### Live Tail

1. **Select a File**: Choose the file you want to monitor
2. **Click "Live Tail"**: Button turns green when active
3. **Auto-Refresh**: Content updates every 2 seconds
4. **Stop**: Click button again to stop

### Downloading

1. **Select a File**: Choose the file to download
2. **Click Download**: File opens in new tab or downloads

### Filtering Files

- **By Name**: Type in the "Filter files..." box in sidebar
- **By Extension**: Configured in `config.yml`

---

## File Identification

Files are identified using the format: `{directory_key}/{filename}`

**Examples:**
- `webapp/error.log` - error.log from webapp directory
- `ros2/sensor.log` - sensor.log from ros2 directory

This prevents conflicts when multiple directories contain files with the same name.

---

## Performance Considerations

### Caching
- File lists are cached for 30 seconds (configurable)
- Reduces filesystem scans on each request
- Cache is invalidated on manual refresh

### Line Limiting
- Default: 500 lines
- Prevents browser slowdown with large files
- Use "All lines" option carefully

### Streaming
- Large files can be streamed via `/api/file/stream`
- Avoids loading entire file into memory
- Useful for files > 100 MB

---

## Security Considerations

### Read-Only Access
- All operations are read-only
- No file modification or deletion
- No command execution

### Path Validation
- Only configured directories are accessible
- File paths are validated against whitelist
- No directory traversal attacks

### File Type Restrictions
- Only configured extensions (`.log`, `.txt`) are served
- Binary files are rejected
- MIME type validation on download

---

## Troubleshooting

### Files Not Appearing

1. **Check Configuration**:
   ```yaml
   log_dirs:
     - key: myapp
       path: /correct/path/to/logs  # Verify this path
   ```

2. **Check Permissions**: Ensure the app has read access
   ```bash
   ls -la /path/to/logs
   ```

3. **Check File Extensions**: Only `.log` and `.txt` by default
   ```yaml
   allowed_extensions:
     - .log
     - .txt
   ```

### Server Won't Start

1. **Port in Use**: Change port in `config.yml`
2. **Missing Dependencies**: Run `pip install -r requirements.txt`
3. **Python Version**: Requires Python 3.8+

### Search Not Working

1. **Check Config**: Ensure search is enabled
   ```yaml
   search:
     enabled: true
   ```

2. **Large Files**: Search may timeout on very large files
3. **Special Characters**: Escape regex characters if needed

---

## API Response Examples

### List Files Response

```json
{
  "webapp": {
    "description": "Web Application Logs",
    "files": [
      {
        "id": "webapp/app.log",
        "name": "app.log",
        "path": "/path/to/logs/app.log",
        "dir_key": "webapp",
        "dir_description": "Web Application Logs",
        "size": 12345,
        "size_human": "12.06 KB",
        "modified_time": "2025-11-12T08:30:00",
        "modified_time_human": "2 hours ago",
        "exists": true,
        "extension": ".log"
      }
    ]
  }
}
```

### View File Response

```json
{
  "file_id": "webapp/app.log",
  "metadata": {
    "name": "app.log",
    "size_human": "12.06 KB",
    "modified_time_human": "2 hours ago"
  },
  "lines": [
    "[2025-11-12 08:30:00] INFO: Application started",
    "[2025-11-12 08:30:01] DEBUG: Loading configuration"
  ],
  "total_lines": 2
}
```

### Search Response

```json
{
  "file_id": "webapp/app.log",
  "search_term": "error",
  "results": [
    {
      "line_number": 42,
      "content": "[2025-11-12 08:31:00] ERROR: Connection failed",
      "file": "app.log",
      "dir_key": "webapp"
    }
  ],
  "total_matches": 1
}
```

---

## Development

### Project Structure

```
web-app/
├── app.py                  # FastAPI application
├── file_discovery.py       # File discovery service
├── config.yml              # Configuration
├── requirements.txt        # Python dependencies
├── templates/
│   └── logs.html          # Main UI template
├── static/
│   └── style.css          # Styles
└── logs/                  # Default log directory
```

### Adding New Features

1. **Backend**: Modify `app.py` to add new endpoints
2. **File Discovery**: Update `file_discovery.py` for new file operations
3. **Frontend**: Edit `templates/logs.html` for UI changes
4. **Styling**: Modify `static/style.css` for appearance

---

## Potential Enhancements

Possible future improvements:

- [ ] **Authentication**: Basic auth for access control
- [ ] **WebSocket Live Tail**: Real-time updates without polling
- [ ] **Syntax Highlighting**: Color-code log levels
- [ ] **Log Parsing**: Structured log parsing (JSON, etc.)
- [ ] **Dark/Light Theme**: User preference toggle
- [ ] **Bookmarks**: Save frequently viewed files
- [ ] **Export**: Export search results to CSV/JSON
- [ ] **Multi-file Search**: Search across multiple files
- [ ] **Log Analytics**: Basic statistics and charts

---

## Design Principles

Built following these principles:
- Minimal dependencies
- Low memory footprint
- YAML-based configuration
- Read-only operations
- File handling implementation

---

## Support

For issues or questions, contact [RobotiXX Lab](https://robotixx.cs.gmu.edu/)
