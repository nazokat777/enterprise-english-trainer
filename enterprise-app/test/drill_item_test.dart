import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/drill/drill_item.dart';

/// SAVOL YASASH — javob hech qachon savolning O'ZIDA ko'rinmasin.
///
/// XATO edi: o'zbekcha tarjimasi YO'Q bandda "harflab yozish" savoli
/// savol matni sifatida inglizcha javobning o'zini ko'rsatardi:
///
///   Savol:  The Statue of Liberty is in New York, the USA.
///   Javob:  The Statue of Liberty is in New York, the USA.
///
/// O'quvchi shunchaki ko'chirardi va hech narsa yodlanmasdi. Buni
/// faqat jonli saytda ochib ko'rgandagina sezish mumkin edi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.repo = ContentRepository();
    app.book = BookRepository();
    await Future.wait([
      app.mastery.load(),
      app.progress.load(),
      app.repo.load(),
      app.book.loadIndex(),
    ]);
  });

  final pool = [
    const DrillSource(itemId: 'a', en: 'cat', uz: 'mushuk'),
    const DrillSource(itemId: 'b', en: 'dog', uz: 'it'),
    const DrillSource(itemId: 'c', en: 'bird', uz: 'qush'),
  ];

  test('tarjimasiz band harflab yozishga BERILMAYDI', () {
    const s = DrillSource(
        itemId: 'x', en: 'The Statue of Liberty is in New York.', uz: '');

    final q = buildQuestion(s, AskFormat.build, pool, Random(1));

    expect(q, isNull, reason: 'savol javobning o\'zi bo\'lib qolardi');
  });

  test('tarjimasiz band tanlashga ham BERILMAYDI', () {
    const s = DrillSource(itemId: 'x', en: 'book', uz: '');

    final q = buildQuestion(s, AskFormat.choice, pool, Random(1));

    expect(q, isNull);
  });

  test('tarjimasi bor band harflab yozishga yaraydi', () {
    const s = DrillSource(itemId: 'x', en: 'book', uz: 'kitob');

    final q = buildQuestion(s, AskFormat.build, pool, Random(1))!;

    expect(q.prompt, 'kitob', reason: 'savol O\'ZBEKChA');
    expect(q.answer, 'book');
    expect(q.pieces, ['b', 'o', 'o', 'k']);
  });

  test('juda uzun gap eshitib yozishga berilmaydi', () {
    const s = DrillSource(
        itemId: 'x',
        en: 'There is also a study with a big bookcase in the house.',
        uz: 'Uyda katta kitob javonli ish xonasi ham bor.');

    expect(buildQuestion(s, AskFormat.listen, pool, Random(1)), isNull);
  });

  test('javob variantlar ichida va takrorlanmaydi', () {
    const s = DrillSource(itemId: 'x', en: 'book', uz: 'kitob');

    final q = buildQuestion(s, AskFormat.choice, pool, Random(3))!;

    expect(q.options, contains(q.answer));
    expect(q.options.toSet().length, q.options.length);
    expect(q.options.length, greaterThanOrEqualTo(2));
  });

  test('HAQIQIY kitobda savol javobni oshkor qilmaydi', () async {
    final rnd = Random(7);
    var checked = 0;
    final bad = <String>[];

    for (final brief in app.book.units.take(12)) {
      final u = await app.book.load(brief.unit);
      if (u == null) continue;
      // Havza HAR BAND uchun qayta hisoblanmasin — unit bo'yicha
      // bir marta. Aks holda tekshiruv 30 soniyadan oshib ketadi.
      final src = sourcesFromUnit(u);
      for (final s in src) {
        for (final f in AskFormat.values) {
          // Talaffuzda savol = javob ATAYLAB (so'z ko'rsatilib aytiladi).
          if (f == AskFormat.speak) continue;
          final q = buildQuestion(s, f, src, rnd);
          if (q == null) continue;
          checked++;
          final prompt = q.prompt.trim().toLowerCase();
          final answer = q.answer.trim().toLowerCase();
          if (prompt == answer) {
            bad.add('${q.format} | ${q.prompt}');
          }
        }
      }
    }

    expect(checked, greaterThan(500), reason: 'haqiqiy kontent tekshirilsin');
    expect(bad, isEmpty, reason: bad.take(5).join('; '));
  });


  // XATO edi: mashqning tanlash bandida `en` javob, `uz` esa SAVOL
  // tarjimasi. Ularni tarjima juftidek so\'rash ma\'nosiz savol berardi:
  //   "Brazil"  ->  "Ketmon ushlagan ikki dehqon, dalada"
  group('tarjima jufti BO\'LMAGAN band', () {
    const s = DrillSource(
      itemId: 't::x::0',
      en: 'Brazil',
      uz: 'Ketmon ushlagan ikki dehqon, dalada',
      pair: false,
      question: 'Two farmers with hoes, working in a field',
      sentence: 'Two farmers with hoes, working in a field',
      options: ['Brazil', 'Spain', 'India', 'Scotland'],
    );

    test('o\'z savoli bilan so\'raladi, tarjima juftidek emas', () {
      final qq = buildQuestion(s, AskFormat.choice, pool, Random(1))!;

      expect(qq.prompt, 'Two farmers with hoes, working in a field');
      expect(qq.answer, 'Brazil');
      expect(qq.options, contains('Brazil'));
    });

    test('o\'zbekchadan inglizchaga so\'ralmaydi', () {
      expect(buildQuestion(s, AskFormat.produce, pool, Random(1)), isNull);
      expect(buildQuestion(s, AskFormat.listen, pool, Random(1)), isNull);
    });

    test('harflab yozishda savol GAP bo\'ladi, tarjima emas', () {
      final qq = buildQuestion(s, AskFormat.build, pool, Random(1))!;
      expect(qq.prompt, isNot('Ketmon ushlagan ikki dehqon, dalada'));
      expect(qq.answer, 'Brazil');
    });
  });

  test('HAQIQIY kitobda javob savolga MA\'NAN mos', () async {
    // Tarjima juftidek so\'ralgan bandning javobi UZUN gap bo\'lmasin —
    // "so\'z -> tavsif" ko\'rinishidagi savollar shundan bilinadi.
    final rnd = Random(11);
    final bad = <String>[];
    for (final brief in app.book.units.take(10)) {
      final u = await app.book.load(brief.unit);
      if (u == null) continue;
      final src = sourcesFromUnit(u);
      for (final x in src) {
        final qq = buildQuestion(x, AskFormat.choice, src, rnd);
        if (qq == null) continue;
        // Tanlash savolida javob 5 so\'zdan uzun bo\'lsa — bu tarjima
        // emas, tavsif.
        if (x.pair && qq.answer.split(RegExp(r'\s+')).length > kMaxWords) {
          bad.add('${qq.prompt} -> ${qq.answer}');
        }
      }
    }
    expect(bad, isEmpty,
        reason: 'uzun matn mashq bandi bo\'lmasin: ${bad.take(3).join(' | ')}');
  });
}
