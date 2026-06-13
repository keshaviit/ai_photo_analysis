from pathlib import Path
from sqlalchemy.orm import Session
from app.models import Photo, Face
from app.services.storage import get_image_metadata, copy_image_to_uploads
from app.services.phash import compute_phash
from app.services.clip import clip_service
from app.services.ocr import ocr_service
from app.services.face import detect_and_encode_faces, cluster_all_faces
from app.services.vector_search import vector_search_service
import logging

logger = logging.getLogger(__name__)

def process_photo(
    db: Session, 
    file_path: Path, 
    original_filename: str, 
    trigger_clustering: bool = True
) -> Photo:
    """
    Orchestrates the entire image processing pipeline:
    1. Extracts width, height, and file size.
    2. Computes pHash.
    3. Generates CLIP embedding.
    4. Extracts OCR text.
    5. Detects and encodes faces.
    6. Saves Photo and Face records in the database.
    7. Inserts the embedding into the FAISS index.
    8. (Optional) Re-runs DBSCAN clustering on all faces.
    """
    logger.info(f"Processing photo: {original_filename} ({file_path})")
    
    # 1. Image metadata
    width, height, file_size = get_image_metadata(file_path)
    
    # 2. Perceptual Hashing (pHash)
    phash_val = compute_phash(file_path)
    
    # 3. CLIP Embedding (normalized 512-d float32 array)
    clip_emb = clip_service.get_image_embedding(file_path)
    
    # 4. OCR Extraction
    ocr_text = ocr_service.extract_text(file_path)
    
    # 4.5. Zero-shot CLIP classification
    categories = ["Document/Receipt", "Landscape/Nature", "Portrait/People", "Animal/Pet", "Other"]
    try:
        category = clip_service.classify_image(file_path, categories)
    except Exception as e:
        logger.error(f"Failed to classify image {original_filename}: {e}")
        category = "Other"
    
    # Create Photo DB record
    photo = Photo(
        filename=original_filename,
        filepath=str(file_path.relative_to(file_path.parent.parent.parent)), # store relative path from workspace root
        phash=phash_val,
        ocr_text=ocr_text,
        category=category,
        width=width,
        height=height,
        file_size=file_size
    )
    photo.set_clip_embedding_array(clip_emb)
    
    db.add(photo)
    db.flush()  # populate photo.id
    
    # 5. Face Recognition (detection and encoding)
    detected_faces = detect_and_encode_faces(file_path)
    for (top, right, bottom, left), encoding in detected_faces:
        face = Face(
            photo_id=photo.id,
            box_top=top,
            box_right=right,
            box_bottom=bottom,
            box_left=left
        )
        face.set_encoding_array(encoding)
        db.add(face)
        
    db.commit()
    db.refresh(photo)
    
    # 6. Update FAISS Index with photo ID and its CLIP embedding
    vector_search_service.add_photo(photo.id, clip_emb)
    
    # 7. Optionally trigger clustering
    if trigger_clustering and detected_faces:
        try:
            cluster_all_faces(db)
        except Exception as e:
            logger.error(f"Failed to cluster faces during pipeline run: {e}")
            
    logger.info(f"Finished processing photo ID {photo.id}: {original_filename}")
    return photo

def process_local_directory(
    db: Session, 
    image_paths: list[Path],
    progress_callback = None
) -> int:
    """
    Processes a list of local image paths in batch mode:
    1. Copies them to the UPLOAD_DIR.
    2. Runs the processing pipeline (deferring face clustering).
    3. Runs face clustering once at the end of the batch.
    """
    count = 0
    for path in image_paths:
        try:
            # Copy file to uploads folder to manage it locally
            target_path, unique_name = copy_image_to_uploads(path)
            
            # Run pipeline without clustering to keep batch fast
            process_photo(db, target_path, path.name, trigger_clustering=False)
            count += 1
            
            if progress_callback:
                progress_callback(count, len(image_paths))
        except Exception as e:
            logger.error(f"Failed to process scanned image {path}: {e}")
            
    # Run face clustering once for the entire batch
    if count > 0:
        try:
            cluster_all_faces(db)
        except Exception as e:
            logger.error(f"Failed to run batch face clustering: {e}")
            
    return count
