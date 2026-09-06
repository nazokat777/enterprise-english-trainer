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

    test('so\'z necha marta uchrasa, HAMMASI berkitiladi', () {
      // Ilgari faqat birinchisi almashardi va javob gapning o'zida
      // ko'rinib turardi — ya'ni savol o'z javobini ko'rsatardi.
      final s = fillBlank('I eat what they eat.', 'eat');
      expect(s, 'I _____ what they _____.');
    });
  });

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
}
