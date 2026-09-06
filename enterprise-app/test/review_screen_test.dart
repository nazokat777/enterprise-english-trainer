import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/review_screen.dart';

/// "Takrorlash kerak" ekrani — haqiqiy kitob kontenti ustida.
///
/// Bu ekran BARCHA unitlarni o'qiydi; ilgari buni birin-ketin qilardi
/// va jonli saytda ~20 soniya aylanib turardi.
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

  /// `pumpAndSettle` BU YERDA ISHLAMAYDI: yuklanayotganda ekranda
  /// cheksiz aylanadigan `CircularProgressIndicator` turadi, shuning
  /// uchun "tinchish" hech qachon yetib kelmaydi va test osilib qoladi.
  ///
  /// Unitlar `runAsync` ichida oldindan keshga olinadi: asset o'qish
  /// HAQIQIY vaqt talab qiladi, testning soxta soati esa uni kutmaydi.
  /// Keshdan keyin ekranning `load` chaqiruvlari darhol qaytadi.
  Future<void> pump(WidgetTester t) async {
    await t.runAsync(() =>
        Future.wait(app.book.units.map((b) => app.book.load(b.unit))));
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: ReviewScreen())));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
  }

  testWidgets('xato mashq yo\'q bo\'lsa bo\'sh holat chiqadi', (t) async {
    await pump(t);
    expect(find.textContaining('Takrorlash kerak bo\'lgan mashq yo\'q'),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('xato bilan tugatilgan mashq ro\'yxatda ko\'rinadi', (t) async {
    // Haqiqiy mashq: 1-unit, Coursebook 6-bet, Ex. 1.
    final u = await t.runAsync(
        () => app.book.load(app.book.units.first.unit));
    final e = u!.sections.first.exercises.first;
    final id = e.progressId;
    await app.progress.markExerciseResult(id, clean: false);

    await pump(t);

    expect(find.text('1 ta mashq xato bilan tugatilgan'), findsOneWidget);
  });

  testWidgets('xatosiz tugatilgan mashq ro\'yxatga tushmaydi', (t) async {
    final u = await t.runAsync(
        () => app.book.load(app.book.units.first.unit));
    final e = u!.sections.first.exercises.first;
    final id = e.progressId;
    await app.progress.markExerciseResult(id, clean: false);
    await app.progress.markExerciseResult(id, clean: true);

    await pump(t);

    expect(find.textContaining('Takrorlash kerak bo\'lgan mashq yo\'q'),
        findsOneWidget);
  });

  test('har bir mashqning progress kaliti NOYOB', () async {
    // XATO: raqamlanmagan betlarda kalit `ex::coursebook::0::muqova`
    // bo'lardi — to'rtta har xil mashq uchun bir xil. Bittasini
    // tugatsangiz to'rttasi ham "bajarildi" bo'lib qolardi.
    final seen = <String, String>{};
    for (final brief in app.book.units) {
      final u = await app.book.load(brief.unit);
      for (final s in u!.sections) {
        for (final e in s.exercises) {
          final prev = seen[e.progressId];
          expect(prev, isNull,
              reason: 'kalit takrorlandi: ${e.progressId} | $prev');
          seen[e.progressId] = '${u.displayLabel} / ${s.titleUz} / ${e.title}';
        }
      }
    }
  });
}
