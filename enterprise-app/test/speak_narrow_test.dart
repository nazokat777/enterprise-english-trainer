import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/drill/drill_item.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/speak/role_play_screen.dart';
import 'package:enterprise_english/speak/speak_task.dart';
import 'package:enterprise_english/stats.dart';

/// Gapirish ekranlari 320px tor ekranda chiqib ketmaydi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.rewards = RewardEngine();
    app.progress = Progress();
    app.mastery = MasteryStore();
    await app.rewards.load();
    await app.progress.load();
    await app.mastery.load();
  });

  testWidgets('SpeakTask 320x560', (t) async {
    t.view.physicalSize = const Size(320, 560);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    const q = DrillQuestion(
      itemId: 'w::x',
      format: AskFormat.speak,
      prompt: 'boarding-school',
      promptUz: 'internat maktab, yotoqxonali maktab',
      answer: 'boarding-school',
      speak: 'boarding-school',
      unit: 1,
      topic: '',
    );
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SpeakTask(q: q, locked: false, onDone: (_) {}, onSkip: () {}))));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('RolePlayScreen 320x560 (rol tanlash va o\'yin)', (t) async {
    t.view.physicalSize = const Size(320, 560);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final e = BookExercise.fromJson({
      'ref': '1',
      'kind': 'study',
      'tasks': [
        {'en': 'Tony: Excuse me. Are you Rita Brian, the new neighbour from number twelve?', 'uz': 'Kechirasiz. Siz Rita Brianmisiz?'},
        {'en': 'Rita: Yes, I am. Nice to meet you, and welcome to the street.', 'uz': 'Ha, menman.'},
        {'en': 'Tony: Nice to meet you too.', 'uz': 'Men ham.'},
      ],
    });
    await t.pumpWidget(MaterialApp(home: RolePlayScreen(exercise: e, title: 'Rol')));
    await t.pump();
    expect(t.takeException(), isNull);
    await t.tap(find.textContaining('Rita  ·'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('Sizning navbatingiz'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
