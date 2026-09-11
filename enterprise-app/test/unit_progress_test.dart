import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/book_screens.dart';

/// Unit kartochkasida "nechta mashq tugatildi" ko'rsatkichi.
///
/// Ilgari o'quvchi unitni ochmasdan qancha ish qilganini bilolmasdi:
/// kartochkada faqat "57 mashq" degan umumiy son turardi.
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

  test('tugatilgan mashq unit hisobiga qo\'shiladi', () async {
    expect(app.progress.doneInUnit(1), 0);

    await app.progress.markExerciseResult('ex::cb::6::1', clean: true, unit: 1);
    await app.progress.markExerciseResult('ex::cb::6::2', clean: false, unit: 1);
    await app.progress.markExerciseResult('ex::cb::9::1', clean: true, unit: 2);

    expect(app.progress.doneInUnit(1), 2);
    expect(app.progress.doneInUnit(2), 1);
  });

  test('bir mashq ikki marta sanalmaydi', () async {
    await app.progress.markExerciseResult('ex::cb::6::1', clean: false, unit: 1);
    await app.progress.markExerciseResult('ex::cb::6::1', clean: true, unit: 1);

    expect(app.progress.doneInUnit(1), 1);
  });

  test('hisob saqlanadi va qayta o\'qiladi', () async {
    await app.progress.markExerciseResult('ex::cb::6::1', clean: true, unit: 3);

    final again = Progress();
    await again.load();

    expect(again.doneInUnit(3), 1);
  });

  test('jarayon o\'chirilsa hisob ham nolga tushadi', () async {
    await app.progress.markExerciseResult('ex::cb::6::1', clean: true, unit: 3);
    await app.progress.resetAll();

    expect(app.progress.doneInUnit(3), 0);
  });

  testWidgets('kartochkada tugatilgan mashqlar soni chiqadi', (t) async {
    // Ma'lumot bo'limlari (muqova, mundarija) endi yig'ilgan — haqiqiy dars kerak.
    final brief =
        app.book.units.firstWhere((u) => !u.isInfo && u.exercises > 2);
    await app.progress
        .markExerciseResult('ex::cb::1::a', clean: true, unit: brief.unit);
    await app.progress
        .markExerciseResult('ex::cb::1::b', clean: true, unit: brief.unit);

    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: BookUnitsScreen())));
    await t.pump();

    expect(find.text('2 / ${brief.exercises} mashq tugatildi'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
