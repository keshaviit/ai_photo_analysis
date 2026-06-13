from fastapi import APIRouter, Depends, UploadFile, File, BackgroundTasks, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from pathlib import Path
from app.database import get_db
from app.schemas import PhotoResponse, ScanFolderResponse
from app.services.storage import save_upload, scan_directory_for_images, is_allowed_file
from app.services.pipeline import process_photo, process_local_directory
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/photos", tags=["photos"])

class ScanFolderRequest(BaseModel):
    directory_path: str

def run_background_scan(directory_path: str, db_session_factory, image_paths: list[Path]):
    """
    Background worker that runs directory ingestion.
    Uses a fresh DB session to avoid lifecycle conflicts with the HTTP request.
    """
    db = db_session_factory()
    try:
        logger.info(f"Starting background scan for {directory_path} with {len(image_paths)} images")
        
        def progress_log(current, total):
            if current % 10 == 0 or current == total:
                logger.info(f"Scan progress for {directory_path}: {current}/{total} images processed")
                
        processed_count = process_local_directory(db, image_paths, progress_callback=progress_log)
        logger.info(f"Completed background scan for {directory_path}. Processed: {processed_count}/{len(image_paths)}")
    except Exception as e:
        logger.error(f"Error in background scan for {directory_path}: {e}")
    finally:
        db.close()

@router.post("/upload", response_model=PhotoResponse, status_code=201)
async def upload_photo(file: UploadFile = File(...), db: Session = Depends(get_db)):
    """
    Uploads a single photo and runs the processing pipeline synchronously on the main thread loop.
    """
    if not is_allowed_file(file.filename):
        raise HTTPException(status_code=400, detail="Unsupported image format. Allowed formats: JPG, JPEG, PNG, WEBP, BMP")
        
    try:
        # Read file data
        contents = await file.read()
        
        # Save file to uploads folder
        target_path, unique_name = save_upload(contents, file.filename)
        
        # Run pipeline
        photo = process_photo(db, target_path, file.filename, trigger_clustering=True)
        return photo
    except Exception as e:
        logger.error(f"Failed to process upload {file.filename}: {e}")
        raise HTTPException(status_code=500, detail=f"Image processing failed: {str(e)}")

@router.post("/scan-folder", response_model=ScanFolderResponse)
def scan_folder(
    request: ScanFolderRequest, 
    background_tasks: BackgroundTasks, 
    db: Session = Depends(get_db)
):
    """
    Scans a local directory and imports all eligible images in the background.
    """
    dir_path = Path(request.directory_path)
    if not dir_path.exists() or not dir_path.is_dir():
        raise HTTPException(status_code=404, detail=f"Directory '{request.directory_path}' not found or is not a directory.")
        
    try:
        image_paths = scan_directory_for_images(request.directory_path)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to scan directory: {str(e)}")
        
    if not image_paths:
        return ScanFolderResponse(
            status="success",
            message="No supported images found in the specified directory.",
            scanned_path=request.directory_path,
            photos_found=0,
            photos_processed=0
        )
        
    # Queue the heavy scanning and processing work to background tasks
    # We pass the session maker class/binding to ensure a fresh session is used inside the thread
    from app.database import SessionLocal
    background_tasks.add_task(
        run_background_scan, 
        request.directory_path, 
        SessionLocal, 
        image_paths
    )
    
    return ScanFolderResponse(
        status="processing",
        message=f"Scan initialized in the background. Found {len(image_paths)} images to process.",
        scanned_path=request.directory_path,
        photos_found=len(image_paths),
        photos_processed=0
    )
