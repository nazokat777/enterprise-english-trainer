import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/speak/pronunciation_screen.dart';
import 'package:enterprise_english/stats.dart';

/// Talaffuz treningi: o'rganilgan so'zlardan navbat, o'tkazish, yakun.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('3 so\'z -> 3 marta o\'tkazish -> yakun', (t) async {
    SharedPreferences.setMockInitialValues({});
    app.rewards = RewardEngine();
    app.progress = Progress();
    app.mastery = MasteryStore();
    await app.rewards.load();
    await app.progress.load();
    await app.mastery.load();
    for (final (en, uz) in [('cat', 'mushuk'), ('dog', 'it'), ('cow', 'sigir')]) {
      await app.mastery.record('w::$en', AskFormat.choice, ok: true, en: en, uz: uz);
    }
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(const MaterialApp(home: PronunciationScreen(count: 10)));
    await t.pump();
    expect(find.text('Talaffuz · 1/3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.textContaining('tkazish'));
      await t.pump();
    }
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Trening tugadi'), findsOneWidget);
    expect(find.text('0 / 3 so\'z to\'g\'ri aytildi'), findsOneWidget);
  });

  testWidgets('so\'z yo\'q -> maslahat', (t) async {
    SharedPreferences.setMockInitialValues({});
    app.mastery = MasteryStore();
    await app.mastery.load();
    await t.pumpWidget(const MaterialApp(home: PronunciationScreen()));
    await t.pump();
    expect(find.textContaining('Hali o\'rganilgan so\'z yo\'q'), findsOneWidget);
  });
}
