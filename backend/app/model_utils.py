# backend/app/model_utils.py
import logging
from pathlib import Path
from typing import List, Dict, Any, Optional

import numpy as np
from PIL import Image
from ultralytics import YOLO

from app.config import MODEL_PATH, DEFAULT_CONFIDENCE

logger = logging.getLogger("model_utils")
logger.setLevel(logging.INFO)


class YOLOModel:
    """Wrapper around ultralytics.YOLO for simple loading + inference"""

    def __init__(self, model_path: Optional[str] = None, conf_threshold: float = DEFAULT_CONFIDENCE):
        self.model_path = model_path or MODEL_PATH
        self.conf_threshold = conf_threshold
        self.model = None
        self.names = {}
        self._load_model()

    def _load_model(self):
        model_file = Path(self.model_path)
        if not model_file.exists():
            logger.warning("YOLO model file not found at %s. Model will not be available.", self.model_path)
            self.model = None
            return

        try:
            logger.info("Loading YOLO model from %s ...", self.model_path)
            self.model = YOLO(str(self.model_path))
            self.names = getattr(self.model, "names", {}) or {}
            logger.info("Model loaded. %d classes available.", len(self.names))
        except Exception as e:
            logger.exception("Failed to load YOLO model: %s", e)
            self.model = None

    def predict(self, image: Image.Image) -> List[Dict[str, Any]]:
        """Run inference and return list of detections"""
        if self.model is None:
            raise RuntimeError("YOLO model is not loaded.")

        img_np = np.array(image)
        results = self.model.predict(source=img_np, conf=self.conf_threshold, verbose=False, device="cpu")

        detections = []
        if not results:
            return detections

        r = results[0]
        boxes = r.boxes.xyxy.cpu().numpy()
        scores = r.boxes.conf.cpu().numpy()
        clsids = r.boxes.cls.cpu().numpy()

        for i in range(len(boxes)):
            x1, y1, x2, y2 = [float(x) for x in boxes[i]]
            conf = float(scores[i])
            cid = int(clsids[i])
            label = str(self.names.get(cid, str(cid)))
            detections.append({
                "box": [x1, y1, x2, y2],
                "confidence": conf,
                "class_id": cid,
                "label": label
            })

        return detections

    def set_confidence(self, conf: float):
        self.conf_threshold = conf

    def is_loaded(self) -> bool:
        return self.model is not None
