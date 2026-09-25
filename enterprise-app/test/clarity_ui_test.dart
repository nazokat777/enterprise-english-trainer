import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/mistakes.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/screens/book/exercise_player.dart';
import 'package:enterprise_english/stats.dart';

/// MAVHUMLIK YO'Q: kitobi yo'q odam ham nima so'ralayotganini ko'radi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.mistakes = MistakeStore();
    app.repo = ContentRepository();
    app.rewards = RewardEngine();
    await Future.wait([
      app.progress.load(),
      app.mastery.load(),
      app.mistakes.load(),
      app.rewards.load(),
    ]);
  });

  Future<void> open(WidgetTester t, BookExercise ex) async {
    t.view.physicalSize = const Size(500, 1100);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: ExercisePlayer(
        exercise: ex,
        sectionTitle: 'Takror',
        unitLabel: '11-unit',
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  testWidgets('a)/b) bandida tugmalarda TO\'LIQ gap turadi', (t) async {
    final ex = BookExercise.fromJson({
      'ref': '13',
      'kind': 'choice',
      'book': 'coursebook',
      'bookPage': 78,
      'instructionUz': 'To\'g\'ri gapni belgilang, namunadagidek.',
      'tasks': [
        {
          'prompt': '1  a) Susie is going cycling in her free time.   '
              'b) Susie goes cycling in her free time.',
          'options': ['a', 'b'],
          'answer': 'b',
        },
      ],
    });
    await open(t, ex);

    // Nima qilinadi - o'zbekcha, manzili bilan.
    expect(find.text('Nima qilinadi'), findsOneWidget);
    expect(find.textContaining('To\'g\'ri gapni belgilang'), findsWidgets);
    expect(find.textContaining('Coursebook'), findsWidgets);

    // Tugmalar: quruq "a"/"b" EMAS, to'liq gaplar.
    expect(find.text('Susie is going cycling in her free time.'), findsOneWidget);
    expect(find.text('Susie goes cycling in her free time.'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsNothing);
  });

  testWidgets('T/F bandida tugmalar o\'zbekcha', (t) async {
    final ex = BookExercise.fromJson({
      'ref': '7',
      'kind': 'choice',
      'book': 'coursebook',
      'bookPage': 10,
      'instructionUz': 'Gaplarni o\'qing, tinglang va belgilang.',
      'tasks': [
        {
          'prompt': 'Omar is twenty-six years old.',
          'options': ['T', 'F'],
          'answer': 'F',
        },
      ],
    });
    await open(t, ex);
    expect(find.text('To\'g\'ri'), findsOneWidget);
    expect(find.text('Noto\'g\'ri'), findsOneWidget);
    expect(find.text('T'), findsNothing);
    expect(find.text('F'), findsNothing);
    expect(find.textContaining('Quyidagi gap to\'g\'rimi?'), findsOneWidget);

    // To'g'ri javob tanlansa - qabul qilinadi.
    await t.tap(find.text('Noto\'g\'ri'));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
