"""Loyiha sozlamalari — barcha yo'llar va Claude API konfiguratsiyasi shu yerda.

Maxfiy kalit (.env) hech qachon kodga yozilmaydi, faqat muhit o'zgaruvchisidan
o'qiladi.
"""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# Loyiha ildizi (shu fayl joylashgan papka).
BASE_DIR: Path = Path(__file__).resolve().parent

# .env faylini yuklash (agar mavjud bo'lsa).
load_dotenv(BASE_DIR / ".env")

# --- Ma'lumotlar papkalari ---
DATA_DIR: Path = BASE_DIR / "data"
PDF_DIR: Path = DATA_DIR / "pdfs"
PARSED_DIR: Path = DATA_DIR / "parsed"
CHROMA_DIR: Path = DATA_DIR / "chroma_db"

# Tuzilgan (structured) kontent va SQLite bazasi.
STRUCTURED_JSON: Path = PARSED_DIR / "structured.json"
PROGRESS_DB: Path = BASE_DIR / "progress.db"

# --- OCR (Tesseract) ---
# Windows'da standart o'rnatish yo'li. Boshqa OS yoki yo'l bo'lsa, .env dagi
# TESSERACT_CMD orqali bekor qilish mumkin.
_DEFAULT_TESSERACT = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
TESSERACT_CMD: str = os.getenv("TESSERACT_CMD", _DEFAULT_TESSERACT)

# OCR rasm aniqligi (DPI). Yuqori = aniqroq, lekin sekinroq.
OCR_DPI: int = int(os.getenv("OCR_DPI", "300"))

# --- Tarjima ---
# Bepul Google Translate (deep-translator) ishlatiladi — API kalit kerak emas.
TRANSLATE_SOURCE: str = "en"
TRANSLATE_TARGET: str = "uz"


def ensure_dirs() -> None:
    """Kerakli papkalar mavjudligini ta'minlaydi (yo'q bo'lsa yaratadi)."""
    for d in (PDF_DIR, PARSED_DIR, CHROMA_DIR):
        d.mkdir(parents=True, exist_ok=True)


def configure_tesseract() -> None:
    """pytesseract'ga Tesseract dasturining yo'lini ko'rsatadi.

    Agar topilmasa, aniq o'zbekcha xato beradi.
    """
    import pytesseract

    if not Path(TESSERACT_CMD).exists():
        raise RuntimeError(
            f"Tesseract topilmadi: {TESSERACT_CMD}\n"
            "Uni o'rnating (Windows: winget install UB-Mannheim.TesseractOCR) "
            "yoki .env ichida TESSERACT_CMD yo'lini ko'rsating."
        )
    pytesseract.pytesseract.tesseract_cmd = TESSERACT_CMD
