import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/grammar_school.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.repo = ContentRepository();
    app.book = BookRepository();
    await Future.wait([
      app.mastery.load(),
      app.progress.load(),
      app.repo.load(),
      app.book.loadIndex(),
    ]);
  });

  test("ikki darajada ham 15 unit va ko'p qoida bor, ma'lumot butun", () async {
    for (final lv in ['beginner', 'elementary']) {
      final units = await GrammarSchool.load(lv);
      expect(units.length, 15, reason: lv);
      final ids = <String>{};
      for (final u in units) {
        expect(u.rules, isNotEmpty, reason: '$lv ${u.unit}');
        for (final r in u.rules) {
          expect(ids.add(r.id), isTrue, reason: 'dublikat ${r.id}');
          expect(r.sections.length, greaterThanOrEqualTo(3), reason: r.id);
          expect(r.examples, isNotEmpty, reason: r.id);
          for (final q in r.quiz) {
            expect(q.answer, inInclusiveRange(0, q.options.length - 1),
                reason: r.id);
          }
        }
      }
    }
  });

  testWidgets("ekran: unit ro'yxati, qidiruv va dars ochiladi",
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: GrammarSchoolScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Grammatika maktabi'), findsOneWidget);
    expect(find.textContaining('ta grammatika qoidasi'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'some');
    await tester.pumpAndSettle();
    final tile = find.textContaining('Some').first;
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Mini-test'), findsOneWidget);
    expect(find.text('Odatiy xatolar'), findsOneWidget);
  });
}
