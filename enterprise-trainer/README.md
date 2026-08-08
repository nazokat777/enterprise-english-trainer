# Enterprise English Personal Trainer

Shaxsiy, oflayn ishlaydigan ingliz tili o'rgatuvchi dastur. U **Enterprise**
(Express Publishing) darsligingizdan lug'at, so'z yasalishi (word formation) va
grammatikani o'rgatadi. Barcha izoh va tushuntirishlar **o'zbek tilida**,
o'rganilayotgan kontent esa ingliz tilida bo'ladi.

Dastur siz qayerda qiynalayotganingizni aniqlaydi va o'sha mavzuni mahoratingiz
**100%** ga yetguncha takrorlab mashq qildiradi (adaptiv interval takrorlash —
spaced repetition).

> Bu dastur faqat shaxsiy foydalanish uchun, ommaviy tarqatish uchun emas.

---

## 1. O'rnatish

Python 3.11 yoki undan yuqori versiya kerak.

```bash
# 1. Loyiha papkasiga kiring
cd enterprise-trainer

# 2. Virtual muhit yarating (tavsiya etiladi)
python -m venv .venv
# Windows (PowerShell):
.venv\Scripts\Activate.ps1
# Linux / macOS:
source .venv/bin/activate

# 3. Kutubxonalarni o'rnating
pip install -r requirements.txt
```

## 2. PDF darsliklarni qo'shish

Enterprise PDF fayllaringizni `data/pdfs/` papkasiga joylashtiring.
Dastur shu papkadagi **har bir** PDF ni to'liq o'qiydi.

## 3. OCR dasturini o'rnatish (Tesseract)

Dastur skanerlangan PDF lardan matnni **bepul, oflayn** Tesseract OCR bilan
o'qiydi. Uni bir marta o'rnating:

```bash
# Windows:
winget install UB-Mannheim.TesseractOCR
```

> Bu loyiha **to'liq BEPUL** ishlaydi — hech qanday pullik API kerak emas.
> Tarjima (inglizcha→o'zbekcha) bepul Google Translate orqali (kalitsiz),
> matn esa Tesseract OCR orqali olinadi. Faqat internet kerak (tarjima uchun).

## 4. Ingestion (ma'lumotlarni tayyorlash, bir marta)

PDF → OCR matn → tuzilgan JSON jarayonini ishga tushiradi:

```bash
python -m ingest.pdf_extract     # PDF -> OCR -> matn (data/parsed/)
python -m ingest.structure       # matn -> structured.json (lug'at/grammatika)
```

Bu sizning kitoblaringizdan `data/parsed/structured.json` ni yaratadi
(lug'at + so'z yasalishi + grammatika, o'zbekcha tarjimalar bilan).

## 5. Dasturni ishga tushirish

```bash
uvicorn app.main:app --reload
```

So'ng brauzerda oching: http://127.0.0.1:8000

Birinchi ishga tushganda baza `structured.json` dan avtomatik to'ldiriladi.

## Testlar

```bash
python -m pytest tests/ -q
```

---

## Papkalar tuzilishi

```
enterprise-trainer/
├── data/{pdfs, parsed, chroma_db}/   # PDF, ajratilgan matn, vektor baza
├── ingest/                           # PDF → struktura → indeks quvuri
├── core/                             # SRS, progress, retriever, generator
├── app/                              # FastAPI backend + frontend
├── config.py                         # Yo'llar va API sozlamalari
├── requirements.txt
└── .env.example
```

## Holat (development)

- [x] 1-bosqich: Loyiha skeleti, requirements, README
- [x] 2-bosqich: PDF dan matn ajratish (Tesseract OCR)
- [x] 3-bosqich: Tuzilgan JSON (qoidaviy + bepul tarjima)
- [x] 4-bosqich: SRS + progress (SQLite, testlar bilan)
- [x] 5-bosqich: Retriever (structured.json dan)
- [x] 6-bosqich: Mashq generatori + baholash (shablon, AI'siz)
- [x] 7-bosqich: FastAPI endpointlar
- [x] 8-bosqich: Frontend (sahifa, dashboard)
- [ ] 9-bosqich: Gamifikatsiya (streak, kunlik maqsad), yakuniy sayqal
