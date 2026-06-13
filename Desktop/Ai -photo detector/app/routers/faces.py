from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.schemas import FaceClusterResponse, FaceClusterUpdate
from app.models import FaceCluster
from app.services.face import FACE_REC_AVAILABLE
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/faces", tags=["faces"])

@router.get("/groups", response_model=List[FaceClusterResponse])
def get_face_groups(db: Session = Depends(get_db)):
    """
    Retrieves all face clusters (representing individual people) and their associated face records.
    """
    if not FACE_REC_AVAILABLE:
        raise HTTPException(
            status_code=501, 
            detail="Face recognition features are disabled locally because the required native compiler library (dlib) is missing. Run the app via Docker to enable face recognition!"
        )
    try:
        # Fetch clusters along with associated faces
        clusters = db.query(FaceCluster).all()
        return clusters
    except Exception as e:
        logger.error(f"Failed to fetch face groups: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch face groups: {str(e)}")

@router.put("/groups/{id}", response_model=FaceClusterResponse)
def rename_face_group(
    id: int, 
    update_data: FaceClusterUpdate, 
    db: Session = Depends(get_db)
):
    """
    Renames a specific face cluster (e.g. naming 'Person 3' to 'Alice').
    """
    if not FACE_REC_AVAILABLE:
        raise HTTPException(
            status_code=501, 
            detail="Face recognition features are disabled locally because the required native compiler library (dlib) is missing. Run the app via Docker to enable face recognition!"
        )
    cluster = db.query(FaceCluster).filter(FaceCluster.id == id).first()
    if not cluster:
        raise HTTPException(status_code=404, detail=f"Face cluster with ID {id} not found.")
        
    try:
        cluster.name = update_data.name
        db.commit()
        db.refresh(cluster)
        return cluster
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to rename face group {id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to rename face group: {str(e)}")
