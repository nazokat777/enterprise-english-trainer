import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/levels.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/shell.dart';

/// DARAJA va KITOB bog'liqligi.
///
/// XATO edi: `BookRepository` papkasi qat'iy `enterprise1` edi. Daraja
/// almashtirilsa lug'at o'zgarardi, kitob bo'limi esa BARIBIR
/// Enterprise 1 ni ko'rsatardi. Elementary qo'shilganda bu jimgina
/// noto'g'ri kitobni ochib beradigan xatoga aylanardi.
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
      BookRepository.probeLevels(),
    ]);
  });

  test('har bir daraja o\'z papkasiga ishora qiladi', () {
    expect(BookRepository.dirs['beginner'], 'assets/content/enterprise1');
    expect(BookRepository.dirs['elementary'], 'assets/content/enterprise2');
  });

  test('kitobi bor daraja HAQIQIY fayldan aniqlanadi', () async {
    // Qo'lda yozilgan ro'yxat emas — index.json o'qiladi.
    expect(BookRepository.hasBook('beginner'), isTrue);
    expect(BookRepository.hasBook('elementary'), isTrue,
        reason: 'Elementary kitobi eksport qilingan');
  });

  test('daraja almashsa kitob ham almashadi', () async {
    expect(app.book.units, isNotEmpty);

    await app.book.setLevel('elementary');
    expect(app.book.units, isNotEmpty,
        reason: 'Elementary kitobi ham eksport qilingan');
    expect(app.book.units.first.title, isNot('Hi!'),
        reason: 'Beginner kitobini ko\'rsatmasin');
    await app.book.setLevel('beginner');
    expect(app.book.units, isNotEmpty);
  });

  testWidgets('eksport qilingan daraja tanlanadi', (t) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: AppShell()));
    await t.pump();

    await t.tap(find.text('Beginner').first);
    await t.pumpAndSettle();

    // Elementary kitobi eksport qilingandan keyin daraja TANLANADIGAN
    // bo'ldi -- 'tayyor emas' yorlig'i endi ko'rinmasligi kerak.
    expect(find.textContaining('tayyor emas'), findsNothing);
    final item = t.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Elementary'));
    expect(item.enabled, isTrue);
  });


  // Darajalar ro\'yxati BITTA joyda: `levels.dart`. Ilgari u to\'rt
  // joyda takrorlanardi va yangi kitob qo\'shishda bittasi esdan
  // chiqsa, daraja qisman ishlagan bo\'lardi.
  test('darajalar ro\'yxati bitta manbadan olinadi', () {
    expect(kLevels.map((l) => l.id), containsAll(['beginner', 'elementary']));
    expect(levelLabel('beginner'), 'Beginner');
    expect(levelLabel('elementary'), 'Elementary');
    // Noma\'lum kalit ilovani yiqitmasin.
    expect(levelLabel('yoq-daraja'), 'Beginner');

    for (final l in kLevels) {
      expect(BookRepository.dirs[l.id], l.bookDir);
      expect(l.vocabDir, isNotEmpty);
    }
  });
}
