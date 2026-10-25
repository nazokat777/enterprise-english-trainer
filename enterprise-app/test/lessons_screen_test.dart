import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/lessons/lessons_screen.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';

/// SO'Z DARSLARI RO'YXATI - kitobni ko'rmagan o'quvchi ham tushunsin:
/// nega ba'zi darslar qulflangan, hozir qaysi biri, nechtasi tugagan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BookUnit unitWith(int n) => BookUnit(
        unit: 1,
        title: 'Birinchi bob',
        module: 1,
        sections: const [],
        wordFormation: const [],
        sentencePatterns: const [],
        vocabulary: [
          for (var i = 0; i < n; i++) VocabEntry(en: 'word$i', uz: 'soz$i'),
        ],
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.book = BookRepository();
    await Future.wait([app.progress.load(), app.mastery.load()]);
  });

  testWidgets("qulflangan darsda sabab yozilgan, ro'yxat tushuntirilgan",
      (t) async {
    t.view.physicalSize = const Size(420, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: LessonsScreen(unit: unitWith(15))));
    await t.pump(const Duration(seconds: 1));

    // 15 so'z -> 3 dars; tugagani nechta - yorliqli.
    expect(find.text("3 ta dars · 15 ta so'z"), findsOneWidget);
    expect(find.text('Tugatilgan darslar: 0 / 3'), findsOneWidget);
    // Ro'yxat tepasida nima ekani va nega qulflanishi.
    expect(find.textContaining("kichik darslarga bo'lingan"), findsOneWidget);
    expect(find.textContaining('ketma-ket ochiladi'), findsOneWidget);
    // Hozirgi dars belgilangan; 2- va 3-darsda HAQIQIY oldingi raqam.
    expect(find.text('Hozir shu'), findsOneWidget);
    expect(find.text('1-darsni tugatgach ochiladi'), findsOneWidget);
    expect(find.text('2-darsni tugatgach ochiladi'), findsOneWidget);
    // Birinchi dars qulflanmagan - unda sabab yozilmaydi.
    expect(find.text('0-darsni tugatgach ochiladi'), findsNothing);
    // Tezlik o'yini nima ekani aytilgan.
    expect(find.text("60 soniyalik tezlik o'yini"), findsOneWidget);
    expect(find.textContaining('ko\'p toping'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
