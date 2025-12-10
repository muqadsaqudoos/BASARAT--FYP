# BASARAT - FYP (Blind Vision Frontend)

This is the **frontend** of our Final Year Project *Blind Vision*, built with **Flutter**.
The app is designed to assist visually impaired users with features such as **Text Reading** (camera → OCR → speech).

---

## Setup Instructions

To get started with this project, please follow the setup steps in [SETUP.md](SETUP.md).

---

## Getting Started with Flutter

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



# BASARAT - FYP (Blind Vision Backend)



1. **Clone the repository** (if not already done)
2. **Navigate to the backend directory**:
   ```bash
   cd backend
   ```

3. **Create a virtual environment**:
   ```bash
   python -m venv venv

     
   venv\Scripts\activate       # On mac: source venv/bin/activate
 if any restriction then Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
and then try 
venv\Scripts\activate 
   ```

4. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

5. **Install OCR dependencies** (choose one or more):
   

6.. **Place your YOLO model**:
   - Copy your YOLO model file to `models/yolo_model.pt`
   - Or update the `MODEL_PATH` in your `.env` file

## Usage

### Running the API

**Development mode**:
```bash
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Production mode**:
```bash
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```


### Adding New Features

1. **New endpoints**: Add to `main.py`
2. **Model improvements**: Modify `model_utils.py`
3. **OCR enhancements**: Update `ocr_utils.py`
4. **Configuration**: Add to `config.py`

