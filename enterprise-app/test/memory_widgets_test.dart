import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/lessons/lesson_screen.dart';
import 'package:enterprise_english/drill/drill_screen.dart';
import 'package:enterprise_english/memory/memory.dart';
import 'package:enterprise_english/memory/memory_widgets.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/book_screens.dart';

/// Xotira qutqaruvi kartasi va seansi — brauzerdagi holatga yaqin
/// ma'lumot bilan (saqlangan JSON dan yuklanadi).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const day = 86400000;

  Map<String, dynamic> seed(int now) {
    Map<String, dynamic> w(String en, String uz, int iv, int agoDays,
            {int lapses = 0, String hook = ''}) =>
        {
          'c': 3,
          'l': lapses,
          'f': [0, 5],
          't': now - agoDays * day,
          'iv': iv,
          'd': now - agoDays * day,
          'e': en,
          'u': uz,
          if (hook.isNotEmpty) 'h': hook,
        };
    return {
      'beginner::w::married': w('married', 'turmush qurgan', 3, 2),
      'beginner::w::daughter': w('daughter', 'qiz (farzand)', 1, 1),
      'beginner::w::husband': w('husband', 'er', 7, 3),
      'beginner::w::nephew':
          w('nephew', 'jiyan', 1, 5, lapses: 3, hook: 'NEVara emas, JIYAN'),
      'beginner::w::aunt': w('aunt', 'xola', 3, 2),
      'beginner::w::son': {
        'c': 3, 'l': 0, 'f': [0, 5], 't': now - day, 'iv': 30,
        'd': now + 29 * day, 'e': 'son', 'u': 'o\'g\'il',
      },
    };
  }

  setUp(() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'mastery': json.encode(seed(now)),
    });
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.rewards = RewardEngine();
    app.repo = ContentRepository();
    app.book = BookRepository();
    await Future.wait([
      app.mastery.load(),
      app.progress.load(),
      app.rewards.load(),
      app.repo.load(),
      app.book.loadIndex(),
    ]);
  });

  testWidgets('saqlangan JSON dan 5 ta o\'chayotgan so\'z topiladi',
      (t) async {
    expect(app.mastery.fadingCount(), 5);
    expect(app.mastery.of('w::son').isFading(
        DateTime.now().millisecondsSinceEpoch), isFalse);
    expect(app.mastery.garden(), [2, 2, 1, 1, 0]);
  });

  testWidgets('bosh ekranda qutqarish kartasi, bosilsa seans ochiladi',
      (t) async {
    t.view.physicalSize = const Size(500, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: BookUnitsScreen())));
    await t.pump(const Duration(seconds: 2));

    expect(find.text('5 ta so\'z o\'chib ketmoqda'), findsOneWidget);
    expect(find.textContaining('Qutqarish'), findsOneWidget);

    final title = find.text('5 ta so\'z o\'chib ketmoqda');
    await t.ensureVisible(title);
    await t.tap(title);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    // Tanishuv yo'q — darhol savol.
    expect(find.textContaining('Xotira qutqaruvi'), findsOneWidget);
    expect(find.text('YANGI SO\'Z'), findsNothing);
  });

  testWidgets('xotira bog\'i kartasi o\'chayotgan so\'z bo\'lmasa', (t) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in app.mastery.fadingIds()) {
      app.mastery.of(id).dueMs = now + day;
    }
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: MemoryRescueCard()))));
    await t.pump();
    expect(find.textContaining('Xotira bog\'i'), findsOneWidget);
  });

  testWidgets('qutqaruv yakunida osish korinadi (oldin != keyin)', (t) async {
    t.view.physicalSize = const Size(500, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final l = MemoryRescue.lesson(app.mastery)!;
    await t.pumpWidget(MaterialApp(
        home: LessonScreen(lesson: l, unitLabel: 'X', rescue: true)));
    await t.pump();
    // Hamma savolga to'g'ri javob (10 ta: produce + build) — savol
    // vidjetining onDone orqali, xuddi foydalanuvchi bosgandek.
    for (var i = 0; i < 40; i++) {
      final choice = find.byType(ChoiceTask);
      final build = find.byType(BuildTask);
      if (choice.evaluate().isNotEmpty) {
        t.widget<ChoiceTask>(choice).onDone(true);
      } else if (build.evaluate().isNotEmpty) {
        t.widget<BuildTask>(build).onDone(true);
      } else {
        break;
      }
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
    }
    await t.pump(const Duration(seconds: 3));
    expect(find.textContaining('qutqarildi'), findsOneWidget);
    expect(find.textContaining('xotirangizda o\'sdi'), findsOneWidget);
  });
}
