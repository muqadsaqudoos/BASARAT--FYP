# Full Audit & Verification — Capture → Compress → FastAPI → Words Only

This document verifies the object-detection implementation (Flutter capture/upload + FastAPI YOLOv8 + words-only results) against the stated requirements.

---

## A) Audit Checklist Report

Each requirement is marked ✅ (met) or ❌ (missing/wrong) with file references and line numbers.

### No live detection

| Requirement | Status | Reference |
|-------------|--------|-----------|
| App must NOT use `startImageStream` for detection | ✅ | [object_detection_screen.dart](frontend/lib/screens/object_detection_screen.dart) uses only `takePicture()` (line 127). No `startImageStream` in this screen. |
| Detection must happen only after `takePicture()` | ✅ | Flow: tap button → `_captureAndDetect()` → `takePicture()` → compress → upload → `postDetect()` (lines 119–147). |

### Local compress + resize before upload

| Requirement | Status | Reference |
|-------------|--------|-----------|
| Max dimension 960 or 1280 | ✅ | `kMaxImageDimension = 1280` in [object_detection_screen.dart](frontend/lib/screens/object_detection_screen.dart) (line 14). |
| JPEG quality 75–80 | ✅ | `kJpegQuality = 77` (line 16). |
| Store temp file locally only (ok) | ✅ | Temp file written to `Directory.systemTemp` (lines 110–111). |
| Upload the compressed file (not original) | ✅ | `_compressAndSave(xFile.path)` returns resized/compressed file; that file is passed to `postDetect(tempFile)` (lines 127–130). |

### FastAPI backend uses yolov8n.pt

| Requirement | Status | Reference |
|-------------|--------|-----------|
| Model file at `backend/models/yolov8n.pt` | ✅ | [config.py](backend/app/config.py) line 17: `YOLO_DETECT_MODEL = ... / "models" / "yolov8n.pt"`. |
| Model loaded once at startup | ✅ | [main.py](backend/app/main.py): `load_yolo_once()` called at startup (line 70); `get_yolo()` returns cached `yolo_model`. |
| Backend runs inference and returns JSON | ✅ | `POST /detect` runs `model.predict(...)` and returns `DetectResponse` (Pydantic → JSON) (lines 116–166). |
| Backend must NOT store images | ✅ | Image read with `await file.read()` and `Image.open(io.BytesIO(contents))`; no `open(..., 'wb')` or save to disk. |
| Process upload in memory only | ✅ | `contents = await file.read()`, then `io.BytesIO(contents)` and `np.array(pil_img)`; no temp file. |
| No temp file for decoding (or delete immediately) | ✅ | No file write for `/detect`; all in-memory. |

### Result screen — words only

| Requirement | Status | Reference |
|-------------|--------|-----------|
| Do NOT show captured image | ✅ | [detection_result_screen.dart](frontend/lib/screens/detection_result_screen.dart): no `Image` widget; only text and chips. |
| Do NOT show bounding boxes | ✅ | UI shows only summary text and chips with label + confidence; no box coordinates. |
| Summary line e.g. "TV, Remote, Laptop" | ✅ | `summaryText = detections.map((d) => d.label).join(', ')` (lines 47–48, 76). |
| List/chips with confidence | ✅ | `Chip(label: Text('${d.label} (${(d.score * 100).toStringAsFixed(0)}%)'))` (lines 91–96). |
| Remove duplicates (keep max score per label) | ✅ | `postProcessDetections()` in [detection_result_screen.dart](frontend/lib/screens/detection_result_screen.dart) (lines 138–153): `byLabel` map keeps highest score per label. |
| Sort by confidence | ✅ | `..sort((a, b) => b.score.compareTo(a.score))` (line 151). |
| Threshold >= 0.30 | ✅ | `kMinConfidence = 0.30` (line 9); used in `postProcessDetections` (line 145). |
| Show top 5 only | ✅ | `kMaxTopLabels = 5` and `list.take(topK).toList()` (lines 10, 152). |

### Networking reliability

| Requirement | Status | Reference |
|-------------|--------|-----------|
| Dio timeout 30s | ✅ | [detection_api.dart](frontend/lib/api/detection_api.dart) lines 17–20: `connectTimeout`, `receiveTimeout`, `sendTimeout` all 30 seconds. |
| Proper errors + Retry / Back UI | ✅ | [object_detection_screen.dart](frontend/lib/screens/object_detection_screen.dart) lines 169–214: on error set `_detectionError`; full-screen message "Detection failed. Check internet or server." with Retry and Back buttons. |
| Base URL: emulator `http://10.0.2.2:8000` | ✅ | [detection_api.dart](frontend/lib/api/detection_api.dart) line 10: `kDetectionBaseUrlDefault = 'http://10.0.2.2:8000'`. |
| Base URL: physical device `http://<LAN_IP>:8000` | ✅ | Line 13: `detectionBaseUrl` is configurable; override for device (e.g. in `main.dart` or a config file). |
| Backend started with host 0.0.0.0 | ✅ | [config.py](backend/app/config.py) line 11: `HOST = "0.0.0.0"`; used when running uvicorn. |

### Android internet permission

| Requirement | Status | Reference |
|-------------|--------|-----------|
| `INTERNET` permission | ✅ | [AndroidManifest.xml](frontend/android/app/src/main/AndroidManifest.xml) line 2: `<uses-permission android:name="android.permission.INTERNET" />`. |

---

## B) Lightweight Sanity Checks (Added)

- **GET /health**  
  - Endpoint: `GET /health`  
  - Response: `{ "status": "ok" }`  
  - File: [backend/app/main.py](backend/app/main.py).

- **Startup log**  
  - On successful YOLO load: `logger.info("YOLO model loaded from %s", path)` and `print("YOLO model loaded")` so it is visible in the console when running uvicorn.  
  - File: [backend/app/main.py](backend/app/main.py).

- **Response validation**  
  - Backend builds each detection with `DetectionItem(label=name, score=round(conf, 4), box=[...])`; Pydantic enforces `label: str` and `score: float`.  
  - `name` is explicitly `str(...)` so detections always have `label` and `score`.  
  - File: [backend/app/main.py](backend/app/main.py).

---

## C) Developer-Friendly Testing Steps

### Backend (FastAPI)

1. **Install and run**
   ```bash
   cd backend
   pip install -r requirements.txt
   uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
   Ensure `backend/models/yolov8n.pt` exists (download from Ultralytics if needed).

2. **Health check**
   ```bash
   curl -s http://localhost:8000/health
   ```
   Expected: `{"status":"ok"}`

3. **Root info (optional)**
   ```bash
   curl -s http://localhost:8000/
   ```
   Expected: JSON with `message`, `yolo_loaded`, `ocr_engine`.

4. **Detection with an image**
   ```bash
   curl -X POST http://localhost:8000/detect \
     -F "file=@/path/to/your/image.jpg" \
     -H "Accept: application/json"
   ```
   Expected: JSON with `detections` (array of `label`, `score`, `box`), and optional `imageWidth` / `imageHeight`.

### Flutter

1. **Emulator**
   - Use default base URL: `http://10.0.2.2:8000` in [detection_api.dart](frontend/lib/api/detection_api.dart) (no change needed).
   - Run app, open Object Detection → Capture & Detect. Ensure device/emulator can reach host machine (backend on same machine as emulator).

2. **Physical device**
   - Set backend base URL to your machine’s LAN IP, e.g. `http://192.168.1.100:8000`.
   - Change in code: in [detection_api.dart](frontend/lib/api/detection_api.dart), set `detectionBaseUrl` before any detection call (e.g. in `main.dart` after `runApp` or in a config that runs early):
     ```dart
     import 'api/detection_api.dart';
     // e.g. in main():
     detectionBaseUrl = 'http://192.168.1.100:8000';  // your LAN IP
     ```
   - Or read from env/constants (e.g. flavor or build config).
   - Run backend with `--host 0.0.0.0` so it listens on the LAN.

3. **Where to change base URL**
   - File: [frontend/lib/api/detection_api.dart](frontend/lib/api/detection_api.dart).
   - Variable: `detectionBaseUrl` (default `kDetectionBaseUrlDefault` = `http://10.0.2.2:8000`). Override this once at app startup for physical device testing.

---

## D) Code Quality Checks

| Check | Status | Notes |
|-------|--------|-------|
| Unused imports | ✅ | [object_detection_screen.dart](frontend/lib/screens/object_detection_screen.dart) does not import `../models/detection.dart` (only uses API and detection_result_screen). |
| Dead code | ✅ | No redundant null check on `encodeJpg`; no dead branches in the capture flow. |
| Silent try/catch hiding failures | ✅ | `_captureAndDetect` catch sets `_detectionError` and shows Retry/Back. `finally` only catches temp-file delete errors so the app does not crash on cleanup failure. |
| Temp file cleanup | ✅ | [object_detection_screen.dart](frontend/lib/screens/object_detection_screen.dart) lines 154–157: in `finally`, `if (tempFile != null && await tempFile.exists()) await tempFile.delete()`. |
| Confidence threshold consistency | ✅ | Backend: [config.py](backend/app/config.py) `DETECT_CONFIDENCE = 0.30`; frontend: [detection_result_screen.dart](frontend/lib/screens/detection_result_screen.dart) `kMinConfidence = 0.30`. Both 0.30. |

---

## Fixes Applied During Audit

1. **Backend**
   - Added **GET /health** returning `{"status": "ok"}` for health checks.
   - Added **print("YOLO model loaded")** on successful YOLO load (in addition to `logger.info`) for console visibility.
   - Documented in code that detections are built with required `label` and `score` and ensured `name` is `str(...)`.

2. **Flutter / docs**
   - No code fixes required for the audit; temp file cleanup, error UI, and thresholds were already correct.
   - This document adds the audit report and testing steps.

---

## Summary

- All stated requirements are met (audit checklist above).
- Backend does not store images; model is loaded once; response includes only in-memory processing.
- Flutter flow: single capture → compress → upload → words-only result screen with dedupe, sort, top 5, and 0.30 threshold.
- Health endpoint, startup log, and response contract are in place; testing steps and base-URL instructions are documented above.
