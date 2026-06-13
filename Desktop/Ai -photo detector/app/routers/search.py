from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.schemas import SearchResult, DuplicateGroup, CategoryGroup, PhotoResponse
from app.models import Photo
from app.services.clip import clip_service
from app.services.vector_search import vector_search_service
from app.services.phash import find_duplicates_in_db
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["search"])

@router.get("/search", response_model=List[SearchResult])
async def search_photos(
    q: str = Query(..., description="The search query text"),
    type: str = Query("semantic", description="Search type: 'semantic', 'ocr', or 'combined'"),
    limit: int = Query(10, ge=1, le=50, description="Max number of results to return"),
    db: Session = Depends(get_db)
):
    """
    Search for photos using semantic (CLIP), keyword (OCR), or combined methods.
    """
    type = type.lower()
    if type not in ("semantic", "ocr", "combined"):
        raise HTTPException(status_code=400, detail="Search type must be 'semantic', 'ocr', or 'combined'")

    results = []

    # 1. OCR search (SQL-based search over photo.ocr_text)
    ocr_photos = []
    if type in ("ocr", "combined"):
        ocr_photos = db.query(Photo).filter(Photo.ocr_text.like(f"%{q}%")).limit(limit).all()

    # 2. Semantic search (FAISS vector search using CLIP query embedding)
    semantic_results = []
    if type in ("semantic", "combined"):
        try:
            # Generate CLIP embedding of search text
            query_emb = clip_service.get_text_embedding(q)
            
            # Query FAISS
            faiss_res = vector_search_service.search(query_emb, top_k=limit)
            
            if faiss_res:
                # Fetch matching photos from DB
                photo_ids = [idx for idx, _ in faiss_res]
                db_photos = db.query(Photo).filter(Photo.id.in_(photo_ids)).all()
                
                # Create lookup mapping
                photo_map = {photo.id: photo for photo in db_photos}
                
                # Preserve FAISS relevance order
                for photo_id, sim in faiss_res:
                    if photo_id in photo_map:
                        semantic_results.append(
                            SearchResult(
                                photo=PhotoResponse.model_validate(photo_map[photo_id]),
                                similarity=sim
                            )
                        )
        except Exception as e:
            logger.error(f"Semantic search failed: {e}")
            if type == "semantic":
                raise HTTPException(status_code=500, detail=f"Semantic search engine failure: {str(e)}")

    # 3. Combine results
    if type == "ocr":
        # Return OCR hits with similarity of 1.0 (exact match indicator)
        results = [SearchResult(photo=PhotoResponse.model_validate(p), similarity=1.0) for p in ocr_photos]
    elif type == "semantic":
        results = semantic_results
    elif type == "combined":
        # Merge results, keeping highest similarity. Match OCR items with 1.0 score.
        seen_photo_ids = set()
        for res in semantic_results:
            results.append(res)
            seen_photo_ids.add(res.photo.id)
            
        for p in ocr_photos:
            if p.id not in seen_photo_ids:
                results.append(SearchResult(photo=PhotoResponse.model_validate(p), similarity=1.0))
                
        # Sort by similarity score descending
        results.sort(key=lambda r: r.similarity, reverse=True)
        results = results[:limit]

    return results

@router.get("/duplicates", response_model=List[DuplicateGroup])
def get_duplicates(
    threshold: Optional[int] = Query(None, description="pHash Hamming distance threshold"),
    db: Session = Depends(get_db)
):
    """
    Find and group photos that are exact or near-duplicates based on pHash distance.
    """
    from app.config import PHASH_THRESHOLD
    dist_threshold = threshold if threshold is not None else PHASH_THRESHOLD
    
    try:
        dup_groups = find_duplicates_in_db(db, threshold=dist_threshold)
        
        response_data = []
        for group in dup_groups:
            # Group phash is taken from the first photo in the group
            phash_val = group[0].phash or ""
            photo_responses = [PhotoResponse.model_validate(p) for p in group]
            response_data.append(DuplicateGroup(phash=phash_val, photos=photo_responses))
            
        return response_data
    except Exception as e:
        logger.error(f"Duplicate detection failed: {e}")
        raise HTTPException(status_code=500, detail=f"Duplicate detection failed: {str(e)}")

@router.get("/categories", response_model=List[CategoryGroup])
def get_categories(db: Session = Depends(get_db)):
    """
    Get all photos grouped by their assigned zero-shot category.
    """
    try:
        photos = db.query(Photo).all()
        category_map = {}
        
        for p in photos:
            cat = p.category or "Other"
            if cat not in category_map:
                category_map[cat] = []
            category_map[cat].append(PhotoResponse.model_validate(p))
            
        response_data = []
        for cat, items in category_map.items():
            response_data.append(CategoryGroup(category=cat, photos=items))
            
        return response_data
    except Exception as e:
        logger.error(f"Category grouping failed: {e}")
        raise HTTPException(status_code=500, detail=f"Category grouping failed: {str(e)}")
