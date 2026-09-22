import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/levels.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/mistakes.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/screens/book/book_screens.dart';
import 'package:enterprise_english/stats.dart';

/// DARAJA ALMAShISH: Elementary tanlansa kitob, sarlavha va unitlar
/// ro'yxati ham almashadi (ilgari Beginner turib qolardi).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.mistakes = MistakeStore();
    app.repo = ContentRepository();
    app.rewards = RewardEngine();
    app.book = BookRepository();
    await Future.wait([
      app.progress.load(),
      app.mastery.load(),
      app.mistakes.load(),
      app.repo.load(),
      app.rewards.load(),
      app.book.loadIndex(),
    ]);
  });

  test('har daraja o\'z kitob papkasi va sarlavhasiga ega', () {
    expect(kLevels.map((l) => l.bookDir).toSet().length, kLevels.length);
    expect(levelBookTitle('beginner'), 'Enterprise 1 - Beginner');
    expect(levelBookTitle('elementary'), 'Enterprise 2 - Elementary');
  });

  test('book.setLevel unitlarni almashtiradi va xabar beradi', () async {
    final before = app.book.units.map((u) => u.unit).toList();
    expect(before, isNotEmpty);
    var notified = 0;
    app.book.addListener(() => notified++);
    await app.book.setLevel('elementary');
    expect(notified, greaterThan(0));
    expect(app.book.units, isNotEmpty);
    final u = await app.book.load(app.book.units.first.unit);
    expect(u, isNotNull);
  });

  testWidgets('daraja almashsa bosh ekran sarlavhasi yangilanadi', (t) async {
    t.view.physicalSize = const Size(500, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: BookUnitsScreen())));
    await t.pump();
    expect(find.text('Enterprise 1 - Beginner'), findsOneWidget);

    await app.book.setLevel('elementary');
    await app.progress.setLevel('elementary');
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Enterprise 2 - Elementary'), findsOneWidget);
    expect(find.text('Enterprise 1 - Beginner'), findsNothing);
  });
}
