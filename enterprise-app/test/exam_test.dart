import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/drill/drill_screen.dart';
import 'package:enterprise_english/exam/exam.dart';
import 'package:enterprise_english/exam/exam_screen.dart';
import 'package:enterprise_english/exam/exam_widgets.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/screens/book/book_screens.dart';
import 'package:enterprise_english/screens/book/type_stage.dart';
import 'package:enterprise_english/stats.dart';

/// 📝 Yig'ma imtihon: 1..N unitlar, uch qism, xato qaytadi, natija.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.rewards = RewardEngine();
    app.repo = ContentRepository();
    app.book = BookRepository();
    await Future.wait([
      app.progress.load(),
      app.mastery.load(),
      app.rewards.load(),
      app.repo.load(),
      app.book.loadIndex(),
    ]);
  });

  test('ExamBuilder: 1-2 unitlar uchun uch qism, chegaralar', () async {
    final plan = await ExamBuilder(
            book: app.book, mastery: app.mastery, random: Random(1))
        .build(2);
    expect(plan.count(ExamPart.words), ExamBuilder.wordTarget(2));
    expect(plan.count(ExamPart.grammar), greaterThan(0));
    expect(plan.count(ExamPart.grammar),
        lessThanOrEqualTo(ExamBuilder.grammarTarget(2)));
    expect(plan.count(ExamPart.sentences), greaterThan(0));
    // Har band faqat 1-2 unitdan.
    expect(plan.items.every((e) => e.unit >= 1 && e.unit <= 2), isTrue);
    // Lug'at: tanlash va yozish navbatma-navbat.
    final w = plan.items.where((e) => e.part == ExamPart.words).toList();
    expect(w.any((e) => e.q!.format == AskFormat.produce), isTrue);
    expect(w.any((e) => e.q!.format == AskFormat.build), isTrue);
    // Gaplar yozish rejimida.
    expect(plan.items.where((e) => e.part == ExamPart.sentences)
        .every((e) => e.task!.typed), isTrue);
  });

  test('ExamBuilder: onlyIds faqat shu bandlar (qayta ishlash)', () async {
    final b = ExamBuilder(book: app.book, mastery: app.mastery, random: Random(2));
    final full = await b.build(1);
    final ids = full.items.take(3).map((e) => e.id).toSet();
    final part = await b.build(1, onlyIds: ids);
    expect(part.items.map((e) => e.id).toSet(), ids);
  });

  test('ExamStore: eng yaxshi baho saqlanadi, zaif ro\'yxat yangilanadi',
      () async {
    await ExamStore.save('beginner', const ExamResult(
        uptoUnit: 1, score: 80, total: 10, dateMs: 1, weakIds: ['a', 'b']));
    await ExamStore.save('beginner', const ExamResult(
        uptoUnit: 1, score: 60, total: 10, dateMs: 2, weakIds: ['c']));
    final r = (await ExamStore.load('beginner', 1))!;
    expect(r.score, 80);
    expect(r.weakIds, ['c']);
    expect(r.passed, isFalse);
  });

  testWidgets('highestCompletedUnit va bosh ekran kartasi', (t) async {
    expect(highestCompletedUnit(), 0);
    app.rewards.unitsCompleted.add(2);
    expect(highestCompletedUnit(), 2);
    t.view.physicalSize = const Size(500, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: BookUnitsScreen())));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Imtihon · 1-2 unitlar'), findsOneWidget);
  });

  testWidgets('ExamScreen: hammasi to\'g\'ri -> 100%, yutuq, saqlanadi',
      (t) async {
    t.view.physicalSize = const Size(500, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: ExamScreen(uptoUnit: 1)));
    // Reja yuklanishi (asset o'qish real vaqt).
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 800)));
    await t.pump();
    expect(find.textContaining('Boshlash'), findsOneWidget);
    await t.tap(find.textContaining('Boshlash'));
    await t.pump();

    for (var i = 0; i < 80; i++) {
      final choice = find.byType(ChoiceTask);
      final build = find.byType(BuildTask);
      final type = find.byType(TypeStage);
      if (choice.evaluate().isNotEmpty) {
        t.widget<ChoiceTask>(choice).onDone(true);
      } else if (build.evaluate().isNotEmpty) {
        t.widget<BuildTask>(build).onDone(true);
      } else if (type.evaluate().isNotEmpty) {
        t.widget<TypeStage>(type).onDone(true);
      } else {
        break;
      }
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
    }
    await t.pump(const Duration(seconds: 2));
    expect(find.text('Imtihondan o\'tdingiz!'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(app.rewards.examsPassed, contains(1));
    expect(app.rewards.achievements, contains('exam1'));
    final saved = await ExamStore.load('beginner', 1);
    expect(saved!.score, 100);
    expect(saved.weakIds, isEmpty);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('ExamScreen: xato band qaytadi va zaif ro\'yxatga tushadi',
      (t) async {
    t.view.physicalSize = const Size(500, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: ExamScreen(uptoUnit: 1)));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 800)));
    await t.pump();
    await t.tap(find.textContaining('Boshlash'));
    await t.pump();

    var first = true;
    String? firstId;
    var answered = 0;
    for (var i = 0; i < 90; i++) {
      final choice = find.byType(ChoiceTask);
      final build = find.byType(BuildTask);
      final type = find.byType(TypeStage);
      final ok = !first;
      if (choice.evaluate().isNotEmpty) {
        firstId ??= t.widget<ChoiceTask>(choice).q.itemId;
        t.widget<ChoiceTask>(choice).onDone(ok);
      } else if (build.evaluate().isNotEmpty) {
        firstId ??= t.widget<BuildTask>(build).q.itemId;
        t.widget<BuildTask>(build).onDone(ok);
      } else if (type.evaluate().isNotEmpty) {
        t.widget<TypeStage>(type).onDone(ok);
      } else {
        break;
      }
      first = false;
      answered += 1;
      await t.pump();
      await t.pump(const Duration(milliseconds: 1400));
    }
    await t.pump(const Duration(seconds: 2));
    // Birinchi band xato -> oxirida yana so'raldi -> jami +1.
    final plan = await ExamBuilder(book: app.book, mastery: app.mastery).build(1);
    expect(answered, plan.items.length + 1);
    expect(find.text('Hali mustahkam emas'), findsNothing,
        reason: 'bitta xato 90% dan tushirmaydi');
    expect(find.textContaining('1 ta band qayta so\'raldi'), findsOneWidget);
    final saved = await ExamStore.load('beginner', 1);
    expect(saved!.weakIds, [firstId]);
    expect(saved.score, lessThan(100));
    await t.pump(const Duration(seconds: 3));
  });
}
