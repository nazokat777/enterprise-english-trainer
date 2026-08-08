# Enterprise English Trainer — Flutter qayta dizayni (Design Spec **v2**)

**Sana:** 2026-08-08
**Holat:** Yo'nalish tasdiqlangan. v2 = "ULTRA PRO PROMPT" g'oyalari **Flutter/bepul/offline** stekka moslashtirildi.
**Maqsad:** Enterprise (Express Publishing) darsligi asosida gamifikatsiyalangan, spaced-repetition, **video komponentisiz** (audio+matn+interaktiv mashq urg'uli) ingliz tili ilovasi. Referens dizayn/UX: yuborilgan prompt (Englify-ilhomli) + `LEARN ARABIC EASILY` (Flutter pattern'lari).

---

## 0. Reconciliation — prompt ↔ bizning cheklovlar

Prompt React+Node+Postgres, multiplayer, pullik AI deb yozilgan. Foydalanuvchi qarori: **Flutter Web (bepul/offline/bitta foydalanuvchi)** stekda qolamiz, promptning **g'oyalari/oqimlari/dizaynini** olamiz. Moslashtirish:

| Prompt talabi | v2 dagi yechim (bepul/offline) |
|---|---|
| React+TS+Vite+Tailwind | **Flutter Web** (bir xil natija: SPA, dark mode, komponentli) |
| Node+Express+Postgres+Prisma | **Backend yo'q** — Dart modellar + JSON asset + `shared_preferences` (progress/stats) |
| Ierarxik URL (`/unit/:id/...`) | Flutter `Navigator` + nomli route'lar (bir xil ierarxiya, URL emas) |
| Prisma schema | **Dart data-model + JSON** (§4) — bir xil entity'lar |
| Battle: AI / Duel / Group | **Faqat AI ga qarshi** (offline, kompyuter raqib). Duel/Group tashlanadi |
| Leaderboard (multiplayer) | **Shaxsiy rekordlar/tarix** (bitta foydalanuvchi) |
| AI chatbot (nutq) | **Web Speech API (STT) + skriptli dialog** — generativ LLM emas (pullik emas). Cheklov §9.4 |
| "oldindan yozilgan audio fayllar" | **TTS** (`flutter_tts`, en-US/en-GB) — copyright-safe. Audio fayl saqlanmaydi |
| VIDEO YO'Q (o'quv o'zagida) | To'g'ri — o'zakda video yo'q. Media bo'limida **ixtiyoriy** YouTube embed (foydalanuvchi so'ragan, §8) |

---

## 1. Stek va asosiy qarorlar

| Qaror | Tanlov |
|---|---|
| Frontend | **Flutter Web** (client-side SPA, offline, Vercel) |
| Persistence | `shared_preferences` (web = IndexedDB/localStorage) — progress, stats, SRS |
| Kontent | `structured.json` (har daraja) → **JSON asset** (build-time skript) |
| Audio | `flutter_tts` (en-US/en-GB) + audio pleyer (0.5x–2x) |
| Shrift | **Geist** (OFL, bepul) — `google_fonts` yoki asset sifatida bundle |
| Darajalar | **Beginner** (Enterprise 1, tayyor) + **Elementary** (OCR kerak) — header almashtirgich |
| Dark mode | To'liq (ThemeMode + AppColors light/dark, `class`-uslub ekvivalenti) |
| Deploy | Vercel + GitHub Actions (`flutter build web`) |
| Foydalanuvchi | Bitta (egasi) — auth/multiplayer yo'q |

> **Copyright:** PDF/rasmiy audio/video ommaviy deploy'da qayta chop etilmaydi. Faqat lug'at/qoida ma'lumotlari (shaxsiy o'rganish), TTS audio, public-domain manbalar, qonuniy embed.

---

## 2. Ma'lumotlar modeli (Dart + JSON — Prisma ekvivalenti)

Prisma entity'lari **Dart class + JSON asset + `shared_preferences`**ga xaritalanadi. SQL yo'q.

**Kontent (asset, faqat o'qish — `assets/content/<level>/`):**
- `Level` — `{id, name:"Beginner"/"Elementary", cefr, order}` (2 ta, kod ichida)
- `Unit` — `{id, levelId, code:"Unit 1", title, order, isRevision}`
- `Component` — `{id, unitId, type: VOCABULARY|HOMEWORK, order}`
- `VocabPack` — `{id, componentId, name:"Pack 1", order}`
- `Word` — `{id, packId, english, translation(uz), partOfSpeech, phonetic, example(bold target), audio: TTS}`
- `Exercise` — `{id, componentId, tokenId, mechanic: CHOOSE|CONSTRUCT|MATCH|FILL, topic: GRAMMAR|LISTENING, title, maxScore}`
- `ExerciseItem` — `{id, exerciseId, prompt, options[], correctAnswer, hint?}`

**Progress/stats (`shared_preferences`, o'zgaruvchan — daraja prefiksli kalitlar):**
- `WordProgress` — `{wordKey, srsStage, nextReviewAt, correctCount}` (kalit: `beginner::word-0007`)
- `UserExercise` — `{exerciseKey, score, done}`
- `UserStats` — `{xp, coins, rank, skillListening, skillGrammar, skillVocab, skillReading, skillWriting, streak, lastActiveDay}` (global)
- `BattleHistory` — `[{type:"AI", lobby, score, date}]` (shaxsiy rekord)

### 2.1 Kontent ierarxiyasini structured.json'dan qurish (cheklov + yechim)
`structured.json` **tekis** (so'zlar "Module (Units X-Y)" tegi bilan; per-unit tuzilma yo'q). Shuning uchun build-skript **taxminiy** ierarxiya yasaydi:
- `Module` → bir nechta `Unit` (masalan har ~12 so'z = 1 Unit).
- Har `Unit` → `VOCABULARY` komponenti (2–3 `Pack`, 5–6 so'zdan) + `HOMEWORK` komponenti (shu unit so'zlari/grammatika/word-formation'dan yasalgan mashqlar).
- `isRevision` — har 4-unit revision deb belgilanadi.
> Yaxshiroq per-unit tuzilma keyin OCR'ni takomillashtirib olinadi. Hozir taxminiy guruhlash yetarli.

### 2.2 Kamaytirilgan maydonlar (bepul boyitish)
- **`phonetic`** (`/juː/`): structured.json'da yo'q → build-time **CMU Pronouncing Dictionary** (public-domain) orqali ARPAbet→IPA generatsiya. Topilmasa — yashiriladi.
- **`partOfSpeech`** (Olmosh/Bog'lovchi...): ko'pi "—" → build-time oddiy POS (misol gapdan) yoki generic "so'z". Ixtiyoriy.
- **`example`**: 296 toza/104 shovqin (§3). Target so'z **bold** qilinadi.

---

## 3. Kontent pipeline

### 3.0 Darajalar
| Daraja | Manba | Holat |
|---|---|---|
| **Beginner** | `enterprise-1-*` | ✅ `structured.json` tayyor (400/67/12) |
| **Elementary** | `Enterprise_Elementary_*` (`Enterprise PDF/Elementary/`) | ⏳ OCR kerak |

**Elementary ingestion:** PDF → `ingest.pdf_extract` (Tesseract OCR) → `ingest.structure` → `structured-elementary.json`.

### 3.1 Asset generatsiyasi
`ingest/export_assets.py` (yangi): har daraja `structured.json` → ierarxiya (§2.1) + tozalash + CMU fonetika → `assets/content/<level>/` (`units.json`, `words.json`, `exercises.json`, `media.json`). Build-time (runtime emas).

**Misol gap tozalash:** noisy heuristika (caps-run, junk-token, `....`/`eeee`, weird-char>3, harf<60%) → noisy bo'lsa `example=""`.

---

## 4. Dinamik SRS — SM-2 (ilg'or prompt §1) ✅ QURILDI

Statik 1→3→7→30 o'rniga **SM-2** (soddalashtirilgan):
- Har so'z: `easeFactor` (default 2.5, min 1.3), `interval` (kun), `repetitions`.
- 4 baho tugmasi: **Bilmadim** (q=1) · **Qiyin** (q=3) · **Yaxshi** (q=4) · **Oson** (q=5).
- Algoritm: `q<3` → `repetitions=0, interval=1`; aks holda rep 0→`iv=1`, 1→`iv=6`, ≥2→`iv=round(iv*EF)`, `rep++`. Har holatda `EF=max(1.3, EF+(0.1-(5-q)*(0.08+(5-q)*0.02)))`. `nextReviewAt=now+iv kun`.
- **Recall-probability:** rejalashtirilgan interval nuqtasida ~0.9 (retention 85–90%); 0.9 dan past → takror.
- **Lug'at 3 toifa:** "Yangi" (ko'rilmagan) · "O'rganilayotgan" (`iv<21`) · "Barcha"; `iv≥21` (mature) → ma'lum.
- "Bugun takrorlanadigan" queue + sidebar **Due badge**. Per-daraja kalitlar.

`lib/srs.dart`: `WordSrs`, `Quality`, `review(q)`, `recallProbability(now)`, `isDue/isNew/isKnown`. Testlar (`test/srs_test.dart`): interval 1/6/round, xatoda reset, EF kamayishi, isDue/isNew. ✅

---

## 5. Dizayn tizimi (promptdan — aniq qiymatlar)

**Shrift:** Geist (sans). Body 16px/400, sarlavha 24px/700.

**Ranglar (`AppColors`):**
- Light fon `#F5F6FA`, Dark fon `#25272D`
- Sarlavha matni `#28004D` (to'q binafsha)
- Harakat tugmasi `blue-600` (`#2563EB`)
- Aksentlar: **yashil** to'g'ri (`#16A34A`), **to'q sariq** homework/leaderboard (`#EA580C`), **sariq** coin (`#F59E0B`), **binafsha** brend/vocabulary (`#7C3AED`)
- Neutral border/soya: `#C9CDE3`

**Radiuslar:** 8 / 12 / 16 / pill 9999.

**Neomorfik 3D tugma:** `box-shadow: 0 4px 0 0 #C9CDE3` → bosilganda pastga tushadi (Flutter: `AnimatedContainer` + `Transform.translate` yoki soya o'zgarishi). `PressableScale`/`Pressable3D` widget.

**Orqa fon:** subtil geometrik naqsh (uchburchak/doira/X) — `CustomPainter`, past opacity.

**Dark mode:** to'liq — fon/matn o'zgaradi, brend/funksional ranglar saqlanadi. `ThemeMode` + header toggle, `shared_preferences`da saqlanadi.

**Animatsiya:** `EntranceFade` (staggered), `Pressable3D`, katta yashil **"To'g'ri ✓"** pastdan chiqish animatsiyasi, `ZoomPageTransitions`.

---

## 6. Ekranlar / navigatsiya

### 6.1 Layout — `AppShell`
- **Chap sidebar:** Darslar · Resuslar · Suhbatlar · Sozlamalar · Yordam · Chiqish. (Mobil: pastki nav yoki drawer.)
- **Header:** logo · **LevelSwitcher** (`Beginner ▾`/`Elementary`) · dark-mode toggle · 🔥streak · XP/coin · profil.

### 6.2 Darslar (game-map) — `LessonMapScreen`
Duolingo uslubi: punktir yo'l bilan bog'langan **Unit tugunlari**, har tugunda **progress %**, bulut/yulduzcha bezaklar. Tugunga bosilsa → `UnitScreen`.

### 6.3 `UnitScreen`
Komponent kartalari (videosiz): **Vocabulary** (Pack'lar) + **Homework** (mashqlar). Har kartada progress bar + ballari.

### 6.4 Lug'at oqimi — `VocabPackFlow` (prompt 4 bosqichi)
Pack (5–6 so'z), ketma-ket:
1. **Tanishtirish** — so'zlar birma-bir "Keyingi" bilan. Har karta: 🇬🇧 bayroq, **so'z turkumi**, inglizcha so'z, 🔊 talaffuz (TTS), **fonetik** (`/juː/`), **kontekst misol** (target **bold**), o'zbekcha tarjima.
2. **Moslash** — 2 ustun (EN / UZ), to'g'ri juftlik **darhol yashil**.
3. **Audio + Imlo** — so'zni 🔊 eshit → aralash harflardan yig'ish.
4. **So'z-bo'lak yig'ish** — iboralar uchun bo'laklardan ("on"+"holiday").
- Har to'g'ri javobda katta yashil **"To'g'ri ✓"** animatsiyasi. Har javob `srs.answer()`.

### 6.5 Mashqlar — 4 qayta-ishlatiladigan komponent (§7)
### 6.6 Grammar/Word-formation — HOMEWORK komponentlarida mashq sifatida (Choose+Grammar, Construct, Fill).
### 6.7 Resuslar (Media) — §8.  ### 6.8 Suhbatlar (nutq) — §9.4.  ### 6.9 Battle/Leaderboard — §9.

---

## 7. Mashqlar tizimi (4 reusable komponent)

Har mashq: **MEXANIKA teg** (yashil: Choose/Construct) + **MAVZU teg** (to'q sariq: Grammar/Listening) + **XP (⚡ chaqmoq)** + **coin (🪙)** indikatorlari + **progress bar**. Oxirida **"Yuborish"** → tekshirish + feedback.

1. **CHOOSE + LISTENING** (`ListeningCloze`): tepada **audio pleyer** (progress bar, `00:00/00:15`, tezlik `0.5x/1x/1.5x/2x`, ovoz — TTS). Pastda dialog `___` bo'sh joylar bilan; har bo'sh joy tagida **3 variant**. Tanlangan so'z bo'sh joyga tushadi + **"×"** o'chirish.
2. **CHOOSE + GRAMMAR** (`GrammarChoose`): gaplarni variant tanlab to'ldirish (grammar cloze).
3. **CONSTRUCT / REARRANGE** (`SentenceBuilder`): aralash so'z-tugmalarni to'g'ri tartibda bosib gap tuzish; **"Misol: ..."** hint rangli.
4. **FILL / COMPLETE DIALOGUE** (`DialogueFill`): dialogni so'z/iboralar bilan to'ldirish.

Umumiy: `ExerciseScaffold` (teglar+ball+progress), `AudioPlayer` widget, feedback+XP/coin berish.

---

## 8. Resuslar / Media (Faza 10)

Gradient banner kartalar (**video YO'Q — o'quv o'zagida**; media bo'limi ixtiyoriy): **Kitoblar** (Gutenberg reader), **Podkastlar** (bepul RSS/audio), **Videolar** (qonuniy **YouTube embed**, faqat `videoId`), **Eksklyuzivlar/Level Podcast** (muallif kontenti). Hammasi **bepul/ochiq/qonuniy**, fayl saqlanmaydi. Interaktiv qatlam: so'z-tap → ma'no+TTS+lug'atga saqlash, mini-quiz.

---

## 9. Gamifikatsiya va ijtimoiy (bitta foydalanuvchiga moslashgan)

- **XP (⚡) + coin (🪙) + rank** — `UserStats`. To'g'ri javob → XP/coin.
- **Ko'nikma statistikasi:** Lug'at/Yozish/O'qish/Tinglash/Grammatika (%). Mashq turiga qarab mos ko'nikma oshadi.
- **9.1 Battle — faqat AI ga qarshi:** offline Kahoot-uslubidagi tezkor viktorina (2 lobbi: Grammar/Vocabulary). Kompyuter raqib (turli qiyinlik). Duel/Group YO'Q.
- **9.2 Leaderboard = shaxsiy rekordlar:** o'z natijalaringiz tarixi/eng yaxshi ball (multiplayer emas).
- **9.3 Motivatsion xabarlar:** skriptli (streak, maqsad, tabrik).
- **9.4 Suhbatlar (nutq mashqi):** **Web Speech API (STT)** + **skriptli dialoglar** — foydalanuvchi gapiradi, javob kutilgan iboraga solishtiriladi (talaffuz/javob tekshiruvi). **Generativ AI emas** (pullik LLM yo'q). *Cheklov: haqiqiy erkin suhbat uchun keyin (ixtiyoriy) pullik LLM kerak bo'ladi.*

---

## 10. Kod tuzilishi (Flutter)

```
enterprise-app/
├── pubspec.yaml                # flutter, shared_preferences, google_fonts, flutter_tts, url_launcher, (web) HtmlElementView (YouTube embed)
├── assets/
│   ├── content/{beginner,elementary}/  # units.json, words.json, exercises.json, media.json
│   └── fonts/geist/            # Geist (OFL) — google_fonts topilmasa
├── lib/
│   ├── main.dart               # ArabApp→EnterpriseApp, AppShell, ThemeMode
│   ├── theme.dart              # AppColors(light/dark) + AppTheme(Geist) + Pressable3D
│   ├── content.dart            # modellar + ContentRepository (per-daraja) + currentLevel
│   ├── srs.dart                # WordProgress + stage(1/3/7/30) + due/kategoriya
│   ├── stats.dart              # UserStats (xp/coins/rank/skills/streak) + Battle history
│   ├── grading.dart            # fuzzy grade (imlo tolerant)
│   ├── widgets/{entrance,pressable3d,level_switcher,audio_player,correct_burst,geo_bg}.dart
│   ├── services/{tts,speech}.dart   # TTS + Web Speech STT
│   └── screens/
│       ├── shell.dart          # sidebar + header
│       ├── lesson_map.dart     # game-map
│       ├── unit_screen.dart
│       ├── resources.dart · battle.dart · leaderboard.dart · conversations.dart · settings.dart
│       ├── pack/{intro,match,audio_spell,block_build}.dart   # 4 bosqich
│       └── exercise/{scaffold,listening_cloze,grammar_choose,sentence_builder,dialogue_fill}.dart
└── .github/workflows/deploy.yml
```

---

## 11. Deploy · Testlar
- **Deploy:** Vercel + GitHub Actions (`flutter build web`), Arabic `deploy.yml` nusxasi.
- **Testlar (TDD):** `srs_test` (stage/reset/due), `grading_test`, `content_test` (asset yuklanadi, id noyob), pack/exercise widget smoke-testlar.

---

## 12. Implementatsiya bosqichlari (prompt 10-qadam tartibi, Flutter'ga)

1. **Skelet + tema:** Flutter loyihasi, `theme.dart` (Geist, ranglar, radius, dark mode, Pressable3D, geo-bg), `EntranceFade`.
2. **Layout:** `AppShell` (sidebar + header + LevelSwitcher + dark toggle), responsive.
3. **Data model + assetlar:** Dart modellar + `export_assets.py` (Beginner) → `content/beginner/`.
4. **Elementary ingestion (OCR):** parallel, keyin `content/elementary/`.
5. **SRS + stats + grading:** `srs.dart`, `stats.dart`, `grading.dart` + testlar.
6. **Darslar game-map + Unit sahifasi.**
7. **Lug'at pack oqimi (4 bosqich)** + TTS + audio pleyer + "To'g'ri ✓".
8. **4 mashq komponenti** (Listening/Grammar/Construct/Fill).
9. **Gamifikatsiya:** XP/coin/rank/skills, Battle (AI), Leaderboard (shaxsiy), motivatsion xabarlar, nutq (STT+skript).
10. **Media/Resuslar** (Kitoblar/Podkastlar/Videolar) + yakuniy sayqal + deploy.

> Har bosqichdan keyin TO'XTAB, test usuli aytiladi (foydalanuvchi step-by-step ishlashni afzal ko'radi). Kod izohlari **o'zbekcha**.

---

## 13. Ochiq/keyin
- Elementary kontenti OCR'dan o'tishi kerak (Beginner tayyor — undan boshlanadi).
- Fonetika (CMU) va POS — bepul boyitish, ixtiyoriy.
- Haqiqiy generativ AI suhbat — faqat foydalanuvchi pullik LLM'ga rozi bo'lsa (hozir skriptli).
- Dizayn detallari sozlanishi mumkin ("dizaynni keyin o'zgartiramiz").

---

## 14. Ilg'or funksiyalar (2-prompt — top-30 ilova tahlili) — reconciliation

React/Prisma/multiplayer/pullik-AI talablari **Flutter/bepul/offline/bitta-foydalanuvchi**ga moslashtirildi:

| Funksiya | v3 yechim | Prioritet |
|---|---|---|
| Dinamik SRS (SM-2) | §4 — qurildi ✅ | 2 |
| **Retention yadrosi** | Streak (`currentStreak/longestStreak/lastActiveDate/streakFreeze` — coin bilan) + Daily Goal (10/20/30/50 XP, progress ring) + local eslatma. Onboarding: signup yo'q → darhol | 1 |
| **Ligalar** | Bronze→Diamond (10). Multiplayer yo'q → **simulyatsiya raqiblar** (bot XP), haftalik ko'tarilish/tushish, offline | 4 |
| **Karaoke reader** | Reading/Dialogue: TTS + jumla-highlight + so'z-tap (tarjima+fonetik+audio+lug'atga) + LingQ holatlari (yangi/o'rganilayotgan/ma'lum) + known-words + EN / EN+UZ | 3 |
| **Audio nutq** | Active-recall drill (Pimsleur) + talaffuz baholash **Web Speech API** (bepul); Azure = kelajak (pullik) | 5 |
| **AI qatlami** | ⚠️ Pullik LLM — hard "bepul"ga zid. **Qaror:** §14.1 | 6 |
| **Pedagogika** | Interleaving, spiral revision, dual-coding (emoji/CC-rasm), production/generation effect, CEFR can-do | 7 |
| Push | Server yo'q → **local** (Web Notifications, ilova ochiqda) | — |

### 14.1 AI qatlami — qaror kerak
Generativ funksiyalar (xato tushuntirish, roleplay, yozma baholash, shaxsiy misol) LLM talab qiladi. Variantlar: **(A)** skriptli/qoidaviy bepul (grammatika qoidalari bizda bor) — hozir; **(B)** bepul-tier LLM (Gemini/Groq) — internet+kalit+limit; **(C)** lokal WebLLM (offline, og'ir yuklab); **(D)** keyinga. Arxitektura pluggable.

### 14.2 State modeli (qurildi)
`lib/stats.dart` — `Progress` (ChangeNotifier): `xp, coins, currentStreak, longestStreak, streakFreezeCount, lastActiveDate, dailyGoal, todayXp, skills{5}, darkMode, currentLevel, league`. `shared_preferences`da saqlanadi. ✅
