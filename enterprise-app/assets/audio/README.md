# Audio fayllar — shu papkaga joylashtiriladi

Bu papka **faqat lokal (oilaviy) build uchun**. Ichidagi audio fayllar
`.gitignore` da — GitHub'ga ham, Vercel'ga ham **chiqmaydi**. Faqat shu
README yuklanadi.

Sabab: Express Publishing "Enterprise" audio CD'lari mualliflik huquqi bilan
himoyalangan. Kitob va audio egasining o'z nusxasidan olinadi.

---

## Papka tuzilishi

```
assets/audio/
  README.md              ← shu fayl
  enterprise1/
    coursebook/          ← Coursebook (Student's Book) audiosi
    workbook/            ← Workbook audiosi (agar alohida bo'lsa)
```

Agar audio CD bo'yicha bo'lsa (CD1, CD2, CD3), shunday qo'ying:

```
    coursebook/
      cd1/
      cd2/
      cd3/
```

---

## Fayl nomlari

Nom qanday bo'lishidan qat'i nazar **o'zgartirmasdan** tashlab qo'ying —
keyin men xarita (`audio_map.json`) yozaman va har mashqni to'g'ri trekka
bog'layman.

Lekin agar nomlarni o'zingiz tartibga solmoqchi bo'lsangiz, eng qulayi:

```
cb_p97_ex14.mp3       ← Coursebook 97-bet, 14-mashq
cb_p101_ex11.mp3
```

---

## Format

- **MP3** eng qulay (Flutter web va mobil ikkalasida ham ishlaydi)
- M4A, OGG, WAV ham bo'ladi
- CD'dan olingan bo'lsa: 128 kbps mono yetarli — hajmi kichik bo'ladi

---

## Keyin nima bo'ladi

Fayllar joylashgach:

1. `pubspec.yaml` ga `assets/audio/` qo'shiladi
2. `just_audio` paketi ulanadi
3. `audio_map.json` yoziladi — har bet/mashq uchun:
   fayl nomi + boshlanish/tugash vaqti
4. Mashq ekranida **▶ tugma** chiqadi

Modelda `audio` va `audioNoteUz` maydonlari **allaqachon bor**
(`lib/book_content.dart`) — faqat fayl yo'li qo'shiladi.

---

# HOLAT

Baza **to'liq**: uchala kitob ham oxirigacha yozilgan.

| Kitob | Betlar |
|---|---|
| Coursebook | 159 / 159 |
| Workbook | 80 / 80 |
| Grammar Book | 77 / 77 |
| **Jami** | **316 bet**, 10 455 band, 8978 lug'at yozuvi |

Butun bazada **atigi 33 band** audiosiz yopilmadi. Ular taxmin bilan
**to'ldirilmagan** — mashq ichida `⚠ AUDIODAN ANIQLANADI` deb ochiq
qoldirilgan, chunki noto'g'ri javob yozgandan ko'ra ochiq qoldirgan
yaxshiroq.

---

## A. Audio kerak — 33 band ochiq

| Bet | Mashq | Ochiq | Nima kerak |
|-----|-------|-------|------------|
| CB **95** | Ex.10a | 2 | Tokyo va New York ob-havo belgisi |
| CB **97** | Ex.14 | 10 | o'n bashoratning W (ayol) / M (erkak) taqsimoti |
| CB **101** | Ex.11 | 4 | MUST / CAN'T / CAN |
| CB **107** | Ex.13 | 5 | ✓ yoki ✗ |
| CB **109** | Ex.19 | 11 | qaysi javob qaysi savolga mos |
| CB **111** | Ex.2 | 1 | 4-band: kim aytdi |

---

### 1. CB 95-bet, Ex.10a — ob-havo jadvali

Sakkiz shahardan **oltitasi kitobning o'zidan** aniqlangan:
Bangkok = sunny, Dublin = foggy, Harare = windy, Seoul = rainy,
Sydney = sunny, Warsaw = snowy.

| Shahar | Variantlar |
|---|---|
| **Tokyo** | foggy yoki rainy? |
| **New York** | windy yoki foggy? |

---

### 2. CB 97-bet, Ex.14 — W / M

"What will life be like in 30 years' time?" — o'nta bashorat.
Har birining yoniga **W** (ayol aytdi) yoki **M** (erkak aytdi) qo'yiladi.

⚠ Bu ma'lumot **faqat audioda** bor — kitobda hech qanday ip yo'q.

| № | Bashorat | W / M |
|---|---|---|
| 1 | People will travel in flying cars. | ? |
| 2 | People will live in underwater cities. | ? |
| 3 | Life will be more expensive. | ? |
| 4 | People will go on holiday to the moon. | ? |
| 5 | There will be more people in the world. | ? |
| 6 | Pollution will be worse. | ? |
| 7 | There won't be enough trees. | ? |
| 8 | People will use oxygen masks to breathe. | ? |
| 9 | There will be food pills instead of fresh food. | ? |
| 10 | There won't be enough water for everyone. | ? |

---

### 3. CB 101-bet, Ex.11 — Mrs Battersby va ijarachi

Uy egasi yangi ijarachiga qoidalarni aytadi. Jadvalda **10 qator**.

**6 tasi kitobning o'zidan yopilgan:**
keep pets = CAN'T · play loud music = CAN'T · use the telephone = CAN ·
make the bed = MUST · keep the room clean = MUST · be home by 11 pm = MUST

**4 tasi ochiq:**

| Qator | MUST / CAN'T / CAN? |
|---|---|
| have parties in the room | ? |
| have a TV in the room | ? |
| put posters on the walls | ? |
| pay the rent on time | ? |

---

### 4. CB 107-bet, Ex.13 — Parij sayohati

Etti qatordan **2 tasi kitobda berilgan**:
Eiffel Tower = ✓ · Versailles = ✗

**5 tasi ochiq** — betning hech yerida yozilmagan:

| Qator | ✓ / ✗ |
|---|---|
| the Louvre | ? |
| Notre Dame | ? |
| a boat trip on the Seine | ? |
| Montmartre | ? |
| the Champs-Elysees | ? |

⚠ Aniq nomlarni audio bilan solishtiring — betdagi ro'yxat tartibi
saqlangan.

---

### 5. CB 109-bet, Ex.19 — savol-javob mosligi

⚠ Bu mashqda **savollar bosilmagan** — kitobda faqat ikkitadan javob
varianti bor. Ya'ni savol audioda aytiladi.

Grammatik jihatdan **faqat 4-band** aniqlanadi:
`Yes, I loved` — noto'g'ri ingliz tili, demak ikkinchi variant to'g'ri.

Qolgan **11 band** audiodan aniqlanadi. Har biri uchun JSON'da
"qaysi savolga qaysi javob mos keladi" tahlili bor — audio bilan
solishtirish oson bo'ladi.

---

### 6. CB 111-bet, Ex.2 — kim aytdi

1, 2, 3-bandlar 110-betdagi komiksdan **aniq** aniqlanadi
(gap pufakchalarining dumi kimga ishora qilishidan).

**4-band** esa faqat naqsh asosida taxmin qilinadi — audio tasdiqlashi
kerak.

---

## B. To'ldirilgan, lekin tasdiq kerak — 4 band

### CB 81-bet, Ex.21 — "Listen to the story"

Tonining hikoyasi, sakkiz bo'shliq ravishlar bilan to'ldiriladi.
Kitob faqat **a** bandini bergan (`suddenly`). Qolganlari matn mantiqidan
chiqarilgan — to'rttasi ishonchli, to'rttasi **tekshirilsin**:

| Band | Gap | Javob |
|---|---|---|
| a | Tony ...... heard noises. | suddenly *(kitob bergan)* |
| b | He went ...... to the window. | sleepily |
| c | He ran ...... downstairs. | **nervously** ← tekshirilsin |
| d | He ...... rushed upstairs. | **immediately** ← tekshirilsin |
| e | He closed the door ...... . | tightly |
| f | "Help!" he shouted ...... . | desperately |
| g | He climbed ...... onto a ladder. | **quickly** ← tekshirilsin |
| h | He climbed ...... down. | **carefully** ← tekshirilsin |

---

## C. Audio KERAK EMAS — chalkashmaslik uchun

Kitobda **"listen and check"** deb yozilgan, lekin javob betning o'zida
bosilgan bo'lgan mashqlar. Bular allaqachon **to'liq yopilgan**, audio
faqat talaffuz uchun kerak:

CB 82 (Ex.3) · CB 86 (Ex.16, 17) · CB 87 (Ex.19a) · CB 89 (Ex.2, 5) ·
CB 92 (Ex.1b, 2) · CB 96 (Ex.12a) · CB 98 (Ex.3) · CB 99 (Ex.6) ·
CB 100 (Ex.7a) · CB 102 (Ex.14) · CB 104 (Ex.3) · CB 108 (Ex.17a, 18) ·
CB 110 · CB 112 · CB 113 (Ex.2)

Har birida sabab JSON'ning `audioRequiredUz` maydonida yozilgan.

---

## Eng tez yo'l

Yuqoridagi **A** bo'limidagi 6 ta mashqni tinglab javoblarni aytsangiz —
JSON'larga kiritaman va baza **100 % yopiladi**. Butun audio pleerni
qurish shart emas.

**B** bo'limidagi 4 ta ravishni ham o'sha paytda tasdiqlab qo'yish mumkin.

---

## Qayta skanerlash kerak bo'lgan betlar

Audioga aloqasi yo'q, lekin shu yerda qayd etilsin — bu betlar
skanerga tushmagan:

| Kitob | Bet | Nima yo'q |
|---|---|---|
| Grammar | 71, 73 | Progress Tests 1 va 2 |
| Coursebook | 123 | Word List: 10-unit oxiri, 2-hikoya 2-epizodi, 11-12-unitlar, 13-unit boshi |
| Coursebook | 4 | kirish qismidagi bet (mundarija bilan Introduction orasida) |
