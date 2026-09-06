import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/exercise_player.dart';

/// O'qish kartochkasi: inglizcha matn + o'zbekcha tarjima.
///
/// Grammatika sarlavhalarida ("Present Continuous") o'zbekcha maydon
/// aynan inglizchasini takrorlaydi — atamaning o'zi shu. Ilgari ilova
/// ikkala qatorni ham chizardi va o'quvchi bir xil yozuvni ikki marta
/// ko'rardi.
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

  BookExercise study(List<ExTask> tasks) => BookExercise(
        ref: 'x',
        kind: ExKind.study,
        tasks: tasks,
        book: 'coursebook',
        bookPage: 1,
      );

  Future<void> pump(WidgetTester t, BookExercise e) async {
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: ExercisePlayer(
          exercise: e, sectionTitle: 'Test', unitLabel: '1-unit'),
    ));
    await t.pump();
  }

  testWidgets('tarjima asl matndan farq qilsa — ikkalasi ham chiqadi',
      (t) async {
    await pump(
        t,
        study([
          const ExTask(en: 'The cat is on the mat.', uz: 'Mushuk gilamda.'),
        ]));

    expect(find.text('The cat is on the mat.'), findsOneWidget);
    expect(find.text('Mushuk gilamda.'), findsOneWidget);
  });

  testWidgets('tarjima asl matn bilan bir xil bo\'lsa — bir marta chiqadi',
      (t) async {
    await pump(
        t,
        study([
          const ExTask(en: 'Present Continuous', uz: 'Present Continuous'),
        ]));

    expect(find.text('Present Continuous'), findsOneWidget);
  });

  testWidgets('katta-kichik harf farqi ham takror hisoblanadi', (t) async {
    await pump(
        t,
        study([
          const ExTask(en: 'Quite/Very/Too', uz: 'quite/very/too'),
        ]));

    expect(find.text('quite/very/too'), findsNothing);
    expect(find.text('Quite/Very/Too'), findsOneWidget);
  });
}
