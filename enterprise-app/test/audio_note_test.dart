import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/exercise_player.dart';

/// AUDIO IZOHI — "kitobda shu yerda audio bor, javoblarni 4-mashqdan
/// toping" kabi yo'l-yo'riq.
///
/// XATO edi: bu izoh FAQAT o'qish (study) rejimida chiqardi. Kitobda
/// esa 30 ta mashqda u tanlash/yozish/moslash rejimida va o'quvchi uni
/// umuman ko'rmasdi — mashq javobsizdek tuyulardi.
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

  const note = 'Kitobda audio bor. Javoblarni 4-mashqdan toping.';

  BookExercise make(ExKind kind, List<ExTask> tasks) => BookExercise(
        ref: 'x',
        kind: kind,
        tasks: tasks,
        book: 'coursebook',
        bookPage: 1,
        audioNoteUz: note,
      );

  Future<void> pump(WidgetTester t, BookExercise e) async {
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: ExercisePlayer(exercise: e, sectionTitle: 'Test'),
    ));
    await t.pump();
  }

  testWidgets('tanlash rejimida audio izohi ko\'rinadi', (t) async {
    await pump(
        t,
        make(ExKind.choice, const [
          ExTask(prompt: 'Where?', answer: 'here', options: ['here', 'there']),
        ]));

    expect(find.text(note), findsOneWidget);
  });

  testWidgets('yozish rejimida ham ko\'rinadi', (t) async {
    await pump(
        t,
        make(ExKind.text, const [
          ExTask(prompt: 'Where?', answer: 'here'),
        ]));

    expect(find.text(note), findsOneWidget);
  });

  testWidgets('moslash rejimida ham ko\'rinadi', (t) async {
    await pump(
        t,
        make(ExKind.match, const [
          ExTask(left: 'cat', right: 'mushuk'),
          ExTask(left: 'dog', right: 'it'),
        ]));

    expect(find.text(note), findsOneWidget);
  });

  testWidgets('o\'qish rejimida ham ko\'rinadi', (t) async {
    await pump(
        t,
        make(ExKind.study, const [
          ExTask(en: 'Hello.', uz: 'Salom.'),
        ]));

    expect(find.text(note), findsOneWidget);
  });

  testWidgets('izoh bo\'lmasa bo\'sh joy egallamaydi', (t) async {
    await pump(
        t,
        BookExercise(
          ref: 'y',
          kind: ExKind.choice,
          book: 'coursebook',
          bookPage: 1,
          tasks: const [
            ExTask(prompt: 'Where?', answer: 'here', options: ['here', 'there'])
          ],
        ));

    // Kartochka bo'sh matn bilan hech nima chizmaydi.
    expect(find.byIcon(Icons.headphones_rounded), findsNothing);
  });

  test('kitobdagi audio izohlari o\'yin rejimlarida ham bor', () async {
    var games = 0;
    for (final brief in app.book.units) {
      final u = await app.book.load(brief.unit);
      for (final s in u!.sections) {
        for (final e in s.exercises) {
          if (e.audioNoteUz.trim().isEmpty) continue;
          if (e.kind != ExKind.study) games++;
        }
      }
    }
    expect(games, greaterThan(20),
        reason: 'o\'yin rejimidagi audio izohlari haqiqatan ko\'p');
  });
}
