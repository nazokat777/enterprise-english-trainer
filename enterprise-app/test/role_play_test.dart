import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/speak/role_play_screen.dart';
import 'package:enterprise_english/stats.dart';

/// Rol o'ynash: dialog satrlari ajratiladi, rol tanlanadi, ilova
/// satrlari o'tib o'quvchi satrida to'xtaydi; o'tkazish davom ettiradi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BookExercise dialogue() => BookExercise.fromJson({
        'ref': '17a',
        'kind': 'study',
        'tasks': [
          {'en': 'Tony: Excuse me. Are you Rita?', 'uz': 'Tony: Kechirasiz. Siz Ritamisiz?'},
          {'en': 'Rita: Yes, I am.', 'uz': 'Ha, menman.'},
          {'en': 'Tony: Nice to meet you.', 'uz': 'Tanishganimdan xursandman.'},
          {'en': 'Rita: Nice to meet you, too.', 'uz': 'Men ham.'},
        ],
      });

  test('DialogueLine.parse / of', () {
    final lines = DialogueLine.of(dialogue());
    expect(lines.length, 4);
    expect(lines[0].speaker, 'Tony');
    expect(lines[0].en, 'Excuse me. Are you Rita?');
    expect(lines[0].uz, 'Kechirasiz. Siz Ritamisiz?');
    final notDialogue = BookExercise.fromJson({
      'ref': 'x',
      'kind': 'study',
      'tasks': [
        {'en': 'I am a student.', 'uz': 'Men talabaman.'},
        {'en': 'Tony: Hi.', 'uz': ''},
        {'en': 'Tony: Bye.', 'uz': ''},
      ],
    });
    expect(DialogueLine.of(notDialogue), isEmpty);
  });

  testWidgets('rol tanlash -> o\'quvchi satri -> o\'tkazish -> yakun', (t) async {
    SharedPreferences.setMockInitialValues({});
    app.rewards = RewardEngine();
    app.progress = Progress();
    await app.rewards.load();
    await app.progress.load();
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
        home: RolePlayScreen(exercise: dialogue(), title: 'Rol')));
    await t.pump();
    expect(find.text('Kim bo\'lib gapirasiz?'), findsOneWidget);
    await t.tap(find.text('Rita  ·  2 satr'));
    // Tony gapiradi (TTS test muhitida bo'sh) -> Rita satriga keladi.
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('Sizning navbatingiz'), findsOneWidget);

    await t.tap(find.text('O\'tkazish'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('Sizning navbatingiz'), findsOneWidget);
    await t.tap(find.text('O\'tkazish'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Dialog tugadi'), findsOneWidget);
    expect(find.text('0 / 2 satr to\'g\'ri aytildi'), findsOneWidget);
  });
}
