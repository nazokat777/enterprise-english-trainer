"""PDF dan matn ajratish — OCR orqali (2-bosqich).

Enterprise kitoblari skanerlangan rasm bo'lgani uchun oddiy matn qatlami yo'q.
Shuning uchun har bir sahifa rasmga aylantirilib, Tesseract OCR bilan o'qiladi.
HAR BIR sahifa qayta ishlanadi — hech biri o'tkazib yuborilmaydi.

Ikki xil chiqish fayli (har bir kitob uchun):
  * data/parsed/<kitob>.txt   — odam o'qishi uchun, sahifa belgilari bilan
  * data/parsed/<kitob>.json  — keyingi bosqichlar uchun, sahifa raqami bilan

Ishga tushirish (hammasi):
    python -m ingest.pdf_extract
Bitta kitob yoki sahifa oralig'i:
    python -m ingest.pdf_extract --book enterprise-1-workbook --start 10 --end 20
"""
from __future__ import annotations

import argparse
import io
import json
import re
import sys
from pathlib import Path
from typing import TypedDict

import fitz  # PyMuPDF
import pytesseract
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config  # noqa: E402


class PageText(TypedDict):
    """Bitta sahifaning OCR orqali o'qilgan matni."""

    page: int  # 1 dan boshlanadigan sahifa raqami
    text: str  # tozalangan matn


PAGE_SEP = "\n\n===== SAHIFA {page} =====\n\n"


def clean_text(raw: str) -> str:
    """OCR dan kelgan xom matnni tozalaydi.

    - Qator oxiri bilan bo'lingan so'zlarni birlashtiradi.
    - Chekka bo'sh joylarni va takror bo'sh qatorlarni qisqartiradi.
    """
    raw = re.sub(r"(\w)-\n(\w)", r"\1\2", raw)
    lines = [ln.strip() for ln in raw.splitlines()]
    cleaned: list[str] = []
    blank = False
    for ln in lines:
        if ln:
            cleaned.append(ln)
            blank = False
        elif not blank:
            cleaned.append("")
            blank = True
    return "\n".join(cleaned).strip()


def ocr_page(page: fitz.Page, dpi: int = config.OCR_DPI) -> str:
    """Bitta PDF sahifasini rasmga aylantirib, OCR bilan o'qiydi.

    Args:
        page: PyMuPDF sahifa obyekti.
        dpi: Rasm aniqligi (yuqori = aniqroq, sekinroq).

    Returns:
        Tozalangan matn (bo'sh ham bo'lishi mumkin).
    """
    pix = page.get_pixmap(dpi=dpi)
    img = Image.open(io.BytesIO(pix.tobytes("png")))
    raw = pytesseract.image_to_string(img, lang="eng")
    return clean_text(raw)


def extract_pdf(
    pdf_path: Path, start: int = 1, end: int | None = None
) -> list[PageText]:
    """PDF ning HAR sahifasidan OCR orqali matn ajratadi.

    Args:
        pdf_path: PDF fayl yo'li.
        start: Boshlanish sahifasi (1 dan).
        end: Tugash sahifasi (None = oxirigacha).

    Returns:
        Har sahifa uchun {page, text} ro'yxati.
    """
    pages: list[PageText] = []
    with fitz.open(pdf_path) as doc:
        last = doc.page_count if end is None else min(end, doc.page_count)
        for index in range(start, last + 1):
            page = doc[index - 1]
            text = ocr_page(page)
            pages.append(PageText(page=index, text=text))
            mark = "·" if text else "○"  # matnli / bo'sh
            print(f"    {mark} {index}/{last}", end="\r", flush=True)
    print()
    return pages


def save_outputs(book_name: str, pages: list[PageText]) -> tuple[Path, Path]:
    """Ajratilgan sahifalarni .txt va .json sifatida saqlaydi."""
    config.PARSED_DIR.mkdir(parents=True, exist_ok=True)
    txt_path = config.PARSED_DIR / f"{book_name}.txt"
    json_path = config.PARSED_DIR / f"{book_name}.json"

    parts: list[str] = []
    for p in pages:
        parts.append(PAGE_SEP.format(page=p["page"]))
        parts.append(p["text"])
    txt_path.write_text("".join(parts), encoding="utf-8")

    json_path.write_text(
        json.dumps({"book": book_name, "pages": pages}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return txt_path, json_path


def extract_all(
    book_filter: str | None = None, start: int = 1, end: int | None = None
) -> dict[str, int]:
    """data/pdfs/ ichidagi PDF larni OCR bilan qayta ishlaydi.

    Args:
        book_filter: Faqat shu nomli kitobni qayta ishlash (ixtiyoriy).
        start, end: Sahifa oralig'i (test uchun).

    Returns:
        {kitob_nomi: qayta_ishlangan_sahifalar_soni} lug'ati.
    """
    config.ensure_dirs()
    config.configure_tesseract()

    pdfs = sorted(config.PDF_DIR.glob("*.pdf"))
    if book_filter:
        pdfs = [p for p in pdfs if p.stem == book_filter]
    if not pdfs:
        raise FileNotFoundError(
            f"{config.PDF_DIR} papkasida mos PDF topilmadi. "
            "Enterprise PDF larni shu papkaga joylang."
        )

    summary: dict[str, int] = {}
    for pdf in pdfs:
        book = pdf.stem
        print(f"[+] OCR o'qilmoqda: {pdf.name} ...")
        pages = extract_pdf(pdf, start=start, end=end)
        non_empty = sum(1 for p in pages if p["text"])
        save_outputs(book, pages)
        summary[book] = len(pages)
        print(f"    -> {len(pages)} sahifa ({non_empty} matnli) saqlandi: {book}")
    return summary


def main() -> None:
    """CLI kirish nuqtasi."""
    ap = argparse.ArgumentParser(description="PDF dan OCR orqali matn ajratish")
    ap.add_argument("--book", help="Faqat shu kitob (fayl nomi, .pdf siz)")
    ap.add_argument("--start", type=int, default=1, help="Boshlanish sahifasi")
    ap.add_argument("--end", type=int, default=None, help="Tugash sahifasi")
    args = ap.parse_args()

    summary = extract_all(book_filter=args.book, start=args.start, end=args.end)
    total = sum(summary.values())
    print("\n=== Yakun ===")
    for book, n in summary.items():
        print(f"  {book}: {n} sahifa")
    print(f"  Jami: {total} sahifa")


if __name__ == "__main__":
    main()
