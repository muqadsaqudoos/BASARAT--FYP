# backend/app/main.py
import io
import logging
from pathlib import Path

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from PIL import Image

from app.config import UPLOAD_DIR, MAX_FILE_SIZE, CORS_ORIGINS, HOST, PORT, DEBUG
from app.ocr_utils import OCRProcessor

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

# --- Initialize OCR only ---
logger.info("Starting OCR engine (YOLO disabled)...")
ocr = OCRProcessor()

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
@app.get("/", summary="Health check")
async def root():
    return {
        "message": "Basarat OCR backend",
        "yolo_loaded": False,  # Always false (disabled)
        "ocr_engine": ocr.engine,
    }


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
