# Enterprise English Trainer

Ingliz tilini o'rganish uchun gamifikatsiyalangan, spaced-repetition (SM-2) ilova.
Interfeys va izohlar **o'zbekcha**, o'rganiladigan kontent inglizcha.
To'liq **bepul va offline** stack — pullik API yo'q.

## Tuzilishi

| Papka | Nima | Texnologiya |
|---|---|---|
| [`enterprise-app/`](enterprise-app) | **Asosiy mahsulot** — Flutter web ilova | Flutter 3.41 / Dart |
| [`enterprise-trainer/`](enterprise-trainer) | Kontent quvuri — PDF → OCR → JSON asset | Python, Tesseract |
| [`docs/`](docs) | Dizayn spec'lari va implementatsiya rejalari | Markdown |

## Ilovaning imkoniyatlari

- **Vocabulary pack'lari** — Tanishuv → Moslash → Imlo → Yig'ish bosqichlari
- **SM-2 spaced repetition** — har so'z uchun dinamik takrorlash jadvali
- **Gamifikatsiya** — XP, tanga, streak (muzlatgich bilan), kunlik maqsad, liga
- **TTS** — brauzer ovozi (audio fayl saqlanmaydi)
- **Offline** — barcha progress `shared_preferences` da mahalliy saqlanadi
- **Dark mode**

## Ishga tushirish

```bash
cd enterprise-app
flutter pub get
flutter run -d chrome
```

Testlar:

```bash
cd enterprise-app
flutter test
```

## Kontent haqida

`assets/content/` ichidagi JSON fayllar shaxsiy o'quv maqsadida tayyorlangan
so'z ro'yxatlari. **Skanerlangan darsliklar va ularning OCR matni repozitoriyga
kiritilmagan** (mualliflik huquqi) — `.gitignore` ga qarang.

Darajalar: `beginner` (to'ldirilgan, 400 so'z / 34 unit) · `elementary` (bo'sh).
