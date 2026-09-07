import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/drill/drill_item.dart';
import 'package:enterprise_english/drill/drill_session.dart';

/// DARS USTASI — "100% javob bergunicha qo'ymaydi" mantiqi.
///
/// Egasining talabi: bugungi darsni to'liq o'zlashtirgunicha
/// qayta-qayta so'rasin, so'ng shu darsgacha bo'lgan hamma mavzu
/// aralashtirilib yana 100% gacha.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  List<DrillSource> lesson(int n, {int unit = 9}) => [
        for (var i = 0; i < n; i++)
          DrillSource(
            itemId: 'w::soz$i',
            en: 'word$i',
            uz: 'soz$i',
            unit: unit,
            topic: 'Lug\'at',
          ),
      ];

  Future<MasteryStore> store() async {
    final s = MasteryStore();
    await s.load();
    return s;
  }

  test('savol bor va u shu darsdan', () async {
    final s = DrillSession(
        mastery: await store(),
        lessonSources: lesson(3),
        random: Random(1));

    expect(s.phase, DrillPhase.lesson);
    expect(s.current, isNotNull);
    expect(s.current!.unit, 9);
  });

  test('lug\'at savoli AVVAL tanish, KEYIN harflab yozish', () async {
    final m = await store();
    final s = DrillSession(
        mastery: m, lessonSources: lesson(4), random: Random(2));

    // Birinchi ko'rinish — interaktiv tanlash.
    expect(s.current!.format, AskFormat.choice);

    // Shu bandni to'g'ri javob bilan o'tkazamiz.
    final id = s.current!.itemId;
    await s.answer(true);

    // Shu band keyin qaytganda BOShQA ko'rinishda so'ralishi kerak.
    final later = DrillSession(
        mastery: m,
        lessonSources: [lesson(4).firstWhere((e) => e.itemId == id)],
        random: Random(3));
    expect(later.current!.format, isNot(AskFormat.choice));
  });

  test('band FAQAT ikki xil shakldan keyin o\'zlashtiriladi', () async {
    final m = await store();
    final src = lesson(1);
    var s = DrillSession(mastery: m, lessonSources: src, random: Random(4));

    await s.answer(true); // 1-shakl
    expect(m.allStrong(src.map((e) => e.itemId)), isFalse);

    s = DrillSession(mastery: m, lessonSources: src, random: Random(5));
    await s.answer(true); // 2-shakl
    s = DrillSession(mastery: m, lessonSources: src, random: Random(6));
    await s.answer(true); // 3-shakl (ishlab chiqarish)

    expect(m.allStrong(src.map((e) => e.itemId)), isTrue);
  });

  test('xato qilingan band SEANSNI tugatmaydi', () async {
    final m = await store();
    final src = lesson(2);
    final s = DrillSession(mastery: m, lessonSources: src, random: Random(7));

    // Hammasiga xato javob beramiz — seans tugamasligi kerak.
    for (var i = 0; i < 6 && s.phase == DrillPhase.lesson; i++) {
      await s.answer(false);
    }

    expect(m.allStrong(src.map((e) => e.itemId)), isFalse);
    expect(s.remaining, greaterThan(0));
  });

  test('dars 100% bo\'lgach ARALASH bosqichga o\'tadi', () async {
    final m = await store();
    final src = lesson(2, unit: 9);
    final earlier = lesson(3, unit: 5)
        .map((e) => DrillSource(
            itemId: '${e.itemId}-old',
            en: '${e.en}old',
            uz: '${e.uz}eski',
            unit: 5,
            topic: 'Lug\'at'))
        .toList();

    final s = DrillSession(
        mastery: m,
        lessonSources: src,
        earlierSources: earlier,
        mixedSize: 3,
        random: Random(8));

    var guard = 0;
    while (s.phase == DrillPhase.lesson && guard++ < 200) {
      await s.answer(true);
    }

    expect(m.allStrong(src.map((e) => e.itemId)), isTrue,
        reason: 'dars 100% bo\'lishi kerak');
    expect(s.phase, DrillPhase.mixed);
    expect(s.current, isNotNull);
    expect(s.current!.unit, 5, reason: 'endi OLDINGI darslardan so\'raladi');
  });

  test('aralash bosqich ham 100% gacha davom etadi', () async {
    final m = await store();
    final earlier = lesson(3, unit: 5);
    final s = DrillSession(
        mastery: m,
        lessonSources: lesson(1, unit: 9),
        earlierSources: earlier,
        mixedSize: 3,
        random: Random(9));

    var guard = 0;
    while (s.phase != DrillPhase.done && guard++ < 500) {
      await s.answer(true);
    }

    expect(s.phase, DrillPhase.done);
    expect(m.allStrong(earlier.map((e) => e.itemId)), isTrue);
  });

  test('kombo to\'g\'ri javobda o\'sadi, xatoda nolga tushadi', () async {
    final s = DrillSession(
        mastery: await store(),
        lessonSources: lesson(6),
        random: Random(10));

    await s.answer(true);
    await s.answer(true);
    expect(s.combo, 2);
    expect(s.bestCombo, 2);

    await s.answer(false);
    expect(s.combo, 0);
    expect(s.bestCombo, 2, reason: 'eng yaxshi kombo saqlanadi');
  });

  test('oldingi dars yo\'q bo\'lsa aralash bosqich o\'tkazib yuboriladi',
      () async {
    final m = await store();
    final s = DrillSession(
        mastery: m, lessonSources: lesson(1), random: Random(11));

    var guard = 0;
    while (s.phase != DrillPhase.done && guard++ < 100) {
      await s.answer(true);
    }

    expect(s.phase, DrillPhase.done);
  });


  // Bitta unitda 578 tagacha band bor. Hammasini bir o\'tirishda 100%
  // qilish imkonsiz — seans QISQA va TUGAYDIGAN bo\'lishi kerak.
  test('seans darsdan faqat bir bo\'lakni oladi', () async {
    final m = await store();
    final big = lesson(50);
    final s = DrillSession(
        mastery: m, lessonSources: big, lessonBatch: 6, random: Random(20));

    expect(s.remaining, 6, reason: 'bitta seansda 6 band');
    expect(s.lessonProgress, 0, reason: 'butun dars hali 0%');

    var guard = 0;
    while (s.phase == DrillPhase.lesson && guard++ < 300) {
      await s.answer(true);
    }

    expect(s.phase, DrillPhase.done, reason: 'oldingi dars yo\'q');
    // Dars 100% emas — lekin oldinga siljidi.
    expect(s.lessonProgress, greaterThan(0));
    expect(s.lessonProgress, lessThan(1));
  });

  test('keyingi seans QOLGAN bandlarni oladi', () async {
    final m = await store();
    final big = lesson(12);

    var s = DrillSession(
        mastery: m, lessonSources: big, lessonBatch: 4, random: Random(21));
    var guard = 0;
    while (s.phase == DrillPhase.lesson && guard++ < 300) {
      await s.answer(true);
    }
    final firstDone = big.where((e) => m.of(e.itemId).isStrong).length;
    expect(firstDone, 4);

    s = DrillSession(
        mastery: m, lessonSources: big, lessonBatch: 4, random: Random(22));
    guard = 0;
    while (s.phase == DrillPhase.lesson && guard++ < 300) {
      await s.answer(true);
    }

    expect(big.where((e) => m.of(e.itemId).isStrong).length, 8,
        reason: 'ikkinchi seans YANGI bandlarni oldi');
  });


  // O\'YIN: bir xil ko\'rinishdagi savollar ketma-ket kelsa diqqat
  // so\'nadi. Har necha savoldan keyin moslash o\'yini qo\'yiladi.
  group('moslash o\'yini', () {
    test('savollar orasiga qo\'yiladi', () async {
      final m = await store();
      final s = DrillSession(
          mastery: m, lessonSources: lesson(12), random: Random(30));

      var seenMatch = false;
      var guard = 0;
      while (s.current != null && guard++ < 30) {
        if (s.current!.format == AskFormat.match) {
          seenMatch = true;
          expect(s.current!.pairs.length, DrillSession.matchPairs);
          break;
        }
        await s.answer(true);
      }
      expect(seenMatch, isTrue, reason: 'seansda o\'yin ham bo\'lsin');
    });

    test('topilgan juftlar yoziladi, topilmagani xato', () async {
      final m = await store();
      final s = DrillSession(
          mastery: m, lessonSources: lesson(12), random: Random(31));

      var guard = 0;
      while (s.current != null &&
          s.current!.format != AskFormat.match &&
          guard++ < 30) {
        await s.answer(true);
      }
      final game = s.current!;
      expect(game.format, AskFormat.match);

      // Faqat birinchi juftni topdik.
      final first = game.pairs.first.itemId;
      await s.answerMatch({first});

      expect(m.of(first).passed.contains(AskFormat.match), isTrue);
      for (final p in game.pairs.skip(1)) {
        expect(m.of(p.itemId).lapses, greaterThan(0),
            reason: 'topilmagan juft xato hisoblansin');
      }
    });

    test('o\'yin O\'ZI bandni o\'zlashtirmaydi', () async {
      final m = await store();
      await m.record('w::x', AskFormat.match, ok: true);
      await m.record('w::x', AskFormat.choice, ok: true);

      expect(m.of('w::x').isStrong, isFalse,
          reason: 'ikkalasi ham TANISh — yozish hali tekshirilmadi');
    });
  });
}
