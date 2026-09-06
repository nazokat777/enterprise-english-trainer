import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/book_screens.dart';
import 'package:enterprise_english/screens/book/exercise_player.dart';

/// "DAVOM ETISH" — o'quvchi 51 unit va 1545 mashq ichida qayerda
/// qolganini O'ZI eslab qolishi kerak edi. Xotirasi yomon odam uchun
/// bu ilovadan foydalanishning eng katta to'sig'i edi.
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

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: BookUnitsScreen())));
    await t.pump();
  }

  testWidgets('hech narsa ochilmagan bo\'lsa banner yo\'q', (t) async {
    await pump(t);
    expect(find.text('Davom etish'), findsNothing);
  });

  testWidgets('mashq ochilsa joy eslab qolinadi', (t) async {
    // Asset o'qish HAQIQIY vaqt talab qiladi — testning soxta soati
    // uni kutmaydi, shuning uchun `runAsync` kerak.
    final u = await t.runAsync(
        () => app.book.load(app.book.units.first.unit));
    final s = u!.sections.first;
    final e = s.exercises.first;

    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: ExercisePlayer(
          exercise: e, sectionTitle: s.titleUz, unitLabel: u.displayLabel),
    ));
    await t.pump();

    expect(app.progress.lastExerciseId, e.progressId);
    expect(app.progress.lastUnitNo, u.unit);
    expect(app.progress.lastLabel, contains(e.title));
  });

  testWidgets('eslab qolingan joy Darslar ekranida ko\'rinadi', (t) async {
    await app.progress.rememberExercise(
        unit: 1, id: 'ex::coursebook::6::1', label: 'Kirish · Ex. 1');

    await pump(t);

    expect(find.text('Davom etish'), findsOneWidget);
    expect(find.text('Kirish · Ex. 1'), findsOneWidget);
  });

  testWidgets('jarayon o\'chirilsa banner ham yo\'qoladi', (t) async {
    await app.progress.rememberExercise(
        unit: 1, id: 'ex::coursebook::6::1', label: 'Kirish · Ex. 1');
    await app.progress.resetAll();

    await pump(t);

    expect(find.text('Davom etish'), findsNothing);
  });
}
