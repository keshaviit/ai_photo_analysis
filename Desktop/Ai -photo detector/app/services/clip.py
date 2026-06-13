import torch
from transformers import CLIPProcessor, CLIPModel
from PIL import Image
from pathlib import Path
import numpy as np
from app.config import CLIP_MODEL_NAME

class CLIPService:
    _instance = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(CLIPService, cls).__new__(cls, *args, **kwargs)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.model = None
        self.processor = None
        self._initialized = True

    def _load_model(self):
        if self.model is None or self.processor is None:
            # Load CLIP model and processor lazily
            self.model = CLIPModel.from_pretrained(CLIP_MODEL_NAME).to(self.device)
            self.processor = CLIPProcessor.from_pretrained(CLIP_MODEL_NAME)

    def get_image_embedding(self, image_path: Path) -> np.ndarray:
        """
        Generates a 512-dimensional, L2-normalized CLIP embedding for an image.
        """
        self._load_model()
        with Image.open(image_path) as img:
            inputs = self.processor(images=img, return_tensors="pt").to(self.device)
            
        with torch.no_grad():
            outputs = self.model.get_image_features(**inputs)
            # In transformers v5, get_image_features returns BaseModelOutputWithPooling
            # We extract pooler_output, with fallback to outputs itself for older versions
            features = outputs.pooler_output if hasattr(outputs, "pooler_output") else outputs
            # Normalize embedding
            features = features / features.norm(p=2, dim=-1, keepdim=True)
            embedding = features[0].cpu().numpy()
            
        return embedding

    def get_text_embedding(self, text: str) -> np.ndarray:
        """
        Generates a 512-dimensional, L2-normalized CLIP embedding for a text query.
        """
        self._load_model()
        inputs = self.processor(text=[text], return_tensors="pt", padding=True).to(self.device)
        
        with torch.no_grad():
            outputs = self.model.get_text_features(**inputs)
            # In transformers v5, get_text_features returns BaseModelOutputWithPooling
            features = outputs.pooler_output if hasattr(outputs, "pooler_output") else outputs
            # Normalize embedding
            features = features / features.norm(p=2, dim=-1, keepdim=True)
            embedding = features[0].cpu().numpy()
            
        return embedding

    def classify_image(self, image_path: Path, categories: list[str]) -> str:
        """
        Classifies an image into one of the provided categories using zero-shot classification.
        """
        self._load_model()
        with Image.open(image_path) as img:
            inputs = self.processor(
                text=categories, 
                images=img, 
                return_tensors="pt", 
                padding=True
            ).to(self.device)
            
        with torch.no_grad():
            outputs = self.model(**inputs)
            logits_per_image = outputs.logits_per_image  # image-text similarity score
            probs = logits_per_image.softmax(dim=-1).cpu().numpy()[0]
            
        best_idx = np.argmax(probs)
        return categories[best_idx]

# Singleton instance
clip_service = CLIPService()
