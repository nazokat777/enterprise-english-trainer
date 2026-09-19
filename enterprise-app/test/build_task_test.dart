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
    expect(find.text('. . .'), findsOneWidget);
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
}
