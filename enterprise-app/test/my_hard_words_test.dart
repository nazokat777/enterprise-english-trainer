import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/hardwords/my_hard_words.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';

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
    final s = MyHardWords.instance;
    await s.ensure();
    for (final e in List.of(s.items)) {
      await s.remove(e.en);
    }
  });

  test("yulduz: qo'shadi, qayta bossa olib tashlaydi", () async {
    final s = MyHardWords.instance;
    expect(await s.toggle('apple', 'olma'), isTrue);
    expect(s.has('APPLE'), isTrue, reason: 'katta-kichik harf farqsiz');
    expect(await s.toggle('apple', 'olma'), isFalse);
    expect(s.has('apple'), isFalse);
  });

  test("uch marta ketma-ket to'g'ri -> o'zlashtirildi, xato -> qaytadi",
      () async {
    final s = MyHardWords.instance;
    await s.toggle('house', 'uy');
    await s.record('house', true);
    await s.record('house', true);
    expect(s.active.single.streak, 2);
    await s.record('house', false);
    expect(s.active.single.streak, 0);
    expect(s.active.single.wrong, 1);
    for (var i = 0; i < MyHardWords.masterAt; i++) {
      await s.record('house', true);
    }
    expect(s.active, isEmpty);
    expect(s.mastered.single.en, 'house');
    await s.reopen('house');
    expect(s.active.single.streak, 0);
  });

  test("addAll takrorlarni qo'shmaydi va saqlanadi", () async {
    final s = MyHardWords.instance;
    expect(await s.addAll([('cat', 'mushuk'), ('dog', 'it')]), 2);
    expect(await s.addAll([('cat', 'mushuk'), ('bird', 'qush')]), 1);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('myhard::beginner'), contains('bird'));
  });

  testWidgets("ro'yxat va mashq ekrani ishlaydi", (t) async {
    t.view.physicalSize = const Size(900, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = MyHardWords.instance;
    await s.addAll([
      ('apple', 'olma'),
      ('house', 'uy'),
      ('water', 'suv'),
      ('book', 'kitob'),
    ]);
    await t.pumpWidget(
        const MaterialApp(home: MyHardWordsScreen()));
    await t.pumpAndSettle();
    expect(find.text('apple'), findsOneWidget);
    expect(find.textContaining('Mashq qilish'), findsOneWidget);

    await t.tap(find.textContaining('Mashq qilish'));
    await t.pumpAndSettle();
    expect(find.text("Bilmayman - javobni ko'rsat"), findsOneWidget);
    await t.tap(find.text("Bilmayman - javobni ko'rsat"));
    await t.pumpAndSettle();
    expect(find.text('Keyingisi'), findsOneWidget);
    expect(find.textContaining('Bu so\'z yana qaytadi'), findsOneWidget);
  });

  testWidgets('HardStar bosilsa so\'z daftarga tushadi', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: HardStar(en: 'tree', uz: 'daraxt'))));
    await t.pumpAndSettle();
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    expect(MyHardWords.instance.has('tree'), isTrue);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });
}
