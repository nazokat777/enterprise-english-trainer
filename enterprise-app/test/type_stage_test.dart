import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/exercise_player.dart';
import 'package:enterprise_english/screens/book/type_stage.dart';

/// O'qish mashqi -> "Yodlash" -> so'zlardan yig'ish + klaviaturada yozish.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final study = BookExercise(
    ref: '2a',
    kind: ExKind.study,
    tasks: const [
      ExTask(en: 'I am from Scotland.', uz: 'Men Shotlandiyadanman.'),
      ExTask(en: 'I\'m not married.', uz: 'Men uylanmaganman.'),
    ],
    instructionEn: 'Listen and repeat.',
    instructionUz: 'Eshiting va takrorlang.',
    book: 'coursebook',
    pageLabel: '6-bet',
  );

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
    ]);
  });

  test('memorizeExerciseFrom: har satr uchun yig\'ish + yozish', () {
    final m = memorizeExerciseFrom(study);
    expect(m.kind, ExKind.text);
    expect(m.tasks.length, 4);
    expect(m.tasks.take(2).every((t) => !t.typed), isTrue);
    expect(m.tasks.skip(2).every((t) => t.typed), isTrue);
    expect(m.tasks.first.answer, 'I am from Scotland.');
    expect(m.tasks.first.speak, 'I am from Scotland.');
    expect(m.tasks.last.promptUz, 'Men uylanmaganman.');
  });

  testWidgets('o\'qish ekranida Yodlash tugmasi bor', (t) async {
    t.view.physicalSize = const Size(500, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: ExercisePlayer(exercise: study, sectionTitle: 'Kirish')));
    await t.pump();
    expect(find.textContaining('Yodlash: tinglab'), findsOneWidget);
    expect(find.text('O\'qib chiqdim'), findsOneWidget);
  });

  testWidgets('TypeStage: to\'g\'ri yozilsa onDone(true), xato bo\'lsa diff',
      (t) async {
    t.view.physicalSize = const Size(500, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final results = <bool>[];
    final task = memorizeExerciseFrom(study).tasks.last;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TypeStage(task: task, explanation: '', onDone: (ok, {String given = ''}) => results.add(ok)),
      ),
    ));
    await t.pump();
    // Punktuatsiya va katta-kichik harf farqi xato emas.
    await t.enterText(find.byType(TextField), "i'm not married");
    await t.pump();
    await t.tap(find.text('Tekshirish'));
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(results, [true]);

    results.clear();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TypeStage(
            key: const ValueKey('again'),
            task: task,
            explanation: '',
            onDone: (ok, {String given = ''}) => results.add(ok)),
      ),
    ));
    await t.pump();
    await t.enterText(find.byType(TextField), "I am not merried.");
    await t.pump();
    await t.tap(find.text('Tekshirish'));
    await t.pump();
    expect(find.text('To\'g\'risi:'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(results, [false]);
  });
}
