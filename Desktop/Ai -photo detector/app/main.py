import os
from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from app.config import UPLOAD_DIR, FAISS_INDEX_PATH
from app.database import engine, Base, SessionLocal
from app.routers import photos, search, faces
from app.services.vector_search import vector_search_service
import logging

# Set up logging configuration
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)

# Ensure uploads directory exists at import time
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# Create FastAPI application
app = FastAPI(
    title="PhotoMind AI",
    description="Local AI-powered photo management platform API with semantic search, OCR, duplicates and face grouping.",
    version="1.0.0"
)

# Set up CORS middleware to allow cross-origin requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create database tables
Base.metadata.create_all(bind=engine)

# Register Routers BEFORE mounting static files so API routes take precedence
app.include_router(photos.router)
app.include_router(search.router)
app.include_router(faces.router)

# Mount static file directories at module level (not in startup event)
# This ensures routes are registered in correct order
app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")
app.mount("/data/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="data_uploads")
app.mount("/static", StaticFiles(directory="app/static"), name="static")

@app.get("/")
def read_root():
    """Serve the main UI dashboard."""
    index_path = Path("app/static/index.html")
    if index_path.exists():
        return FileResponse(str(index_path))
    return {"status": "online", "service": "PhotoMind AI", "version": "1.0.0"}

@app.on_event("startup")
def on_startup():
    logger.info("Initializing PhotoMind AI services...")
    
    # Pre-load AI models on main thread to prevent sub-thread PyTorch initialization crashes on macOS
    logger.info("Pre-loading CLIP model and EasyOCR reader on main thread...")
    try:
        from app.services.clip import clip_service
        from app.services.ocr import ocr_service
        clip_service._load_model()
        ocr_service._load_reader()
        logger.info("AI models pre-loaded successfully.")
    except Exception as e:
        logger.error(f"Failed to pre-load AI models: {e}")
        
    # Reload or rebuild FAISS index from SQLite records
    db = SessionLocal()
    try:
        if not FAISS_INDEX_PATH.exists() or vector_search_service.index.ntotal == 0:
            logger.info("FAISS index not found or empty. Rebuilding index from database photos...")
            vector_search_service.rebuild_index(db)
        else:
            logger.info(f"FAISS index loaded successfully with {vector_search_service.index.ntotal} vectors.")
    except Exception as e:
        logger.error(f"Error initializing FAISS index: {e}")
    finally:
        db.close()
    
    logger.info("PhotoMind AI is ready! Visit http://127.0.0.1:8000 to open the dashboard.")
