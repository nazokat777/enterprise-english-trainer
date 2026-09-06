import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/exercise_player.dart';

/// MOSLASH mashqi uchun XP.
///
/// XATO edi: moslash faqat mashqni tugatgani uchun +3 XP berardi.
/// Tanlash mashqi esa har bir band uchun +2 beradi. Natijada kitob
/// oxiridagi 50 juftlik lug'at ro'yxatini moslash 3 XP, to'rt bandli
/// kichik mashq esa 11 XP olib kelardi — mehnat bilan mukofot mutlaqo
/// mos emas edi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.repo = ContentRepository();
    app.book = BookRepository();
    await Future.wait([app.mastery.load(), app.progress.load(), app.repo.load(), app.book.loadIndex()]);
  });

  final ex = BookExercise(
    ref: 'm',
    kind: ExKind.match,
    book: 'coursebook',
    bookPage: 7,
    tasks: const [
      ExTask(left: 'cat', right: 'mushuk'),
      ExTask(left: 'dog', right: 'it'),
      ExTask(left: 'bird', right: 'qush'),
    ],
  );

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: ExercisePlayer(exercise: ex, sectionTitle: 'Test'),
    ));
    await t.pump();
  }

  Future<void> pair(WidgetTester t, String left, String right) async {
    await t.tap(find.text(left).first);
    await t.pump();
    await t.tap(find.text(right).first);
    await t.pump(const Duration(milliseconds: 120));
  }

  testWidgets('har bir juft uchun XP beriladi', (t) async {
    await pump(t);
    await pair(t, 'cat', 'mushuk');
    await pair(t, 'dog', 'it');
    await pair(t, 'bird', 'qush');
    await t.pump(const Duration(milliseconds: 900));

    // 3 juft x 2 + 3 (mashq bonusi)
    expect(app.progress.xp, 9);
  });

  testWidgets('xato qilingan juft uchun XP berilmaydi', (t) async {
    await pump(t);
    // "cat" ni noto'g'ri juftga bosamiz.
    await t.tap(find.text('cat').first);
    await t.pump();
    await t.tap(find.text('it').first);
    await t.pump(const Duration(milliseconds: 500));

    await pair(t, 'cat', 'mushuk');
    await pair(t, 'dog', 'it');
    await pair(t, 'bird', 'qush');
    await t.pump(const Duration(milliseconds: 900));

    // 2 juft x 2 + 3 — xato qilingani uchun ball yo'q.
    expect(app.progress.xp, 7);
  });

  testWidgets('moslash lug\'at ko\'nikmasiga yoziladi', (t) async {
    await pump(t);
    await pair(t, 'cat', 'mushuk');
    await pair(t, 'dog', 'it');
    await pair(t, 'bird', 'qush');
    await t.pump(const Duration(milliseconds: 900));

    expect(app.progress.skillPercent(Skill.vocab), greaterThan(0),
        reason: 'moslash ham ko\'nikma hisobiga kirsin');
  });


  // Sarlavhadagi chiziq ilgari moslashda BOShIDANOQ to\'la turardi —
  // kitob oxiridagi 50 juftlik lug\'at ro\'yxatida o\'quvchi qancha
  // qolganini bilolmasdi.
  testWidgets('chiziq topilgan juftlarga qarab o\'sadi', (t) async {
    await pump(t);

    double barValue() => t
        .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator).first)
        .value!;

    expect(barValue(), 0.0, reason: 'boshida bo\'sh');

    await pair(t, 'cat', 'mushuk');
    expect(barValue(), closeTo(1 / 3, 0.01));

    await pair(t, 'dog', 'it');
    expect(barValue(), closeTo(2 / 3, 0.01));
  });
}
