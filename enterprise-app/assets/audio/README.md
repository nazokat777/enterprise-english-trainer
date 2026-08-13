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
u13_ex14.mp3          ← 13-unit, 14-mashq
u13_ex21.mp3
cb_p97_ex14.mp3       ← Coursebook 97-bet, 14-mashq
```

---

## Format

- **MP3** eng qulay (Flutter web va mobil ikkalasida ham ishlaydi)
- M4A, OGG, WAV ham bo'ladi
- CD'dan olingan bo'lsa: 128 kbps mono yetarli — hajmi kichik bo'ladi

---

## Keyin nima bo'ladi

Fayllar joylashgach, men quyidagilarni qilaman:

1. `pubspec.yaml` ga `assets/audio/` qo'shaman
2. `just_audio` paketini ulayman
3. `audio_map.json` yozaman — har bet/mashq uchun:
   fayl nomi + boshlanish/tugash vaqti
4. Mashq ekranida **▶ tugma** chiqaradi

Modelda `audio` va `audioNoteUz` maydonlari **allaqachon bor**
(`lib/book_content.dart`, 157-158-qatorlar) — faqat fayl yo'li qo'shiladi.

---

## Hozircha ochiq qolgan 4 mashq

Butun bazada (220 bet, ~4900 band) faqat **shu to'rttasi** audioga muhtoj.
Qolgan hammasi kitob matnidan yopilgan.

| Bet | Mashq | Nima kerak |
|-----|-------|------------|
| Coursebook **81** | Ex.21 | c, d, g, h bandlaridagi ravishlar |
| Coursebook **95** | Ex.10a | Tokyo va New York ob-havo belgisi |
| Coursebook **97** | Ex.14 | 10 bashoratning W (ayol) / M (erkak) taqsimoti |
| Coursebook **101** | Ex.11 | 4 qator: MUST / CAN'T / CAN |

Batafsil ro'yxat — pastda.

---

### 1. Coursebook 81-bet, Ex.21 — "Listen to the story"

Tonining hikoyasi. Sakkiz bo'shliq, ravishlar bilan to'ldiriladi.
**b, c, d, g, h** — mening taxminim, **tasdiqlash kerak**:

| Band | Gap | Mening javobim |
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

### 2. Coursebook 95-bet, Ex.10a — ob-havo jadvali

Sakkiz shahardan **oltitasi kitobning o'zidan aniqlangan**:
Bangkok = sunny, Dublin = foggy, Harare = windy, Seoul = rainy,
Sydney = sunny, Warsaw = snowy.

Ikkitasi ochiq:

| Shahar | Variantlar | Kerak |
|---|---|---|
| **Tokyo** | foggy yoki rainy? | qaysi biri? |
| **New York** | windy yoki foggy? | qaysi biri? |

---

### 3. Coursebook 97-bet, Ex.14 — W / M

"What will life be like in 30 years' time?" — o'nta bashorat.
Har birining yoniga **W** (ayol aytdi) yoki **M** (erkak aytdi) qo'yiladi.

| № | Bashorat | W yoki M? |
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

### 4. Coursebook 101-bet, Ex.11 — Mrs Battersby va ijarachi

Uy egasi yangi ijarachiga qoidalarni aytadi. Jadvalda **10 qator**,
har biriga MUST / CAN'T / CAN dan bittasi belgilanadi.

**6 tasi kitobning o'zidan yopilgan:**

| Qator | Javob | Qayerdan |
|---|---|---|
| keep pets | CAN'T | kitobda ✓ berilgan |
| play loud music | CAN'T | Ex.12 namuna dialogi |
| use the telephone | CAN | Ex.12 namuna dialogi |
| make the bed | MUST | Ex.12 namuna dialogi |
| keep the room clean | MUST | grammatika qutisi |
| be home by 11 pm | MUST | Grammar Book 60-bet |

**4 tasi ochiq:**

| Qator | MUST / CAN'T / CAN? |
|---|---|
| have parties in the room | ? |
| have a TV in the room | ? |
| put posters on the walls | ? |
| pay the rent on time | ? |

---

**Eng tez yo'l:** shu to'rtta mashqni tinglab, javoblarni menga aytsangiz —
JSON'larga kiritaman va baza 100% yopiladi. Butun audio pleerni qurish
shart emas.
