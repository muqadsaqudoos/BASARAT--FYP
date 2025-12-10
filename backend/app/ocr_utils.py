# backend/app/ocr_utils.py
import logging
from typing import Optional
from PIL import Image
import numpy as np

from app.config import OCR_ENGINE, OCR_LANGUAGE, OCR_MODEL_DIR

logger = logging.getLogger("ocr_utils")
logger.setLevel(logging.INFO)


class OCRProcessor:
    """Simple wrapper supporting 'easyocr' or 'tesseract' engines."""

    def __init__(self, engine: Optional[str] = None, lang: Optional[str] = None):
        self.engine = (engine or OCR_ENGINE).lower()
        self.lang = lang or OCR_LANGUAGE
        self._reader = None
        self._init_engine()

    def _init_engine(self):
        if self.engine == "easyocr":
            try:
                import easyocr
                logger.info("Initializing EasyOCR (lang=%s)", self.lang)
                self._reader = easyocr.Reader(
                    [lang.strip() for lang in self.lang.split(",")],
                    gpu=False,
                    model_storage_directory=OCR_MODEL_DIR
                )
            except Exception as e:
                logger.exception("EasyOCR init failed: %s", e)
                self._reader = None
        elif self.engine in ("pytesseract", "tesseract"):
            try:
                import pytesseract
                logger.info("Using pytesseract (lang=%s). Ensure tesseract binary is installed.", self.lang)
                self._reader = pytesseract
            except Exception as e:
                logger.exception("pytesseract import failed: %s", e)
                self._reader = None
        else:
            logger.warning("Unknown OCR engine '%s'", self.engine)
            self._reader = None

    def extract_text(self, image: Image.Image) -> str:
        """Run OCR and return extracted text"""
        if self._reader is None:
            return ""

        if self.engine == "easyocr":
            np_img = np.array(image.convert("RGB"))
            try:
                results = self._reader.readtext(np_img, detail=0)
                return "\n".join([r for r in results if r])
            except Exception as e:
                logger.exception("EasyOCR failed: %s", e)
                return ""
        else:  # pytesseract
            try:
                return self._reader.image_to_string(image, lang=self.lang)
            except Exception as e:
                logger.exception("pytesseract failed: %s", e)
                return ""
