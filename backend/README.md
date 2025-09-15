
1. **Clone the repository** (if not already done)
2. **Navigate to the backend directory**:
   ```bash
   cd backend
   ```

3. **Create a virtual environment**:
   ```bash
   python -m venv venv

     
   venv\Scripts\activate       # On mac: source venv/bin/activate
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

