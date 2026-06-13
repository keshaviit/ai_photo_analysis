import os
from pathlib import Path

# Base workspace path
BASE_DIR = Path(__file__).resolve().parent.parent

# Database configuration
DATABASE_URL = os.environ.get("DATABASE_URL", f"sqlite:///{BASE_DIR}/data/database.db")

# Storage paths
UPLOAD_DIR = Path(os.environ.get("UPLOAD_DIR", BASE_DIR / "data" / "uploads"))
FAISS_INDEX_PATH = Path(os.environ.get("FAISS_INDEX_PATH", BASE_DIR / "data" / "faiss_index.bin"))

# Ensure directories exist
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
FAISS_INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)

# AI Model settings
CLIP_MODEL_NAME = os.environ.get("CLIP_MODEL_NAME", "openai/clip-vit-base-patch32")

# Matching thresholds
PHASH_THRESHOLD = int(os.environ.get("PHASH_THRESHOLD", 10))  # Hamming distance <= 10 means duplicate
FACE_DISTANCE_THRESHOLD = float(os.environ.get("FACE_DISTANCE_THRESHOLD", 0.6))  # Face match tolerance
