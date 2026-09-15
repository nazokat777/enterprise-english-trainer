import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/screens/tutor_setup_screen.dart';
import 'package:enterprise_english/services/ai_tutor_service.dart';
import 'package:enterprise_english/services/tutor_prefs.dart';
import 'package:enterprise_english/stats.dart';

/// Mr. Vaysaqi sozlash: fe'l slayderi, ovoz rejimi, 18+, UZ/EN.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    await Future.wait([app.progress.load(), app.mastery.load()]);
    await tutorPrefs.load();
  });

  test('systemPrompt: fe\'l, ochiq rejim va izoh tili promptga tushadi', () {
    final angry = AiTutorService.systemPrompt('beginner', strictness: 0);
    expect(angry, contains('grumpy'));
    expect(angry, contains('no swearing'));
    expect(angry, contains('Uzbek explanation'));

    final friend = AiTutorService.systemPrompt('elementary',
        strictness: 3, openMode: true, noteLang: 'en');
    expect(friend, contains('best-friend'));
    expect(friend, contains('ADULT MODE'));
    expect(friend, contains('Never insult'));
    expect(friend, contains('English explanation'));
    expect(friend, isNot(contains('Uzbek explanation')));
  });

  test('TutorPrefs saqlanadi va qayta yuklanadi', () async {
    await tutorPrefs.setStrictness(0);
    await tutorPrefs.setVoiceMode('free');
    await tutorPrefs.setOpenMode(true);
    await tutorPrefs.setNoteLang('en');
    final again = TutorPrefs();
    await again.load();
    expect(again.strictness, 0);
    expect(again.strictLabel, 'Jahldor');
    expect(again.voiceMode, 'free');
    expect(again.openMode, isTrue);
    expect(again.noteLang, 'en');
    await again.setStrictness(9);
    expect(again.strictness, 3, reason: 'chegaralanadi');
  });

  testWidgets('sozlash ekrani: slayder fe\'lni o\'zgartiradi, 18+ belgisi',
      (t) async {
    t.view.physicalSize = const Size(500, 1100);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: TutorSetupScreen()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('qattiqqo\'l bo\'lsin'), findsOneWidget);
    expect(find.text('MULOYIM'), findsOneWidget); // standart 2
    expect(find.byType(TutorFace), findsOneWidget);
    expect(find.text('Erkin suhbat'), findsOneWidget);
    expect(find.text('Bosib turing'), findsOneWidget);
    expect(find.text('18+'), findsNothing);

    // Slayderni chapga — jahldor.
    final slider = find.byType(Slider);
    await t.drag(slider, const Offset(-400, 0));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(tutorPrefs.strictness, 0);
    expect(find.text('JAHLDOR'), findsWidgets);
    expect(find.textContaining('Qo\'pol, kinoyali'), findsOneWidget);

    // 18+ yoqiladi — yuqorida belgi chiqadi.
    await t.tap(find.byType(Switch));
    await t.pump();
    expect(tutorPrefs.openMode, isTrue);
    expect(find.text('18+'), findsOneWidget);

    // Kalit yo'q — tugma "API kalitini kiritish".
    expect(find.text('API kalitini kiritish'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });
}
