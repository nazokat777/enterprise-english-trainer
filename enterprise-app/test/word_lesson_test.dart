import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/drill/drill_item.dart';
import 'package:enterprise_english/levels.dart';
import 'package:enterprise_english/lessons/lesson_session.dart';
import 'package:enterprise_english/lessons/word_lesson.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';

/// SO'Z DARSLARI — Duolingo uslubi: kichik dars, avval tanishuv,
/// so'ng uch bosqich, xato qaytadi, oxirida hammasi mustahkam.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  BookUnit unitWith(int n) => BookUnit(
        unit: 1,
        title: 't',
        module: 1,
        sections: const [],
        wordFormation: const [],
        sentencePatterns: const [],
        vocabulary: [
          for (var i = 0; i < n; i++) VocabEntry(en: 'word$i', uz: 'soz$i'),
        ],
      );

  test('lug\'at 5-8 talik darslarga bo\'linadi, oxirgisi mayda emas', () {
    final ls = lessonsOf(unitWith(15));
    expect(ls.length, 3);
    for (final l in ls) {
      expect(l.words.length, inInclusiveRange(4, kLessonSize));
    }
    expect(ls.fold(0, (s, l) => s + l.words.length), 15);
    expect(ls.map((l) => l.index), [1, 2, 3]);
  });

  test('takror va inglizchasi=o\'zbekchasi bo\'lgan so\'z tashlanadi', () {
    final u = BookUnit(
      unit: 1,
      title: 't',
      module: 1,
      sections: const [],
      wordFormation: const [],
      sentencePatterns: const [],
      vocabulary: const [
        VocabEntry(en: 'golf', uz: 'golf'),
        VocabEntry(en: 'cat', uz: 'mushuk'),
        VocabEntry(en: 'Cat', uz: 'mushuk'),
        VocabEntry(en: '', uz: 'bo\'sh'),
      ],
    );
    final ls = lessonsOf(u);
    expect(ls.length, 1);
    expect(ls.first.words.map((w) => w.en), ['cat']);
  });

  test('seans: 3 raund, hammasi to\'g\'ri bo\'lsa so\'zlar mustahkam', () async {
    final m = MasteryStore();
    await m.load();
    final l = lessonsOf(unitWith(6)).first;
    final s = LessonSession(lesson: l, mastery: m, random: Random(1));

    // Raundlar tartibi: tanish -> tanlash -> yozish.
    expect(s.current!.format, AskFormat.choice);
    var n = 0;
    while (!s.isDone) {
      await s.answer(true);
      n++;
    }
    expect(n, 6 * 3);
    expect(m.allStrong(l.itemIds), isTrue);
  });

  test('xato so\'z o\'sha shaklda QAYTADI va seans uzayadi', () async {
    final m = MasteryStore();
    await m.load();
    final l = lessonsOf(unitWith(6)).first;
    final s = LessonSession(lesson: l, mastery: m, random: Random(3));

    final first = s.current!;
    await s.answer(false);
    expect(s.mistakes, 1);
    // 18 + 1 qaytarilgan.
    var seen = 0;
    var again = false;
    while (!s.isDone) {
      final q = s.current!;
      if (q.itemId == first.itemId && q.format == first.format) again = true;
      await s.answer(true);
      seen++;
    }
    expect(again, isTrue);
    expect(seen, 18);
    expect(m.allStrong(l.itemIds), isTrue);
  });

  // Ikki daraja (Beginner + Elementary) — 8000+ so'z × 3 shakl; to'liq
  // to'plam parallel yurganda 30 s standart limitga sig'maydi.
  test('har darajadagi har unit darslari savol yasay oladi', () async {
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.repo = ContentRepository();
    app.book = BookRepository();
    await Future.wait(
        [app.mastery.load(), app.progress.load(), app.repo.load()]);
    for (final level in kLevels) {
      await app.book.setLevel(level.id);
      await app.book.loadIndex();
      for (final b in app.book.units) {
        final u = await app.book.load(b.unit);
        if (u == null) continue;
        final ls = lessonsOf(u);
        if (b.words > 0) {
          expect(ls, isNotEmpty, reason: '${level.id} ${b.displayLabel}');
        }
        final pool = [for (final l in ls) ...l.sources];
        for (final l in ls) {
          // Har so'z UCh shaklda ham savolga aylanishi shart — aks
          // holda dars oxirida so'z mustahkam bo'lolmaydi.
          for (final src in l.sources) {
            for (final f in LessonSession.rounds) {
              final q = buildQuestion(src, f, pool, Random(l.index));
              expect(q, isNotNull,
                  reason: '${level.id} ${b.displayLabel} ${src.en} $f');
              if (f != AskFormat.build) {
                expect(q!.options.length, greaterThanOrEqualTo(2));
                expect(q.options, contains(q.answer));
              }
            }
          }
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
