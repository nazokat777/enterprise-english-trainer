import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/pack/pack_flow.dart';
import 'package:enterprise_english/screens/units_screen.dart';

/// TAKRORLASH VAQTI — SM-2 jadvali bo'yicha muddati kelgan so'zlar.
///
/// XATO edi: `dueCount()` allaqachon hisoblanardi ("sidebar Due badge"
/// deb yozilgan), lekin uni HECH BIR ekran ko'rsatmasdi va muddati
/// kelgan so'zlarni mashq qilishning yo'li ham yo'q edi — ya'ni butun
/// takrorlash jadvali o'quvchi uchun ko'rinmas edi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.repo = ContentRepository();
    await Future.wait([app.mastery.load(), app.progress.load(), app.repo.load()]);
  });

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: UnitsScreen())));
    await t.pump();
  }

  test('muddati kelgan so\'zlar eng kechikkanidan boshlab keladi', () async {
    final p = Progress();
    await p.load();

    // Uch so'z — turli muddat bilan.
    p.srsFor('a')
      ..interval = 1
      ..nextReviewAt = DateTime.now().subtract(const Duration(days: 5));
    p.srsFor('b')
      ..interval = 1
      ..nextReviewAt = DateTime.now().subtract(const Duration(days: 1));
    p.srsFor('c')
      ..interval = 1
      ..nextReviewAt = DateTime.now().add(const Duration(days: 3));

    expect(p.dueCount(), 2, reason: 'kelajakdagi so\'z sanalmaydi');
    expect(p.dueWordIds(), ['a', 'b'], reason: 'eng kechikkani birinchi');
  });

  test('boshqa darajaning so\'zlari aralashmaydi', () async {
    final p = Progress();
    await p.load();
    p.srsFor('a')
      ..interval = 1
      ..nextReviewAt = DateTime.now().subtract(const Duration(days: 2));

    await p.setLevel('elementary');
    expect(p.dueWordIds(), isEmpty);

    await p.setLevel('beginner');
    expect(p.dueWordIds(), ['a']);
  });

  testWidgets('muddati kelgan so\'z bo\'lmasa banner yo\'q', (t) async {
    await pump(t);
    expect(find.text('Takrorlash vaqti keldi'), findsNothing);
  });

  testWidgets('muddati kelgan so\'z bo\'lsa banner chiqadi', (t) async {
    final c = app.repo.forLevel('beginner');
    final ids = c.wordsById.keys.take(3).toList();
    for (final id in ids) {
      app.progress.srsFor(id)
        ..interval = 1
        ..nextReviewAt = DateTime.now().subtract(const Duration(days: 2));
    }

    await pump(t);

    expect(find.text('Takrorlash vaqti keldi'), findsOneWidget);
    expect(find.textContaining('3 ta so\'z'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('banner bosilganda mashq ochiladi', (t) async {
    final c = app.repo.forLevel('beginner');
    for (final id in c.wordsById.keys.take(4)) {
      app.progress.srsFor(id)
        ..interval = 1
        ..nextReviewAt = DateTime.now().subtract(const Duration(days: 2));
    }

    await pump(t);
    await t.tap(find.text('Takrorlash vaqti keldi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    // Eski ekran daraxtda qoladi (Navigator.push), shuning uchun
    // YANGI ekran paydo bo'lganini tekshiramiz.
    expect(find.byType(PackFlow), findsOneWidget,
        reason: 'mashq ekrani ochilsin');
    expect(t.takeException(), isNull);
  });
}
