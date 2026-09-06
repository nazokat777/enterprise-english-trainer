import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/conversations_screen.dart';

/// Menyudagi "Suhbatlar" bandi bo'sh ekran ochardi, kitobda esa
/// o'nlab dialog bor edi — ular unitlar bo'ylab tarqalib yotardi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.repo = ContentRepository();
    app.book = BookRepository();
    await Future.wait(
        [app.progress.load(), app.repo.load(), app.book.loadIndex()]);
  });

  test('kitobda dialoglar topiladi', () async {
    var found = 0;
    for (final brief in app.book.units) {
      final u = await app.book.load(brief.unit);
      for (final s in u!.sections) {
        for (final e in s.exercises) {
          if (isDialogue(e)) found++;
        }
      }
    }
    expect(found, greaterThan(20), reason: 'kitobda dialoglar bor');
  });

  // XATO: aniqlagich "Contents:", "SHOPPING:", "AmE:" kabi
  // sarlavhalarni ham gapiruvchi deb hisoblardi va mundarija sahifasi
  // suhbatlar ro'yxatida birinchi bo'lib turardi.
  test('sarlavhalar dialog deb hisoblanmaydi', () async {
    final wrong = <String>[];
    for (final brief in app.book.units) {
      final u = await app.book.load(brief.unit);
      for (final s in u!.sections) {
        for (final e in s.exercises) {
          if (!isDialogue(e)) continue;
          for (final t in e.tasks) {
            final head = t.en.trim().split(':').first.toLowerCase();
            if (const ['contents', 'grammar', 'ame', 'bre', 'shopping',
                       'nightlife', 'qayd'].contains(head)) {
              wrong.add('${u.displayLabel} Ex.${e.ref}: ${t.en}');
            }
          }
        }
      }
    }
    expect(wrong, isEmpty, reason: wrong.join('; '));
  });

  testWidgets('suhbatlar ekrani ro\'yxatni chizadi', (t) async {
    await t.runAsync(
        () => Future.wait(app.book.units.map((b) => app.book.load(b.unit))));

    t.view.physicalSize = const Size(375, 812);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: ConversationsScreen())));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }

    expect(find.text('Suhbatlar'), findsOneWidget);
    expect(find.textContaining('ta dialog'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
