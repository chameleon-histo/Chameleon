# Batch Stain Normalizer – Python  v2.1
### Four-mode histogram & Reinhard normalisation for H&E / IHC brightfield images

---

## Files

| File | Purpose |
|------|---------|
| `normalizer_core.py` | All normalisation algorithms — no GUI dependency, importable standalone |
| `normalizer_app.py` | PyQt6 GUI application |
| `run_normalizer.py` | Launcher / PyInstaller entry point |
| `requirements.txt` | Python dependencies |

---

## Installation

```bash
pip install -r requirements.txt
```

### requirements.txt
```
PyQt6>=6.4
matplotlib>=3.7
numpy>=1.24
scikit-image>=0.21
```

---

## Running

```bash
python run_normalizer.py
```

---

## Packaging as a Standalone Executable

Requires PyInstaller:

```bash
pip install pyinstaller
```

### Windows (.exe)
```bash
pyinstaller --onefile --windowed --name "BatchStainNormalizer" run_normalizer.py
```

### macOS (.app)
```bash
pyinstaller --onefile --windowed --name "BatchStainNormalizer" \
    --osx-bundle-identifier com.yourname.batchstainnormalizer \
    run_normalizer.py
```

The packaged executable appears in the `dist/` folder. It includes everything needed to run on a machine without Python installed.

---

## Modes

| Mode | Method | Reference |
|------|--------|-----------|
| 1 | Histogram matching | User-chosen reference image |
| 2 | Histogram matching | Batch-average CDF |
| 3 | Reinhard color transfer | User-chosen reference image |
| 4 | Reinhard color transfer | Batch-average synthetic reference |

---

## Supported Formats

**Input:** `.tif`, `.tiff`, `.jpg`, `.jpeg`, `.bmp` (case-insensitive)  
**Output:** `.tif`, `.jpg` (100% quality), `.bmp`

---

## Notes

- The `normalizer_core.py` module can be imported independently for scripted/headless use.
- Processing runs in a background thread so the UI stays responsive during long batches.
- The Pre-flight Inspector computes batch statistics on the main thread with `processEvents()` calls — for very large batches (>200 images) the inspector may take a few seconds to populate.
