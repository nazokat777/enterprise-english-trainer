import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/mistakes.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/screens/shell.dart';
import 'package:enterprise_english/stats.dart';

// TEMPORARY PROBE - deleted after the run.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'rw_pet': 'Test'});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.mistakes = MistakeStore();
    app.repo = ContentRepository();
    app.rewards = RewardEngine();
    app.book = BookRepository();
    await Future.wait([
      app.progress.load(),
      app.mastery.load(),
      app.mistakes.load(),
      app.repo.load(),
      app.rewards.load(),
      app.book.loadIndex(),
      BookRepository.probeLevels(),
    ]);
  });

  String pill() {
    final btn = find.byType(PopupMenuButton<String>);
    final txt = find.descendant(of: btn, matching: find.byType(Text));
    return txt.evaluate().map((e) => (e.widget as Text).data).join(',');
  }

  testWidgets('PROBE who rebuilds the pill (wide)', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.runAsync(() async {
      await app.book.setLevel('beginner');
      await app.progress.setLevel('beginner');
    });
    await t.pumpWidget(const MaterialApp(home: AppShell()));
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    // ignore: avoid_print
    print('PROBE before: pill=${pill()}');

    final rebuilt = <String>[];
    Element switcherEl() => t.element(find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_LevelSwitcher',
        ));
    final swBefore = identityHashCode(switcherEl().widget);
    final btnBefore = identityHashCode(
        find.byType(PopupMenuButton<String>).evaluate().single.widget);
    String? popupStack;
    debugOnRebuildDirtyWidget = (el, builtOnce) {
      rebuilt.add(el.widget.runtimeType.toString());
      if (el.widget is PopupMenuButton<String>) {
        popupStack = StackTrace.current.toString();
      }
    };
    await t.runAsync(() async => app.progress.setLevel('elementary'));
    debugPrintScheduleBuildForStacks = true;
    await t.pump();
    debugPrintScheduleBuildForStacks = false;
    debugOnRebuildDirtyWidget = null;
    final interesting = rebuilt
        .where((s) =>
            s.contains('LevelSwitcher') ||
            s.contains('PopupMenu') ||
            s.contains('_header') ||
            s.contains('ListenableBuilder') ||
            s.contains('LayoutBuilder') ||
            s.contains('_AppShell') ||
            s.contains('_Stat') ||
            s.contains('_DailyRing'))
        .toList();
    // ignore: avoid_print
    print('PROBE after: pill=${pill()} rebuiltCount=${rebuilt.length} '
        'interesting=$interesting');
    final idx = rebuilt.indexOf('PopupMenuButton<String>');
    final lo = idx - 12 < 0 ? 0 : idx - 12;
    final hi = idx + 6 > rebuilt.length ? rebuilt.length : idx + 6;
    // ignore: avoid_print
    print('PROBE chain around PopupMenuButton: ${rebuilt.sublist(lo, hi)}');
    // Direct check: is the Text inside the pill a NEW widget instance?
    final btnEl = find.byType(PopupMenuButton<String>).evaluate().single;
    final btnWidget = btnEl.widget as PopupMenuButton<String>;
    // ignore: avoid_print
    print('PROBE identities: switcherWidget before=$swBefore '
        'after=${identityHashCode(switcherEl().widget)} | popupWidget '
        'before=$btnBefore after=${identityHashCode(btnWidget)}');
    final frames = (popupStack ?? 'NO STACK')
        .split('\n')
        .where((l) => l.contains('framework.dart') ||
            l.contains('shell.dart') ||
            l.contains('layout_builder') ||
            l.contains('enterprise'))
        .take(30)
        .map((l) => l.trim())
        .join('\n   ');
    // ignore: avoid_print
    print('PROBE popup rebuild stack:\n   $frames');
  });

  testWidgets('PROBE 375px exception text', (t) async {
    t.view.physicalSize = const Size(375, 812);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: AppShell()));
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    final ex = t.takeException();
    // ignore: avoid_print
    print('PROBE 375 exception: ${ex.toString().split('\n').take(6).join(' | ')}');
  });
}
