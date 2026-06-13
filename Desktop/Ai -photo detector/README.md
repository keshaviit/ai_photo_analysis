# 🧠 PhotoMind AI — Local AI Photo Organizer

> A fully local, privacy-first AI photo management platform. No cloud. No subscriptions. Just your photos, organized intelligently on your own machine.

![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?style=flat&logo=fastapi&logoColor=white)
![CLIP](https://img.shields.io/badge/OpenAI-CLIP-412991?style=flat&logo=openai&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=flat&logo=sqlite&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔍 **Semantic Search** | Search photos using natural language — *"a dog on the beach"*, *"sunset over mountains"* |
| 📄 **OCR Text Search** | Find photos containing text — receipts, screenshots, documents, whiteboards |
| 📁 **Smart Categories** | Zero-shot AI classification into Animals, Landscapes, Portraits, Documents, and more |
| 🔁 **Duplicate Finder** | Detect exact and near-duplicate photos using Perceptual Hashing (pHash) |
| 📤 **Single Upload** | Drag & drop any image directly into the browser |
| 🗂️ **Folder Scanner** | Paste a local folder path to bulk-import and process an entire directory |
| 🖼️ **Lightbox Viewer** | Click any photo for a full-resolution preview with metadata, OCR text, and download |
| 💻 **100% Local** | All AI runs on your machine — CLIP, EasyOCR, FAISS, SQLite — zero cloud dependency |

---

## 🖥️ Tech Stack

### Backend
- **[FastAPI](https://fastapi.tiangolo.com/)** — High-performance async Python web framework
- **[SQLite + SQLAlchemy](https://www.sqlalchemy.org/)** — Lightweight local database for photo metadata
- **[FAISS](https://github.com/facebookresearch/faiss)** — Facebook AI Similarity Search for vector indexing
- **[OpenAI CLIP](https://github.com/openai/CLIP)** — Vision-language model for semantic embeddings
- **[EasyOCR](https://github.com/JaidedAI/EasyOCR)** — Optical Character Recognition for text extraction
- **[ImageHash](https://github.com/JohannesBuchner/imagehash)** — Perceptual hashing for duplicate detection
- **[Uvicorn](https://www.uvicorn.org/)** — ASGI server for running FastAPI

### Frontend
- **Vanilla HTML + CSS + JavaScript** — Zero framework dependencies
- **Google Fonts (Outfit)** — Premium typography
- **Custom SVG Icons** — Inline scalable icons
- **CSS Variables + Animations** — Premium light theme with micro-interactions

---

## 🚀 Getting Started

### Prerequisites
- Python 3.10+
- pip or conda

### 1. Clone the repository
```bash
git clone https://github.com/keshaviit/ai_photo_analysis.git
cd ai_photo_analysis
```

### 2. Create a virtual environment
```bash
python -m venv venv
source venv/bin/activate       # macOS/Linux
venv\Scripts\activate          # Windows
```

### 3. Install dependencies
```bash
pip install -r requirements.txt
```

### 4. Run the server
```bash
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

> ⚠️ First startup takes **15–30 seconds** to pre-load CLIP and EasyOCR models.

### 5. Open the dashboard
```
http://127.0.0.1:8000
```

---

## 📂 Project Structure

```
ai_photo_analysis/
├── app/
│   ├── main.py                  # FastAPI app, startup, static file mounts
│   ├── config.py                # Environment config, paths, thresholds
│   ├── database.py              # SQLAlchemy engine and session
│   ├── models.py                # Photo ORM model
│   ├── schemas.py               # Pydantic request/response schemas
│   ├── routers/
│   │   ├── photos.py            # Upload & folder scan endpoints
│   │   ├── search.py            # Semantic, OCR, categories, duplicates
│   │   └── faces.py             # Face grouping endpoints
│   ├── services/
│   │   ├── clip.py              # CLIP model wrapper (text + image embeddings)
│   │   ├── ocr.py               # EasyOCR wrapper
│   │   ├── phash.py             # Perceptual hash computation & duplicate finder
│   │   ├── vector_search.py     # FAISS index management
│   │   ├── pipeline.py          # Full photo processing pipeline
│   │   ├── storage.py           # File save, directory scan utilities
│   │   └── face.py              # Face detection & clustering
│   └── static/
│       ├── index.html           # Main UI dashboard
│       ├── style.css            # Premium light theme CSS
│       └── app.js               # Frontend logic (tabs, search, upload, modal)
├── data/                        # ⚠️ Git-ignored — created at runtime
│   ├── uploads/                 # Stored image files
│   ├── database.db              # SQLite database
│   └── faiss_index.bin          # FAISS vector index
├── tests/
│   ├── conftest.py              # Test fixtures
│   └── test_api.py              # API endpoint tests
├── Dockerfile                   # Docker container definition
├── docker-compose.yml           # Docker Compose setup
├── requirements.txt             # Python dependencies
├── run_server.sh                # Quick start shell script
└── README.md
```

---

## 🔌 API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/photos/upload` | Upload a single image file |
| `POST` | `/api/photos/scan-folder` | Scan a local directory for images |
| `GET` | `/api/search?q=...&type=semantic\|ocr\|combined` | Search photos |
| `GET` | `/api/categories` | Get all photos grouped by AI category |
| `GET` | `/api/duplicates?threshold=10` | Find near-duplicate photo groups |
| `GET` | `/uploads/{filename}` | Serve uploaded image files |

### Search Types
- `semantic` — Uses CLIP embeddings + FAISS vector search
- `ocr` — SQL `LIKE` search over extracted OCR text
- `combined` — Merges both, ranked by similarity score

---

## 🐳 Docker

```bash
docker-compose up --build
```

This starts the app on `http://localhost:8000` with a persistent data volume.

---

## ⚙️ Configuration

All settings are configurable via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `sqlite:///data/database.db` | SQLAlchemy database URL |
| `UPLOAD_DIR` | `data/uploads` | Directory for uploaded images |
| `FAISS_INDEX_PATH` | `data/faiss_index.bin` | Path to FAISS index file |
| `CLIP_MODEL_NAME` | `openai/clip-vit-base-patch32` | HuggingFace CLIP model |
| `PHASH_THRESHOLD` | `10` | Hamming distance threshold for duplicate detection |

---

## 📸 How It Works

```
Image Upload / Folder Scan
         │
         ▼
   Save to disk (data/uploads/)
         │
         ▼
   Extract metadata (resolution, file size)
         │
    ┌────┴──────────────────────────────┐
    │                                   │
    ▼                                   ▼
EasyOCR                             CLIP Model
(Extract text)                  (Generate 512-dim embedding)
    │                                   │
    ▼                                   ▼
Store OCR text                  Store in FAISS index
in SQLite                       + Zero-shot category
    │                                   │
    └────────────┬──────────────────────┘
                 │
                 ▼
         pHash computed
         (Duplicate detection)
                 │
                 ▼
         Stored in SQLite DB
                 │
                 ▼
         Available in UI 🎉
```

---

## 🛠️ Running Tests

```bash
pytest tests/ -v
```

---

## 🤝 Contributing

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m "Add my feature"`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Keshav Goyal**
- GitHub: [@keshaviit](https://github.com/keshaviit)

---

> Built with ❤️ — 100% local AI, zero cloud, complete privacy.
