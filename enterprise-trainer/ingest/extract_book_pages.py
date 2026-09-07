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
OUT = TRAINER.parent / "enterprise-app" / "assets" / "book_pages"

# Har daraja o'z betlar papkasi, o'z PDF papkasi va o'z fayl nomlariga ega.
# Fayl nomida DARAJA bo'lishi shart: ikkala kitobda ham 'coursebook' bor va
# ikkalasida ham 6-bet bor.
LEVELS = {
    "beginner": ("pages", "pdfs", {
        "coursebook": "enterprise-1-coursebook.pdf",
        "workbook": "enterprise-1-workbook.pdf",
        "grammar": "Enterprise_1_grammar.pdf",
    }),
    "elementary": ("pages-elementary", "pdfs-elementary", {
        "coursebook": "elementary-coursebook.pdf",
        "workbook": "elementary-workbook.pdf",
        "grammar": "elementary-grammar.pdf",
    }),
}
DEFAULT_LEVEL = "beginner"

LEVEL = DEFAULT_LEVEL
PAGES = TRAINER / "data" / LEVELS[DEFAULT_LEVEL][0]
PDFS = TRAINER / "data" / LEVELS[DEFAULT_LEVEL][1]
PDF_FILE = LEVELS[DEFAULT_LEVEL][2]


def set_level(level: str) -> None:
    """Qaysi daraja betlari chiqarilishini belgilaydi."""
    global LEVEL, PAGES, PDFS, PDF_FILE
    if level not in LEVELS:
        raise SystemExit(
            f"Noma'lum daraja: {level}. Mavjud: {', '.join(LEVELS)}"
        )
    src, pdfs, files = LEVELS[level]
    LEVEL = level
    PAGES = TRAINER / "data" / src
    PDFS = TRAINER / "data" / pdfs
    PDF_FILE = files


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
        # Raqamlanmagan betlar (modul muqovasi) siljishni buzadi —
        # ular xaritaga kirmaydi.
        if not d.get("bookPage"):
            continue
        out[book][d["bookPage"]] = (d["pdfPage"], d.get("unit"))
    return out


def unnumbered_pdf_pages():
    """Kitobda RAQAMLANMAGAN betlarning PDF raqamlari.

    Modul muqovalarida bet raqami bosilmagan. Ularni chiqarib
    tashlamasak, keyingi betning raqami ular tomonidan "band qilinadi"
    va butun kitob 2 betga siljib ketadi.
    """
    out = defaultdict(set)
    for f in sorted(PAGES.glob("*/p*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        if d.get("book") and not d.get("bookPage"):
            out[d["book"]].add(d["pdfPage"])
    return out


def extract_all(dpi: int) -> int:
    """Kitobning BARCHA betlarini chiqaradi.

    Bet raqami = PDF beti - siljish.

    DIQQAT — SILJISH BIR XIL EMAS. Kitobda RAQAMLANMAGAN betlar bor
    (modul muqovalari), shuning uchun ulardan keyin siljish o'zgaradi:
      coursebook: 33-betgacha +2, 34-betdan boshlab +4

    Shu sababli bitta siljish emas, SILJISH ZINAPOYASI quriladi:
    har bir PDF beti uchun undan oldingi eng yaqin ma'lum juftlikning
    siljishi ishlatiladi. Yangi bet qo'shilgan sari xarita aniqlashadi.
    """
    mapping = page_map()
    skip_pdf = unnumbered_pdf_pages()
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

        # (pdfPage, offset) juftliklari, pdfPage bo'yicha tartiblangan.
        steps = sorted((pdf, pdf - bp) for bp, (pdf, _) in known.items())
        shown = sorted({o for _, o in steps})

        doc = fitz.open(pdf_path)
        made = 0
        skip = skip_pdf.get(book, set())
        for i in range(len(doc)):
            pdf_page = i + 1
            if pdf_page in skip:
                continue  # raqamlanmagan bet (modul muqovasi)
            offset = steps[0][1]
            for p, o in steps:
                if p <= pdf_page:
                    offset = o
                else:
                    break
            book_page = pdf_page - offset
            if book_page < 1:
                continue  # muqova va kirish betlari
            dest = OUT / f"{LEVEL}_{book}_{book_page}.jpg"
            if dest.exists():
                continue
            doc[i].get_pixmap(dpi=dpi).save(dest)
            made += 1
        n_pages = len(doc)
        doc.close()
        total += made
        last_known = steps[-1][0]
        print(f"  [+] {book}: {made} bet (siljishlar {shown})")
        if last_known < n_pages:
            print(f"      [!] {last_known}-PDF betidan keyingi {n_pages - last_known} "
                  f"bet TAXMINIY joylashtirildi.")
            print(f"          Agar oldinda yana raqamlanmagan bet chiqsa "
                  f"(modul muqovasi), o'sha betlarni")
            print(f"          o'chirib qayta chiqaring — siljish o'zgaradi.")

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
    ap.add_argument("--level", default=DEFAULT_LEVEL,
                    help="Daraja: " + ", ".join(LEVELS))
    ap.add_argument("--all", action="store_true",
                    help="Kitobning BARCHA betlarini chiqarish (hali qayta "
                         "ishlanmaganlari ham). Bet raqami ma'lum betlardan "
                         "hisoblangan siljish bo'yicha aniqlanadi.")
    args = ap.parse_args()
    set_level(args.level)

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
            dest = OUT / f"{LEVEL}_{book}_{book_page}.jpg"
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
