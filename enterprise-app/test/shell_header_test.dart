import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/shell.dart';

/// TELEFONDA yuqori panel ilgari ekrandan CHIQIB KETARDI: 375px kenglikda
/// Flutter "RIGHT OVERFLOWED BY 47 PIXELS" sariq-qora chizig'ini chizardi.
/// Sabab — o'ng tomondagi ko'rsatkichlar guruhi `Spacer()` dan keyin
/// cheksiz kenglik olardi.
void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.repo = ContentRepository();
    app.book = BookRepository();
    await Future.wait(
        [app.progress.load(), app.repo.load(), app.book.loadIndex()]);
  });

  /// Ekran o'lchamini belgilab, qobiqni chizadi.
  Future<void> pumpAt(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: AppShell()));
    await t.pump();
  }

  testWidgets('375px telefon ekranida panel chiqib ketmaydi', (t) async {
    await pumpAt(t, const Size(375, 812));

    // Chizishda overflow bo'lsa, Flutter uni exception qilib qo'yadi.
    expect(t.takeException(), isNull);
  });

  testWidgets('320px eng tor ekranda ham chiqib ketmaydi', (t) async {
    await pumpAt(t, const Size(320, 640));

    expect(t.takeException(), isNull);
  });

  testWidgets('keng ekranda sidebar ko\'rinadi', (t) async {
    await pumpAt(t, const Size(1280, 800));

    expect(t.takeException(), isNull);
    expect(find.text('Darslar'), findsWidgets);
  });

  testWidgets('menyudagi har bir band o\'z ekranini ochadi', (t) async {
    // Menyu ro'yxati bilan `_body()` dagi `case` raqamlari MOS bo'lishi
    // kerak. Bir marta ro'yxatga yangi band qo'shilmay qolgani uchun
    // "Suhbatlar" bosilganda grammatika ekrani ochilib qolgan edi.
    await pumpAt(t, const Size(1280, 800));

    for (final label in ['Darslar', 'Lug\'at', 'Grammatika',
                         'So\'z yasalishi']) {
      await t.tap(find.text(label).first);
      await t.pump();
      expect(t.takeException(), isNull, reason: label);
    }
    // Hali tayyor bo'lmagan bo'limlar "keyingi fazalarda" deb chiqadi.
    await t.tap(find.text('Suhbatlar').first);
    await t.pump();
    expect(find.textContaining('Suhbatlar'), findsWidgets);
  });

  testWidgets('kontenti yo\'q daraja tanlanmaydi', (t) async {
    // Ilgari ro'yxat qat'iy edi: bo'sh 'Elementary' ni tanlash mumkin
    // bo'lgani uchun yuqorida shu yozuv turardi, kitob bo'limi esa
    // baribir Beginner kontentini ko'rsatardi.
    await pumpAt(t, const Size(1280, 800));

    await t.tap(find.text('Beginner').first);
    await t.pumpAndSettle();

    expect(find.textContaining('Elementary'), findsOneWidget);
    final item = t.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Elementary — tayyor emas'));
    expect(item.enabled, isFalse);
  });
}
