import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/drill/drill_screen.dart';
import 'package:enterprise_english/lessons/lesson_screen.dart';
import 'package:enterprise_english/lessons/word_lesson.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/services/pron.dart';
import 'package:enterprise_english/stats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dars yodlashdan OLDIN tarjima va talaffuz ro\'yxatini ko\'rsatadi',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.runAsync(() async {
      app.progress = Progress();
      app.mastery = MasteryStore();
      app.rewards = RewardEngine();
      await app.progress.load();
      await app.mastery.load();
      await app.rewards.load();
      await Pron.load();
    });
    t.view.physicalSize = const Size(500, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    const l = WordLesson(index: 1, unit: 1, words: [
      LessonWord(en: 'kettle', uz: 'choynak'),
      LessonWord(en: 'ice cream', uz: 'muzqaymoq'),
    ]);
    await t.pumpWidget(const MaterialApp(
        home: LessonScreen(lesson: l, unitLabel: 'X')));
    await t.pump();

    expect(find.text('Bu darsda 2 ta yangi so\'z'), findsOneWidget);
    expect(find.text('kettle'), findsOneWidget);
    expect(find.text('choynak'), findsOneWidget);
    expect(find.text('muzqaymoq'), findsOneWidget);
    // O'qilishi lug'atdan: bor so'zda ko'rsatiladi, yo'g'ida - yo'q.
    expect(find.text('[ays krim]'), findsOneWidget);
    expect(find.textContaining('[ket'), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsNWidgets(2));

    // Asosiy tugma TO'G'RIDAN-TO'G'RI savollarga o'tkazadi: so'zlar
    // ro'yxatda ko'rsatilgan, kartalarda qayta ko'rsatilmaydi.
    expect(find.text("Har so'zni alohida kartada ko'rish"), findsOneWidget);
    await t.tap(find.text('Yodlashni boshlash'));
    await t.pump();
    expect(find.byType(ChoiceTask), findsOneWidget);
    expect(find.textContaining("So'z kartasi"), findsNothing);
    expect(find.text('Bu darsda 2 ta yangi so\'z'), findsNothing);
    // Savol bosqichi nechtadan nechinchi ekani aytiladi.
    expect(find.textContaining(RegExp(r'1/\d-qism')), findsOneWidget);
    expect(find.textContaining('Qolgan savollar:'), findsOneWidget);
  });

  testWidgets("ro'yxat qatorida misol gap (inglizcha + o'zbekcha) ko'rinadi, "
      "ikkinchi tugma kartalarni ochadi", (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.runAsync(() async {
      app.progress = Progress();
      app.mastery = MasteryStore();
      app.rewards = RewardEngine();
      await app.progress.load();
      await app.mastery.load();
      await app.rewards.load();
      await Pron.load();
    });
    t.view.physicalSize = const Size(500, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    const l = WordLesson(index: 1, unit: 1, words: [
      LessonWord(
          en: 'kettle',
          uz: 'choynak',
          exampleEn: 'The kettle is hot.',
          exampleUz: 'Choynak issiq.'),
      LessonWord(en: 'ice cream', uz: 'muzqaymoq'),
    ]);
    await t.pumpWidget(const MaterialApp(
        home: LessonScreen(lesson: l, unitLabel: 'X')));
    await t.pump();

    // Misol faqat gapi bor so'zda; ikkala tilda.
    expect(find.textContaining('The kettle is hot.'), findsOneWidget);
    expect(find.text('Choynak issiq.'), findsOneWidget);
    expect(find.textContaining('Misol:'), findsOneWidget);

    await t.tap(find.text("Har so'zni alohida kartada ko'rish"));
    await t.pump();
    expect(find.textContaining("So'z kartasi · 1/2"), findsOneWidget);
    expect(find.text("So'zni o'qing, tinglang va yodlang"), findsOneWidget);
    expect(find.text('Bu darsda 2 ta yangi so\'z'), findsNothing);
  });

  testWidgets("savolda 'Bilmayman' javobni ko'rsatadi, 'O'tkazish' oxirgi ro'yxatga tushiradi",
      (t) async {
    t.view.physicalSize = const Size(500, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    const l = WordLesson(index: 1, unit: 1, words: [
      LessonWord(en: 'kettle', uz: 'choynak'),
      LessonWord(en: 'ice cream', uz: 'muzqaymoq'),
    ]);
    // Qutqaruv rejimi - tanishuvsiz, darhol savol.
    await t.pumpWidget(const MaterialApp(
        home: LessonScreen(lesson: l, unitLabel: 'X', rescue: true)));
    await t.pump();

    await t.tap(find.text("Bilmayman - ko'rsat"));
    await t.pumpAndSettle();
    expect(find.text("To'g'ri javob:"), findsOneWidget);
    await t.tap(find.text('Tushundim, davom etamiz'));
    await t.pumpAndSettle();

    for (var i = 0; i < 30; i++) {
      final skip = find.text("O'tkazib yuborish");
      if (skip.evaluate().isEmpty) break;
      await t.tap(skip.first);
      await t.pump();
    }
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.textContaining("Adashgan so'zlar (2)"), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
