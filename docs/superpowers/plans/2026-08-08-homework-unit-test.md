# Homework — unit bo'yicha baholi test (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `unit_screen.dart`dagi Homework placeholder'ini butun unit so'zlari bo'yicha baholanadigan (80% o'tish chegarasi) interaktiv testga aylantirish.

**Architecture:** Sof mantiq (savol generatsiyasi, distraktor tanlash, baho hisobi) UI'dan ajratilgan `homework_model.dart`da — `flutter test` bilan to'liq tekshiriladi. UI (`homework_flow.dart`) mavjud dizayn komponentlarini (`RoundPlay`, `Pressable3D`, `showCorrectBurst`) qayta ishlatadi. `pack_flow.dart`ga tegilmaydi.

**Tech Stack:** Flutter 3.41 / Dart, `flutter_test`, `shared_preferences` (mavjud `Progress` orqali).

**Spec:** `docs/superpowers/specs/2026-08-08-homework-unit-test-design.md`

## Global Constraints

- **Paket nomi `enterprise_english`** (papka nomi `enterprise-app` — import'da ISHLATILMAYDI). Test import'lari: `package:enterprise_english/...`
- **Flutter yo'li:** `d:\flutter\bin\flutter` (PATH'da bo'lmasligi mumkin)
- **Ish papkasi:** barcha buyruqlar `d:\Enterprise\enterprise-app` ichidan ishga tushiriladi
- **UI matni va kod izohlari — O'ZBEKCHA.** O'rganiladigan kontent inglizcha
- **Lint 0 bo'lishi shart:** `flutter analyze` toza chiqishi kerak (`flutter_lints ^6.0.0`)
- **Mavjud testlar buzilmaydi:** `test/srs_test.dart` (10 ta) o'tishda davom etsin
- **O'tish chegarasi:** 80% — butun son arifmetikasi (`earned * 100 >= 80 * total`)
- **Yangi paket qo'shilmaydi** (bepul/offline stek)
- **Git:** `d:\Enterprise` hali git repo emas. `git init` qilinmaguncha commit qadamlarini o'tkazib yuboring (kod baribir diskda saqlanadi)

---

## File Structure

| Fayl | Mas'uliyat | Holat |
|---|---|---|
| `lib/screens/homework/homework_model.dart` | Sof mantiq: `HwQuestion`, `HwPlan`, `HwResult`, `buildPlan`, `pickDistractors`, `fillBlank` | Yaratiladi (Task 1) |
| `test/homework_test.dart` | Model testlari | Yaratiladi (Task 1) |
| `lib/screens/homework/homework_flow.dart` | UI: savol ekranlari, match, tuzatish, natija | Yaratiladi (Task 2, 3) |
| `lib/screens/unit_screen.dart` | Homework kartasini ulash (3 holat) | O'zgartiriladi (Task 4) |

---

## Task 1: Model va sof mantiq (TDD)

**Files:**
- Create: `lib/screens/homework/homework_model.dart`
- Test: `test/homework_test.dart`

**Interfaces:**
- Consumes: `Word` (`lib/content.dart` — maydonlar: `id, en, uz, example, module, pos, phonetic, freq`)
- Produces:
  - `enum QuestionKind { choose, fill, construct }`
  - `class HwQuestion { QuestionKind kind; Word word; List<String> options; String? sentence; String get answer; }`
  - `class HwPlan { List<HwQuestion> questions; List<Word> matchRound; int get totalPoints; }`
  - `class HwResult { int earned; int total; List<Word> wrongWords; int get percent; bool get passed; }`
  - `HwPlan buildPlan(List<Word> unitWords, List<Word> levelWords, Random rnd)`
  - `List<Word> pickDistractors(Word target, List<Word> pool, int count, Random rnd)`
  - `String? fillBlank(String example, String word)`
  - `const int kPassMark = 80; const int kPassBonusXp = 10;`

- [ ] **Step 1: Yordamchi test faylini va birinchi failing testni yozish**

Create `test/homework_test.dart`:

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/screens/homework/homework_model.dart';

/// Test uchun qisqa Word quruvchi.
Word w(
  String id,
  String en,
  String uz, {
  String example = '',
  String pos = '',
}) =>
    Word(
      id: id,
      en: en,
      uz: uz,
      example: example,
      module: 'M1',
      pos: pos,
      phonetic: '',
      freq: 5.0,
    );

void main() {
  final rnd = Random(42); // aniq natija uchun qat'iy urug'

  group('fillBlank', () {
    test('so\'zni topib _____ ga almashtiradi', () {
      final s = fillBlank('What do koalas eat?', 'eat');
      expect(s, 'What do koalas _____?');
    });
  });
}
```

- [ ] **Step 2: Testni ishga tushirib, muvaffaqiyatsizligini tasdiqlash**

Run:
```bash
d:\flutter\bin\flutter test test/homework_test.dart
```
Expected: FAIL — `Error: Couldn't resolve the package 'enterprise_english' ... homework_model.dart` yoki `Target of URI doesn't exist` (fayl hali yo'q).

- [ ] **Step 3: `fillBlank` ni minimal implementatsiya qilish**

Create `lib/screens/homework/homework_model.dart`:

```dart
import 'dart:math';

import '../../content.dart';

/// Homework savol turlari (Match alohida raund — bu enum'ga kirmaydi).
enum QuestionKind { choose, fill, construct }

/// O'tish chegarasi (foiz) va o'tgani uchun bonus XP.
const int kPassMark = 80;
const int kPassBonusXp = 10;

/// Misol gapdagi target so'zni `_____` ga almashtiradi.
/// So'z chegarasi (`\b`) bilan qidiradi — "present" so'zi "represent" ichida
/// almashmasligi uchun. Topilmasa `null` (savol Choose'ga tushadi).
String? fillBlank(String example, String word) {
  final e = example.trim();
  final t = word.trim();
  if (e.isEmpty || t.isEmpty) return null;
  final re = RegExp(r'\b' + RegExp.escape(t) + r'\b', caseSensitive: false);
  if (!re.hasMatch(e)) return null;
  return e.replaceFirst(re, '_____');
}
```

- [ ] **Step 4: Testni qayta ishga tushirib, o'tishini tasdiqlash**

Run:
```bash
d:\flutter\bin\flutter test test/homework_test.dart
```
Expected: PASS — `+1: All tests passed!`

- [ ] **Step 5: Qolgan `fillBlank` testlarini qo'shish**

`test/homework_test.dart` ichidagi `group('fillBlank', ...)` blokiga qo'shing:

```dart
    test('katta-kichik harfga befarq', () {
      final s = fillBlank('Eat your breakfast.', 'eat');
      expect(s, '_____ your breakfast.');
    });

    test('qisman so\'z almashmaydi (so\'z chegarasi)', () {
      final s = fillBlank('They represent the team.', 'present');
      expect(s, isNull);
    });

    test('so\'z umuman yo\'q → null', () {
      final s = fillBlank('A completely different sentence.', 'eat');
      expect(s, isNull);
    });

    test('bo\'sh misol → null', () {
      expect(fillBlank('', 'eat'), isNull);
      expect(fillBlank('Some text', ''), isNull);
    });

    test('faqat birinchi uchrashuvi almashadi', () {
      final s = fillBlank('I eat what they eat.', 'eat');
      expect(s, 'I _____ what they eat.');
    });
```

- [ ] **Step 6: Testlarni ishga tushirish**

Run:
```bash
d:\flutter\bin\flutter test test/homework_test.dart
```
Expected: PASS — 6 ta test o'tadi.

- [ ] **Step 7: `pickDistractors` uchun failing testlar yozish**

`test/homework_test.dart` ichida, `group('fillBlank', ...)` dan keyin qo'shing:

```dart
  group('pickDistractors', () {
    test('target va bir xil uz tarjimalar chiqarib tashlanadi', () {
      final target = w('t', 'hot', 'issiq');
      final pool = [
        target,
        w('a', 'warm', 'issiq'), // BIR XIL tarjima — ikkinchi to'g'ri javob bo'lardi
        w('b', 'cold', 'sovuq'),
        w('c', 'big', 'katta'),
        w('d', 'small', 'kichik'),
      ];
      final d = pickDistractors(target, pool, 3, rnd);
      expect(d.length, 3);
      expect(d.any((x) => x.id == 't'), isFalse, reason: 'target o\'zi chiqmasin');
      expect(d.any((x) => x.uz == 'issiq'), isFalse,
          reason: 'bir xil tarjima ikkita to\'g\'ri javob yaratadi');
    });

    test('distraktorlar takrorlanmaydi', () {
      final target = w('t', 'hot', 'issiq');
      final pool = [
        target,
        w('b', 'cold', 'sovuq'),
        w('c', 'big', 'katta'),
        w('d', 'small', 'kichik'),
      ];
      final d = pickDistractors(target, pool, 3, rnd);
      expect(d.map((x) => x.id).toSet().length, d.length);
    });

    test('nomzod yetmasa bor bo\'lganicha qaytaradi', () {
      final target = w('t', 'hot', 'issiq');
      final pool = [target, w('b', 'cold', 'sovuq')];
      final d = pickDistractors(target, pool, 3, rnd);
      expect(d.length, 1);
    });

    test('bir xil pos afzal ko\'riladi', () {
      final target = w('t', 'run', 'yugurmoq', pos: 'fe\'l');
      final pool = [
        target,
        w('a', 'jump', 'sakramoq', pos: 'fe\'l'),
        w('b', 'swim', 'suzmoq', pos: 'fe\'l'),
        w('c', 'walk', 'yurmoq', pos: 'fe\'l'),
        w('x', 'table', 'stol', pos: 'ot'),
        w('y', 'chair', 'stul', pos: 'ot'),
      ];
      final d = pickDistractors(target, pool, 3, rnd);
      expect(d.every((x) => x.pos == 'fe\'l'), isTrue);
    });
  });
```

- [ ] **Step 8: Testni ishga tushirib, muvaffaqiyatsizligini tasdiqlash**

Run:
```bash
d:\flutter\bin\flutter test test/homework_test.dart
```
Expected: FAIL — `The function 'pickDistractors' isn't defined`.

- [ ] **Step 9: `pickDistractors` ni implementatsiya qilish**

`lib/screens/homework/homework_model.dart` oxiriga qo'shing:

```dart
/// Ko'p tanlovli savol uchun `count` ta noto'g'ri variant tanlaydi.
///
/// Kritik qoida: `uz` (yoki `en`) target bilan bir xil bo'lgan so'zlar
/// CHIQARIB TASHLANADI — beginner kontentida 11 ta takroriy tarjima bor
/// ("issiq", "suzish", ...), ular savolda ikkinchi to'g'ri javob yaratadi.
/// Iloji bo'lsa bir xil `pos` dagi so'zlar afzal ko'riladi.
List<Word> pickDistractors(Word target, List<Word> pool, int count, Random rnd) {
  final out = <Word>[];
  final seenUz = <String>{target.uz};
  final seenEn = <String>{target.en};

  void take(Iterable<Word> src) {
    final list = List.of(src)..shuffle(rnd);
    for (final x in list) {
      if (out.length >= count) return;
      if (x.id == target.id) continue;
      if (seenUz.contains(x.uz) || seenEn.contains(x.en)) continue;
      out.add(x);
      seenUz.add(x.uz);
      seenEn.add(x.en);
    }
  }

  if (target.pos.isNotEmpty) {
    take(pool.where((x) => x.pos == target.pos)); // avval bir xil turkum
  }
  take(pool); // keyin qolganlari
  return out;
}
```

- [ ] **Step 10: Testlarni ishga tushirish**

Run:
```bash
d:\flutter\bin\flutter test test/homework_test.dart
```
Expected: PASS — 10 ta test o'tadi.

- [ ] **Step 11: `HwResult` uchun failing testlar yozish**

`test/homework_test.dart` ichida qo'shing:

```dart
  group('HwResult', () {
    test('80% aynan o\'tadi, 79% yiqiladi', () {
      expect(const HwResult(earned: 8, total: 10).passed, isTrue);
      expect(const HwResult(earned: 8, total: 10).percent, 80);
      expect(const HwResult(earned: 79, total: 100).passed, isFalse);
      expect(const HwResult(earned: 79, total: 100).percent, 79);
    });

    test('79.5% yiqiladi (yaxlitlash o\'tkazib yubormaydi)', () {
      const r = HwResult(earned: 159, total: 200);
      expect(r.passed, isFalse, reason: '79.5% — 80 ga yaxlitlansa ham o\'tmasin');
    });

    test('nol savol → 0% va yiqiladi', () {
      const r = HwResult(earned: 0, total: 0);
      expect(r.percent, 0);
      expect(r.passed, isFalse);
    });

    test('to\'liq to\'g\'ri → 100%', () {
      const r = HwResult(earned: 12, total: 12);
      expect(r.percent, 100);
      expect(r.passed, isTrue);
    });
  });
```

- [ ] **Step 12: Testni ishga tushirib, muvaffaqiyatsizligini tasdiqlash**

Run:
```bash
d:\flutter\bin\flutter test test/homework_test.dart
```
Expected: FAIL — `Undefined class 'HwResult'`.

- [ ] **Step 13: `HwResult` ni implementatsiya qilish**

`lib/screens/homework/homework_model.dart` oxiriga qo'shing:

```dart
/// Test yakuni.
class HwResult {
  final int earned; // olingan ball
  final int total; // jami ball
  final List<Word> wrongWords; // birinchi urinishda xato qilinganlar

  const HwResult({
    required this.earned,
    required this.total,
    this.wrongWords = const [],
  });

  /// Ko'rsatish uchun foiz (yaxlitlangan).
  int get percent => total == 0 ? 0 : ((earned / total) * 100).round();

  /// O'tdimi — BUTUN SON arifmetikasi bilan, `percent` orqali emas:
  /// 79.5% yaxlitlanib 80 bo'lib qolmasin.
  bool get passed => total > 0 && earned * 100 >= kPassMark * total;
}
```

- [ ] **Step 14: Testlarni ishga tushirish**

Run:
```bash
d:\flutter\bin\flutter test test/homework_test.dart
```
Expected: PASS — 14 ta test o'tadi.

- [ ] **Step 15: `buildPlan` uchun failing testlar yozish**

`test/homework_test.dart` ichida qo'shing:

```dart
  group('buildPlan', () {
    /// 12 ta so'z: yarmida misol bor, yarmida yo'q.
    List<Word> unit12() => List.generate(
          12,
          (i) => w(
            'u$i',
            'word$i',
            'tarjima$i',
            example: i.isEven ? 'I like word$i very much.' : '',
          ),
        );

    test('har bir so\'z aynan bitta savol beradi (chegara yo\'q)', () {
      final words = unit12();
      final plan = buildPlan(words, words, rnd);
      expect(plan.questions.length, 12);
      expect(
        plan.questions.map((q) => q.word.id).toSet(),
        words.map((x) => x.id).toSet(),
        reason: 'so\'z tushib qolmasin, takrorlanmasin',
      );
    });

    test('har uchinchi savol Construct', () {
      final words = unit12();
      final plan = buildPlan(words, words, rnd);
      for (var i = 0; i < plan.questions.length; i++) {
        if (i % 3 == 2) {
          expect(plan.questions[i].kind, QuestionKind.construct,
              reason: '$i-savol Construct bo\'lishi kerak');
        }
      }
    });

    test('misolsiz so\'z hech qachon Fill emas', () {
      final words = unit12();
      final plan = buildPlan(words, words, rnd);
      for (final q in plan.questions) {
        if (q.kind == QuestionKind.fill) {
          expect(q.word.example.trim(), isNotEmpty);
          expect(q.sentence, contains('_____'));
        }
      }
    });

    test('Choose variantlari uz, Fill variantlari en', () {
      final words = unit12();
      final plan = buildPlan(words, words, rnd);
      for (final q in plan.questions) {
        if (q.kind == QuestionKind.choose) {
          expect(q.options, contains(q.word.uz));
          expect(q.answer, q.word.uz);
        } else if (q.kind == QuestionKind.fill) {
          expect(q.options, contains(q.word.en));
          expect(q.answer, q.word.en);
        }
      }
    });

    test('pool >= 4 → oxirida Match raundi bor', () {
      final words = unit12();
      final plan = buildPlan(words, words, rnd);
      expect(plan.matchRound.length, inInclusiveRange(4, 5));
      expect(plan.matchRound.map((x) => x.id).toSet().length,
          plan.matchRound.length,
          reason: 'match juftlari takrorlanmasin');
    });

    test('pool < 4 → Match raundi yo\'q', () {
      final words = [
        w('a', 'one', 'bir'),
        w('b', 'two', 'ikki'),
        w('c', 'three', 'uch'),
      ];
      final plan = buildPlan(words, words, rnd);
      expect(plan.matchRound, isEmpty);
      expect(plan.questions.length, 3);
    });

    test('totalPoints = savollar + match juftlari', () {
      final words = unit12();
      final plan = buildPlan(words, words, rnd);
      expect(plan.totalPoints, plan.questions.length + plan.matchRound.length);
    });

    test('distraktor topilmasa Construct\'ga tushadi', () {
      // Bitta so'z: distraktor yo'q → Choose/Fill imkonsiz.
      final words = [w('solo', 'alone', 'yolg\'iz', example: 'I am alone.')];
      final plan = buildPlan(words, words, rnd);
      expect(plan.questions.single.kind, QuestionKind.construct);
    });

    test('bo\'sh unit → bo\'sh reja', () {
      final plan = buildPlan([], [], rnd);
      expect(plan.questions, isEmpty);
      expect(plan.matchRound, isEmpty);
      expect(plan.totalPoints, 0);
    });
  });
```

- [ ] **Step 16: Testni ishga tushirib, muvaffaqiyatsizligini tasdiqlash**

Run:
```bash
d:\flutter\bin\flutter test test/homework_test.dart
```
Expected: FAIL — `The function 'buildPlan' isn't defined`, `Undefined class 'HwQuestion'`.

- [ ] **Step 17: `HwQuestion`, `HwPlan`, `buildPlan` ni implementatsiya qilish**

`lib/screens/homework/homework_model.dart` oxiriga qo'shing:

```dart
/// Bitta savol (har doim bitta so'z haqida).
class HwQuestion {
  final QuestionKind kind;
  final Word word;

  /// Choose uchun — o'zbekcha variantlar; Fill uchun — inglizcha variantlar;
  /// Construct uchun — bo'sh.
  final List<String> options;

  /// Fill uchun `_____` li gap; boshqa turlarda `null`.
  final String? sentence;

  const HwQuestion({
    required this.kind,
    required this.word,
    this.options = const [],
    this.sentence,
  });

  /// To'g'ri javob matni.
  String get answer =>
      kind == QuestionKind.choose ? word.uz : word.en;
}

/// Butun test rejasi: savollar + (ixtiyoriy) oxirgi Match raundi.
class HwPlan {
  final List<HwQuestion> questions;
  final List<Word> matchRound; // bo'sh bo'lishi mumkin

  const HwPlan({required this.questions, required this.matchRound});

  /// Jami ball: har savol 1, Match'da har juft 1.
  int get totalPoints => questions.length + matchRound.length;
}

/// Unit so'zlaridan test rejasini quradi.
///
/// [unitWords] — unitning barcha so'zlari (chegara YO'Q, hammasi savolga
/// aylanadi). [levelWords] — distraktor uchun kengroq havza.
HwPlan buildPlan(List<Word> unitWords, List<Word> levelWords, Random rnd) {
  // Takrorlarni olib tashlash (bir so'z ikki pack'da bo'lishi mumkin).
  final uniq = <String, Word>{};
  for (final x in unitWords) {
    uniq[x.id] = x;
  }
  final words = uniq.values.toList()..shuffle(rnd);
  if (words.isEmpty) {
    return const HwPlan(questions: [], matchRound: []);
  }

  // Distraktor havzasi: avval unit, keyin butun daraja.
  final pool = <String, Word>{};
  for (final x in [...words, ...levelWords]) {
    pool[x.id] = x;
  }
  final distractorPool = pool.values.toList();

  final questions = <HwQuestion>[
    for (var i = 0; i < words.length; i++)
      _makeQuestion(words[i], i, distractorPool, rnd),
  ];

  // Match: kamida 4 so'z bo'lsa, 5 tagacha juft.
  final matchRound = words.length >= 4
      ? (List.of(words)..shuffle(rnd)).take(min(5, words.length)).toList()
      : <Word>[];

  return HwPlan(questions: questions, matchRound: matchRound);
}

/// Bitta so'z uchun savol turini aniqlaydi (indeks bo'yicha — takrorlanadigan).
HwQuestion _makeQuestion(Word x, int i, List<Word> pool, Random rnd) {
  HwQuestion construct() =>
      HwQuestion(kind: QuestionKind.construct, word: x);

  // Har uchinchi savol — Construct (xilma-xillik uchun).
  if (i % 3 == 2) return construct();

  final blank = fillBlank(x.example, x.en);
  final distractors = pickDistractors(x, pool, 3, rnd);

  // Bitta ham distraktor topilmasa ko'p tanlovli savol ma'nosiz.
  if (distractors.isEmpty) return construct();

  if (blank != null) {
    final options = [x.en, ...distractors.map((d) => d.en)]..shuffle(rnd);
    return HwQuestion(
      kind: QuestionKind.fill,
      word: x,
      options: options,
      sentence: blank,
    );
  }

  final options = [x.uz, ...distractors.map((d) => d.uz)]..shuffle(rnd);
  return HwQuestion(kind: QuestionKind.choose, word: x, options: options);
}
```

- [ ] **Step 18: Barcha testlarni ishga tushirish**

Run:
```bash
d:\flutter\bin\flutter test
```
Expected: PASS — `test/srs_test.dart` (10 ta) + `test/homework_test.dart` (23 ta) = **33 ta test o'tadi**.

- [ ] **Step 19: Lint tekshiruvi**

Run:
```bash
d:\flutter\bin\flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 20: Commit**

> Git repo yo'q bo'lsa bu qadamni o'tkazib yuboring.

```bash
git add lib/screens/homework/homework_model.dart test/homework_test.dart
git commit -m "feat(homework): savol generatsiyasi va baholash mantiqi + testlar"
```

---

## Task 2: Test oqimi UI — savollar va natija

**Files:**
- Create: `lib/screens/homework/homework_flow.dart`
- Read (o'zgartirilmaydi): `lib/screens/pack/pack_flow.dart` (`RoundPlay`, `boldExample` import uchun)

**Interfaces:**
- Consumes: Task 1 dan `HwPlan`, `HwQuestion`, `HwResult`, `QuestionKind`, `buildPlan`, `kPassBonusXp`; `progress` (`lib/main.dart`), `Quality`/`xpForQuality` (`lib/srs.dart`), `RoundPlay` (`lib/screens/pack/pack_flow.dart`), `Pressable3D`, `showCorrectBurst(BuildContext)`, `Tts.instance`
- Produces: `class HomeworkFlow extends StatefulWidget` — konstruktor `HomeworkFlow({required Unit unit, required List<Word> unitWords, required List<Word> levelWords})`

- [ ] **Step 1: Oqim skeletini yozish (savollar → natija)**

Create `lib/screens/homework/homework_flow.dart`:

```dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../../content.dart';
import '../../main.dart';
import '../../srs.dart';
import '../../theme.dart';
import '../../services/tts.dart';
import '../../widgets/correct_burst.dart';
import '../../widgets/pressable3d.dart';
import '../pack/pack_flow.dart' show RoundPlay;
import 'homework_model.dart';

/// Unit bo'yicha baholi test: savollar → (match) → tuzatish → natija.
class HomeworkFlow extends StatefulWidget {
  final Unit unit;
  final List<Word> unitWords;
  final List<Word> levelWords;

  const HomeworkFlow({
    super.key,
    required this.unit,
    required this.unitWords,
    required this.levelWords,
  });

  @override
  State<HomeworkFlow> createState() => _HomeworkFlowState();
}

/// Oqim bosqichlari.
enum _Phase { question, result }

class _HomeworkFlowState extends State<HomeworkFlow> {
  late HwPlan _plan;
  _Phase _phase = _Phase.question;

  int _index = 0; // joriy savol
  int _earned = 0; // olingan ball
  int _sessionXp = 0;
  final List<Word> _wrong = []; // birinchi urinishda xato qilinganlar

  @override
  void initState() {
    super.initState();
    _plan = buildPlan(widget.unitWords, widget.levelWords, Random());
  }

  @override
  void dispose() {
    Tts.instance.stop();
    super.dispose();
  }

  /// Savolga javob berildi: SRS + XP + ball.
  Future<void> _answered(Word word, bool correct) async {
    final q = correct ? Quality.good : Quality.unknown;
    await progress.reviewWord(word.id, q);
    if (!mounted) return;
    setState(() {
      if (correct) {
        _earned += 1;
        _sessionXp += xpForQuality(q);
      } else if (!_wrong.any((x) => x.id == word.id)) {
        // Bir so'z savolda ham, match'da ham xato bo'lishi mumkin —
        // tuzatish raundida ikki marta so'ralmasin.
        _wrong.add(word);
      }
    });
  }

  /// Keyingi savolga o'tish (yoki yakunlash).
  void _next() {
    if (_index + 1 < _plan.questions.length) {
      setState(() => _index += 1);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final result = HwResult(
      earned: _earned,
      total: _plan.totalPoints,
      wrongWords: _wrong,
    );
    if (result.passed) {
      _sessionXp += kPassBonusXp;
      await progress.addXp(kPassBonusXp);
      if (!progress.isDone('hw::${widget.unit.id}')) {
        await progress.markDone('hw::${widget.unit.id}');
      }
    }
    if (mounted) setState(() => _phase = _Phase.result);
  }

  HwResult get _result => HwResult(
        earned: _earned,
        total: _plan.totalPoints,
        wrongWords: _wrong,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.coin.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '⚡ $_sessionXp XP',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.coin,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_plan.questions.isEmpty) {
      return const Center(child: Text('Bu unitda so\'z yo\'q'));
    }
    switch (_phase) {
      case _Phase.question:
        final q = _plan.questions[_index];
        return Column(
          children: [
            _progressBar(_index, _plan.questions.length),
            Expanded(
              child: _QuestionCard(
                key: ValueKey('q$_index'),
                question: q,
                onAnswered: (ok) => _answered(q.word, ok),
                onNext: _next,
              ),
            ),
          ],
        );
      case _Phase.result:
        return _ResultView(
          result: _result,
          xp: _sessionXp,
          onClose: () => Navigator.pop(context),
          onRetry: _restart,
        );
    }
  }

  void _restart() {
    setState(() {
      _plan = buildPlan(widget.unitWords, widget.levelWords, Random());
      _phase = _Phase.question;
      _index = 0;
      _earned = 0;
      _sessionXp = 0;
      _wrong.clear();
    });
  }

  Widget _progressBar(int i, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : (i + 1) / total,
              minHeight: 6,
              backgroundColor: AppColors.homework.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.homework),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${i + 1} / $total',
              style: const TextStyle(fontSize: 12, color: AppColors.lightMuted),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Savol kartasini (Choose/Fill/Construct) yozish**

`lib/screens/homework/homework_flow.dart` oxiriga qo'shing:

```dart
/// Bitta savol: Choose/Fill — 4 variant; Construct — harf plitkalari.
class _QuestionCard extends StatefulWidget {
  final HwQuestion question;
  final ValueChanged<bool> onAnswered;
  final VoidCallback onNext;

  const _QuestionCard({
    super.key,
    required this.question,
    required this.onAnswered,
    required this.onNext,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  String? _chosen; // tanlangan variant (Choose/Fill)
  bool _locked = false; // javob berilgan — qayta bosib bo'lmaydi

  HwQuestion get q => widget.question;

  @override
  void initState() {
    super.initState();
    // Faqat Fill — so'z gapda yashiringan, eshitish yordam beradi.
    // Construct o'z ichida gapiradi (ikki marta o'qilmasin), Choose'da
    // inglizcha so'z ko'rinib turadi.
    if (q.kind == QuestionKind.fill) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Tts.instance.speak(q.word.en, id: 'hw'),
      );
    }
  }

  void _choose(String option) {
    if (_locked) return;
    final ok = option == q.answer;
    setState(() {
      _chosen = option;
      _locked = true;
    });
    widget.onAnswered(ok);
    if (ok) showCorrectBurst(context);
    Tts.instance.speak(q.word.en, id: 'hw');
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) widget.onNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (q.kind == QuestionKind.construct) {
      return _ConstructBody(
        word: q.word,
        onDone: (ok) {
          widget.onAnswered(ok);
          // Xato bo'lsa to'g'ri yozilishini o'qishga ulgursin.
          Future.delayed(Duration(milliseconds: ok ? 900 : 1700), () {
            if (mounted) widget.onNext();
          });
        },
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _prompt(context),
        const SizedBox(height: 18),
        Text(
          q.kind == QuestionKind.fill
              ? 'Bo\'sh joyni to\'ldiring'
              : 'Ma\'nosini tanlang',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 10),
        for (final o in q.options) _optionTile(o),
      ],
    );
  }

  /// Savol qismi: Choose — so'z; Fill — bo'sh joyli gap.
  Widget _prompt(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.3 : 0.05),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        children: [
          if (q.kind == QuestionKind.choose) ...[
            if (q.word.pos.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  q.word.pos,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.brandPurple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              q.word.en,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: dark ? AppColors.darkHeading : AppColors.lightHeading,
              ),
            ),
          ] else
            Text(
              q.sentence ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.5,
                color: dark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
          const SizedBox(height: 12),
          RoundPlay(text: q.word.en),
        ],
      ),
    );
  }

  /// Variant tugmasi — javobdan keyin to'g'ri yashil, tanlangan xato qizil.
  Widget _optionTile(String option) {
    Color border = Colors.black12;
    Color? text;
    if (_locked) {
      if (option == q.answer) {
        border = AppColors.success;
        text = AppColors.success;
      } else if (option == _chosen) {
        border = AppColors.danger;
        text = AppColors.danger;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: _locked ? null : () => _choose(option),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: border, width: 1.8),
            ),
            child: Text(
              option,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Construct (harf yig'ish) qismini yozish**

`lib/screens/homework/homework_flow.dart` oxiriga qo'shing:

```dart
/// Harf plitkalaridan so'zni yig'ish. Ibora bo'lsa — bo'sh joy bo'yicha bo'linadi.
class _ConstructBody extends StatefulWidget {
  final Word word;
  final ValueChanged<bool> onDone;

  const _ConstructBody({required this.word, required this.onDone});

  @override
  State<_ConstructBody> createState() => _ConstructBodyState();
}

class _ConstructBodyState extends State<_ConstructBody> {
  final _rnd = Random();
  late List<String> _target;
  late List<String> _tiles;
  final List<int> _picked = [];
  bool? _result;

  @override
  void initState() {
    super.initState();
    final en = widget.word.en.trim();
    // Beginner kontentida ibora yo'q — deyarli har doim harf bo'yicha.
    _target = en.contains(' ') ? en.split(RegExp(r'\s+')) : en.split('');
    final scrambled = List.of(_target)..shuffle(_rnd);
    if (scrambled.join() == _target.join() && _target.length > 1) {
      scrambled.shuffle(_rnd);
    }
    _tiles = scrambled;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Tts.instance.speak(widget.word.en, id: 'hw'),
    );
  }

  void _tap(int i) {
    if (_result != null || _picked.contains(i)) return;
    setState(() => _picked.add(i));
    if (_picked.length == _target.length) _check();
  }

  void _undo() {
    if (_result != null || _picked.isEmpty) return;
    setState(() => _picked.removeLast());
  }

  /// BITTA urinish — Choose/Fill bilan bir xil qoida (spec §5: ball faqat
  /// birinchi urinishda). Xato bo'lsa to'g'ri yozilishi ko'rsatiladi va
  /// keyingi savolga o'tiladi; qayta urinish YO'Q (aks holda oqim qotib qoladi).
  void _check() {
    final sep = widget.word.en.trim().contains(' ') ? ' ' : '';
    final built = _picked.map((k) => _tiles[k]).join(sep);
    final ok = built.toLowerCase() == _target.join(sep).toLowerCase();
    setState(() => _result = ok);
    if (ok) showCorrectBurst(context);
    widget.onDone(ok); // ball + keyingiga o'tish (kechikish ota-widget'da)
  }

  @override
  Widget build(BuildContext context) {
    final sep = widget.word.en.trim().contains(' ') ? ' ' : '';
    final built = _picked.map((k) => _tiles[k]).join(sep);
    final long = _target.length > 12;
    final size = long ? 40.0 : 52.0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          '🧩 So\'zni yig\'ing',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            widget.word.uz,
            style: const TextStyle(fontSize: 16, color: AppColors.lightMuted),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: RoundPlay(text: widget.word.en, size: 56)),
        const SizedBox(height: 20),
        Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _result == null
                  ? Colors.black26
                  : _result!
                      ? AppColors.success
                      : AppColors.danger,
              width: 2,
            ),
          ),
          child: Text(
            built.isEmpty ? '_ _ _' : built,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: _result == false
              // Xato — to'g'ri yozilishini ko'rsatamiz (o'rganish uchun).
              ? Center(
                  child: Text(
                    'To\'g\'risi: ${widget.word.en}',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : _picked.isNotEmpty
                  ? Center(
                      child: TextButton.icon(
                        onPressed: _undo,
                        icon: const Icon(Icons.backspace_outlined, size: 18),
                        label: const Text('Orqaga'),
                      ),
                    )
                  : const SizedBox(),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _tiles.length; i++)
              GestureDetector(
                onTap: () => _tap(i),
                child: AnimatedOpacity(
                  opacity: _picked.contains(i) ? 0.25 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: sep.isEmpty ? size : null,
                    height: size,
                    padding: sep.isEmpty
                        ? null
                        : const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color:
                            AppColors.brandPurple.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _tiles[i],
                        style: TextStyle(
                          fontSize: long ? 18 : 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Natija ekranini yozish**

`lib/screens/homework/homework_flow.dart` oxiriga qo'shing:

```dart
/// Yakuniy natija: foiz, o'tdi/yiqildi, XP va tugmalar.
class _ResultView extends StatelessWidget {
  final HwResult result;
  final int xp;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  const _ResultView({
    required this.result,
    required this.xp,
    required this.onClose,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final passed = result.passed;
    final color = passed ? AppColors.success : AppColors.danger;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(
              passed ? Icons.check_rounded : Icons.refresh_rounded,
              color: Colors.white,
              size: 68,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '${result.percent}%',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        Center(
          child: Text(
            passed ? 'O\'tdingiz! 🎉' : 'O\'tish uchun $kPassMark% kerak',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '${result.earned} / ${result.total} to\'g\'ri',
            style: const TextStyle(color: AppColors.lightMuted),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.coin.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '+$xp XP',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.coin,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Pressable3D(
          color: AppColors.brandPurple,
          shadowColor: const Color(0xFF5B22B5),
          onPressed: onClose,
          child: const Center(
            child: Text(
              'Unitga qaytish',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Pressable3D(
          color: AppColors.homework,
          shadowColor: const Color(0xFFB8410C),
          onPressed: onRetry,
          child: const Center(
            child: Text(
              'Qayta topshirish',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Lint va testlarni tekshirish**

Run:
```bash
d:\flutter\bin\flutter analyze
```
Expected: `No issues found!`

Run:
```bash
d:\flutter\bin\flutter test
```
Expected: 33 ta test o'tadi (UI o'zgarishi mantiqqa tegmaydi).

- [ ] **Step 6: Commit**

> Git repo yo'q bo'lsa bu qadamni o'tkazib yuboring.

```bash
git add lib/screens/homework/homework_flow.dart
git commit -m "feat(homework): savol ekranlari (choose/fill/construct) va natija"
```

---

## Task 3: Match raundi va tuzatish raundi

**Files:**
- Modify: `lib/screens/homework/homework_flow.dart` (`_Phase` enum, `_body()`, yangi widget'lar)

**Interfaces:**
- Consumes: Task 2 dan `_HomeworkFlowState`, `_Phase`; Task 1 dan `HwPlan.matchRound`, `HwResult.wrongWords`
- Produces: `_MatchRound`, `_CorrectionRound` (fayl ichida xususiy)

- [ ] **Step 1: `_Phase` enum'ga yangi bosqichlarni qo'shish**

`lib/screens/homework/homework_flow.dart` ichida almashtiring:

```dart
enum _Phase { question, result }
```

bunga:

```dart
enum _Phase { question, match, correction, result }
```

- [ ] **Step 2: Bosqichlar o'tishini yangilash**

`_HomeworkFlowState` ichidagi `_next()` va `_finish()` metodlarini almashtiring:

```dart
  /// Keyingi savolga o'tish (yoki match/tuzatish/natijaga).
  void _next() {
    if (_index + 1 < _plan.questions.length) {
      setState(() => _index += 1);
    } else {
      _afterQuestions();
    }
  }

  void _afterQuestions() {
    if (_plan.matchRound.isNotEmpty) {
      setState(() => _phase = _Phase.match);
    } else {
      _afterMatch();
    }
  }

  /// Match tugadi: xato so'zlar bo'lsa tuzatish raundi, aks holda natija.
  void _afterMatch() {
    if (_wrong.isNotEmpty) {
      setState(() => _phase = _Phase.correction);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final result = HwResult(
      earned: _earned,
      total: _plan.totalPoints,
      wrongWords: _wrong,
    );
    if (result.passed) {
      _sessionXp += kPassBonusXp;
      await progress.addXp(kPassBonusXp);
      if (!progress.isDone('hw::${widget.unit.id}')) {
        await progress.markDone('hw::${widget.unit.id}');
      }
    }
    if (mounted) setState(() => _phase = _Phase.result);
  }

  /// Match juftlari uchun ball (har juft 1) — SRS bilan birga.
  Future<void> _matchPair(Word word, bool correct) async {
    await progress.reviewWord(word.id, correct ? Quality.good : Quality.unknown);
    if (!mounted) return;
    setState(() {
      if (correct) {
        _earned += 1;
        _sessionXp += xpForQuality(Quality.good);
      } else if (!_wrong.any((x) => x.id == word.id)) {
        _wrong.add(word);
      }
    });
  }
```

- [ ] **Step 3: `_body()` ga yangi bosqichlarni ulash**

`_body()` ichidagi `switch` ni almashtiring:

```dart
    switch (_phase) {
      case _Phase.question:
        final q = _plan.questions[_index];
        return Column(
          children: [
            _progressBar(_index, _plan.questions.length),
            Expanded(
              child: _QuestionCard(
                key: ValueKey('q$_index'),
                question: q,
                onAnswered: (ok) => _answered(q.word, ok),
                onNext: _next,
              ),
            ),
          ],
        );
      case _Phase.match:
        return _MatchRound(
          words: _plan.matchRound,
          onPair: _matchPair,
          onDone: _afterMatch,
        );
      case _Phase.correction:
        return _CorrectionRound(
          words: List.of(_wrong),
          levelWords: widget.levelWords,
          onDone: _finish,
        );
      case _Phase.result:
        return _ResultView(
          result: _result,
          xp: _sessionXp,
          onClose: () => Navigator.pop(context),
          onRetry: _restart,
        );
    }
```

- [ ] **Step 4: Match raundini yozish**

`lib/screens/homework/homework_flow.dart` oxiriga qo'shing:

```dart
/// Moslash raundi: chapda inglizcha, o'ngda o'zbekcha. Har juft 1 ball.
/// Ball faqat BIRINCHI urinishda beriladi (xato bosilsa — juft "kuygan").
class _MatchRound extends StatefulWidget {
  final List<Word> words;
  final Future<void> Function(Word, bool) onPair;
  final VoidCallback onDone;

  const _MatchRound({
    required this.words,
    required this.onPair,
    required this.onDone,
  });

  @override
  State<_MatchRound> createState() => _MatchRoundState();
}

class _MatchRoundState extends State<_MatchRound> {
  final _rnd = Random();
  late List<Word> _left;
  late List<Word> _right;
  String? _selected; // tanlangan chap so'z id
  final Set<String> _matched = {};
  final Set<String> _failed = {}; // xato urinish bo'lgan so'zlar
  String? _wrongFlash;

  @override
  void initState() {
    super.initState();
    _left = List.of(widget.words)..shuffle(_rnd);
    _right = List.of(widget.words)..shuffle(_rnd);
  }

  Future<void> _tapRight(Word r) async {
    final sel = _selected;
    if (sel == null || _matched.contains(r.id)) return;

    if (sel == r.id) {
      setState(() {
        _matched.add(r.id);
        _selected = null;
      });
      await widget.onPair(r, !_failed.contains(r.id));
      Tts.instance.speak(r.en, id: r.id);
      if (_matched.length == widget.words.length) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) widget.onDone();
        });
      }
    } else {
      setState(() {
        _failed.add(sel); // tanlangan chap so'z uchun xato hisoblanadi
        _wrongFlash = r.id;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _wrongFlash = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '🔗 Moslash raundi',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (final x in _left)
                        _tile(
                          label: x.en,
                          done: _matched.contains(x.id),
                          selected: _selected == x.id,
                          onTap: () {
                            if (_matched.contains(x.id)) return;
                            setState(() => _selected = x.id);
                            Tts.instance.speak(x.en, id: x.id);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      for (final x in _right)
                        _tile(
                          label: x.uz,
                          done: _matched.contains(x.id),
                          wrong: _wrongFlash == x.id,
                          onTap: () => _tapRight(x),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile({
    required String label,
    required VoidCallback onTap,
    bool done = false,
    bool selected = false,
    bool wrong = false,
  }) {
    Color border = Colors.black12;
    Color bg = Theme.of(context).colorScheme.surface;
    if (done) {
      border = AppColors.success;
      bg = AppColors.success.withValues(alpha: 0.12);
    } else if (wrong) {
      border = AppColors.danger;
      bg = AppColors.danger.withValues(alpha: 0.12);
    } else if (selected) {
      border = AppColors.brandPurple;
      bg = AppColors.brandPurple.withValues(alpha: 0.10);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: done ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: border, width: 1.8),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: done ? AppColors.success : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Tuzatish raundini yozish**

`lib/screens/homework/homework_flow.dart` oxiriga qo'shing:

```dart
/// Tuzatish raundi: xato qilingan so'zlar to'g'ri javob berilguncha so'raladi.
/// BALLGA TA'SIR QILMAYDI — maqsadi o'rgatish (spec §5.1).
class _CorrectionRound extends StatefulWidget {
  final List<Word> words;
  final List<Word> levelWords;
  final VoidCallback onDone;

  const _CorrectionRound({
    required this.words,
    required this.levelWords,
    required this.onDone,
  });

  @override
  State<_CorrectionRound> createState() => _CorrectionRoundState();
}

class _CorrectionRoundState extends State<_CorrectionRound> {
  final _rnd = Random();
  int _i = 0;
  late List<String> _options;
  String? _chosen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final target = widget.words[_i];
    final pool = [...widget.words, ...widget.levelWords];
    final d = pickDistractors(target, pool, 3, _rnd);
    _options = [target.uz, ...d.map((x) => x.uz)]..shuffle(_rnd);
    _chosen = null;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Tts.instance.speak(target.en, id: 'fix'),
    );
  }

  void _tap(String option) {
    final target = widget.words[_i];
    if (_chosen != null) return;
    setState(() => _chosen = option);

    if (option != target.uz) {
      // Xato — to'g'risini ko'rsatib, shu so'zni qayta so'raymiz.
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(_load);
      });
      return;
    }

    showCorrectBurst(context);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_i + 1 < widget.words.length) {
        setState(() {
          _i += 1;
          _load();
        });
      } else {
        widget.onDone();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.words[_i];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            const Text(
              '🔁 Xatolar ustida ishlash',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const Spacer(),
            Text(
              '${_i + 1} / ${widget.words.length}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.homework,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Bu raund bahoga ta\'sir qilmaydi',
          style: TextStyle(fontSize: 12, color: AppColors.lightMuted),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            target.en,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        Center(child: RoundPlay(text: target.en)),
        const SizedBox(height: 22),
        for (final o in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: _chosen == null ? () => _tap(o) : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: _chosen == null
                          ? Colors.black12
                          : o == target.uz
                              ? AppColors.success
                              : o == _chosen
                                  ? AppColors.danger
                                  : Colors.black12,
                      width: 1.8,
                    ),
                  ),
                  child: Text(
                    o,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 6: Lint va testlarni tekshirish**

Run:
```bash
d:\flutter\bin\flutter analyze
```
Expected: `No issues found!`

Run:
```bash
d:\flutter\bin\flutter test
```
Expected: 33 ta test o'tadi.

- [ ] **Step 7: Commit**

> Git repo yo'q bo'lsa bu qadamni o'tkazib yuboring.

```bash
git add lib/screens/homework/homework_flow.dart
git commit -m "feat(homework): match raundi va xatolar ustida ishlash"
```

---

## Task 4: `unit_screen.dart` ga ulash

**Files:**
- Modify: `lib/screens/unit_screen.dart:52-56` (Homework bo'limi) va `:159-185` (`_HomeworkCard`)

**Interfaces:**
- Consumes: Task 2/3 dan `HomeworkFlow({required Unit unit, required List<Word> unitWords, required List<Word> levelWords})`
- Produces: (yakuniy — boshqa task ishlatmaydi)

- [ ] **Step 1: Import qo'shish**

`lib/screens/unit_screen.dart` boshidagi import bloki ichida, `import 'pack/pack_flow.dart';` dan keyin qo'shing:

```dart
import 'homework/homework_flow.dart';
```

- [ ] **Step 2: Homework bo'limini haqiqiy ma'lumot bilan ulash**

`lib/screens/unit_screen.dart` ichidagi quyidagi blokni:

```dart
              const SizedBox(height: 24),
              _sectionTitle(context, '📝 Homework', '4 interaktiv mashq turi'),
              const SizedBox(height: 12),
              EntranceFade(
                child: _HomeworkCard(),
              ),
```

bunga almashtiring:

```dart
              const SizedBox(height: 24),
              _sectionTitle(
                context,
                '📝 Homework',
                'Unit bo\'yicha test — o\'tish uchun 80%',
              ),
              const SizedBox(height: 12),
              EntranceFade(
                child: _HomeworkCard(
                  unitWords: _unitWords(c),
                  done: progress.isDone('hw::${unit.id}'),
                  onStart: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomeworkFlow(
                        unit: unit,
                        unitWords: _unitWords(c),
                        levelWords: c.wordsById.values.toList(),
                      ),
                    ),
                  ),
                ),
              ),
```

- [ ] **Step 3: Unit so'zlarini yig'uvchi yordamchi qo'shish**

`lib/screens/unit_screen.dart` ichida, `_sectionTitle` metodidan oldin (`UnitScreen` klassi ichida) qo'shing:

```dart
  /// Unitning barcha vocab so'zlari (takrorsiz) — Homework testi uchun.
  List<Word> _unitWords(LevelContent c) {
    final seen = <String, Word>{};
    for (final cm in unit.vocabComponents) {
      for (final p in cm.packs) {
        for (final x in c.wordsOf(p)) {
          seen[x.id] = x;
        }
      }
    }
    return seen.values.toList();
  }
```

- [ ] **Step 4: `_HomeworkCard` ni 3 holatli qilib qayta yozish**

`lib/screens/unit_screen.dart` oxiridagi butun `_HomeworkCard` klassini almashtiring:

```dart
/// Homework kartasi — 3 holat: so'z yo'q / bajarilmagan / bajarilgan.
class _HomeworkCard extends StatelessWidget {
  final List<Word> unitWords;
  final bool done;
  final VoidCallback onStart;

  const _HomeworkCard({
    required this.unitWords,
    required this.done,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final empty = unitWords.isEmpty;
    final color = empty
        ? AppColors.lightMuted
        : done
            ? AppColors.success
            : AppColors.homework;
    final shadow = empty
        ? const Color(0xFF4B5563)
        : done
            ? const Color(0xFF0F7A37)
            : const Color(0xFFB8410C);
    final label = empty
        ? 'So\'zlar yo\'q'
        : done
            ? 'Qayta topshirish'
            : 'Testni boshlash';

    return Pressable3D(
      color: color,
      shadowColor: shadow,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: AppRadius.md,
      enabled: !empty,
      onPressed: onStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            empty
                ? Icons.block_rounded
                : done
                    ? Icons.check_circle_rounded
                    : Icons.quiz_rounded,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          if (!empty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${unitWords.length} so\'z',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Lint tekshiruvi**

Run:
```bash
d:\flutter\bin\flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 6: Barcha testlarni ishga tushirish**

Run:
```bash
d:\flutter\bin\flutter test
```
Expected: 33 ta test o'tadi.

- [ ] **Step 7: Commit**

> Git repo yo'q bo'lsa bu qadamni o'tkazib yuboring.

```bash
git add lib/screens/unit_screen.dart
git commit -m "feat(homework): unit ekraniga ulash (3 holat)"
```

- [ ] **Step 8: TO'XTASH — foydalanuvchi qo'lda sinaydi**

Ilovani ishga tushirish:
```bash
d:\flutter\bin\flutter run -d chrome
```

Sinash ro'yxati:
1. Darslar → Unit 1 → pastda **Homework** kartasi to'q sariq, "12 so'z" belgisi bilan
2. "Testni boshlash" → savollar ketma-ket keladi (har 3-savol harf yig'ish)
3. Xato javob → to'g'risi yashil bilan ochiladi
4. Savollar tugagach **Moslash raundi**
5. Xato qilingan bo'lsa **"Xatolar ustida ishlash"** raundi (bahoga ta'sir qilmaydi)
6. Natija: foiz, 80%+ bo'lsa yashil "O'tdingiz! 🎉" va +10 XP bonus
7. 80%+ olgach unitga qaytilsa — Homework kartasi **yashil** "Qayta topshirish" bo'ladi
8. Header'dagi XP/coin/streak yangilangan bo'lishi kerak

---

## Bajarilgandan keyin

Xotira faylini (`enterprise-trainer-stack.md`) yangilash: Homework endi bajarilgan, "KEYINGI nomzodlar" ro'yxatidan (A) olib tashlanadi.
