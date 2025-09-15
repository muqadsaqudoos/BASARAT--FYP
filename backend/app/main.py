from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
from typing import List, Optional
import os
from pathlib import Path

from model_utils import YOLOModel
from ocr_utils import OCRProcessor

# Initialize FastAPI app
app = FastAPI(
    title="Basarat",
    description="API for YOLO object detection and OCR text extraction",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize model instances
yolo_model = None
ocr_processor = None

@app.get("/")
async def root():
    """Health check endpoint"""
    return {"message": "Basarat YOLO OCR API is running", "status": "healthy"}


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
