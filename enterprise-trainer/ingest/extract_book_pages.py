"""Kitob betlarini ilovaning LOKAL build'i uchun rasmga aylantiradi.

FAQAT SHAXSIY/OILAVIY FOYDALANISH UCHUN.

Chiqadigan fayllar `enterprise-app/assets/book_pages/` ga tushadi va u
papka `.gitignore` da — ya'ni GitHub'ga ham, Vercel'ga ham CHIQMAYDI.
Ochiq saytda betlar bo'lmaydi, ilova esa tavsiflar bilan ishlayveradi.

Ishlatish:
    python -m ingest.extract_book_pages              # hammasi
    python -m ingest.extract_book_pages --unit 1     # faqat 1-unit
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

import fitz  # PyMuPDF

TRAINER = Path(__file__).resolve().parent.parent
PAGES = TRAINER / "data" / "pages"
PDFS = TRAINER / "data" / "pdfs"
OUT = TRAINER.parent / "enterprise-app" / "assets" / "book_pages"

PDF_FILE = {
    "coursebook": "enterprise-1-coursebook.pdf",
    "workbook": "enterprise-1-workbook.pdf",
    "grammar": "Enterprise_1_grammar.pdf",
}


def page_map():
    """Sahifa JSON'laridan (kitob, bet) -> PDF beti xaritasini quradi.

    Har JSON'da `pdfPage` va `bookPage` bor, shuning uchun taxmin qilish
    shart emas — aniq moslik ishlatiladi.
    """
    out = defaultdict(dict)  # book -> {bookPage: (pdfPage, unit)}
    for f in sorted(PAGES.glob("*/p*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        book = d.get("book")
        if not book:
            continue
        out[book][d["bookPage"]] = (d["pdfPage"], d.get("unit"))
    return out


def extract_all(dpi: int) -> int:
    """Kitobning BARCHA betlarini chiqaradi.

    Bet raqami = PDF beti - siljish. Siljish allaqachon qayta ishlangan
    betlardan aniqlanadi (ularda pdfPage va bookPage juftligi bor),
    shuning uchun taxmin qilinmaydi.
    """
    mapping = page_map()
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for book, pdf_name in sorted(PDF_FILE.items()):
        pdf_path = PDFS / pdf_name
        if not pdf_path.exists():
            print(f"  [-] {book}: PDF topilmadi ({pdf_name})")
            continue

        known = mapping.get(book, {})
        if not known:
            print(f"  [-] {book}: siljishni aniqlash uchun ma'lumot yo'q")
            continue
        offsets = {pdf - bp for bp, (pdf, _) in known.items()}
        if len(offsets) != 1:
            print(f"  [!] {book}: siljish bir xil emas {sorted(offsets)} — "
                  f"o'tkazib yuborildi")
            continue
        offset = offsets.pop()

        doc = fitz.open(pdf_path)
        made = 0
        for i in range(len(doc)):
            book_page = (i + 1) - offset
            if book_page < 1:
                continue  # muqova va kirish betlari
            dest = OUT / f"{book}_{book_page}.jpg"
            if dest.exists():
                continue
            doc[i].get_pixmap(dpi=dpi).save(dest)
            made += 1
        doc.close()
        total += made
        print(f"  [+] {book}: {made} bet (siljish {offset:+d})")

    size_mb = sum(f.stat().st_size for f in OUT.glob('*.jpg')) // (1024 * 1024)
    print(f"\nJami yangi: {total} bet | papka hajmi: {size_mb} MB")
    print("Bu papka .gitignore da — GitHub va Vercel'ga CHIQMAYDI.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Kitob betlarini lokal build uchun rasmga aylantirish"
    )
    ap.add_argument("--unit", type=int, default=None,
                    help="Faqat shu unit betlari (standart: hammasi)")
    ap.add_argument("--dpi", type=int, default=190,
                    help="Rasm aniqligi (standart 190)")
    ap.add_argument("--all", action="store_true",
                    help="Kitobning BARCHA betlarini chiqarish (hali qayta "
                         "ishlanmaganlari ham). Bet raqami ma'lum betlardan "
                         "hisoblangan siljish bo'yicha aniqlanadi.")
    args = ap.parse_args()

    if args.all:
        return extract_all(args.dpi)

    mapping = page_map()
    if not mapping:
        print("Sahifa JSON'lari topilmadi — avval betlarni qayta ishlang.")
        return 1

    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for book, pages in sorted(mapping.items()):
        pdf_path = PDFS / PDF_FILE.get(book, "")
        if not pdf_path.exists():
            print(f"  [-] {book}: PDF topilmadi ({pdf_path.name})")
            continue
        doc = fitz.open(pdf_path)
        made = 0
        for book_page, (pdf_page, unit) in sorted(pages.items()):
            if args.unit is not None and unit != args.unit:
                continue
            dest = OUT / f"{book}_{book_page}.jpg"
            if dest.exists():
                continue
            pix = doc[pdf_page - 1].get_pixmap(dpi=args.dpi)
            pix.save(dest)
            made += 1
        doc.close()
        total += made
        print(f"  [+] {book}: {made} bet")

    print(f"\nJami: {total} bet -> {OUT}")
    print("\nBu papka .gitignore da — GitHub va Vercel'ga CHIQMAYDI.")
    print("Ilovani lokal ishga tushiring:")
    print("    cd enterprise-app && flutter run -d chrome")
    return 0


if __name__ == "__main__":
    sys.exit(main())
