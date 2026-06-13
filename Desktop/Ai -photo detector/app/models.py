from datetime import datetime
import json
import numpy as np
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, LargeBinary
from sqlalchemy.orm import relationship
from app.database import Base

class Photo(Base):
    __tablename__ = "photos"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    filename = Column(String, nullable=False)
    filepath = Column(String, nullable=False)
    phash = Column(String, index=True, nullable=True)
    ocr_text = Column(Text, nullable=True)
    category = Column(String, index=True, nullable=True)
    width = Column(Integer, nullable=True)
    height = Column(Integer, nullable=True)
    file_size = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Store the 512-d CLIP vector as binary (numpy array of float32)
    clip_embedding = Column(LargeBinary, nullable=True)

    # Relationships
    faces = relationship("Face", back_populates="photo", cascade="all, delete-orphan")

    def get_clip_embedding_array(self) -> np.ndarray:
        if self.clip_embedding is None:
            return None
        return np.frombuffer(self.clip_embedding, dtype=np.float32)

    def set_clip_embedding_array(self, arr: np.ndarray):
        if arr is not None:
            self.clip_embedding = arr.astype(np.float32).tobytes()


class FaceCluster(Base):
    __tablename__ = "face_clusters"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    faces = relationship("Face", back_populates="cluster")


class Face(Base):
    __tablename__ = "faces"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    photo_id = Column(Integer, ForeignKey("photos.id"), nullable=False)
    
    # Bounding box coordinates: [top, right, bottom, left]
    box_top = Column(Integer, nullable=False)
    box_right = Column(Integer, nullable=False)
    box_bottom = Column(Integer, nullable=False)
    box_left = Column(Integer, nullable=False)
    
    # Store the 128-d face recognition vector as binary (numpy array of float64)
    encoding = Column(LargeBinary, nullable=False)
    
    cluster_id = Column(Integer, ForeignKey("face_clusters.id", ondelete="SET NULL"), nullable=True)

    # Relationships
    photo = relationship("Photo", back_populates="faces")
    cluster = relationship("FaceCluster", back_populates="faces")

    def get_encoding_array(self) -> np.ndarray:
        if self.encoding is None:
            return None
        return np.frombuffer(self.encoding, dtype=np.float64)

    def set_encoding_array(self, arr: np.ndarray):
        if arr is not None:
            self.encoding = arr.astype(np.float64).tobytes()
            
    def get_bounding_box(self) -> dict:
        return {
            "top": self.box_top,
            "right": self.box_right,
            "bottom": self.box_bottom,
            "left": self.box_left
        }
