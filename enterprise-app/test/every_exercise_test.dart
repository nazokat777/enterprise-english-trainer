import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/book_screens.dart';
import 'package:enterprise_english/screens/book/exercise_player.dart';
import 'package:enterprise_english/screens/book/reference_screens.dart';

/// KITOBDAGI HAR BIR MASHQ chiziladimi.
///
/// Alohida testlar faqat namunaviy mashqlarni sinaydi. Kitobda esa 1545
/// mashq bor va ular 24 xil manba turidan yasalgan — kamdan-kam
/// uchraydigan shakl (bo'sh variantlar ro'yxati, juda uzun matn, bitta
/// bandli moslash) faqat o'quvchi o'sha betni ochganda bilinardi.
///
/// Bu yerda hammasi telefon o'lchamida chiziladi va hech biri xato
/// bermasligi tekshiriladi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<BookUnit> allUnits;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.repo = ContentRepository();
    app.book = BookRepository();
    await Future.wait([app.mastery.load(), app.progress.load(), app.repo.load(), app.book.loadIndex()]);
    final loaded =
        await Future.wait(app.book.units.map((b) => app.book.load(b.unit)));
    allUnits = loaded.whereType<BookUnit>().toList();
  });

  Future<void> renderAll(WidgetTester t, Size size,
      {double scale = 1.0}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    final broken = <String>[];
    var count = 0;

    for (final u in allUnits) {
      for (final s in u.sections) {
        for (final e in s.exercises) {
          count++;
          await t.pumpWidget(MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: ExercisePlayer(
                exercise: e,
                sectionTitle: s.titleUz,
                unitLabel: u.displayLabel,
              ),
            ),
          ));
          await t.pump();
          final err = t.takeException();
          if (err != null) {
            broken.add('${u.displayLabel} / ${s.titleUz} / Ex.${e.ref}: $err');
          }
        }
      }
    }

    // Bo'shatib qo'yamiz — keyingi testlar uchun toza holat.
    await t.pumpWidget(const SizedBox());

    expect(count, greaterThan(1000), reason: 'kitob to\'liq yuklansin');
    expect(broken, isEmpty,
        reason: '${size.width.round()}px x$scale: '
            '${broken.take(10).join('; ')}');
  }

  testWidgets('barcha mashqlar 375px da xatosiz chiziladi', (t) async {
    await renderAll(t, const Size(375, 812));
  });

  // Chiqib ketish (overflow) aynan TOR ekranda chiqadi — qobiq
  // panelida shunday xato bor edi va uni faqat brauzerda ochib
  // ko'rgandagina sezish mumkin edi.
  testWidgets('barcha mashqlar 320px da ham sig\'adi', (t) async {
    await renderAll(t, const Size(320, 640));
  });

  // Tizim shrifti kattalashtirilgan telefonlar ham bor.
  testWidgets('barcha mashqlar 1.5x shriftda sig\'adi', (t) async {
    await renderAll(t, const Size(375, 812), scale: 1.5);
  });


  // Mashqlardan tashqari ma\'lumotnoma ekranlari ham kitob kontentini
  // chizadi: qoidalar, so\'z oilalari, gap qoliplari, unit lug\'ati.
  // Ularda ham noyob shakl uchrashi mumkin.
  testWidgets('barcha ma\'lumotnoma ekranlari 320px da sig\'adi', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    final broken = <String>[];
    var count = 0;

    Future<void> check(String what, Widget w) async {
      count++;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: w)));
      await t.pump();
      final err = t.takeException();
      if (err != null) broken.add('$what: $err');
    }

    for (final u in allUnits) {
      if (u.wordFormation.isNotEmpty) {
        await check('${u.displayLabel} so\'z yasalishi',
            WordFormationScreen(unit: u));
      }
      if (u.sentencePatterns.isNotEmpty) {
        await check('${u.displayLabel} gap qoliplari',
            SentencePatternsScreen(unit: u));
      }
      if (u.vocabulary.isNotEmpty) {
        await check('${u.displayLabel} lug\'at', UnitVocabularyScreen(unit: u));
      }
      for (final s in u.sections) {
        if (s.rule != null) {
          await check('${u.displayLabel} / ${s.titleUz} qoida',
              RuleScreen(section: s));
        }
      }
    }

    await t.pumpWidget(const SizedBox());
    expect(count, greaterThan(50));
    expect(broken, isEmpty, reason: broken.take(10).join('; '));
  });


  // Unit va bet ro\'yxatlari ham haqiqiy kontent bilan chiziladi.
  // `mobile_layout_test.dart` faqat SUN\'IY unit bilan ishlaydi.
  testWidgets('barcha unit va bet ekranlari 320px da sig\'adi', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    final broken = <String>[];
    var count = 0;

    Future<void> check(String what, Widget w) async {
      count++;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: w)));
      await t.pump();
      final err = t.takeException();
      if (err != null) broken.add('$what: $err');
    }

    for (final u in allUnits) {
      await check('${u.displayLabel} unit', BookUnitScreen(unit: u));
      await check('${u.displayLabel} betlar', BookPagesScreen(unit: u));
      for (final pg in u.pages()) {
        await check('${u.displayLabel} ${pg.book} ${pg.bookPage}-bet',
            BookPageScreen(page: pg));
      }
    }

    await t.pumpWidget(const SizedBox());
    expect(count, greaterThan(200));
    expect(broken, isEmpty, reason: broken.take(8).join('; '));
  });
}
