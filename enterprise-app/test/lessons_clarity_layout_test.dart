import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/blitz/blitz_screen.dart';
import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/drill/drill_item.dart';
import 'package:enterprise_english/drill/drill_screen.dart';
import 'package:enterprise_english/lessons/lesson_screen.dart';
import 'package:enterprise_english/lessons/lessons_screen.dart';
import 'package:enterprise_english/lessons/word_lesson.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/services/pron.dart';
import 'package:enterprise_english/stats.dart';

/// Kitobni ko'rmagan o'quvchi uchun tushunarli ekranlar TOR telefonda
/// (320 px) va KATTA shriftda (x1.5) ham sig'sin: so'z darsi, trening
/// natijasi, tezlik o'yini.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.rewards = RewardEngine();
    app.book = BookRepository();
    await Future.wait(
        [app.progress.load(), app.mastery.load(), app.rewards.load()]);
  });

  const lesson = WordLesson(index: 2, unit: 1, words: [
    LessonWord(
        en: 'kettle',
        uz: 'choynak',
        exampleEn: 'The kettle is on the cooker in the kitchen.',
        exampleUz: 'Choynak oshxonadagi plitada turibdi.'),
    LessonWord(en: 'ice cream', uz: 'muzqaymoq'),
    LessonWord(en: 'fridge', uz: 'muzlatgich'),
    LessonWord(en: 'cooker', uz: 'plita'),
  ]);

  Future<void> size(WidgetTester t, Size s) async {
    t.view.physicalSize = s;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
  }

  Widget scaled(Widget child, double scale) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      );

  // Asosiy tugma kichik telefonda ham ekran ichida turadi (qotirilgan),
  // uzun ro'yxat/matn uni ekrandan tashqariga itarib yubormaydi.
  testWidgets("so'zlar ro'yxati: asosiy tugma 320x640 da ham ko'rinadi",
      (t) async {
    await t.runAsync(Pron.load);
    await size(t, const Size(320, 640));
    await t.pumpWidget(scaled(
        const LessonScreen(lesson: lesson, unitLabel: 'Unit 1'), 1.5));
    await t.pump();
    final btn = find.text('Yodlashni boshlash');
    expect(btn, findsOneWidget);
    expect(t.getRect(btn).bottom, lessThanOrEqualTo(640));
    expect(find.text("Har so'zni alohida kartada ko'rish"), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets("tezlik o'yini: BOShLASh tugmasi 320x568 da ham ko'rinadi",
      (t) async {
    await size(t, const Size(320, 568));
    final src = [
      for (var i = 0; i < 6; i++)
        DrillSource(itemId: 'w::e$i', en: 'word$i', uz: 'soz$i'),
    ];
    await t.pumpWidget(scaled(
        BlitzScreen(sources: src, label: 'Unit 1', recordKey: 'vis'), 1.5));
    await t.pump();
    final btn = find.text('BOShLASh');
    expect(btn, findsOneWidget);
    expect(t.getRect(btn).bottom, lessThanOrEqualTo(568));
    expect(t.takeException(), isNull);
  });

  for (final cfg in const [(Size(320, 1400), 1.0), (Size(320, 1400), 1.5)]) {
    final tag = '${cfg.$1.width.round()}px x${cfg.$2}';

    testWidgets('so\'z darsi: ro\'yxat -> savol -> natija sig\'adi ($tag)',
        (t) async {
      await t.runAsync(Pron.load);
      await size(t, cfg.$1);
      await t.pumpWidget(scaled(
          const LessonScreen(lesson: lesson, unitLabel: 'Unit 1'), cfg.$2));
      await t.pump();
      expect(find.text('Darsdagi so\'zlar'), findsOneWidget);
      expect(find.textContaining('Misol:'), findsOneWidget);
      expect(t.takeException(), isNull);

      // Savol bosqichi: ko'rsatma, qolgan savollar, yordam tugmalari.
      await t.tap(find.text('Yodlashni boshlash'));
      await t.pump();
      expect(find.textContaining('Qolgan savollar: '), findsOneWidget);
      expect(find.text("Bilmayman - ko'rsat"), findsOneWidget);
      expect(find.text("O'tkazib yuborish"), findsOneWidget);
      expect(find.text("Quyidagi so'zning o'zbekcha ma'nosini tanlang"),
          findsOneWidget);
      expect(t.takeException(), isNull);

      // Hamma savolga to'g'ri javob -> natija ekrani.
      for (var i = 0; i < 60; i++) {
        final choice = find.byType(ChoiceTask);
        final build = find.byType(BuildTask);
        if (choice.evaluate().isNotEmpty) {
          t.widget<ChoiceTask>(choice).onDone(true);
        } else if (build.evaluate().isNotEmpty) {
          t.widget<BuildTask>(build).onDone(true);
        } else {
          break;
        }
        await t.pump();
        await t.pump(const Duration(milliseconds: 700));
      }
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Zo\'r! Xatosiz tugadingiz.'), findsOneWidget);
      expect(find.text('Tugatish va qaytish'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('trening natijasi nima ekanini aytadi ($tag)', (t) async {
      await size(t, cfg.$1);
      // Savollari yo'q trening darhol natija ekranini ko'rsatadi.
      await t.pumpWidget(scaled(
          const DrillScreen(title: 'Unit 1 — mashq', lessonSources: []),
          cfg.$2));
      await t.pump();
      expect(find.text('Mashq tugadi'), findsOneWidget);
      expect(find.textContaining('yodlanganlik: '), findsOneWidget);
      expect(find.textContaining('ketma-ket to\'g\'ri javob: '),
          findsOneWidget);
      expect(find.text('Orqaga qaytish'), findsOneWidget);
      expect(find.textContaining('Fokus'), findsNothing);
      expect(find.textContaining('kombo'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('tezlik o\'yini: tayyorlik -> o\'yin -> natija ($tag)',
        (t) async {
      await size(t, cfg.$1);
      final src = [
        for (final p in const [
          ('cat', 'mushuk'),
          ('dog', 'it'),
          ('cow', 'sigir'),
          ('hen', 'tovuq'),
          ('goat', 'echki'),
        ])
          DrillSource(itemId: 'w::${p.$1}', en: p.$1, uz: p.$2),
      ];
      await t.pumpWidget(scaled(
          BlitzScreen(sources: src, label: 'Unit 1', recordKey: 'lay'),
          cfg.$2));
      await t.pump();
      expect(find.textContaining('Tezlik o\'yini'), findsOneWidget);
      expect(find.textContaining('ball'), findsWidgets);
      expect(find.textContaining('xalta'), findsNothing);
      expect(find.textContaining('ochko'), findsNothing);
      expect(t.takeException(), isNull);

      await t.tap(find.text('BOShLASh'));
      await t.pump();
      expect(find.text('soniya qoldi'), findsOneWidget);
      expect(find.text('ball'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pump(const Duration(seconds: 61));
      expect(find.textContaining('hisobingizga qo\'shildi'), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
      expect(find.text('Orqaga qaytish'), findsOneWidget);
      expect(find.textContaining('Aniqlik - '), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('darslar ro\'yxati sig\'adi ($tag)', (t) async {
      // Balandroq oyna: hamma qator qurilsin (sust ro'yxat).
      await size(t, Size(cfg.$1.width, 3000));
      final u = BookUnit(
        unit: 1,
        title: 'Birinchi bob',
        module: 1,
        sections: const [],
        wordFormation: const [],
        sentencePatterns: const [],
        vocabulary: [
          for (var i = 0; i < 15; i++) VocabEntry(en: 'word$i', uz: 'soz$i'),
        ],
      );
      await t.pumpWidget(scaled(LessonsScreen(unit: u), cfg.$2));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('1-darsni tugatgach ochiladi'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
