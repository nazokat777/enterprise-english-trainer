import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/lessons/word_lesson.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/plan/hook_lesson_screen.dart';
import 'package:enterprise_english/plan/peg_screen.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/stats.dart';

/// Mnemonika AMALDA: ilgak darsi va qarmoq mashqi to'liq o'tiladi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.rewards = RewardEngine();
    await app.progress.load();
    await app.mastery.load();
    await app.rewards.load();
  });

  Future<void> tall(WidgetTester t) async {
    t.view.physicalSize = const Size(420, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
  }

  testWidgets('ilgak darsi: 4 qadam, ilgak saqlanadi, yopib eslash', (t) async {
    await tall(t);
    final lesson = WordLesson(index: 1, unit: 1, words: const [
      LessonWord(en: 'bucket', uz: 'chelak'),
      LessonWord(en: 'book', uz: 'kitob'),
    ]);
    var finished = false;
    await t.pumpWidget(MaterialApp(
      home: HookLessonScreen(
          lesson: lesson, unitLabel: '1-unit', onFinished: () => finished = true),
    ));
    await t.pump();

    for (var w = 0; w < 2; w++) {
      expect(find.text('1. Ma\'no'), findsOneWidget);
      await t.tap(find.text('Tushundim - ilgak topamiz'));
      await t.pump();
      expect(find.text('2. Ilgak'), findsOneWidget);
      // Ilova ilgak taklif qilgan (bucket -> buket).
      if (w == 0) expect(find.text('buket'), findsOneWidget);
      await t.tap(find.text('Ilgak tayyor - sahna quramiz'));
      await t.pump();
      await t.enterText(find.byType(TextField), 'ulkan buket chelakdan chiqyapti');
      await t.tap(find.text('Saqlash va tasavvur qilish'));
      await t.pump();
      // 5 soniya tasavvur.
      await t.pump(const Duration(seconds: 6));
      await t.tap(find.textContaining(w == 0 ? 'Keyingi so\'z' : 'yopib eslaymiz'));
      await t.pump();
    }
    expect(app.mastery.of('w::bucket').hook, contains('buket'));

    // Yopib eslash: hammasini to'g'ri yozamiz.
    for (var i = 0; i < 2; i++) {
      final uz = find.text('chelak').evaluate().isNotEmpty ? 'bucket' : 'book';
      await t.enterText(find.byType(TextField), uz);
      await t.tap(find.text('Tekshirish'));
      await t.pump();
      await t.tap(find.text('Keyingisi'));
      await t.pump();
    }
    expect(find.text('2 / 2'), findsOneWidget);
    await t.tap(find.text('Mustahkamlash darsiga o\'tish'));
    await t.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('qarmoq mashqi: test -> qarmoqlar -> qayta test -> natija', (t) async {
    await tall(t);
    await t.pumpWidget(const MaterialApp(home: PegScreen()));
    await t.pump();
    await t.tap(find.text('Boshlash - 1-test'));
    await t.pump();
    await t.tap(find.text('Tayyorman'));
    await t.pump();
    await t.tap(find.text('Tekshirish'));
    await t.pump();
    expect(find.text('1-test: 0 / 10'), findsOneWidget);
    expect(find.textContaining('1 = quyosh'), findsOneWidget);
    await t.tap(find.text('Qarmoqlarni bildim - so\'zlarni ilamiz'));
    await t.pump();
    for (var i = 0; i < 9; i++) {
      await t.tap(find.text('Ko\'rdim - keyingisi'));
      await t.pump();
    }
    await t.tap(find.text('Tayyor - qayta test'));
    await t.pump();
    expect(find.textContaining('Qayta test'), findsOneWidget);
    await t.tap(find.text('Tekshirish'));
    await t.pump();
    expect(find.text('Qarmoq usuli'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
