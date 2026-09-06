# enterprise-trainer

Enterprise 1 kitobini ilovaga aylantiradigan **kontent quvuri**.

## Hozir ishlatiladigan qism

    ingest/          PDF va skanlardan kontent yig'ish + eksport
      pdf_extract.py       PDF dan matn va rasm
      extract_book_pages.py bet skanlarini tayyorlash
      structure.py         betni tuzilmaga solish
      grammar_rules.py     grammatika qoidalarini ajratish
      export_pages.py      -> enterprise-app/assets/content/enterprise1/
      export_assets.py     -> enterprise-app/assets/content/beginner/
      check_content.py     SIFAT NAZORATI — "TOZA" chiqishi shart
      fetch_images.py      mashq rasmlarini yuklash

    data/pages/      qo'lda tekshirilgan manba (316 bet, JSON)
    tests/           test_answer_speech.py, test_book_glosses.py

Odatiy ish tartibi:

```bash
python -m ingest.export_pages     # kitob mashqlari
python -m ingest.check_content    # TOZA bo'lishi shart
```

## Eski (ishlatilmaydigan) qism

`app/` va `core/` — loyihaning BIRINCHI arxitekturasi: FastAPI backend
+ SQLAlchemy bazasi + server tomonidagi SRS. Ilova Flutter'ga
ko'chirilgach ular kerak bo'lmay qoldi:

* takrorlash jadvali endi `enterprise-app/lib/srs.dart` da,
* jarayon `enterprise-app/lib/stats.dart` da (brauzer xotirasida),
* mashqlar server emas, eksport bosqichida tayyorlanadi.

`ingest/` ularga UMUMAN bog'lanmagan. `tests/test_progress.py` va
`app/` ni ishga tushirish uchun `fastapi` va `sqlalchemy` kerak —
ular bu mashinada o'rnatilmagan, shuning uchun o'sha testlar
ishlamaydi. Kod tarix uchun saqlanyapti; yangi ish faqat `ingest/`
va `enterprise-app/` da qilinadi.
