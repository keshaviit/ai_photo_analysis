from datetime import datetime
from typing import List, Optional, Dict
from pydantic import BaseModel, ConfigDict

# Face Schemas
class FaceBase(BaseModel):
    box_top: int
    box_right: int
    box_bottom: int
    box_left: int

class FaceCreate(FaceBase):
    encoding: bytes
    photo_id: int
    cluster_id: Optional[int] = None

class FaceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    photo_id: int
    box_top: int
    box_right: int
    box_bottom: int
    box_left: int
    cluster_id: Optional[int] = None


# Photo Schemas
class PhotoBase(BaseModel):
    filename: str
    filepath: str
    phash: Optional[str] = None
    ocr_text: Optional[str] = None
    category: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    file_size: Optional[int] = None

class PhotoCreate(PhotoBase):
    clip_embedding: Optional[bytes] = None

class PhotoResponse(PhotoBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    faces: List[FaceResponse] = []


# Face Cluster Schemas
class FaceClusterBase(BaseModel):
    name: str

class FaceClusterUpdate(BaseModel):
    name: str

class FaceClusterResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    created_at: datetime
    faces: List[FaceResponse] = []


# Search & Grouping Schemas
class SearchResult(BaseModel):
    photo: PhotoResponse
    similarity: float

class DuplicateGroup(BaseModel):
    phash: str
    photos: List[PhotoResponse]

class CategoryGroup(BaseModel):
    category: str
    photos: List[PhotoResponse]

class ScanFolderResponse(BaseModel):
    status: str
    message: str
    scanned_path: str
    photos_found: int
    photos_processed: int
