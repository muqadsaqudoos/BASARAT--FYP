# Object detection models

- **efficientdet_lite0.tflite** – Bundled. Used when YOLOv8 is missing or returns no detections (so you always get results for laptop, chair, etc.).
- **yolov8n.tflite** – Optional. When present and working, the app uses it first for better accuracy.

## If you see "No object detected" with YOLOv8

The app will automatically use **EfficientDet** when YOLOv8 is not available or returns nothing. Ensure **efficientdet_lite0.tflite** is in this folder (it is bundled by default).

## Optional: add YOLOv8n for better accuracy

1. `pip install ultralytics`
2. `yolo export model=yolov8n.pt format=tflite`
3. Copy the `.tflite` file here and name it **yolov8n.tflite**
4. Add to `pubspec.yaml` under `flutter.assets`: `- assets/models/yolov8n.tflite`
5. `flutter pub get` and rebuild

If YOLOv8 returns no detections (e.g. different export format), the app falls back to EfficientDet so you still get detections.
