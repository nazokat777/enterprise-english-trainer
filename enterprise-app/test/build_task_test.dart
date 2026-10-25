import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_english/drill/drill_item.dart';
import 'package:enterprise_english/drill/drill_screen.dart';
import 'package:enterprise_english/mastery.dart';

/// Harflab yig'ish: plitkalar matn kengligida (butun qator emas) va
/// klaviaturadan harf bosib yig'ish mumkin; Backspace orqaga.
void main() {
  const q = DrillQuestion(
    itemId: 'w::cat',
    format: AskFormat.build,
    prompt: 'mushuk',
    answer: 'cat',
    speak: '',
    unit: 1,
    topic: '',
  );

  testWidgets('plitka butun kenglikni egallamaydi', (t) async {
    t.view.physicalSize = const Size(800, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: BuildTask(q: q, locked: false, onDone: (_) {}))));
    await t.pump();
    final tile = find.ancestor(of: find.text('c'), matching: find.byType(Container)).first;
    expect(t.getSize(tile).width, lessThan(120));
  });

  testWidgets('klaviatura: c-a-t yig\'iladi, Backspace orqaga', (t) async {
    bool? result;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BuildTask(q: q, locked: false, onDone: (ok) => result = ok))));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.keyC);
    await t.pump();
    expect(find.text('c'), findsNWidgets(2)); // plitka + yig'ilgan matn
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.pump();
    expect(find.text("Javobingiz shu yerda yig'iladi"), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.keyC);
    await t.sendKeyEvent(LogicalKeyboardKey.keyA);
    await t.sendKeyEvent(LogicalKeyboardKey.keyT);
    await t.pump();
    expect(result, isTrue);
    expect(find.text('cat'), findsOneWidget);
  });

  testWidgets('tanlash: 1-4 raqam tugmasi variantni tanlaydi', (t) async {
    const cq = DrillQuestion(
      itemId: 'w::cat',
      format: AskFormat.choice,
      prompt: 'cat',
      answer: 'mushuk',
      options: ['it', 'mushuk', 'sigir', 'tovuq'],
      speak: '',
      unit: 1,
      topic: '',
    );
    bool? result;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChoiceTask(q: cq, locked: false, onDone: (ok) => result = ok))));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.digit2);
    await t.pump();
    expect(result, isTrue);
  });

  group("ko'rsatma savolning O'ZIDA turadi", () {
    Future<void> show(WidgetTester t, Widget w) async {
      t.view.physicalSize = const Size(500, 1200);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: w)));
      await t.pump();
    }

    testWidgets("tanlash (tarjima): so'zning ma'nosini tanlang", (t) async {
      const cq = DrillQuestion(
        itemId: 'w::cat',
        format: AskFormat.choice,
        prompt: 'cat',
        answer: 'mushuk',
        options: ['it', 'mushuk', 'sigir', 'tovuq'],
        speak: 'cat',
      );
      await show(t, ChoiceTask(q: cq, locked: false, onDone: (_) {}));
      expect(find.text("Quyidagi so'zning o'zbekcha ma'nosini tanlang"),
          findsOneWidget);
      // Ovoz tugmasi nima ekani aytilgan.
      expect(find.byTooltip('Eshitish'), findsOneWidget);
    });

    testWidgets("inglizchasini tanlash va gapdagi bo'shliq", (t) async {
      const pq = DrillQuestion(
        itemId: 'w::cat',
        format: AskFormat.produce,
        prompt: 'mushuk',
        answer: 'cat',
        options: ['dog', 'cat'],
      );
      await show(t, ChoiceTask(q: pq, locked: false, onDone: (_) {}));
      expect(find.text("O'zbekchasiga mos inglizcha so'zni tanlang"),
          findsOneWidget);

      const cq = DrillQuestion(
        itemId: 'w::cat',
        format: AskFormat.cloze,
        prompt: 'The _____ is black.',
        promptUz: 'mushuk',
        answer: 'cat',
        options: ['dog', 'cat'],
      );
      await show(t, ChoiceTask(q: cq, locked: false, onDone: (_) {}));
      expect(find.text("Gapdagi bo'sh joyga mos so'zni tanlang"),
          findsOneWidget);
      // O'zbekcha qator nima ekani yozilgan.
      expect(find.text('Ishora: mushuk'), findsOneWidget);
    });

    testWidgets("harflab yig'ish va eshitib yig'ish", (t) async {
      await show(t, BuildTask(q: q, locked: false, onDone: (_) {}));
      expect(
          find.text("Harflarni to'g'ri tartibda bosib inglizchasini yig'ing"),
          findsOneWidget);
      expect(find.text("Javobingiz shu yerda yig'iladi"), findsOneWidget);

      const lq = DrillQuestion(
        itemId: 'w::cat',
        format: AskFormat.listen,
        prompt: 'Eshiting va yozing',
        promptUz: 'mushuk',
        answer: 'cat',
        speak: 'cat',
      );
      await show(t, BuildTask(q: lq, locked: false, onDone: (_) {}));
      expect(find.text("Eshiting va eshitganingizni harflardan yig'ing"),
          findsOneWidget);
      // Katta matn - so'zning ma'nosi ekani aytilgan.
      expect(find.text("Ma'nosi:"), findsOneWidget);
    });

    test("instructionOf: kitob savoli va so'z-so'z yig'ish", () {
      expect(
          instructionOf(const DrillQuestion(
              itemId: 't',
              format: AskFormat.choice,
              prompt: 'Capital of Brazil?',
              answer: 'Brasilia',
              options: ['a', 'b'])),
          "To'g'ri javobni tanlang");
      expect(
          instructionOf(const DrillQuestion(
              itemId: 's',
              format: AskFormat.build,
              prompt: 'Gapni tuzing',
              answer: 'I like cats')),
          "So'zlarni to'g'ri tartibda bosib gapni tuzing");
      // Hamma shaklning ko'rsatmasi bor va bo'sh emas.
      for (final f in AskFormat.values) {
        expect(instructionFor(f).trim(), isNotEmpty, reason: '$f');
      }
    });
  });
}
