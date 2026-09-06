import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/conversations_screen.dart';

/// Menyudagi "Suhbatlar" bandi bo'sh ekran ochardi, kitobda esa
/// o'nlab dialog bor edi — ular unitlar bo'ylab tarqalib yotardi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.repo = ContentRepository();
    app.book = BookRepository();
    await Future.wait([app.mastery.load(), app.progress.load(), app.repo.load(), app.book.loadIndex()]);
  });

  // Dialoglar ro'yxati EKSPORTDA hisoblanadi va indeksga yoziladi.
  // Ilova uni o'zi ajratmaydi — shuning uchun tekshiruv ham aynan
  // eksport natijasiga qaraydi.
  test('indeksda dialoglar bor', () {
    expect(app.book.dialogues.length, greaterThan(20));
  });

  test('sarlavhalar dialog deb hisoblanmagan', () async {
    final wrong = <String>[];
    for (final d in app.book.dialogues) {
      final u = await app.book.load(d.unit);
      if (u == null) continue;
      for (final s in u.sections) {
        for (final e in s.exercises) {
          if (e.ref != d.ref || e.bookPage != d.bookPage) continue;
          for (final task in e.tasks) {
            final head = task.en.trim().split(':').first.toLowerCase();
            if (const ['contents', 'grammar', 'ame', 'bre', 'shopping',
                       'nightlife', 'qayd'].contains(head)) {
              wrong.add('${u.displayLabel} Ex.${e.ref}: ${task.en}');
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
