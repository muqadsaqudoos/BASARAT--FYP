# backend/app/main.py
import io
import logging
from pathlib import Path

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from PIL import Image

from app.config import (
    UPLOAD_DIR,
    MAX_FILE_SIZE,
    CORS_ORIGINS,
    HOST,
    PORT,
    DEBUG,
    YOLO_DETECT_MODEL,
    DETECT_CONFIDENCE,
)
from app.ocr_utils import OCRProcessor

# --- YOLO detector (loaded once at startup, no image storage) ---
yolo_model = None


def get_yolo():
    global yolo_model
    if yolo_model is None:
        return None
    return yolo_model


def load_yolo_once():
    global yolo_model
    if yolo_model is not None:
        return
    path = Path(YOLO_DETECT_MODEL)
    if not path.exists():
        logger.warning("YOLO model not found at %s; POST /detect will return 503.", path)
        return
    try:
        from ultralytics import YOLO
        yolo_model = YOLO(str(path))
        logger.info("YOLO model loaded from %s", path)
        print("YOLO model loaded")  # visible in console when running uvicorn
    except Exception as e:
        logger.exception("Failed to load YOLO: %s", e)

# --- Logging setup ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("backend.main")

# Ensure upload directory exists
Path(UPLOAD_DIR).mkdir(parents=True, exist_ok=True)

# --- FastAPI app ---
app = FastAPI(title="Basarat OCR API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if CORS_ORIGINS == "*" else [o.strip() for o in CORS_ORIGINS.split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Initialize OCR and optional YOLO ---
logger.info("Starting OCR engine...")
ocr = OCRProcessor()
load_yolo_once()

# --- OCR endpoint ---
@app.post("/ocr")
async def read_text(file: UploadFile = File(...)):
    """Run OCR and return extracted text"""
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


# --- Health check ---
@app.get("/", summary="Root / info")
async def root():
    return {
        "message": "Basarat backend",
        "yolo_loaded": get_yolo() is not None,
        "ocr_engine": ocr.engine,
    }


@app.get("/health", summary="Health check")
async def health():
    """Lightweight health check for load balancers and clients. Returns 200 when service is up."""
    return {"status": "ok"}


# --- Object detection: in-memory only, no image storage ---
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/jpg", "image/png"}
MAX_DETECT_FILE_SIZE = 10 * 1024 * 1024  # 10MB


class DetectionItem(BaseModel):
    label: str
    score: float
    box: list[float]  # [x1, y1, x2, y2]


class DetectResponse(BaseModel):
    detections: list[DetectionItem]
    imageWidth: int | None = None
    imageHeight: int | None = None


@app.post("/detect", response_model=DetectResponse)
async def detect(file: UploadFile = File(...)):
    """
    Run YOLO object detection on uploaded image. Image is processed in memory only;
    nothing is stored on disk.
    """
    model = get_yolo()
    if model is None:
        raise HTTPException(status_code=503, detail="Detection model not available.")

    content_type = (file.content_type or "").lower()
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail="Only image types (jpg, png) are allowed.")

    contents = await file.read()
    if len(contents) > MAX_DETECT_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large.")

    try:
        pil_img = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file.")

    width, height = pil_img.size
    # Run inference (in memory; no disk write)
    import numpy as np
    img_np = np.array(pil_img)
    results = model.predict(
        img_np,
        conf=DETECT_CONFIDENCE,
        verbose=False,
    )

    # Build detections: each item has label and score (required by API contract)
    detections = []
    for r in results:
        if r.boxes is None:
            continue
        for box in r.boxes:
            conf = float(box.conf[0])
            cls_id = int(box.cls[0])
            name = str(r.names.get(cls_id, f"class_{cls_id}"))
            xyxy = box.xyxy[0].tolist()
            detections.append(
                DetectionItem(label=name, score=round(conf, 4), box=[round(x, 2) for x in xyxy])
            )

    return DetectResponse(
        detections=detections,
        imageWidth=width,
        imageHeight=height,
    )


# --- OCR-only predict endpoint ---
class PredictResponse(BaseModel):
    detections: list
    text: str


def _validate_file_size(file_bytes: bytes):
    if len(file_bytes) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail=f"File too large. Max allowed: {MAX_FILE_SIZE} bytes")


@app.post("/predict/", response_model=PredictResponse)
async def predict(image: UploadFile = File(...)):
    """Accept an image and return OCR text (YOLO disabled)"""
    contents = await image.read()
    _validate_file_size(contents)

    try:
        pil_img = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file.")

    detections = []  # YOLO is disabled
    text = ""
    try:
        text = ocr.extract_text(pil_img)
    except Exception as e:
        logger.exception("OCR failed: %s", e)

    return JSONResponse({"detections": detections, "text": text})


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=HOST, port=PORT, reload=DEBUG)
