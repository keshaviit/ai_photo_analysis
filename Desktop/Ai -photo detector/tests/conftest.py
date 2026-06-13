import sys
from pathlib import Path
from unittest.mock import MagicMock

# Mock out heavy libraries at the module level so pytest can load and run all files
# without requiring dlib, torch, transformers, faiss or easyocr compilation.
dummy_modules = [
    'torch', 
    'transformers', 
    'easyocr', 
    'face_recognition', 
    'faiss'
]
for mod_name in dummy_modules:
    if mod_name not in sys.modules:
        sys.modules[mod_name] = MagicMock()

import pytest
import numpy as np
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient
from unittest.mock import patch

from app.database import Base, get_db
from app.main import app

# In-memory SQLite for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="function")
def db():
    # Create tables
    Base.metadata.create_all(bind=engine)
    db_session = TestingSessionLocal()
    try:
        yield db_session
    finally:
        db_session.close()
        # Drop tables
        Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def client(db):
    def override_get_db():
        try:
            yield db
        finally:
            pass
            
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()

# Auto-apply mocks to avoid downloading model files during unit tests
@pytest.fixture(autouse=True)
def mock_ai_services():
    # Mock CLIP Service methods
    mock_clip = MagicMock()
    mock_clip.get_image_embedding.return_value = np.random.rand(512).astype(np.float32)
    mock_clip.get_text_embedding.return_value = np.random.rand(512).astype(np.float32)
    mock_clip.classify_image.return_value = "Landscape/Nature"
    
    # Mock OCR Service methods
    mock_ocr = MagicMock()
    mock_ocr.extract_text.return_value = "Mocked OCR Invoice text"
    
    # Mock face recognition returns
    mock_face_locs = [(50, 150, 150, 50)]
    mock_face_encs = [np.random.rand(128).astype(np.float64)]
    
    # Standard static mock Path that supports relative_to computations
    mock_path = Path("/Users/keshavgoyal/Desktop/Ai -photo detector/data/uploads/mock.jpg")
    
    # We patch where these items are imported/used to ensure Python mocks them correctly.
    with patch("app.services.pipeline.clip_service.get_image_embedding", mock_clip.get_image_embedding), \
         patch("app.services.pipeline.clip_service.classify_image", mock_clip.classify_image), \
         patch("app.services.pipeline.ocr_service.extract_text", mock_ocr.extract_text), \
         patch("app.services.pipeline.detect_and_encode_faces", return_value=list(zip(mock_face_locs, mock_face_encs))), \
         patch("app.services.pipeline.get_image_metadata", return_value=(800, 600, 102400)), \
         patch("app.services.pipeline.compute_phash", return_value="a1a1a1a1a1a1a1a1"), \
         patch("app.services.pipeline.copy_image_to_uploads", return_value=(mock_path, "mock.jpg")), \
         patch("app.routers.photos.save_upload", return_value=(mock_path, "mock.jpg")), \
         patch("app.routers.search.clip_service.get_text_embedding", mock_clip.get_text_embedding), \
         patch("app.routers.search.vector_search_service.search", return_value=[(1, 0.95)]):
        yield {
            "clip": mock_clip,
            "ocr": mock_ocr,
            "face_locations": mock_face_locs,
            "face_encodings": mock_face_encs
        }
