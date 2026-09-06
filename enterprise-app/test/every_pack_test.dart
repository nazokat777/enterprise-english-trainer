import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/pack/pack_flow.dart';
import 'package:enterprise_english/srs.dart';
import 'package:enterprise_english/screens/homework/homework_flow.dart';
import 'package:enterprise_english/screens/unit_screen.dart';

/// LUG'ATDAGI HAR BIR PAKET va HAR BIR UY VAZIFASI chiziladimi.
///
/// `vocab_flow_layout_test.dart` faqat SUN'IY so'zlar bilan ishlaydi.
/// Haqiqiy lug'atda esa uzun so'zlar ("grandmother"), ko'p bo'lakli
/// iboralar va uzun misol gaplar bor — ular tor telefonda chiqib
/// ketishi mumkin, va buni faqat o'quvchi o'sha paketni ochganda
/// bilinardi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.repo = ContentRepository();
    await Future.wait([app.progress.load(), app.repo.load()]);
  });

  Future<List<String>> sweep(WidgetTester t, Size size,
      {double scale = 1.0}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    final c = app.repo.forLevel('beginner');
    final broken = <String>[];
    var count = 0;

    Future<void> check(String what, Widget w) async {
      count++;
      await t.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: w),
        ),
      ));
      await t.pump();
      final err = t.takeException();
      if (err != null) broken.add('$what: $err');
    }

    for (final u in c.units) {
      await check('${u.code} unit ekrani', UnitScreen(unit: u));
      final unitWords = <Word>[];
      for (final comp in u.components) {
        for (final p in comp.packs) {
          final words = c.wordsOf(p);
          if (words.isEmpty) continue;
          unitWords.addAll(words);
          await check('${u.code} / ${p.name}',
              PackFlow(unit: u, pack: p, words: words));
          // PackFlow birinchi pump'da faqat TANIShUV bosqichini
          // chizadi. Qolgan bosqichlar (moslash, imlo, yig'ish) —
          // aynan plitkalar va yozuvlar ko'p bo'lgan joylar — shu
          // yerda alohida tekshiriladi.
          Future<void> noop(Word w, Quality q) async {}
          final single =
              words.where((w) => !w.en.trim().contains(' ')).toList();
          final phrases =
              words.where((w) => w.en.trim().contains(' ')).toList();
          await check('${u.code} / ${p.name} moslash',
              MatchStage(words: words, onReview: noop, onDone: () {}));
          if (single.isNotEmpty) {
            await check('${u.code} / ${p.name} imlo',
                SpellStage(words: single, onReview: noop, onDone: () {}));
          }
          if (phrases.isNotEmpty) {
            await check('${u.code} / ${p.name} yig\'ish',
                BuildStage(words: phrases, onReview: noop, onDone: () {}));
          }
        }
      }
      if (unitWords.isNotEmpty) {
        await check(
            '${u.code} uy vazifasi',
            HomeworkFlow(
                unit: u, unitWords: unitWords, levelWords: c.wordsById.values.toList()));
      }
    }

    await t.pumpWidget(const SizedBox());
    expect(count, greaterThan(50), reason: 'lug\'at to\'liq yuklansin');
    return broken;
  }

  testWidgets('barcha paketlar 375px da chiziladi', (t) async {
    final broken = await sweep(t, const Size(375, 812));
    expect(broken, isEmpty, reason: broken.take(8).join('; '));
  });

  testWidgets('barcha paketlar 320px da ham sig\'adi', (t) async {
    final broken = await sweep(t, const Size(320, 640));
    expect(broken, isEmpty, reason: broken.take(8).join('; '));
  });

  testWidgets('barcha paketlar 1.5x shriftda sig\'adi', (t) async {
    final broken = await sweep(t, const Size(375, 812), scale: 1.5);
    expect(broken, isEmpty, reason: broken.take(8).join('; '));
  });
}
