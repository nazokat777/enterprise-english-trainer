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
