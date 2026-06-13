import imagehash
from PIL import Image
from pathlib import Path
from sqlalchemy.orm import Session
from app.models import Photo
from app.config import PHASH_THRESHOLD
from typing import Dict, List

def compute_phash(image_path: Path) -> str:
    """
    Computes the perceptual hash (pHash) of an image and returns it as a hex string.
    """
    with Image.open(image_path) as img:
        p_hash = imagehash.phash(img)
    return str(p_hash)

def hamming_distance(hash1_hex: str, hash2_hex: str) -> int:
    """
    Calculates the Hamming distance between two pHash hex strings.
    """
    h1 = imagehash.hex_to_hash(hash1_hex)
    h2 = imagehash.hex_to_hash(hash2_hex)
    return h1 - h2

def find_duplicates_in_db(db: Session, threshold: int = PHASH_THRESHOLD) -> List[List[Photo]]:
    """
    Retrieves all photos from the database and groups them into duplicate sets
    based on the Hamming distance threshold.
    """
    photos = db.query(Photo).all()
    visited = set()
    duplicate_groups = []

    for i, p1 in enumerate(photos):
        if p1.id in visited or not p1.phash:
            continue
            
        group = [p1]
        visited.add(p1.id)
        
        for p2 in photos[i+1:]:
            if p2.id in visited or not p2.phash:
                continue
                
            dist = hamming_distance(p1.phash, p2.phash)
            if dist <= threshold:
                group.append(p2)
                visited.add(p2.id)
                
        if len(group) > 1:
            duplicate_groups.append(group)
            
    return duplicate_groups
