# backend/config.py
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
BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = os.environ.get("MODEL_PATH", str(BASE_DIR.parent / "models" / "yolo_model.pt"))
DEFAULT_CONFIDENCE = float(os.environ.get("DEFAULT_CONFIDENCE", 0.35))

# OCR Configuration
OCR_ENGINE = os.environ.get("OCR_ENGINE", "easyocr")  # "easyocr" or "tesseract"
OCR_LANGUAGE = os.environ.get("OCR_LANGUAGE", "en")

# File Upload Configuration
MAX_FILE_SIZE = int(os.environ.get("MAX_FILE_SIZE", 10 * 1024 * 1024))  # 10MB
UPLOAD_DIR = os.environ.get("UPLOAD_DIR", str(BASE_DIR.parent / "uploads"))

# CORS Configuration
CORS_ORIGINS = os.environ.get("CORS_ORIGINS", "*")  # set to comma-separated list in production

# Logging
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

