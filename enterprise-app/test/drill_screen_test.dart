import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/drill/drill_item.dart';
import 'package:enterprise_english/drill/drill_screen.dart';

/// DARS USTASI EKRANI — savolga javob berishning o'zi.
///
/// Ayniqsa HARFLAB YOZISh bosqichi: egasining talabi bo'yicha lug'at
/// o'zbekcha so'ralib, inglizchasi harflardan yig'iladi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.repo = ContentRepository();
    await Future.wait([app.mastery.load(), app.progress.load()]);
  });

  List<DrillSource> words(int n) => [
        for (var i = 0; i < n; i++)
          DrillSource(
              itemId: 'w::s$i', en: 'word$i', uz: 'soz$i', topic: 'Lug\'at'),
      ];

  Future<void> pump(WidgetTester t, List<DrillSource> src,
      {Size size = const Size(420, 900)}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: DrillScreen(title: '1-unit', lessonSources: src),
    ));
    await t.pump();
  }

  testWidgets('tanlash savoli chiziladi va javob qabul qilinadi', (t) async {
    await pump(t, words(4));

    // Savol matni — inglizcha so'z.
    expect(find.textContaining('word'), findsWidgets);
    // Variantlar — o'zbekcha.
    expect(find.textContaining('soz'), findsWidgets);

    // Savollar aralashtiriladi — QAYSI so'z so'ralayotganini ekrandan
    // o'qib, unga mos variantni bosamiz.
    var asked = -1;
    for (var i = 0; i < 4; i++) {
      if (find.text('word$i').evaluate().isNotEmpty) asked = i;
    }
    expect(asked, isNot(-1), reason: 'savol matni ko\'rinsin');

    final before = app.progress.xp;
    await t.tap(find.text('soz$asked').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    // To'g'ri javob belgisi chiqadi.
    expect(find.text('To\'g\'ri'), findsOneWidget,
        reason: 'ekranda: ${t.widgetList<Text>(find.byType(Text)).map((w) => w.data).toList()}');

    await t.pump(const Duration(milliseconds: 900));
    expect(app.progress.xp, greaterThan(before));
  });

  testWidgets('harflab yozish: savol O\'ZBEKChA, javob harflardan', (t) async {
    // Bandni tanlash shaklidan o'tkazamiz — keyingisi yozish bo'ladi.
    await app.mastery.record('w::s0', AskFormat.choice, ok: true);

    await pump(t, [
      const DrillSource(
          itemId: 'w::s0', en: 'book', uz: 'kitob', topic: 'Lug\'at')
    ]);

    expect(find.text('kitob'), findsOneWidget, reason: 'savol o\'zbekcha');
    expect(find.text('Inglizchasini harflab yozing'), findsOneWidget);
    // Harflar alohida plitkalarda.
    for (final ch in ['b', 'o', 'k']) {
      expect(find.text(ch), findsWidgets, reason: '$ch harfi bo\'lsin');
    }
    // Javobning O'ZI ko'rinmasin.
    expect(find.text('book'), findsNothing);
  });

  testWidgets('noto\'g\'ri yig\'ilsa to\'g\'ri javob ko\'rsatiladi',
      (t) async {
    await app.mastery.record('w::s0', AskFormat.choice, ok: true);

    await pump(t, [
      const DrillSource(
          itemId: 'w::s0', en: 'cat', uz: 'mushuk', topic: 'Lug\'at')
    ]);

    // "cat" o'rniga "act" yig'amiz — ataylab noto'g'ri.
    //
    // `.last` MUHIM: yig'ilayotgan so'z ham bitta harf bo'lib qolishi
    // mumkin va u daraxtda plitkalardan OLDIN turadi.
    for (final ch in ['a', 'c', 't']) {
      await t.tap(find.text(ch).last, warnIfMissed: false);
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('To\'g\'risi:'), findsOneWidget,
        reason: 'xato JAZO emas — to\'g\'ri javob ko\'rsatiladi');
  });

  testWidgets('tor telefonda ham sig\'adi', (t) async {
    await pump(t, words(6), size: const Size(320, 640));
    expect(t.takeException(), isNull);
  });

  testWidgets('katta shriftda ham sig\'adi', (t) async {
    t.view.physicalSize = const Size(375, 812);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: DrillScreen(title: '1-unit', lessonSources: words(6)),
      ),
    ));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
