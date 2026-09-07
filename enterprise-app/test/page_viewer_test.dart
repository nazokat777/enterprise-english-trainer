import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_english/screens/book/book_page_viewer.dart';
import 'package:enterprise_english/screens/book/exercise_player.dart';

/// Bet skanlari ~1 MB. Telefonda mobil internet bilan ular bir necha
/// soniya kelishi mumkin va shu vaqt davomida ekran QOP-QORA turardi —
/// o'quvchi ilova buzilgan deb o'ylardi.
void main() {
  testWidgets('bet yuklanayotganda belgi ko\'rinadi', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(const MaterialApp(
      home: BookPageViewer(
          level: 'beginner',
          book: 'coursebook',
          page: 6,
          bookLabel: 'Coursebook'),
    ));
    await t.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Bet yuklanmoqda...'), findsOneWidget);
  });

  testWidgets('bet topilmasa tushunarli xabar chiqadi', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(const MaterialApp(
      home: BookPageViewer(
          level: 'beginner',
          book: 'yoq-kitob',
          page: 9999,
          bookLabel: 'Yo\'q'),
    ));
    await t.pumpAndSettle();

    expect(find.text('Bet surati topilmadi.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('mashq rasmi kichraytirilib ochiladi', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TaskVisual(visual: 'assets/images/unit1/u1-cap-china.jpg'),
      ),
    ));
    await t.pump();

    final img = t.widget<Image>(find.byType(Image));
    final provider = img.image;
    expect(provider, isA<ResizeImage>(),
        reason: 'to\'liq o\'lchamdagi rasm xotiraga ochilmasin');
  });

  testWidgets('emoji rasm sifatida ochilmaydi', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: TaskVisual(visual: '\u{1F1EE}')),
    ));
    await t.pump();

    expect(find.byType(Image), findsNothing);
  });

  test('bet suratining yo\'li DARAJAGA bog\'liq', () {
    // Beginner va Elementary — ikkalasida ham 'coursebook' bor va
    // ikkalasida ham 6-bet bor. Fayl nomida daraja bo'lmasa,
    // Elementary'ning beti Beginner'nikini bosib ketardi.
    final a = BookPageImage.assetPath('beginner', 'coursebook', 6);
    final b = BookPageImage.assetPath('elementary', 'coursebook', 6);
    expect(a, isNot(b));
    expect(a, contains('beginner'));
    expect(b, contains('elementary'));
  });
}
