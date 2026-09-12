# Dofamin dvigateli (Reward Engine) — dizayn

Sana: 2026-09-12. Ilova: `enterprise-app` (Flutter web).

## Maqsad

O'quvchi ilovadan chiqib ketishni xohlamasin. Neyrobiologik asos:
dofamin **kutilmagan mukofot** (variable ratio), **yaqin maqsad**
(goal gradient), **tugallanmagan ish** (Zeigarnik), **o'sish ko'rinishi**
(progress), **yig'ish** (endowment) va **darhol sezgi javobi**
(audio-vizual-haptik) bilan ishlab chiqariladi. Hozirgi ilovada XP, streak,
kombo va liga bor, lekin ular deyarli KO'RINMAYDI va hech qachon
"portlamaydi".

## Nima quriladi

### 1. `lib/reward/reward_engine.dart` — `RewardEngine` (ChangeNotifier, global `rewards`)

* **Daraja (level)**: `xpFor(level) = 60 * level^1.6`; 40 daraja, har
  daraja o'zbekcha unvon ("Yangi o'quvchi" → ... → "Til ustasi").
  Daraja oshganda `levelUp` hodisasi.
* **Kombo**: ketma-ket to'g'ri javoblar; xato → 0. Bosqichlar 3/5/10/20/50 →
  bonus XP (1/2/5/10/25) + `comboMilestone` hodisasi. Kombo ekranlar aro
  saqlanadi (sessiya ichida).
* **O'zgaruvchan mukofot** (har to'g'ri javobda): 12 % "KRIT" (XP ×2, oltin
  chaqnash), 4 % "gem" (+10 tanga). Tasodif — seedlanadigan `Random`.
* **Sirli sandiq**: 5–9 ta to'g'ri javobdan keyin (har safar tasodifiy)
  `chest` hodisasi. Sandiq **bosilib ochiladi** (kutish = dofamin): tanga
  5–30, XP 5–20, 5 % streak-freeze.
* **Kunlik topshiriqlar**: har kuni 3 ta, hovuzdan tasodifiy
  (N to'g'ri javob, N kombo, N mashq, N so'z, kunlik maqsad). Har biri
  tanga+XP; uchalasi → katta sandiq. `questDone` hodisasi.
* **Yutuqlar (achievements)**: ~24 ta, doimiy (`Set<String>`): birinchi
  mashq, 10/100/1000 to'g'ri, kombo 10/25, 3/7/30 kun streak, 5/10/20
  daraja, unit tugatish, 5 ta xatosiz mashq, tungi/ertalabki o'quvchi,
  1000 XP bir kunda va h.k. `achievement` hodisasi.
* **Sessiya statistikasi**: bu mashqdagi to'g'ri/xato, eng katta kombo,
  rekordlar (`newRecord`).
* Saqlash: `shared_preferences` (`rw_*` kalitlari).
* API: `onAnswer(bool ok, {int baseXp})`, `onExerciseDone({bool clean})`,
  `onWordLearned()`, `onDailyGoal()`, `tick()` (kun almashishi).
  `Stream<RewardEvent> events`.

### 2. `lib/reward/reward_overlay.dart` — global qatlam

`MaterialApp.builder` ichida, Navigator USTIDA. Hodisalarga qarab:

* **Uchuvchi XP** — "+2 ⚡" chiplar tepaga suzib so'nadi; KRITda katta
  oltin "+4 KRIT!" silkinish bilan.
* **Kombo meteri** — tepada o'rtada: raqam + olov; har bosqichda
  kattalashish, rang isishi (ko'k→sariq→qizil→binafsha), 10+ da ekran
  cheti yonadi (vignette pulse).
* **Level-up** — to'liq ekran: konfetti (CustomPainter, paketsiz),
  raqam "spring" bilan chiqadi, yangi unvon, "Davom et" tugmasi.
* **Sandiq** — modal; sandiq tebranadi, bosilganda ochiladi (300 ms
  kutish), mukofot chiqadi, tanga hisoblagichga uchadi.
* **Yutuq** — yuqoridan banner (medal + nom), 3 s, bosilsa yopiladi.
* **Topshiriq bajarildi** — pastdan toast.
* Navbat: bir vaqtda bitta modal; kichik effektlar parallel.

### 3. `lib/reward/sfx.dart` — ovoz + haptika

`audioplayers` paketi; `assets/sfx/*.wav` (Python bilan sintez qilinadi:
correct, wrong, combo, crit, coin, chest, levelup, quest, achievement).
Sozlamalarda "Ovoz effektlari" tugmasi (`progress.sfx`). Haptika:
`HapticFeedback.*` (web'da no-op, mobil'da ishlaydi).

### 4. UI ulanishlari

* **Header** (`shell.dart`): daraja halqasi (XP progress ring) + unvon;
  streak olovi jonli (pulsatsiya, 7+ kunda ko'k olov); kunlik maqsad
  halqasi to'lganda bir marta "portlaydi".
* **Bosh ekran** (`units_screen.dart`): "Bugungi topshiriqlar" kartasi
  (3 ta, progress chiziqlari, sandiq belgisi) — ochilishi bilan ko'rinadi.
* **Mashq natijasi** (`exercise_player._result`): raqamlar 0 dan sanab
  chiqadi (count-up), "Eng katta kombo", "Yangi rekord!" belgisi,
  keyingi mashqga o'tish tugmasi (zanjir uzilmasin).
* **Yutuqlar ekrani**: Sozlamalar ichida "Yutuqlar" — olingan/olinmagan
  medallar (qulflangan = kulrang silhouette, "yana 3 ta qoldi").
* Hooklar: `exercise_player._answered`, `drill_session`, `lesson_session`,
  `pack_flow`, `homework_flow` → `rewards.onAnswer`. `Progress.addXp` →
  `rewards.onXp` (daraja hisobi).

### 5. Testlar

* `test/reward_engine_test.dart`: daraja egri chizig'i, kombo bosqichlari,
  sandiq kadensi (5–9), kunlik topshiriq generatsiyasi/rollover, yutuq
  ochilishi, saqlash/yuklash.
* Mavjud 326 test o'tishi shart (overlay 320 px da sig'adi).

## Qamrovdan tashqari

Onlayn liga/do'stlar, push-bildirishnoma, haqiqiy maskot animatsiyasi.

---

## 2-bosqich (2026-09-12, kechki): hissiy bog'lanish va yo'qotish qo'rquvi

1-bosqich "mukofot" edi; 2-bosqich "MUNOSABAT" va "YO'QOTMASLIK":

* **Hamroh (maskot)** — darajaga qarab evolyutsiya (tuxum → jo'ja → ... →
  ajdar), kayfiyati bugungi faollikka bog'liq (uxlayapti / xursand /
  yonib turibdi), gap pufagida kontekstli gaplar. Bosh ekranda va
  natijada. Endowment + g'amxo'rlik instinkti.
* **Streak xavfi** — bugun 0 XP bo'lsa bosh ekranda qizil karta + yarim
  tungacha hisoblagich. Loss aversion (yo'qotish qo'rquvi yutuqdan 2×
  kuchli).
* **Faollik xaritasi** — 12 haftalik issiqlik xaritasi (GitHub uslubi).
  Ko'rinadigan sarmoya = tashlab ketish qiyin.
* **Kunlik g'ildirak (spin)** — kuniga bir marta, 5 ta to'g'ri javobdan
  keyin ochiladi; 8 sektor, og'irlikli tasodif. Variable reward + rasm-
  rusum (ritual).
* **Baxtli soat** — har kuni sanaga bog'liq 1 soatlik ×2 XP oynasi
  (08–22 orasida). Header'da hisoblagich. Scarcity + urgency.
* **Liga ko'tarilishi** — Bronze → ... → Diamond o'tishida to'liq ekran
  nishonlash.

Dvigatel: `dayXp` (90 kun), `happyHour`, `spin()`, `leagueIndex`.

## 3-bosqich: lahza ichidagi his (micro-moments)

* **Oltin savol** — 8 % savol oldindan "×3 XP" deb e'lon qilinadi
  (anticipation dofamini javobdan OLDIN chiqadi).
* **Tezlik bonusi** — 3 soniyadan tez to'g'ri javob → "TEZ! +1"
  (ravonlik/fluency, arousal).
* **Qaytish bonusi** — xatodan keyingi birinchi to'g'ri javob →
  "QAYTISh! +1". Tashlab ketish eng ko'p xatodan keyin bo'ladi; darhol
  tiklanish hissi uni yopadi (resilience).
* **Deyarli!** — yig'ish mashqida 1 harf farq bo'lsa "near-miss" izohi:
  miya buni deyarli g'alaba deb o'qiydi, umidsizlik o'rniga urinish.
* **Rag'bat so'zlari** — "To'g'ri" o'rniga har safar boshqa so'z
  (Zo'r! Qoyil! Barakalla! ...) — kutilmaganlik.
* **Haftalik o'sish** — faollik xaritasida "+40 % hafta" (o'z-o'zi bilan
  raqobat).
* **"Yana N ta qoldi — oz qoldi!"** — unit kartasida 5 va undan kam
  mashq qolganda (goal gradient).
