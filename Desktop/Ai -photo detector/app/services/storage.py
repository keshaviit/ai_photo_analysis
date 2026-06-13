import os
import shutil
import uuid
from pathlib import Path
from typing import List, Tuple, Optional
from PIL import Image
from app.config import UPLOAD_DIR

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}

def is_allowed_file(filename: str) -> bool:
    ext = Path(filename).suffix.lower()
    return ext in ALLOWED_EXTENSIONS

def save_upload(file_data: bytes, filename: str) -> Tuple[Path, str]:
    """
    Saves an uploaded file to the upload directory with a unique UUID prefix
    to prevent collision, returning the absolute path and the saved file name.
    """
    ext = Path(filename).suffix.lower()
    unique_name = f"{uuid.uuid4()}{ext}"
    target_path = UPLOAD_DIR / unique_name
    
    with open(target_path, "wb") as buffer:
        buffer.write(file_data)
        
    return target_path, unique_name

def get_image_metadata(file_path: Path) -> Tuple[int, int, int]:
    """
    Returns (width, height, file_size_bytes) for the given image path.
    """
    file_size = os.path.getsize(file_path)
    with Image.open(file_path) as img:
        width, height = img.size
    return width, height, file_size

def scan_directory_for_images(directory_path: str) -> List[Path]:
    """
    Recursively scans the directory path and returns a list of paths to all supported images.
    """
    dir_path = Path(directory_path)
    if not dir_path.exists() or not dir_path.is_dir():
        raise ValueError(f"Directory {directory_path} does not exist or is not a directory.")
        
    image_paths = []
    for root, _, files in os.walk(dir_path):
        for file in files:
            if is_allowed_file(file):
                image_paths.append(Path(root) / file)
                
    return image_paths

def copy_image_to_uploads(source_path: Path) -> Tuple[Path, str]:
    """
    Copies a local file to the upload directory with a unique name (used during folder scan).
    """
    ext = source_path.suffix.lower()
    unique_name = f"{uuid.uuid4()}{ext}"
    target_path = UPLOAD_DIR / unique_name
    shutil.copy2(source_path, target_path)
    return target_path, unique_name
