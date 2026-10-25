import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/book/book_screens.dart';
import 'package:enterprise_english/screens/book/exercise_player.dart';

/// "DAVOM ETISH" — o'quvchi 51 unit va 1545 mashq ichida qayerda
/// qolganini O'ZI eslab qolishi kerak edi. Xotirasi yomon odam uchun
/// bu ilovadan foydalanishning eng katta to'sig'i edi.
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

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(500, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: BookUnitsScreen())));
    await t.pump();
  }

  testWidgets("hero tugmasi sarlavhadagi darsni boshlaydi (so'zlar ro'yxati)",
      (t) async {
    // Yangi odam: sarlavha "Boshlang: 1-unit, 1-dars" deydi, oq tugma
    // aynan shu darsni ochadi (ilgari boshqa narsani - unit savollarini - ochardi).
    // DIQQAT: bu test faylda BIRINChI turishi kerak - undan oldingi testlar
    // umumiy holatni qoldirib, keyingi dars hisobini to'xtatadi.
    await pump(t);
    // 1-unit katta: keyingi dars hisoblanguncha haqiqiy vaqt kutamiz.
    for (var i = 0; i < 40; i++) {
      if (find.textContaining('Boshlang: ').evaluate().isNotEmpty) break;
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await t.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('Boshlang: 1-unit, 1-dars'), findsOneWidget);
    expect(find.textContaining('Boshlash: 1-dars ('), findsOneWidget);
    // Tez mashq ikkinchi darajali tugma bo'lib qoladi.
    expect(find.textContaining('Tez mashq: 1-unit savollari'), findsOneWidget);

    await t.tap(find.textContaining('Boshlash: 1-dars ('));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Yodlashni boshlash'), findsOneWidget);
  });

  testWidgets('hech narsa ochilmagan bo\'lsa banner yo\'q', (t) async {
    await pump(t);
    expect(find.text('Oxirgi mashqni davom ettirish'), findsNothing);
  });

  testWidgets('mashq ochilsa joy eslab qolinadi', (t) async {
    // Asset o'qish HAQIQIY vaqt talab qiladi — testning soxta soati
    // uni kutmaydi, shuning uchun `runAsync` kerak.
    final u = await t.runAsync(
        () => app.book.load(app.book.units.first.unit));
    final s = u!.sections.first;
    final e = s.exercises.first;

    t.view.physicalSize = const Size(500, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: ExercisePlayer(
          exercise: e, sectionTitle: s.titleUz, unitLabel: u.displayLabel),
    ));
    await t.pump();

    expect(app.progress.lastExerciseId, e.progressId);
    expect(app.progress.lastUnitNo, u.unit);
    // Saqlangan yorliq bo'lim nomi bilan boshlanadi ("Kirish · 1-mashq").
    expect(app.progress.lastLabel, startsWith(s.titleUz));
  });

  testWidgets('eslab qolingan joy Darslar ekranida ko\'rinadi', (t) async {
    await app.progress.rememberExercise(
        unit: 1, id: 'ex::coursebook::6::1', label: 'Kirish · Ex. 1');

    await pump(t);

    // Sarlavha nima ekanini aytadi; manzil unit va "N-mashq" bilan.
    expect(find.text('Oxirgi mashqni davom ettirish'), findsOneWidget);
    expect(find.text('1-unit · Kirish · 1-mashq'), findsOneWidget);
  });

  testWidgets('jarayon o\'chirilsa banner ham yo\'qoladi', (t) async {
    await app.progress.rememberExercise(
        unit: 1, id: 'ex::coursebook::6::1', label: 'Kirish · Ex. 1');
    await app.progress.resetAll();

    await pump(t);

    expect(find.text('Oxirgi mashqni davom ettirish'), findsNothing);
  });

  testWidgets('hero "Davom eting" hikoyada ichki raqamni (901) ko\'rsatmaydi',
      (t) async {
    // Oxirgi mashq hikoyadan (901) bo'lsa, sarlavhada "901-unit" emas,
    // "1-epizod" yozilishi kerak - kitobsiz odam 901 ni tushunmaydi.
    await app.progress.rememberExercise(
        unit: 901, id: 'ex::coursebook::24::1', label: 'Kirish · Ex. 1');

    await pump(t);
    // Keyingi dars asset'dan o'qiladi - haqiqiy vaqt kerak.
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await t.pump(const Duration(seconds: 1));

    expect(find.textContaining('Davom eting: 1-epizod, 1-dars'),
        findsOneWidget);
    expect(find.textContaining('901-unit'), findsNothing);
  });
}
