# backend/app/main.py
import io
import logging
from pathlib import Path

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from PIL import Image

from app.config import UPLOAD_DIR, MAX_FILE_SIZE, CORS_ORIGINS, MODEL_PATH, DEFAULT_CONFIDENCE, HOST, PORT, DEBUG
from app.model_utils import YOLOModel
from app.ocr_utils import OCRProcessor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("backend.main")

Path(UPLOAD_DIR).mkdir(parents=True, exist_ok=True)

app = FastAPI(title="Basarat YOLO+OCR API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if CORS_ORIGINS == "*" else [o.strip() for o in CORS_ORIGINS.split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize model + OCR
logger.info("Loading models...")
yolo = YOLOModel(model_path=MODEL_PATH, conf_threshold=DEFAULT_CONFIDENCE)
ocr = OCRProcessor()

# Optional: standalone OCR endpoint
@app.post("/ocr")
async def read_text(file: UploadFile = File(...)):
    """Run OCR only (no YOLO)"""
    content = await file.read()
    try:
        img = Image.open(io.BytesIO(content)).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file.")
    try:
        text = ocr.extract_text(img)
    except Exception as e:
        logger.exception("OCR failed: %s", e)
        raise HTTPException(status_code=500, detail="OCR failed.")
    return {"text": text}


@app.get("/", summary="Health check")
async def root():
    return {
        "message": "Basarat YOLO+OCR backend",
        "yolo_loaded": yolo.is_loaded(),
        "ocr_engine": ocr.engine,
    }


class PredictResponse(BaseModel):
    detections: list
    text: str


def _validate_file_size(file_bytes: bytes):
    if len(file_bytes) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail=f"File too large. Max allowed: {MAX_FILE_SIZE} bytes")


@app.post("/predict/", response_model=PredictResponse)
async def predict(image: UploadFile = File(...), conf: float = DEFAULT_CONFIDENCE):
    """Accept an image and return YOLO detections + OCR text"""
    contents = await image.read()
    _validate_file_size(contents)

    try:
        pil_img = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file.")

    try:
        conf_val = float(conf)
        if not (0 < conf_val < 1):
            conf_val = DEFAULT_CONFIDENCE
    except Exception:
        conf_val = DEFAULT_CONFIDENCE
    yolo.set_confidence(conf_val)

    detections = []
    if yolo.is_loaded():
        try:
            detections = yolo.predict(pil_img)
        except Exception as e:
            logger.exception("YOLO inference failed: %s", e)
            raise HTTPException(status_code=500, detail="YOLO inference failed.")

    text = ""
    try:
        text = ocr.extract_text(pil_img)
    except Exception as e:
        logger.exception("OCR failed: %s", e)

    return JSONResponse({"detections": detections, "text": text})


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host=HOST, port=PORT, reload=DEBUG)
