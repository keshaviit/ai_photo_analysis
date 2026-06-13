import faiss
import numpy as np
from pathlib import Path
from sqlalchemy.orm import Session
from app.config import FAISS_INDEX_PATH
from app.models import Photo
from typing import List, Tuple
import logging

logger = logging.getLogger(__name__)

class VectorSearchService:
    _instance = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(VectorSearchService, cls).__new__(cls, *args, **kwargs)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self.dimension = 512  # CLIP embedding dimension
        self.index = None
        self.load_index()
        self._initialized = True

    def _init_empty_index(self):
        # IndexFlatIP computes inner product (cosine similarity for normalized vectors)
        quantizer = faiss.IndexFlatIP(self.dimension)
        # IndexIDMap2 allows mapping custom 64-bit IDs (like Photo.id) to the vectors
        self.index = faiss.IndexIDMap2(quantizer)

    def load_index(self):
        """
        Loads the FAISS index from disk. If the file is missing or corrupt, initializes an empty one.
        """
        if FAISS_INDEX_PATH.exists():
            try:
                self.index = faiss.read_index(str(FAISS_INDEX_PATH))
                logger.info(f"FAISS index loaded successfully. Total vectors: {self.index.ntotal}")
                return
            except Exception as e:
                logger.error(f"Failed to read FAISS index from {FAISS_INDEX_PATH}: {e}. Initializing empty index.")
        
        self._init_empty_index()

    def save_index(self):
        """
        Saves the current FAISS index to disk.
        """
        if self.index is None:
            return
        try:
            # Ensure folder exists
            FAISS_INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
            faiss.write_index(self.index, str(FAISS_INDEX_PATH))
            logger.info("FAISS index saved successfully.")
        except Exception as e:
            logger.error(f"Failed to write FAISS index to disk: {e}")

    def add_photo(self, photo_id: int, embedding: np.ndarray):
        """
        Adds a single photo embedding linked to its database ID, and saves the index.
        """
        if self.index is None:
            self._init_empty_index()
            
        # Ensure embedding is shape (1, 512) and type float32
        v = np.array([embedding], dtype=np.float32)
        ids = np.array([photo_id], dtype=np.int64)
        
        self.index.add_with_ids(v, ids)
        self.save_index()

    def remove_photo(self, photo_id: int):
        """
        Removes a photo embedding from the index.
        """
        if self.index is not None and self.index.ntotal > 0:
            ids_to_remove = np.array([photo_id], dtype=np.int64)
            self.index.remove_ids(ids_to_remove)
            self.save_index()

    def search(self, query_vector: np.ndarray, top_k: int = 10) -> List[Tuple[int, float]]:
        """
        Searches the index with the query vector.
        Returns a list of tuples: (photo_id, similarity_score).
        """
        if self.index is None or self.index.ntotal == 0:
            return []
            
        # Format query vector
        q = np.array([query_vector], dtype=np.float32)
        
        # Search index
        scores, ids = self.index.search(q, top_k)
        
        results = []
        for sim, idx in zip(scores[0], ids[0]):
            if idx != -1:  # -1 represents padding in FAISS when fewer items exist than top_k
                results.append((int(idx), float(sim)))
                
        return results

    def rebuild_index(self, db: Session):
        """
        Queries all photos in the database and recreates the FAISS index.
        """
        self._init_empty_index()
        photos = db.query(Photo).all()
        
        embeddings = []
        ids = []
        for photo in photos:
            arr = photo.get_clip_embedding_array()
            if arr is not None:
                embeddings.append(arr)
                ids.append(photo.id)
                
        if embeddings:
            vectors = np.stack(embeddings).astype(np.float32)
            ids_arr = np.array(ids, dtype=np.int64)
            self.index.add_with_ids(vectors, ids_arr)
            
        self.save_index()
        logger.info(f"FAISS index rebuilt with {len(ids)} items.")

# Singleton instance
vector_search_service = VectorSearchService()
