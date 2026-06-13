import pytest
import io
import numpy as np
from pathlib import Path
from app.models import Photo, Face, FaceCluster
from app.services.vector_search import vector_search_service
from app.services.face import cluster_all_faces

def test_read_root(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "online"
    assert "upload_photo" in response.json()["endpoints"]

def test_upload_photo(client, tmp_path):
    # Set mock upload paths inside temporary test directory
    pytest.mock_file_path = tmp_path / "mock.jpg"
    with open(pytest.mock_file_path, "wb") as f:
        f.write(b"fake image bytes")

    # Send file to API
    file_payload = {"file": ("test_photo.jpg", io.BytesIO(b"fake image bytes"), "image/jpeg")}
    response = client.post("/api/photos/upload", files=file_payload)
    
    assert response.status_code == 201
    data = response.json()
    assert data["filename"] == "test_photo.jpg"
    assert data["category"] == "Landscape/Nature"
    assert data["ocr_text"] == "Mocked OCR Invoice text"
    assert len(data["faces"]) == 1
    assert data["faces"][0]["box_top"] == 50

def test_search_photos(client, db, tmp_path):
    # Setup some test photos in the DB directly
    photo1 = Photo(
        filename="dog.jpg",
        filepath="dog.jpg",
        phash="1234",
        ocr_text="Beware of the dog",
        category="Animal/Pet"
    )
    # 512-d normalized floats
    emb1 = np.zeros(512, dtype=np.float32)
    emb1[0] = 1.0 # query dog will have highest match if we set query dog to match emb1
    photo1.set_clip_embedding_array(emb1)
    
    photo2 = Photo(
        filename="receipt.png",
        filepath="receipt.png",
        phash="5678",
        ocr_text="Total: $45.00 Invoice",
        category="Document/Receipt"
    )
    emb2 = np.zeros(512, dtype=np.float32)
    emb2[10] = 1.0
    photo2.set_clip_embedding_array(emb2)
    
    db.add_all([photo1, photo2])
    db.commit()
    db.refresh(photo1)
    db.refresh(photo2)
    
    # Update FAISS
    vector_search_service.rebuild_index(db)
    
    # 1. OCR Keyword search
    response = client.get("/api/search?q=Invoice&type=ocr")
    assert response.status_code == 200
    results = response.json()
    assert len(results) == 1
    assert results[0]["photo"]["filename"] == "receipt.png"
    
    # 2. Semantic search
    response = client.get("/api/search?q=dog&type=semantic")
    assert response.status_code == 200
    results = response.json()
    assert len(results) > 0

def test_duplicates(client, db):
    photo1 = Photo(filename="cat1.jpg", filepath="cat1.jpg", phash="a1a1a1a1a1a1a1a1")
    photo2 = Photo(filename="cat2.jpg", filepath="cat2.jpg", phash="a1a1a1a1a1a1a1a2") # 1 bit difference, Hamming distance 1
    photo3 = Photo(filename="forest.jpg", filepath="forest.jpg", phash="f0f0f0f0f0f0f0f0") # very different
    
    db.add_all([photo1, photo2, photo3])
    db.commit()
    
    response = client.get("/api/duplicates?threshold=10")
    assert response.status_code == 200
    groups = response.json()
    
    # There should be 1 group containing photo 1 and 2
    assert len(groups) == 1
    assert len(groups[0]["photos"]) == 2
    filenames = [p["filename"] for p in groups[0]["photos"]]
    assert "cat1.jpg" in filenames
    assert "cat2.jpg" in filenames

def test_categories(client, db):
    photo1 = Photo(filename="forest.jpg", filepath="forest.jpg", category="Landscape/Nature")
    photo2 = Photo(filename="receipt.jpg", filepath="receipt.jpg", category="Document/Receipt")
    
    db.add_all([photo1, photo2])
    db.commit()
    
    response = client.get("/api/categories")
    assert response.status_code == 200
    categories = response.json()
    
    # Should have 2 category groupings
    assert len(categories) == 2
    cats = [c["category"] for c in categories]
    assert "Landscape/Nature" in cats
    assert "Document/Receipt" in cats

def test_face_groups_and_rename(client, db):
    # Setup photos, faces, and clusters
    photo = Photo(filename="family.jpg", filepath="family.jpg")
    db.add(photo)
    db.flush()
    
    face1 = Face(photo_id=photo.id, box_top=10, box_right=20, box_bottom=20, box_left=10)
    face1.set_encoding_array(np.random.rand(128).astype(np.float64))
    
    face2 = Face(photo_id=photo.id, box_top=30, box_right=40, box_bottom=40, box_left=30)
    face2.set_encoding_array(np.random.rand(128).astype(np.float64))
    
    db.add_all([face1, face2])
    db.commit()
    
    # Trigger clustering
    cluster_all_faces(db)
    
    # Check groups API
    response = client.get("/api/faces/groups")
    assert response.status_code == 200
    groups = response.json()
    assert len(groups) > 0
    
    cluster_id = groups[0]["id"]
    original_name = groups[0]["name"]
    
    # Rename cluster API
    response = client.put(f"/api/faces/groups/{cluster_id}", json={"name": "Alice"})
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Alice"
    assert data["id"] == cluster_id
