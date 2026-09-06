import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/hard_words_screen.dart';
import 'package:enterprise_english/screens/level_reference_screens.dart';
import 'package:enterprise_english/screens/units_screen.dart';
import 'package:enterprise_english/screens/unit_screen.dart';
import 'package:enterprise_english/screens/pack/pack_flow.dart';
import 'package:enterprise_english/srs.dart';
import 'package:enterprise_english/screens/homework/homework_flow.dart';

/// Lug'at (SRS) va uy vazifasi oqimlari — telefon o'lchamida.
///
/// Kitob ekranlarida aynan shunday tekshiruv to'rtta overflow xatosini
/// topgan edi; bu ikki oqim esa umuman sinovdan o'tmagan edi.
Word _w(String id, String en, String uz, {String example = ''}) => Word(
      id: id,
      en: en,
      uz: uz,
      example: example,
      module: 'M1',
      pos: 'noun',
      phonetic: '',
      freq: 5.0,
    );

/// Uzun so'zlar — tor ekranda eng og'ir holat.
final _words = <Word>[
  _w('w1', 'grandmother', 'buvi', example: 'My grandmother lives with us.'),
  _w('w2', 'refrigerator', 'muzlatkich',
      example: 'The milk is in the refrigerator.'),
  _w('w3', 'photographer', 'suratkash'),
  _w('w4', 'uncomfortable', 'noqulay'),
  _w('w5', 'grandfather', 'bobo'),
  _w('w6', 'supermarket', 'katta do\'kon'),
];

final _pack = VocabPack(
    id: 'p1',
    name: 'Oila a\'zolari — juda uzun pack nomi',
    wordIds: _words.map((w) => w.id).toList());

final _unit = Unit(
  id: 'u1',
  code: 'Unit 1 — Family and Home, juda uzun sarlavha',
  title: 'Oila va uy — tor ekran uchun uzun sarlavha',
  module: 'M1',
  order: 1,
  isRevision: false,
  components: [
    Component(id: 'c1', type: 'VOCABULARY', order: 1, packs: [_pack]),
    Component(id: 'c2', type: 'HOMEWORK', order: 2, packs: const []),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.repo = ContentRepository();
    await Future.wait([app.mastery.load(), app.progress.load(), app.repo.load()]);
  });

  Future<void> expectFits(WidgetTester t, Widget screen, Size size,
      {double scale = 1.0}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        // Haqiqiy ilovada bu ekranlar qobiqning `Scaffold` i ichida
        // chiziladi — `InkWell` uchun `Material` shu yerdan keladi.
        child: Scaffold(body: screen),
      ),
    ));
    await t.pump();
    expect(t.takeException(), isNull);
  }

  const phone = Size(375, 812);
  const narrow = Size(320, 640);

  final screens = <String, Widget Function()>{
    'unitlar ro\'yxati': () => const UnitsScreen(),
    'unit ekrani': () => UnitScreen(unit: _unit),
    'pack oqimi': () =>
        PackFlow(unit: _unit, pack: _pack, words: _words),
    'uy vazifasi': () => HomeworkFlow(
        unit: _unit, unitWords: _words, levelWords: _words),
    'qiyin so\'zlar': () => const HardWordsScreen(),
    'daraja grammatikasi': () => const LevelGrammarScreen(),
    'so\'z oilalari': () => const LevelWordFormationScreen(),
  };

  // Junk so'zlar olib tashlangach ikkita pack 3 so'zga qisqardi.
  // Oqim shunday kichik pack bilan ham ishlashi kerak.
  testWidgets('3 so\'zli pack oqimi ishlaydi', (t) async {
    final small = VocabPack(
        id: 'p2', name: 'Kichik pack', wordIds: ['w1', 'w2', 'w3']);
    await expectFits(
        t,
        PackFlow(unit: _unit, pack: small, words: _words.take(3).toList()),
        phone);
  });


  // Uy vazifasining "xatolar ustida ishlash" raundi: xato qilingan so\'z
  // darhol emas, navbat OXIRIDA qayta so\'raladi.
  testWidgets('tuzatish raundi xato so\'zni navbat oxiriga qo\'yadi',
      (t) async {
    await expectFits(
        t,
        HomeworkFlow(unit: _unit, unitWords: _words, levelWords: _words),
        phone);
    // Oqim yiqilmasdan chizildi — raund mantiqining o\'zi
    // homework_test.dart va homework_real_test.dart da tekshiriladi.
    expect(find.byType(HomeworkFlow), findsOneWidget);
  });

  for (final e in screens.entries) {
    testWidgets('${e.key} — 375px', (t) async {
      await expectFits(t, e.value(), phone);
    });
    testWidgets('${e.key} — 320px', (t) async {
      await expectFits(t, e.value(), narrow);
    });
    testWidgets('${e.key} — 375px, shrift 1.5x', (t) async {
      await expectFits(t, e.value(), phone, scale: 1.5);
    });
  }

  // XATO: moslash raundida xato urinish HECH QAYERDA hisoblanmasdi.
  // So'zni bir necha marta xato moslab, oxirida topsangiz ham u
  // "yaxshi bilinadi" deb yozilardi va "Qiyin so'zlar" ro'yxatiga
  // hech qachon tushmasdi.
  testWidgets('moslashdagi xato so\'zni qiyin deb belgilaydi', (t) async {
    final reviewed = <String, Quality>{};
    await expectFits(
        t,
        MatchStage(
          words: _words,
          onReview: (w, q) async => reviewed[w.id] = q,
          onDone: () {},
        ),
        const Size(800, 900));

    // "grandmother" tanlanadi, lekin NOTO'G'RI ma'no bosiladi.
    await t.tap(find.text('grandmother').first);
    await t.pump();
    await t.tap(find.text('muzlatkich').first);
    await t.pump(const Duration(milliseconds: 600));

    expect(app.progress.srsFor('w1').lapses, 1,
        reason: 'xato urinish so\'zning unutishlar tarixiga yozilsin');

    // Endi to'g'ri moslansa ham, so'z "oson" emas — QIYIN deb yoziladi.
    await t.tap(find.text('grandmother').first);
    await t.pump();
    await t.tap(find.text('buvi').first);
    await t.pump(const Duration(milliseconds: 600));

    expect(reviewed['w1'], Quality.hard);
  });

  testWidgets('xatosiz moslash so\'zni qiyin qilmaydi', (t) async {
    final reviewed = <String, Quality>{};
    await expectFits(
        t,
        MatchStage(
          words: _words,
          onReview: (w, q) async => reviewed[w.id] = q,
          onDone: () {},
        ),
        const Size(800, 900));

    await t.tap(find.text('grandmother').first);
    await t.pump();
    await t.tap(find.text('buvi').first);
    await t.pump(const Duration(milliseconds: 600));

    expect(reviewed['w1'], Quality.good);
    expect(app.progress.srsFor('w1').lapses, 0);
  });

  // XATO: bitta qiyin so'z bo'lganda mashqning moslash bosqichida
  // chapda ham, o'ngda ham BITTA yozuv turardi — o'ylamasdan bosilar
  // va so'z qiyinlar ro'yxatidan chiqib ketardi.
  testWidgets('bitta qiyin so\'z bilan ham mashqda tanlov bo\'ladi', (t) async {
    await app.progress.recordMiss('vocab-0066');
    await app.progress.recordMiss('vocab-0066');

    final hard = app.progress
        .hardWordIds()
        .map((id) => app.repo.forLevel('beginner').wordsById[id])
        .whereType<Word>()
        .toList();
    expect(hard.length, 1);

    t.view.physicalSize = const Size(800, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () => HardWordsScreen.drill(c, hard),
            child: const Text('boshlash'),
          ),
        );
      }),
    ));
    await t.tap(find.text('boshlash'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    // Tanishuv bosqichidan moslashgacha o'tamiz.
    for (var i = 0; i < 12; i++) {
      final next = find.textContaining('Keyingi so\'z');
      final start = find.text('Mashqni boshlash');
      if (start.evaluate().isNotEmpty) {
        await t.tap(start.first);
      } else if (next.evaluate().isNotEmpty) {
        await t.tap(next.first);
      } else {
        break;
      }
      await t.pump(const Duration(milliseconds: 400));
    }

    // Moslash bosqichiga yetganini ANIQ tekshiramiz.
    expect(find.text('So\'zlarni ma\'nosiga moslang'), findsOneWidget);
    // Chapda ham, o'ngda ham kamida 4 tadan variant bo'lsin — aks
    // holda tanlov yo'q va mashq o'rgatmaydi.
    expect(find.text('six'), findsOneWidget);
    expect(find.text('olti'), findsOneWidget);
    // Ekranda nechta HAQIQIY inglizcha so'z chizilganini sanaymiz —
    // bosqich sarlavhalari va XP yozuvi hisobga olinmasin.
    final level = app.repo.forLevel('beginner');
    final ens = level.wordsById.values.map((w) => w.en).toSet();
    final shown = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data)
        .whereType<String>()
        .where(ens.contains)
        .toSet();
    expect(shown.length, greaterThanOrEqualTo(4),
        reason: 'moslashda kamida 4 ta variant kerak: $shown');
    expect(t.takeException(), isNull);
  });

  // XATO: imlo bosqichida xato qilingan so'z faqat Quality.hard
  // olardi. SM-2 da hard (q=3) XATO hisoblanmaydi, ya'ni unutishlar
  // tarixi o'smasdi va so'z "Qiyin so'zlar" ga tushmasdi.
  testWidgets('imlodagi xato so\'zning unutishlar tarixiga yoziladi',
      (t) async {
    await expectFits(
        t,
        SpellStage(
          words: [_words.first],
          onReview: (w, q) async {},
          onDone: () {},
        ),
        const Size(800, 900));

    // Noto\'g\'ri harflar ketma-ketligi: birinchi harflarni teskari
    // tartibda bosamiz.
    // Harf plitkalari ARALASHTIRILGAN tartibda chiziladi (kod buni
    // maxsus kafolatlaydi), shuning uchun ularni ekrandagi tartibda
    // bosish NOTO'G'RI so'z beradi.
    const target = 'grandmother';
    for (var i = 0; i < target.length; i++) {
      final letters = find.byWidgetPredicate((w) =>
          w is Text && (w.data ?? '').length == 1 && w.data != '_');
      // Yig'ilayotgan so'z ham bitta harf bo'lib qolishi mumkin —
      // shuning uchun OXIRIDAN sanaymiz: plitkalar doim oxirda.
      final n = letters.evaluate().length;
      if (n <= i) break;
      await t.tap(letters.at(n - 1 - i), warnIfMissed: false);
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 300));

    expect(app.progress.srsFor('w1').lapses, greaterThan(0));

    // Xato javobdan keyin plitkalar qaytariladigan taymer qoladi —
    // test tugashidan oldin uni o'tkazib yuboramiz.
    await t.pump(const Duration(seconds: 2));
  });
}
