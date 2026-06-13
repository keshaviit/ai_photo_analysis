import numpy as np
from PIL import Image
from pathlib import Path
from typing import List, Tuple, Dict, Any
from sqlalchemy.orm import Session
from sklearn.cluster import DBSCAN
from app.models import Face, FaceCluster
from app.config import FACE_DISTANCE_THRESHOLD
import logging

logger = logging.getLogger(__name__)

try:
    import face_recognition
    FACE_REC_AVAILABLE = True
except ImportError:
    face_recognition = None
    FACE_REC_AVAILABLE = False
    logger.warning("face_recognition library (dlib dependency) is not installed. Face features will be disabled locally.")

def detect_and_encode_faces(image_path: Path) -> List[Tuple[Tuple[int, int, int, int], np.ndarray]]:
    """
    Detects faces in an image and generates a 128-dimensional embedding for each.
    Returns a list of tuples containing (bounding_box_tuple, encoding_array).
    Bounding box format: (top, right, bottom, left).
    """
    if not FACE_REC_AVAILABLE:
        return []
    try:
        # Load image using face_recognition (which loads as numpy array)
        image = face_recognition.load_image_file(str(image_path))
        
        # Detect face locations
        # Use hog model by default as it is fast and runs well on CPU
        face_locations = face_recognition.face_locations(image, model="hog")
        if not face_locations:
            return []
            
        # Compute 128-d face encodings
        face_encodings = face_recognition.face_encodings(image, face_locations)
        
        return list(zip(face_locations, face_encodings))
    except Exception as e:
        logger.error(f"Error extracting faces from {image_path}: {e}")
        return []

def cluster_all_faces(db: Session) -> Dict[str, Any]:
    """
    Retrieves all Face records from the database, clusters them using DBSCAN,
    and updates/creates FaceClusters accordingly.
    Preserves existing FaceCluster names where possible.
    """
    if not FACE_REC_AVAILABLE:
        return {"clusters_count": 0, "faces_clustered": 0, "status": "disabled"}
    faces = db.query(Face).all()
    if not faces:
        return {"clusters_count": 0, "faces_clustered": 0}
        
    # Extract encodings
    encodings = []
    valid_faces: List[Face] = []
    for f in faces:
        arr = f.get_encoding_array()
        if arr is not None:
            encodings.append(arr)
            valid_faces.append(f)
            
    if not encodings:
        return {"clusters_count": 0, "faces_clustered": 0}
        
    X = np.stack(encodings)
    
    # Run DBSCAN
    # eps=0.6 is standard face_recognition threshold (Euclidean distance)
    # min_samples=1 allows single faces to form their own cluster
    dbscan = DBSCAN(eps=FACE_DISTANCE_THRESHOLD, min_samples=1, metric="euclidean")
    labels = dbscan.fit_predict(X)
    
    # Group face objects by DBSCAN label
    label_to_faces: Dict[int, List[Face]] = {}
    for face_obj, label in zip(valid_faces, labels):
        if label not in label_to_faces:
            label_to_faces[label] = []
        label_to_faces[label].append(face_obj)
        
    # Track which clusters are currently used to avoid deleting them
    used_cluster_ids = set()
    
    for label, group in label_to_faces.items():
        # Find if any face in this group already has a cluster assigned
        existing_cluster_counts = {}
        for face_obj in group:
            if face_obj.cluster_id is not None:
                existing_cluster_counts[face_obj.cluster_id] = existing_cluster_counts.get(face_obj.cluster_id, 0) + 1
                
        target_cluster_id = None
        
        if existing_cluster_counts:
            # Pick the cluster ID that was most common among faces in this group
            target_cluster_id = max(existing_cluster_counts, key=existing_cluster_counts.get)
            used_cluster_ids.add(target_cluster_id)
        else:
            # Create a brand new cluster
            new_cluster = FaceCluster(name="Unnamed Person")
            db.add(new_cluster)
            db.flush()  # Populates new_cluster.id
            
            # Update name to reflect ID default
            new_cluster.name = f"Person {new_cluster.id}"
            target_cluster_id = new_cluster.id
            used_cluster_ids.add(target_cluster_id)
            
        # Update cluster_id for all faces in this group
        for face_obj in group:
            face_obj.cluster_id = target_cluster_id
            
    db.commit()
    
    # Clean up empty clusters (clusters that no longer contain any faces)
    all_clusters = db.query(FaceCluster).all()
    deleted_count = 0
    for cluster in all_clusters:
        if cluster.id not in used_cluster_ids:
            # Double check if any face is still linked (just in case)
            face_count = db.query(Face).filter(Face.cluster_id == cluster.id).count()
            if face_count == 0:
                db.delete(cluster)
                deleted_count += 1
                
    if deleted_count > 0:
        db.commit()
        
    total_clusters = db.query(FaceCluster).count()
    return {
        "clusters_count": total_clusters,
        "faces_clustered": len(valid_faces),
        "deleted_empty_clusters": deleted_count
    }
