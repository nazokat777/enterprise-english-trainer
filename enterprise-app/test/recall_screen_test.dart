import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/drill/drill_item.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/plan/recall_screen.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/stats.dart';

/// Yopib eslash: o'zlashtirilgan so'zlar ham so'raladi, xato qaytadi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("o'zbekcha -> inglizcha, xato so'z qaytadi, oxirida natija", (t) async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.rewards = RewardEngine();
    await app.progress.load();
    await app.mastery.load();
    await app.rewards.load();
    // So'zlar ALLAQACHON o'zlashtirilgan - baribir so'ralishi kerak.
    for (final f in AskFormat.values) {
      await app.mastery.record('w::cat', f, ok: true, en: 'cat', uz: 'mushuk');
    }
    t.view.physicalSize = const Size(420, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    const words = [
      DrillSource(itemId: 'w::cat', en: 'cat', uz: 'mushuk', unit: 1, topic: ''),
      DrillSource(itemId: 'w::dog', en: 'dog', uz: 'it', unit: 1, topic: ''),
    ];
    final before = app.rewards.exercisesDone;
    await t.pumpWidget(const MaterialApp(
        home: RecallScreen(title: 'Eslash', words: words)));
    await t.pump();
    expect(find.text('Inglizchasini yozing (qaramasdan):'), findsOneWidget);

    var wrongOnce = false;
    for (var i = 0; i < 6; i++) {
      if (find.text('Tayyor').evaluate().isNotEmpty) break;
      final isCat = find.text('mushuk').evaluate().isNotEmpty;
      final answer = !wrongOnce ? 'xxx' : (isCat ? 'cat' : 'dog');
      wrongOnce = true;
      await t.enterText(find.byType(TextField), answer);
      await t.pump();
      await t.tap(find.text('Tekshirish'));
      await t.pump();
      await t.tap(find.text('Keyingisi'));
      await t.pump();
    }
    expect(find.text('Tayyor'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget); // bittasi birinchi urinishda
    expect(app.rewards.exercisesDone, before + 1);
  });
}
