# Homework — unit bo'yicha baholi test (Design Spec)

**Sana:** 2026-08-08
**Holat:** Dizayn tasdiqlangan (mockup ko'rildi). Implementatsiyaga tayyor.
**Maqsad:** `unit_screen.dart`dagi Homework placeholder'ini (hozir faqat snackbar) haqiqiy, **baholanadigan unit testiga** aylantirish.

---

## 1. Nima uchun va qanday farq qiladi

Pack oqimi (`pack_flow.dart`) — **o'rgatadi**: bitta pack (5–6 so'z), bosqichma-bosqich, baho yo'q.
Homework — **tekshiradi**: butun unit so'zlari, aralash mashqlar, foiz bilan baholanadi.

| | Pack oqimi (mavjud) | Homework (yangi) |
|---|---|---|
| Qamrov | 1 pack (5–6 so'z) | Butun unit (barcha pack'lar) |
| Tartib | Qat'iy: Tanishuv→Moslash→Imlo→Yig'ish | Tasodifiy aralash savollar |
| Baho | Yo'q | **Foiz, o'tish chegarasi 80%** |
| Maqsad | O'rganish | Baholash / mustahkamlash |

---

## 2. Kontent tahlili (400 beginner so'z) — dizaynga ta'siri

Implementatsiyadan oldin `words.json` tahlil qilindi. Ikki natija dizaynni **o'zgartirdi**:

| Topilma | Qiymat | Dizayn qarori |
|---|---|---|
| Ko'p so'zli ibora (2+ so'z) | **0 ta** | Construct = **faqat harf-plitka**. So'z-blok yig'ish (pack_flow'dagi `BuildStage`) beginner kontentida hech qachon ishlamaydi. Ibora chiqsa (kelajakdagi elementary) — bo'sh joy bo'yicha bo'linadi (arzon fallback) |
| Misolida so'zi haqiqatan bor | **295 / 400** (74%) | Fill faqat shu so'zlarga. Boshqasi → Choose'ga tushadi |
| Misoli bor-u so'zi yo'q | 1 ta | So'z chegarasi (`\b`) bilan tekshiriladi, aks holda bo'sh joy chiqmaydi |
| Takroriy uz tarjima | **11 ta** | **Kritik:** distraktor tanlashda `uz` bir xil bo'lganlari chiqarib tashlanadi — aks holda ikkita to'g'ri javob bo'ladi |
| `pos` bo'sh | ko'pchilikda | Distraktor: `pos` bir xil bo'lsa afzal, yetmasa tasodifiy |
| Fonetika | 0 ta | Homework'da fonetika ko'rsatilmaydi |
| en > 12 harf | 3 ta | Construct'da plitka o'lchami 12+ harfda kichrayadi (52→40px) |

---

## 3. Arxitektura

Yangi papka: `lib/screens/homework/`. `pack_flow.dart`ga **tegilmaydi** (u allaqachon 957 qator, maqsadi boshqa).

| Fayl | Mas'uliyat | Testlanadi |
|---|---|---|
| `homework_model.dart` | Sof mantiq: savol modeli, generatsiya, baho hisobi. Flutter UI'ga bog'liq emas | ✅ to'liq |
| `homework_flow.dart` | UI: savol ekranlari, progress, natija | qo'lda |

**Nega ajratildi:** savol generatsiyasi va baholash — xato ehtimoli yuqori mantiq (distraktor to'qnashuvi, foiz hisobi). UI'dan ajratilsa `flutter test` bilan tekshirsa bo'ladi, xuddi `srs.dart` kabi.

### 3.1 Modellar (`homework_model.dart`)

```
enum QuestionKind { choose, fill, construct, match }

class HwQuestion            // bitta savol
  kind, word (Word), options (List<String>), sentence (String?), matchWords (List<Word>)

class HwPlan                // butun test rejasi
  questions (List<HwQuestion>), totalPoints (int)

class HwResult              // yakuniy natija
  correct, total, percent, passed, xpEarned, wrongWords
```

### 3.2 Sof funksiyalar

| Funksiya | Vazifa |
|---|---|
| `buildPlan(unitWords, allWords, rnd)` | Savol navbatini quradi (quyidagi qoidalar bo'yicha) |
| `pickDistractors(target, pool, count, rnd)` | 3 ta distraktor — `uz` to'qnashuvisiz, `pos` afzal |
| `fillBlank(example, word)` | Misoldagi so'zni `____` ga almashtiradi (`\b`, katta-kichik harfga befarq); topolmasa `null` |
| `HwResult.percent` / `.passed` | Foiz (yaxlitlangan, faqat ko'rsatish uchun) va o'tish. `passed` **butun son arifmetikasi** bilan: `earned * 100 >= 80 * total` — kasr yaxlitlanishi 79.5% ni 80% qilib yubormasligi uchun |

---

## 4. Savol generatsiyasi qoidalari

1. **Pool** = unitning barcha vocab so'zlari (takrorsiz).
2. **Chegara yo'q** — unitdagi har bir so'z savolga aylanadi (foydalanuvchi qarori).
   Beginner kontentida bu 4 yoki 12 savol demakdir (34 unitning 33 tasida 12 ta so'z), shuning uchun test baribir qisqa. Kelajakdagi kattaroq unitlarda test ham uzunroq bo'ladi — bu kutilgan holat.
3. Har so'zga tur **indeks bo'yicha aniq** beriladi (tasodifiy emas — takrorlanadigan, testlanadigan):
   - `i % 3 == 2` → **Construct** (har uchinchi savol)
   - Aks holda, misolida so'zi bor → **Fill**
   - Aks holda → **Choose**
4. **Match** — pool ≥ 4 bo'lsa, oxirida **1 ta batch raund** (4–5 juft), tasodifiy so'zlardan.
5. Navbat aralashtiriladi; Match doim **oxirgi** (batch bo'lgani uchun).
6. **Distraktorlar:** avval o'sha unit so'zlaridan, yetmasa butun level'dan. Shartlar: `uz` ≠ target `uz`, `en` ≠ target `en`, takrorsiz.

**Ball:** har oddiy savol = 1 ball. Match raundi = juftlar soni ball (masalan 5 juft = 5 ball).
`totalPoints` = oddiy savollar + match juftlari.

---

## 5. Baholash (qat'iy rejim)

| Qoida | Qiymat |
|---|---|
| Ball beriladi | Faqat **birinchi urinish** to'g'ri bo'lsa |
| O'tish chegarasi | **80%** |
| SRS | To'g'ri → `Quality.good` (2 XP) · Xato → `Quality.unknown` (0 XP, SM-2 reset) |
| O'tish bonusi | **+10 XP** (faqat o'tsa) |
| "Bajarildi" belgisi | **Faqat 80%+** olganda |
| Qayta topshirish | Cheksiz — har safar savollar qayta generatsiya qilinadi |

### 5.1 Tuzatish raundi

Birinchi urinishda **xato qilingan so'zlar** test oxirida qayta so'raladi (`Choose` sifatida, to'g'ri bo'lguncha).
**Ballga ta'sir qilmaydi** — maqsadi o'rgatish, jazolash emas. Natija ekranidan oldin ko'rsatiladi.

### 5.2 Persistence

Yangi maydon **shart emas** — mavjud `Progress.completed` ishlatiladi:
`progress.markDone('hw::${unit.id}')` → ichkarida `beginner::hw::u1` bo'lib saqlanadi.
Tekshirish: `progress.isDone('hw::${unit.id}')`.

---

## 6. UI oqimi

```
Homework kartasi (unit ekranida)  →  savollar (1..N)  →  [Match raundi]  →  [tuzatish raundi]  →  natija
```

Alohida "boshlanish ekrani" **yo'q** — unit ekranidagi Homework kartasining o'zi boshlanish nuqtasi (so'z sonini va holatni ko'rsatadi). Ortiqcha bir bosish qo'shilmaydi.

- **Yuqori panel:** orqaga tugma, `Homework` sarlavhasi, sessiya XP hisoblagichi (pack_flow'dagi kabi), to'q sariq (`AppColors.homework`) progress chizig'i + `3 / 12`.
- **Choose / Fill:** so'z yoki bo'sh joyli gap + audio tugma (`RoundPlay`) + 4 variant. To'g'ri → yashil, xato → qizil + to'g'risi yashil bilan ochiladi.
- **Construct:** o'zbekcha ma'no + audio + aralashgan harf plitkalari (`SpellStage` ko'rinishi). **Farqi:** pack oqimidagi `SpellStage` to'g'ri bo'lguncha qayta urintiradi — testda esa **bitta urinish** (Choose/Fill bilan bir xil qoida), xato bo'lsa to'g'ri yozilishi ko'rsatilib keyingi savolga o'tiladi.
- **Match:** ikki ustun (en ↔ uz), moslangani yashil bo'ladi.
- **Natija:** doira ichida foiz, o'tdi/yiqildi, `X / Y to'g'ri`, XP pill, `Unitga qaytish` + `Qayta topshirish`.

### 6.1 Qayta ishlatiladigan komponentlar

`pack_flow.dart`dan: `RoundPlay` (audio tugma).
Widgets'dan: `Pressable3D` (`enabled` bilan), `showCorrectBurst`, `EntranceFade`.
**Yangi komponent yozilmaydi** — mavjud dizayn tili saqlanadi.

### 6.2 `unit_screen.dart` o'zgarishi

`_HomeworkCard` snackbar o'rniga `HomeworkFlow`ga o'tadi. Uch holat:

| Holat | Ko'rinish |
|---|---|
| So'z yo'q (bo'sh unit) | O'chirilgan (kulrang), "So'zlar yo'q" |
| Bajarilmagan | To'q sariq, "Mashqlarni boshlash" |
| Bajarilgan (80%+) | Yashil ✓, "Qayta topshirish" |

---

## 7. Chekka holatlar

| Holat | Yechim |
|---|---|
| Unit'da so'z yo'q | Homework kartasi o'chirilgan, oqim ochilmaydi |
| Pool < 4 so'z | Match raundi tashlanadi |
| Distraktor yetmaydi (kichik level) | Variantlar = target + topilgan distraktorlar (3 tagacha). Kamida **1 ta** distraktor bo'lsa savol qoladi (2 variantli); **0 ta** bo'lsa savol **Construct**'ga aylanadi |
| Fill uchun bo'sh joy chiqmadi | Choose'ga tushadi |
| Foydalanuvchi o'rtada chiqib ketdi | Natija saqlanmaydi (SRS javoblari esa saqlangan) — qayta boshlaydi |
| Elementary bo'sh | Unit yo'q → ekran ham yo'q (mavjud himoya yetarli) |

---

## 8. Test rejasi (`test/homework_test.dart`)

| Test | Tekshiradi |
|---|---|
| `buildPlan` savol soni | Har bir so'z aynan bitta savol beradi (chegara yo'q, so'z tushib qolmaydi) |
| `buildPlan` Match | Pool < 4 bo'lsa Match yo'q; ≥ 4 bo'lsa oxirida bitta |
| `buildPlan` tur taqsimoti | Har uchinchi savol Construct; misolsiz so'z hech qachon Fill emas |
| `pickDistractors` to'qnashuv | Distraktorlar ichida target `uz` yo'q (11 ta takroriy tarjima muammosi) |
| `pickDistractors` takror | Takrorlanmaydi, soni to'g'ri |
| `fillBlank` topdi | So'z `____` ga almashdi, katta-kichik harfga befarq |
| `fillBlank` topmadi | `null` qaytaradi (Choose'ga tushish uchun) |
| `fillBlank` qisman so'z | "present" so'zi "represent" ichida almashmaydi (`\b`) |
| `scoreOf` foiz | 80% chegarasi to'g'ri (79% yiqiladi, 80% o'tadi) |
| `scoreOf` match balli | Match juftlari ballga qo'shiladi |

Mavjud `test/srs_test.dart` (10 ta) buzilmasligi kerak.

---

## 9. Qamrovga KIRMAYDI (YAGNI)

- Homework natijalari tarixi / grafik (keyingi faza)
- Vaqt cheklovi (taymer)
- Grammatika yoki so'z-oilasi savollari (faqat vocabulary)
- Nutq (STT) mashqlari
- `pack_flow.dart` refaktoringi

---

## 10. Bajarish tartibi

1. `homework_model.dart` — sof mantiq
2. `test/homework_test.dart` — testlar (mantiq to'g'riligini tasdiqlash)
3. `homework_flow.dart` — UI ekranlari
4. `unit_screen.dart` — ulash + 3 holat
5. `flutter analyze` (0 lint) + `flutter test` (barchasi o'tadi)
6. **TO'XTASH** → foydalanuvchi `flutter run -d chrome` bilan sinaydi
