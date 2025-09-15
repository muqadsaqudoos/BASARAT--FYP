import cv2
import numpy as np
from typing import List, Dict, Any, Optional, Tuple
import asyncio
from pathlib import Path
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class YOLOModel:
    """
    YOLO model wrapper class for object detection
    """
    
    def __init__(self, model_path: str):
        """
        Initialize YOLO model
        
        Args:
            model_path: Path to the YOLO model file (.pt)
        """
        self.model_path = model_path
        self.model = None
        self.class_names = []
        self.is_loaded = False
        
        # Load model
        self._load_model()
    
 


 