import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/screens/homework/homework_model.dart';

/// Uy vazifasi rejasi HAQIQIY lug'at ustida quriladi.
///
/// Model testlari (homework_test.dart) kichik namunaviy so'zlar bilan
/// ishlaydi. Bu yerda esa ilova yuklaydigan 388 so'z va 34 unitning
/// HAMMASI uchun reja quriladi — chunki savol sifati aynan ma'lumotga
/// bog'liq: misol gap, tarjima takrorlari, so'z turkumi.
const _base = 'assets/content/beginner';

Map<String, dynamic> _json(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  late List<Word> words;
  late Map<String, Word> byId;
  late List<Unit> units;

  setUpAll(() {
    words = (_json('$_base/words.json')['words'] as List)
        .map((e) => Word.fromJson(e as Map<String, dynamic>))
        .toList();
    byId = {for (final w in words) w.id: w};
    units = (_json('$_base/units.json')['units'] as List)
        .map((e) => Unit.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  List<Word> unitWords(Unit u) => [
        for (final c in u.vocabComponents)
          for (final p in c.packs)
            for (final id in p.wordIds)
              if (byId[id] != null) byId[id]!,
      ];

  test('har bir unit uchun reja quriladi va savollari to\'g\'ri', () {
    // Qat'iy urug' — natija takrorlanadigan bo'lsin.
    final rnd = Random(7);
    var total = 0;

    for (final u in units) {
      final uw = unitWords(u);
      if (uw.isEmpty) continue;
      final plan = buildPlan(uw, words, rnd);
      total += plan.questions.length;

      expect(plan.questions, isNotEmpty, reason: '${u.code}: savol yo\'q');
      expect(plan.totalPoints, greaterThan(0));

      for (final q in plan.questions) {
        expect(q.word.uz.trim(), isNotEmpty,
            reason: '${u.code}: "${q.word.en}" tarjimasiz');

        switch (q.kind) {
          case QuestionKind.construct:
            expect(q.options, isEmpty);
          case QuestionKind.choose:
          case QuestionKind.fill:
            // Javob variantlar ichida bo'lishi SHART.
            expect(q.options, contains(q.answer),
                reason: '${u.code}: "${q.word.en}" javobi variantlarda yo\'q');
            // Ikkinchi TO'G'RI javob bo'lmasin: variantlar takrorlanmaydi.
            expect(q.options.toSet().length, q.options.length,
                reason: '${u.code}: "${q.word.en}" variantlari takrorlangan');
            expect(q.options.length, greaterThanOrEqualTo(2));
        }

        if (q.kind == QuestionKind.fill) {
          expect(q.sentence, isNotNull);
          expect(q.sentence, contains('_____'),
              reason: '${u.code}: "${q.word.en}" gapida bo\'shliq yo\'q');
          // Bo'shliq to'g'ri so'z o'rniga qo'yilgan — javob gapda
          // QOLMASLIGI kerak, aks holda javob ko'rinib turadi.
          expect(q.sentence!.toLowerCase(),
              isNot(contains(RegExp(r'\b' + q.word.en.toLowerCase() + r'\b'))),
              reason: '${u.code}: "${q.word.en}" javobi gapda qolgan');
        }
      }
    }
    expect(total, greaterThan(100));
  });

  test('o\'tish chegarasi butun son arifmetikasi bilan hisoblanadi', () {
    // 79.5% yaxlitlanib 80 bo'lib ketmasligi kerak.
    const r = HwResult(earned: 159, total: 200); // 79.5%
    expect(r.percent, 80); // ko'rsatishda yaxlitlanadi
    expect(r.passed, isFalse); // lekin O'TMAYDI
    const ok = HwResult(earned: 160, total: 200); // 80%
    expect(ok.passed, isTrue);
  });

  test('bo\'sh unit yiqilmaydi', () {
    final plan = buildPlan(const [], words, Random(1));
    expect(plan.questions, isEmpty);
    expect(plan.totalPoints, 0);
  });
}
