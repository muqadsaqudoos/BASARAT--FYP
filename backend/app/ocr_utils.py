import cv2
import numpy as np
from typing import List, Dict, Any, Optional, Tuple
import asyncio
import logging
from PIL import Image
import io

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class OCRProcessor:
    """
    OCR processor class for text extraction from images
    """
    
    def __init__(self, engine: str = "tesseract"):
        """
        Initialize OCR processor
        
        Args:
            engine: OCR engine to use ('tesseract', 'easyocr', 'paddleocr')
        """
        self.engine = engine
        self.processor = None
        self.is_loaded = False
        
        # Load OCR engine
        self._load_engine()
    
