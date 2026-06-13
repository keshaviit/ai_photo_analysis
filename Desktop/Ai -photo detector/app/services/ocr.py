import easyocr
from pathlib import Path
from typing import Optional
import logging

logger = logging.getLogger(__name__)

class OCRService:
    _instance = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(OCRService, cls).__new__(cls, *args, **kwargs)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self.reader = None
        self._initialized = True

    def _load_reader(self):
        if self.reader is None:
            # Lazy load reader to save resources on startup
            try:
                self.reader = easyocr.Reader(['en'], gpu=False)
            except Exception as e:
                logger.error(f"Failed to load EasyOCR reader: {e}")
                self.reader = None

    def extract_text(self, image_path: Path) -> Optional[str]:
        """
        Runs EasyOCR on the image and returns a single concatenated string of detected text.
        Returns None if no text is detected.
        """
        self._load_reader()
        if not self.reader:
            return None

        try:
            results = self.reader.readtext(str(image_path))
            if not results:
                return None
            
            # results format: [([[x,y], ...], text, confidence), ...]
            text_list = [res[1] for res in results if res[1]]
            extracted_text = " ".join(text_list).strip()
            return extracted_text if extracted_text else None
        except Exception as e:
            logger.error(f"Error during OCR extraction on {image_path}: {e}")
            return None

# Singleton instance
ocr_service = OCRService()
