import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/mistakes.dart';
import 'package:enterprise_english/plan/mnemonics_screen.dart';
import 'package:enterprise_english/plan/plan_store.dart';
import 'package:enterprise_english/plan/study_plan.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/stats.dart';

/// Mnemonika bo'limi HAQIQIY kitob bilan: hajm aniq sanaladi, muddat
/// tanlanadi, reja va cheklist chiqadi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.mistakes = MistakeStore();
    app.repo = ContentRepository();
    app.rewards = RewardEngine();
    app.book = BookRepository();
    app.plans = PlanStore();
    await Future.wait([
      app.progress.load(),
      app.mastery.load(),
      app.mistakes.load(),
      app.rewards.load(),
      app.book.loadIndex(),
    ]);
  });

  test('Enterprise 1 hajmi aniq (ilova darslari bilan bir xil)', () async {
    final v = await app.plans.volume();
    expect(v.units.length, 15);
    expect(v.lessons, 673);
    expect(v.rules, 51);
    expect(v.grammarExercises, 430);
    expect(v.uniqueWords, greaterThan(3000));
    expect(v.wordsPerLesson, closeTo(7, 0.3));
    // 1-unit: 186 so'z, 27 dars, 4 qoida.
    final u1 = v.units.first;
    expect(u1.unit, 1);
    expect(u1.words, 186);
    expect(u1.lessons.length, 27);
    expect(u1.rules.length, 4);
  });

  testWidgets('reja yo\'q -> muddat tanlash; tanlangach cheklist', (t) async {
    t.view.physicalSize = const Size(420, 2600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(const MaterialApp(home: Scaffold(body: MnemonicsScreen())));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump();

    expect(find.text('Kitob hajmi'), findsOneWidget);
    expect(find.text('673'), findsOneWidget);
    expect(find.text('Kitobni necha kunda tugatasiz?'), findsOneWidget);
    expect(find.text('2 oy'), findsOneWidget);
    expect(find.text('Tavsiya'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.tap(find.text('2 oy'));
    await t.pump();
    await t.tap(find.textContaining('Rejani boshlash'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump();

    expect(find.text('1-kun / 60'), findsOneWidget);
    expect(find.text('Bugungi cheklist'), findsOneWidget);
    expect(find.text('Yangi so\'zlar'), findsOneWidget);
    expect(find.text('Oraliqli takror'), findsOneWidget);
    expect(find.text('Xarita'), findsOneWidget);
    expect(t.takeException(), isNull);

    final p = await t.runAsync(() => app.plans.plan());
    expect(p!.days, 60);
    expect(app.rewards.commitHour, 20);
  });

  test('2 oylik reja: kuniga ~11-12 dars, hamma band taqsimlangan', () async {
    final v = await app.plans.volume();
    final s = buildSchedule(v, 60);
    expect(s.expand((d) => d).length, v.lessons + v.rules);
    expect(paceFor(v, 60).lessonsPerDay, closeTo(11.2, 0.2));
  });

  testWidgets('320px tor ekranda chiqib ketmaydi (reja bilan)', (t) async {
    t.view.physicalSize = const Size(320, 3200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: MnemonicsScreen())));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
