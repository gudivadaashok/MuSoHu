"""
File Discovery Service for Log Viewer
Handles file discovery, metadata collection, and duplicate resolution
"""
import os
import time
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime
import logging

logger = logging.getLogger("uvicorn")


class FileMetadata:
    """Metadata for a discovered file"""
    def __init__(self, name: str, path: str, dir_key: str, dir_description: str):
        self.name = name
        self.path = path
        self.dir_key = dir_key
        self.dir_description = dir_description
        self.size = 0
        self.modified_time = None
        self.exists = False
        
        # Collect metadata if file exists
        if os.path.exists(path) and os.path.isfile(path):
            self.exists = True
            try:
                stat = os.stat(path)
                self.size = stat.st_size
                self.modified_time = datetime.fromtimestamp(stat.st_mtime)
            except Exception as e:
                logger.error(f"Error getting file metadata for {path}: {e}")
    
    def to_dict(self) -> dict:
        """Convert to dictionary representation"""
        return {
            'name': self.name,
            'path': self.path,
            'dir_key': self.dir_key,
            'dir_description': self.dir_description,
            'size': self.size,
            'size_human': self._format_size(self.size),
            'modified_time': self.modified_time.isoformat() if self.modified_time else None,
            'modified_time_human': self._format_time(self.modified_time) if self.modified_time else None,
            'exists': self.exists,
            'extension': os.path.splitext(self.name)[1]
        }
    
    @staticmethod
    def _format_size(size: int) -> str:
        """Format file size in human-readable format"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024.0:
                return f"{size:.2f} {unit}"
            size /= 1024.0
        return f"{size:.2f} TB"
    
    @staticmethod
    def _format_time(dt: datetime) -> str:
        """Format datetime in human-readable format"""
        now = datetime.now()
        diff = now - dt
        
        if diff.days == 0:
            if diff.seconds < 60:
                return "just now"
            elif diff.seconds < 3600:
                minutes = diff.seconds // 60
                return f"{minutes} minute{'s' if minutes != 1 else ''} ago"
            else:
                hours = diff.seconds // 3600
                return f"{hours} hour{'s' if hours != 1 else ''} ago"
        elif diff.days == 1:
            return "yesterday"
        elif diff.days < 7:
            return f"{diff.days} days ago"
        else:
            return dt.strftime("%Y-%m-%d %H:%M")


class FileDiscoveryService:
    """Service for discovering and managing log files"""
    
    def __init__(self, config: dict):
        self.config = config
        self.cache = {}
        self.cache_timestamp = 0
        self.cache_ttl = config.get('log_viewer', {}).get('cache_ttl', 30)
        self.allowed_extensions = tuple(
            config.get('log_viewer', {}).get('allowed_extensions', ['.log', '.txt'])
        )
    
    def discover_files(self, force_refresh: bool = False) -> Dict[str, FileMetadata]:
        """
        Discover all log files from configured directories
        Returns a dictionary with unique IDs as keys
        """
        current_time = time.time()
        
        # Return cached results if still valid
        if not force_refresh and self.cache and (current_time - self.cache_timestamp) < self.cache_ttl:
            return self.cache
        
        files = {}
        log_dirs = self.config.get('log_dirs', [])
        
        for dir_config in log_dirs:
            dir_key = dir_config.get('key', 'unknown')
            dir_path = dir_config.get('path', '')
            dir_description = dir_config.get('description', dir_key)
            
            # Resolve relative paths
            if not os.path.isabs(dir_path):
                base_dir = os.path.dirname(os.path.abspath(__file__))
                dir_path = os.path.abspath(os.path.join(base_dir, dir_path))
            
            if not os.path.exists(dir_path):
                logger.warning(f"Directory not found: {dir_path} (key: {dir_key})")
                continue
            
            if not os.path.isdir(dir_path):
                logger.warning(f"Path is not a directory: {dir_path} (key: {dir_key})")
                continue
            
            try:
                # Scan directory for files
                for filename in os.listdir(dir_path):
                    file_path = os.path.join(dir_path, filename)
                    
                    # Only include files with allowed extensions
                    if not os.path.isfile(file_path):
                        continue
                    
                    if not filename.endswith(self.allowed_extensions):
                        continue
                    
                    # Create unique ID: dir_key/filename
                    file_id = f"{dir_key}/{filename}"
                    
                    # Handle duplicate filenames across directories
                    if file_id in files:
                        logger.warning(f"Duplicate file ID: {file_id}")
                        # Append a counter to make it unique
                        counter = 1
                        while f"{file_id}_{counter}" in files:
                            counter += 1
                        file_id = f"{file_id}_{counter}"
                    
                    # Create file metadata
                    metadata = FileMetadata(filename, file_path, dir_key, dir_description)
                    files[file_id] = metadata
                    
            except Exception as e:
                logger.error(f"Error scanning directory {dir_path}: {e}")
        
        # Update cache
        self.cache = files
        self.cache_timestamp = current_time
        
        logger.info(f"Discovered {len(files)} files across {len(log_dirs)} directories")
        return files
    
    def get_file_by_id(self, file_id: str) -> Optional[FileMetadata]:
        """Get file metadata by ID"""
        files = self.discover_files()
        return files.get(file_id)
    
    def get_files_by_directory(self) -> Dict[str, List[FileMetadata]]:
        """Get files grouped by directory key"""
        files = self.discover_files()
        grouped = {}
        
        for file_id, metadata in files.items():
            dir_key = metadata.dir_key
            if dir_key not in grouped:
                grouped[dir_key] = []
            grouped[dir_key].append(metadata)
        
        # Sort files within each directory
        for dir_key in grouped:
            grouped[dir_key].sort(key=lambda x: x.name.lower())
        
        return grouped
    
    def search_in_file(self, file_id: str, search_term: str, 
                       case_sensitive: bool = False, max_results: int = 1000) -> List[dict]:
        """
        Search for a term in a file
        Returns list of matching lines with line numbers
        """
        metadata = self.get_file_by_id(file_id)
        if not metadata or not metadata.exists:
            return []
        
        results = []
        search_config = self.config.get('log_viewer', {}).get('search', {})
        
        if not search_config.get('enabled', True):
            logger.warning("Search is disabled in configuration")
            return []
        
        max_results = min(max_results, search_config.get('max_results', 1000))
        
        if not case_sensitive:
            search_term = search_term.lower()
        
        try:
            with open(metadata.path, 'r', encoding='utf-8', errors='ignore') as f:
                for line_num, line in enumerate(f, start=1):
                    if len(results) >= max_results:
                        break
                    
                    line_to_search = line if case_sensitive else line.lower()
                    
                    if search_term in line_to_search:
                        results.append({
                            'line_number': line_num,
                            'content': line.rstrip('\n'),
                            'file': metadata.name,
                            'dir_key': metadata.dir_key
                        })
        except Exception as e:
            logger.error(f"Error searching file {metadata.path}: {e}")
        
        return results
    
    def read_file_lines(self, file_id: str, max_lines: Optional[int] = None, 
                       tail: bool = True) -> List[str]:
        """
        Read lines from a file
        
        Args:
            file_id: Unique file identifier
            max_lines: Maximum number of lines to return (None for all)
            tail: If True, return last N lines; if False, return first N lines
        """
        metadata = self.get_file_by_id(file_id)
        if not metadata or not metadata.exists:
            return []
        
        if max_lines is None:
            max_lines = self.config.get('server', {}).get('default_lines', 500)
        
        try:
            with open(metadata.path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                
                if tail:
                    # Return last N lines
                    return lines[-max_lines:] if len(lines) > max_lines else lines
                else:
                    # Return first N lines
                    return lines[:max_lines]
        except Exception as e:
            logger.error(f"Error reading file {metadata.path}: {e}")
            return []
