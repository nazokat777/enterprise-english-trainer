import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/drill/drill_item.dart';
import 'package:enterprise_english/drill/weak_topics.dart';
import 'package:enterprise_english/screens/hard_words_screen.dart';

/// ZAIF MAVZULAR — "qaysi joyini o'zlashtirolmayapti".
///
/// Band darajasidagi hisob bor edi, lekin u MAVZUGA bog'lanmagandi:
/// o'quvchi "grammatikam zaif" degan xulosani chiqara olmasdi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.repo = ContentRepository();
    app.book = BookRepository();
    await Future.wait([
      app.mastery.load(),
      app.progress.load(),
      app.repo.load(),
      app.book.loadIndex(),
    ]);
  });

  test('teginilmagan mavzu ZAIF hisoblanmaydi', () async {
    final t = await weakTopics();
    expect(t, isEmpty,
        reason: 'hali hech narsa qilinmagan — butun kitob zaif emas');
  });

  test('xato qilingan mavzu ro\'yxatga tushadi', () async {
    final u = await app.book.load(app.book.units.first.unit);
    final src = sourcesFromUnit(u!);
    expect(src, isNotEmpty);

    // Bitta bandda ikki marta xato.
    await app.mastery.record(src.first.itemId, AskFormat.choice, ok: false);
    await app.mastery.record(src.first.itemId, AskFormat.choice, ok: false);

    final t = await weakTopics();

    expect(t, isNotEmpty);
    expect(t.first.topic, src.first.topic);
    expect(t.first.left, greaterThan(0));
  });

  test('o\'zlashtirilgan mavzu ro\'yxatdan chiqadi', () async {
    final u = await app.book.load(app.book.units.first.unit);
    final src = sourcesFromUnit(u!);
    final one = src.first;

    await app.mastery.record(one.itemId, AskFormat.choice, ok: false);
    expect((await weakTopics()).any((e) => e.topic == one.topic), isTrue);

    // Shu mavzudagi HAMMA teginilgan bandni o'zlashtiramiz.
    for (final s in src.where((e) => e.topic == one.topic)) {
      if (app.mastery.of(s.itemId).isNew) continue;
      await app.mastery.record(s.itemId, AskFormat.choice, ok: true);
      await app.mastery.record(s.itemId, AskFormat.build, ok: true);
    }

    final t = await weakTopics();
    expect(t.any((e) => e.topic == one.topic), isFalse,
        reason: 'tugagan mavzu ro\'yxatda qolmasin');
  });

  test('eng zaif mavzu BIRINCHI keladi', () async {
    final u = await app.book.load(app.book.units.first.unit);
    final src = sourcesFromUnit(u!);
    final topics = src.map((e) => e.topic).toSet().toList();
    if (topics.length < 2) return; // bu unitda bitta mavzu

    final a = src.firstWhere((e) => e.topic == topics[0]);
    final b = src.firstWhere((e) => e.topic == topics[1]);

    // A — faqat xato; B — bitta shakl o'tgan.
    await app.mastery.record(a.itemId, AskFormat.choice, ok: false);
    await app.mastery.record(b.itemId, AskFormat.choice, ok: true);

    final t = await weakTopics();
    final ia = t.indexWhere((e) => e.topic == a.topic);
    final ib = t.indexWhere((e) => e.topic == b.topic);

    expect(ia, lessThan(ib), reason: 'zaifroq mavzu yuqorida tursin');
  });

  test('mavzuning eng zaif bandlari mashqqa olinadi', () async {
    final u = await app.book.load(app.book.units.first.unit);
    final src = sourcesFromUnit(u!);
    await app.mastery.record(src.first.itemId, AskFormat.choice, ok: false);

    final t = await weakTopics();
    final picked = weakestOf(t.first, limit: 5);

    expect(picked, isNotEmpty);
    expect(picked.length, lessThanOrEqualTo(5));
    expect(picked.every((e) => e.topic == t.first.topic), isTrue);
  });

  testWidgets('ekranda zaif mavzular ko\'rinadi', (t) async {
    final u = await t.runAsync(
        () => app.book.load(app.book.units.first.unit));
    final src = sourcesFromUnit(u!);
    await app.mastery.record(src.first.itemId, AskFormat.choice, ok: false);
    await app.mastery.record(src.first.itemId, AskFormat.choice, ok: false);

    // Barcha unitlar OLDINDAN keshga olinadi: `weakTopics()` ularni
    // o'qiydi, test ichidagi haqiqiy asset o'qish esa soxta soat
    // ostida tugamaydi.
    await t.runAsync(
        () => Future.wait(app.book.units.map((b) => app.book.load(b.unit))));

    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: HardWordsScreen())));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 20));
      if (find.text('Zaif mavzular').evaluate().isNotEmpty) break;
    }

    expect(find.text('Zaif mavzular'), findsOneWidget);
    expect(find.textContaining('band qoldi'), findsWidgets);
    expect(t.takeException(), isNull);
  });
}
