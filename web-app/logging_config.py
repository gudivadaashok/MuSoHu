"""
Logging configuration module for MuSoHu web application
Handles YAML-based logging configuration with file rotation and console output
"""
import logging
import os
from logging.handlers import RotatingFileHandler
import yaml


def load_config():
    """Load configuration from YAML file"""
    config_path = 'config.yml'
    default_config = {
        'logging': {
            'app_log': {
                'enabled': True,
                'path': 'logs/musohu.log',
                'level': 'INFO',
                'max_size': 10485760,
                'backup_count': 5,
                'format': '[%(asctime)s] %(levelname)s: %(message)s',
                'date_format': '%Y-%m-%d %H:%M:%S'
            },
            'console': {
                'enabled': True,
                'level': 'INFO',
                'format': '[%(asctime)s] %(levelname)s: %(message)s',
                'date_format': '%Y-%m-%d %H:%M:%S'
            }
        }
    }

    if os.path.exists(config_path):
        try:
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
                return config if config else default_config
        except Exception as e:
            print(f"Error loading config.yml: {e}. Using defaults.")
            return default_config
    else:
        print(f"Config file not found at {config_path}. Using defaults.")
        return default_config


def setup_logging(app):
    """Configure logging for the Flask application based on YAML config"""
    config = load_config()
    log_config = config.get('logging', {})
    app_log_config = log_config.get('app_log', {})
    console_config = log_config.get('console', {})

    # Create logs directory if it doesn't exist
    log_path = app_log_config.get('path', 'logs/musohu.log')
    log_dir = os.path.dirname(log_path)
    if log_dir and not os.path.exists(log_dir):
        os.makedirs(log_dir, exist_ok=True)

    # Get log level
    log_level_str = app_log_config.get('level', 'INFO')
    log_level = getattr(logging, log_level_str.upper(), logging.INFO)

    # Create formatter
    log_format = app_log_config.get('format', '[%(asctime)s] %(levelname)s: %(message)s')
    date_format = app_log_config.get('date_format', '%Y-%m-%d %H:%M:%S')
    formatter = logging.Formatter(log_format, datefmt=date_format)

    # Get logger and set level
    logger = logging.getLogger()
    logger.setLevel(log_level)

    # Remove any existing handlers
    logger.handlers = []

    # Setup file handler with rotation if enabled
    if app_log_config.get('enabled', True):
        file_handler = RotatingFileHandler(
            log_path,
            maxBytes=app_log_config.get('max_size', 10485760),
            backupCount=app_log_config.get('backup_count', 5)
        )
        file_handler.setFormatter(formatter)
        file_handler.setLevel(log_level)
        logger.addHandler(file_handler)

    # Setup console handler if enabled
    if console_config.get('enabled', True):
        console_level_str = console_config.get('level', 'INFO')
        console_level = getattr(logging, console_level_str.upper(), logging.INFO)
        console_format = console_config.get('format', '[%(asctime)s] %(levelname)s: %(message)s')
        console_date_format = console_config.get('date_format', '%Y-%m-%d %H:%M:%S')

        console_handler = logging.StreamHandler()
        console_formatter = logging.Formatter(console_format, datefmt=console_date_format)
        console_handler.setFormatter(console_formatter)
        console_handler.setLevel(console_level)
        logger.addHandler(console_handler)

    # Set Flask logger to use our handlers
    app.logger.handlers = logger.handlers
    app.logger.setLevel(log_level)

    logger.info(f"Logging initialized: {log_path}")

    return logger
