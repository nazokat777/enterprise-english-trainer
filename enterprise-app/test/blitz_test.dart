import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/blitz/blitz_screen.dart';
import 'package:enterprise_english/drill/drill_item.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/stats.dart';

/// ⚡ Blitz — 60 soniya, ochko, rekord.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sources = [
    for (final p in const [
      ('cat', 'mushuk'),
      ('dog', 'it'),
      ('cow', 'sigir'),
      ('hen', 'tovuq'),
      ('goat', 'echki'),
      ('horse', 'ot'),
      ('sheep', 'qo\'y'),
      ('duck', 'o\'rdak'),
    ])
      DrillSource(itemId: 'w::${p.$1}', en: p.$1, uz: p.$2),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.rewards = RewardEngine();
    await Future.wait(
        [app.progress.load(), app.mastery.load(), app.rewards.load()]);
  });

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: BlitzScreen(sources: sources, label: 'Test', recordKey: 'k')));
    await t.pump();
  }

  /// Ekrandagi savolga to'g'ri javob beradi (variantlar orasidan
  /// javobni topib bosadi).
  Future<bool> answerRight(WidgetTester t) async {
    for (final s in sources) {
      for (final cand in [s.en, s.uz]) {
        final f = find.widgetWithText(InkWell, cand);
        if (f.evaluate().isEmpty) continue;
        // Savol matni (prompt) InkWell ichida emas — faqat variantlar.
        // To'g'ri javob: prompt inglizcha bo'lsa uz, aks holda en.
        final promptIsEn = find.text(s.en).evaluate().isNotEmpty &&
            find.widgetWithText(InkWell, s.en).evaluate().isEmpty;
        final promptIsUz = find.text(s.uz).evaluate().isNotEmpty &&
            find.widgetWithText(InkWell, s.uz).evaluate().isEmpty;
        if (promptIsEn && cand == s.uz) {
          await t.tap(f);
          return true;
        }
        if (promptIsUz && cand == s.en) {
          await t.tap(f);
          return true;
        }
      }
    }
    return false;
  }

  testWidgets('boshlash, to\'g\'ri javoblar ochko beradi, 60 s da tugaydi',
      (t) async {
    await pump(t);
    expect(find.text('BOShLASh'), findsOneWidget);
    await t.tap(find.text('BOShLASh'));
    await t.pump();
    expect(find.text('60'), findsOneWidget);

    var scored = 0;
    for (var i = 0; i < 6; i++) {
      final ok = await answerRight(t);
      expect(ok, isTrue, reason: 'savol $i uchun javob topilmadi');
      scored += 1;
      await t.pump(const Duration(milliseconds: 300));
    }
    // 5-javobdan boshlab x2: 1+1+1+1+2+2 = 8 ochko.
    expect(find.text('8'), findsWidgets);
    expect(find.text('x2'), findsOneWidget);

    await t.pump(const Duration(seconds: 61));
    expect(find.text('YANGI REKORD!'), findsOneWidget);
    expect(await BlitzScreen.bestOf('k'), 8);
    expect(app.progress.xp, greaterThanOrEqualTo(8 + 15));
    expect(scored, 6);
    // Konfetti animatsiyasi tugasin.
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('4 tadan kam so\'z bo\'lsa boshlab bo\'lmaydi', (t) async {
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: BlitzScreen(
            sources: sources.take(3).toList(), label: 'T', recordKey: 'k2')));
    await t.pump();
    expect(find.text('Kamida 4 ta so\'z kerak'), findsOneWidget);
  });
}
