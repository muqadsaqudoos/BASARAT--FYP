# BASARAT - FYP (Blind Vision Frontend)

This is the **frontend** of our Final Year Project *Blind Vision*, built with **Flutter**.  
The app is designed to assist visually impaired users with features such as **Text Reading** (camera → OCR → speech).  

---

## 📦 Prerequisites
- Flutter SDK (>=3.9.2 as defined in `pubspec.yaml`)
- Dart SDK (comes bundled with Flutter)
- Android Studio (with Android SDK) or VS Code
- Git
- A physical Android device or emulator (for camera features)

---

## ⚡ Setup Steps
1. **Clone the repository**

   git clone <repo-url>
   cd BASARAT-FYP/frontend

2. **Install dependencies**
    flutter pub get


3. **Run the app (choose your platform)**

    ## On Web (UI testing only):
        flutter run -d chrome

    ## On Android device:
        flutter run -d <device_id>

4. **Object detection model (YOLOv8n TFLite)**  
   The app uses a YOLOv8n model for object detection. You must export it and place it in the project:
   - Create `frontend/assets/models/` if it does not exist.
   - From a Python environment:
     ```bash
     pip install ultralytics
     yolo export model=yolov8n.pt format=tflite
     ```
   - Copy the generated `yolov8n_saved_model/yolov8n_float32.tflite` (or the default TFLite output) to `frontend/assets/models/yolov8n.tflite`.  
   - If you see a different output name (e.g. `yolov8n_float32.tflite`), rename it to `yolov8n.tflite`.

5. **📝 Additional Notes**
   - If you add new packages, run `flutter pub get` again.
   - For Android/iOS builds, ensure you have the respective SDKs and emulators installed.
   - The Text Reading and Object Detection features require a physical device for camera access (not supported on Chrome).
   - If you face issues, check the official Flutter documentation: https://docs.flutter.dev/get-started/install
