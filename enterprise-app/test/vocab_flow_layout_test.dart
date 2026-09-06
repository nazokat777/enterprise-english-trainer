import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/units_screen.dart';
import 'package:enterprise_english/screens/unit_screen.dart';
import 'package:enterprise_english/screens/pack/pack_flow.dart';
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
    app.repo = ContentRepository();
    await Future.wait([app.progress.load(), app.repo.load()]);
  });

  Future<void> expectFits(WidgetTester t, Widget screen, Size size,
      {double scale = 1.0}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: screen,
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
}
