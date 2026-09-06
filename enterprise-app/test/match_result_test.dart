import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/exercise_player.dart';

/// MOSLASH mashqining natija ekrani.
///
/// XATO edi: natija "o'zlashtirildi" deb hisoblanishi uchun `_mastered`
/// to'plami tekshirilardi, moslash rejimida esa u HECH QAChON
/// to'ldirilmasdi. Ya'ni barcha juftni xatosiz moslagan o'quvchi ham
/// to'q sariq "qayta urinish" belgisini va quruq "5 / 5" yozuvini
/// ko'rardi — go'yo mashqni bajarolmagandek.
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

  final ex = BookExercise(
    ref: 'm',
    kind: ExKind.match,
    book: 'coursebook',
    bookPage: 7,
    tasks: const [
      ExTask(left: 'cat', right: 'mushuk'),
      ExTask(left: 'dog', right: 'it'),
      ExTask(left: 'bird', right: 'qush'),
    ],
  );

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: ExercisePlayer(exercise: ex, sectionTitle: 'Test'),
    ));
    await t.pump();
  }

  /// Barcha juftni to'g'ri moslaydi.
  Future<void> solve(WidgetTester t) async {
    for (final task in ex.tasks) {
      await t.tap(find.text(task.left).first);
      await t.pump();
      await t.tap(find.text(task.right).first);
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(milliseconds: 900));
  }

  testWidgets('xatosiz moslash O\'ZLAShTIRILDI deb baholanadi', (t) async {
    await pump(t);
    await solve(t);

    expect(find.text('O\'zlashtirildi'), findsOneWidget);
    expect(find.text('3 / 3'), findsNothing,
        reason: 'quruq son emas, natija yozilsin');
    expect(find.byIcon(Icons.replay_rounded), findsNothing,
        reason: 'qayta urinish belgisi chiqmasin');
  });

  testWidgets('xatosiz moslash takrorlash ro\'yxatiga tushmaydi', (t) async {
    await pump(t);
    await solve(t);

    expect(app.progress.needsRepeat(ex.progressId), isFalse);
    expect(app.progress.isDone(ex.progressId), isTrue);
  });


  testWidgets('xato bilan moslash TAKRORLAShDA qoladi', (t) async {
    // XATO edi: moslashda `_misses` hech qachon to\'ldirilmasdi,
    // shuning uchun xato qilingan mashq ham "xatosiz" deb yozilardi
    // va "Takrorlash kerak" ro\'yxatiga TUShMASDI.
    await pump(t);

    // Ataylab noto\'g\'ri juft: "cat" ni "it" ga moslaymiz.
    await t.tap(find.text('cat').first);
    await t.pump();
    await t.tap(find.text('it').first);
    await t.pump(const Duration(milliseconds: 500));

    await solve(t);

    expect(app.progress.isDone(ex.progressId), isTrue);
    expect(app.progress.needsRepeat(ex.progressId), isTrue,
        reason: 'xato qilingan mashq takrorlanishi kerak');
    // Hamma juft oxir-oqibat topilgani uchun sarlavha
    // "O\'zlashtirildi" bo\'lib qoladi — lekin nechtasi BIRINChI
    // urinishda topilgani alohida yoziladi va mashq takrorlash
    // ro\'yxatida turadi.
    expect(find.text('O\'zlashtirildi'), findsOneWidget);
    expect(find.textContaining('birinchi urinishda'), findsOneWidget);
  });
}
