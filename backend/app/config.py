import os
from pathlib import Path

# Basic Configuration
APP_NAME = "BASARAT"
APP_VERSION = "1.0.0"
DEBUG = True

# Server Configuration
HOST = "0.0.0.0"
PORT = 8000

# Model Configuration
MODEL_PATH = "models/yolo_model.pt"
DEFAULT_CONFIDENCE = 0.5

# OCR Configuration
OCR_ENGINE = "easyocr" 
OCR_LANGUAGE = "en"

# File Upload Configuration
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
UPLOAD_DIR = "uploads"

# CORS Configuration
CORS_ORIGINS = ["*"]

# Logging Configuration
LOG_LEVEL = "INFO"
