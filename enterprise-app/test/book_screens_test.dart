import 'dart:convert';

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
import 'package:enterprise_english/screens/book/reference_screens.dart';

/// Kichik, lekin haqiqiy unit — eksport skripti chiqaradigan shaklda.
const _unitJson = '''
{
 "unit": 1,
 "title": "Hi!",
 "module": 1,
 "sections": [
  {
   "id": "s1", "kind": "vocabulary", "title": "Vocabulary", "titleUz": "Lug'at",
   "book": "coursebook", "bookPage": 7,
   "exercises": [
    {"ref": "5", "kind": "choice", "instructionUz": "Ma'nosini tanlang.",
     "explanationUz": "Izoh matni", "audio": false,
     "book": "coursebook", "bookPage": 7,
     "tasks": [
      {"prompt": "orange", "answer": "an", "options": ["a", "an"], "whyUz": "o — unli"},
      {"prompt": "book", "answer": "a", "options": ["a", "an"], "whyUz": "b — undosh"}
     ]},
    {"ref": "6", "kind": "text", "instructionUz": "Yig'ing.",
     "book": "coursebook", "bookPage": 7,
     "tasks": [{"prompt": "13", "answer": "cat"}]},
    {"ref": "7", "kind": "match", "instructionUz": "Moslang.",
     "book": "coursebook", "bookPage": 7,
     "tasks": [{"left": "one", "right": "first"}, {"left": "two", "right": "second"}]},
    {"ref": "8", "kind": "study", "instructionUz": "O'qing.",
     "book": "coursebook", "bookPage": 7,
     "tasks": [{"en": "I am from Spain.", "uz": "Men Ispaniyadanman."}]}
   ]
  },
  {
   "id": "s2", "kind": "grammar_theory", "titleUz": "Grammatika — qoida",
   "book": "grammar", "bookPage": 4, "exercises": [],
   "rule": {"titleUz": "to be", "explanationUz": "Qoida tushuntirishi",
            "warningUz": "Ehtiyot bo'ling"}
  }
 ],
 "wordFormation": [
  {"ruleUz": "-er qo'shimchasi", "explanationUz": "izoh",
   "items": [{"base": "farm", "baseUz": "ferma", "derived": "farmer",
              "derivedUz": "dehqon", "note": "farm + er"}],
   "book": "coursebook", "bookPage": 7}
 ],
 "sentencePatterns": [
  {"formula": "I'm a + KASB", "exampleEn": "I'm a doctor.",
   "exampleUz": "Men shifokorman.", "explanationUz": "izoh",
   "book": "coursebook", "bookPage": 7}
 ],
 "vocabulary": [
  {"en": "farmer", "uz": "dehqon"},
  {"en": "doctor", "uz": "shifokor"},
  {"en": "artist", "uz": "rassom"},
  {"en": "pilot", "uz": "uchuvchi"}
 ]
}
''';

late BookUnit unit;

Widget _wrap(Widget child) => MaterialApp(home: child);

/// Baland ekran: `ListView` elementlarni sust quradi, unit sahifasi esa
/// endi tushuntirishlar bilan uzunroq - pastdagi elementlar ham topilsin.
void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 3600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    // Mashq ekrani xato qilingan so'zni lug'at bilan solishtiradi,
    // shuning uchun repozitoriy ham kerak (haqiqiy ilovada u main()
    // da doim tayyorlanadi).
    app.repo = ContentRepository();
    // `book` ham kerak: bet surati fayli DARAJA bilan nomlanadi.
    app.book = BookRepository();
    await Future.wait([app.mastery.load(), app.progress.load(), app.repo.load()]);
    unit = BookUnit.fromJson(json.decode(_unitJson) as Map<String, dynamic>);
  });

  group('BookUnitScreen', () {
    testWidgets('unit sarlavhasi va statistika ko\'rinadi', (t) async {
      await t.pumpWidget(_wrap(BookUnitScreen(unit: unit)));
      await t.pump();

      expect(find.text('1-unit — Hi!'), findsOneWidget);
      expect(find.text('bo\'lim'), findsOneWidget);
      expect(find.text('mashq'), findsOneWidget);
    });

    testWidgets('hikoya beti "epizod" deb belgilanadi', (t) async {
      // Kitobda unitlar orasida "Episode" hikoya betlari bor. Ular unit
      // raqamiga ega emas — yorliq asset'dan keladi.
      final ep = BookUnit.fromJson({
        ...json.decode(_unitJson) as Map<String, dynamic>,
        'unit': 901,
        'label': '1-epizod',
        'title': 'The Loch Ness Monster',
      });
      expect(ep.displayLabel, '1-epizod');
      expect(ep.pages().first.fullLabel, startsWith('1-epizod · '));

      await t.pumpWidget(_wrap(BookUnitScreen(unit: ep)));
      await t.pump();
      expect(find.text('1-epizod — The Loch Ness Monster'), findsOneWidget);
      expect(find.textContaining('901'), findsNothing);
    });

    testWidgets('modul testi ham unit raqamisiz ko\'rsatiladi', (t) async {
      // "Module Self-Assessment" ham unit emas — o'z yorlig'i bo'ladi.
      final test = BookUnit.fromJson({
        ...json.decode(_unitJson) as Map<String, dynamic>,
        'unit': 951,
        'label': '1-modul testi',
        'title': 'Module Self-Assessment 1 (Units 1-4)',
      });
      expect(test.displayLabel, '1-modul testi');

      await t.pumpWidget(_wrap(BookUnitScreen(unit: test)));
      await t.pump();
      expect(find.textContaining('1-modul testi'), findsOneWidget);
      expect(find.textContaining('951'), findsNothing);
    });

    test('unit raqami bo\'lmasa yorliq raqamdan tuziladi', () {
      final u = BookUnit.fromJson(
          json.decode(_unitJson) as Map<String, dynamic>);
      expect(u.displayLabel, '1-unit');
      expect(u.pages().first.unitLabel, '1-unit');
    });

    testWidgets('bo\'limlar turi bo\'yicha guruhlanadi', (t) async {
      _tall(t);
      await t.pumpWidget(_wrap(BookUnitScreen(unit: unit)));
      await t.pump();

      // Yuqorida tugmalar (so'zlar, trening, diktant, betlar) — bo'limlar
      // pastroqda, ko'rish uchun suramiz.
      await t.drag(find.byType(ListView), const Offset(0, -300));
      await t.pump();

      expect(find.text('Lug\'at'), findsWidgets);
      expect(find.text('Grammatika — qoida'), findsOneWidget);
    });

    testWidgets('ma\'lumotnoma bo\'limlari bor', (t) async {
      _tall(t);
      await t.pumpWidget(_wrap(BookUnitScreen(unit: unit)));
      await t.pump();

      // Ro'yxat uzun — ko'rinmagan elementlarni ko'rish uchun pastga suramiz.
      await t.drag(find.byType(ListView), const Offset(0, -600));
      await t.pump();

      expect(find.text('So\'z yasalishi'), findsOneWidget);
      expect(find.text('Gap qoliplari'), findsOneWidget);
      expect(find.text('Unit lug\'ati'), findsOneWidget);
    });

    testWidgets('kitob nomi aniq yoziladi ("3 kitobdan" emas)', (t) async {
      _tall(t);
      await t.pumpWidget(_wrap(BookUnitScreen(unit: unit)));
      await t.pump();
      await t.drag(find.byType(ListView), const Offset(0, -300));
      await t.pump();

      // Bitta kitobdan bo'lsa — bet raqami bilan ("Kitobda: ..." — bu
      // kitob ma'lumoti ekani aytiladi).
      expect(find.text('Kitobda: Coursebook 7-bet'), findsOneWidget);
      expect(find.text('Kitobda: Grammar 4-bet'), findsOneWidget);
      // Noaniq yozuv qolmasin.
      expect(find.textContaining('kitobdan'), findsNothing);
    });

    testWidgets('kitob sahifalari tugmasi bor', (t) async {
      _tall(t);
      await t.pumpWidget(_wrap(BookUnitScreen(unit: unit)));
      await t.pump();

      // 2 ta bet: coursebook 7 va grammar 4
      expect(find.text('Kitob sahifalari bo\'yicha (2 bet)'), findsOneWidget);
    });

    testWidgets('unit sahifasida tavsiya etilgan tartib va izohlar bor',
        (t) async {
      _tall(t);
      await t.pumpWidget(_wrap(BookUnitScreen(unit: unit)));
      await t.pump();

      // Nimadan boshlash kerakligi aytiladi (kitobsiz o'quvchi uchun).
      expect(find.text('Tavsiya etilgan tartib'), findsOneWidget);
      expect(find.text('So\'z darslari'), findsOneWidget);
      expect(find.text('Unit imtihoni'), findsOneWidget);
      // Raqamlar nima ekani yozilgan.
      expect(find.text('Bu unitda:'), findsOneWidget);
      expect(find.text('savol'), findsOneWidget);
      expect(find.text('band'), findsNothing);
    });
  });

  group('Kitob sahifalari ro\'yxati', () {
    testWidgets('betlar kitob bo\'yicha guruhlanadi', (t) async {
      await t.pumpWidget(_wrap(BookPagesScreen(unit: unit)));
      await t.pump();

      // Guruh sarlavhasi — kitob nomi nima ekani bilan.
      expect(find.text('Coursebook (asosiy darslik)'), findsOneWidget);
      expect(find.text('Grammar (grammatika kitobi)'), findsOneWidget);
      // Bet yozuvida ham kitob nomi bor — "7-bet" o'zi yetarli emas edi.
      expect(find.text('Enterprise 1 · Coursebook · 7-bet'), findsOneWidget);
      expect(find.text('Enterprise 1 · Grammar · 4-bet'), findsOneWidget);
    });

    testWidgets('bet ekrani to\'liq manzil va mashqlarni ko\'rsatadi',
        (t) async {
      _tall(t);
      final page = unit.pages().first;
      await t.pumpWidget(_wrap(BookPageScreen(page: page)));
      await t.pump();

      // To'liq manzil: "1-unit · Coursebook · 7-bet"
      expect(find.text('1-unit · Enterprise 1 · Coursebook · 7-bet'), findsOneWidget);
      // Betdagi barcha mashqlar ("Ex. 5" kitob qisqartmasi emas, "5-mashq")
      expect(find.text('5-mashq'), findsOneWidget);
      expect(find.text('6-mashq'), findsOneWidget);
      expect(find.text('7-mashq'), findsOneWidget);
      expect(find.text('8-mashq'), findsOneWidget);
    });

    testWidgets('har mashqda qaysi kitob va bet yozilgan', (t) async {
      _tall(t);
      final page = unit.pages().first;
      await t.pumpWidget(_wrap(BookPageScreen(page: page)));
      await t.pump();

      // Kitob manzili "Kitobda: ..." deb yoziladi (kitobsiz o'quvchi uchun
      // bu faqat ma'lumot).
      expect(
          find.text(
              'Kitobda: 1-unit · Enterprise 1 · Coursebook · 7-bet · 5-mashq'),
          findsOneWidget);
      expect(
          find.text(
              'Kitobda: 1-unit · Enterprise 1 · Coursebook · 7-bet · 6-mashq'),
          findsOneWidget);
    });
  });

  group('BookGroupScreen', () {
    testWidgets('mashqlar va manba kitob belgisi ko\'rinadi', (t) async {
      final g = unit.groupedSections().first;
      await t.pumpWidget(_wrap(BookGroupScreen(group: g)));
      await t.pump();

      expect(find.text('5-mashq'), findsOneWidget);
      expect(find.text('6-mashq'), findsOneWidget);
      expect(find.text('Kitobda: Enterprise 1 · Coursebook, 7-bet'),
          findsOneWidget);
      // Mashq turi belgilari — nima qilinishi so'z bilan aytiladi
      expect(find.text('Variantdan tanlash'), findsOneWidget);
      expect(find.text('So\'z va harflardan yig\'ish'), findsOneWidget);
      expect(find.text('Juftlarni moslash'), findsOneWidget);
      expect(find.text('Faqat o\'qish (savolsiz)'), findsOneWidget);
    });
  });

  group('ExercisePlayer — tanlash', () {
    testWidgets('savol, variantlar va izoh ko\'rinadi', (t) async {
      // Kartalar ko'paygach (Nima qilinadi, Qoida va izoh) variantlar
      // pastroqda - baland ekran.
      _tall(t);
      final ex = unit.sections.first.exercises[0];
      await t.pumpWidget(_wrap(
          ExercisePlayer(exercise: ex, sectionTitle: 'Lug\'at')));
      await t.pump();

      expect(find.text('orange'), findsOneWidget);
      expect(find.text('Izoh matni'), findsOneWidget);
      expect(find.text('a'), findsOneWidget);
      expect(find.text('an'), findsOneWidget);
      // Hisoblagich O'ZLAShTIRILGAN bandlarni ko'rsatadi (o'rinni emas):
      // boshida hali hech narsa o'zlashtirilmagan. Sanagich nimani
      // sanashi yozilgan ("to'g'ri").
      expect(find.text('0 / 2 to\'g\'ri'), findsOneWidget);
      // Mashq qoidasi birinchi savolda bir marta aytiladi.
      expect(find.textContaining('Xato qilgan savol keyinroq yana'),
          findsOneWidget);
      // "Nima qilinadi" kartasi va kitobdagi manzil izohlangan.
      expect(find.text('Nima qilinadi'), findsOneWidget);
    });

    testWidgets('to\'g\'ri javob keyingi savolga o\'tkazadi', (t) async {
      // "Nima qilinadi" kartasi qo'shilgach izoh pastroqda - baland ekran.
      t.view.physicalSize = const Size(800, 1600);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final ex = unit.sections.first.exercises[0];
      await t.pumpWidget(_wrap(
          ExercisePlayer(exercise: ex, sectionTitle: 'Lug\'at')));
      await t.pump();

      await t.tap(find.text('an'));
      await t.pump();
      // "nega shunday" izohi chiqadi
      expect(find.text('o — unli'), findsOneWidget);

      await t.pump(const Duration(milliseconds: 1000));
      await t.pump();
      expect(find.text('book'), findsOneWidget, reason: '2-savolga o\'tdi');
      expect(find.text('1 / 2 to\'g\'ri'), findsOneWidget,
          reason: 'bitta band o\'zlashtirildi');
    });

    testWidgets('barcha savol tugagach natija ekrani chiqadi', (t) async {
      _tall(t);
      final ex = unit.sections.first.exercises[0];
      await t.pumpWidget(_wrap(
          ExercisePlayer(exercise: ex, sectionTitle: 'Lug\'at')));
      await t.pump();

      await t.tap(find.text('an'));
      await t.pump(const Duration(milliseconds: 1000));
      await t.pump();
      await t.tap(find.text('a'));
      await t.pump(const Duration(milliseconds: 1000));
      await t.pump();

      // Hamma band xatosiz to\'g\'ri javob berilgach mashq tugaydi va
      // natija nimani bildirishi aytiladi.
      expect(find.text('Hammasi to\'g\'ri!'), findsOneWidget);
      expect(find.textContaining('Xatosiz bajardingiz'), findsOneWidget);
      expect(find.text('Mashqlar ro\'yxatiga qaytish'), findsOneWidget);
      expect(find.text('Bu mashqni qaytadan boshlash'), findsOneWidget);
    });
  });

  group('ExercisePlayer — o\'zlashtirgunicha takrorlash', () {
    testWidgets('xato qilingan band navbatga QAYTADI', (t) async {
      // Ilgari bandlar bir marta so'ralardi: xato javob shunchaki o'tib
      // ketardi va o'quvchi o'sha bandni boshqa ko'rmasdi.
      _tall(t);
      final ex = unit.sections.first.exercises[0]; // 2 bandli tanlash
      await t.pumpWidget(_wrap(
          ExercisePlayer(exercise: ex, sectionTitle: 'Lug\'at')));
      await t.pump();

      // 1-band: ATAYLAB xato.
      expect(find.text('orange'), findsOneWidget);
      await t.tap(find.text('a'));
      await t.pump(const Duration(milliseconds: 2000));
      await t.pump();

      // Xato band o'zlashtirilmagan.
      expect(find.text('0 / 2 to\'g\'ri'), findsOneWidget);

      // 2-band: to'g'ri.
      expect(find.text('book'), findsOneWidget);
      await t.tap(find.text('a'));
      await t.pump(const Duration(milliseconds: 2000));
      await t.pump();

      // Mashq TUGAMAYDI — xato band qaytadi.
      expect(find.text('orange'), findsOneWidget,
          reason: 'xato qilingan band qayta so\'ralishi kerak');
      expect(find.text('qayta so\'ralyapti'), findsOneWidget);

      // Endi to'g'ri javob — mashq tugaydi. Xato bo'lgani uchun natija
      // "Hammasi to'g'ri" EMAS va nima bo'lishi aytiladi.
      await t.tap(find.text('an'));
      await t.pump(const Duration(milliseconds: 2000));
      await t.pump();
      expect(find.text('Mashq tugadi: hammasini topdingiz'), findsOneWidget);
      expect(find.text('Hammasi to\'g\'ri!'), findsNothing);
      expect(find.textContaining('Takrorlash kerak'), findsOneWidget);
      expect(find.textContaining('Xatolar daftariga'), findsOneWidget);
    });

    testWidgets('hammasi to\'g\'ri bo\'lsa takror bo\'lmaydi', (t) async {
      _tall(t);
      final ex = unit.sections.first.exercises[0];
      await t.pumpWidget(_wrap(
          ExercisePlayer(exercise: ex, sectionTitle: 'Lug\'at')));
      await t.pump();

      await t.tap(find.text('an'));
      await t.pump(const Duration(milliseconds: 2000));
      await t.pump();
      await t.tap(find.text('a'));
      await t.pump(const Duration(milliseconds: 2000));
      await t.pump();

      expect(find.text('Hammasi to\'g\'ri!'), findsOneWidget);
      expect(find.textContaining('adashdingiz'), findsNothing);
    });
  });


  group('ExercisePlayer — yig\'ish', () {
    testWidgets('harf plitkalari chiqadi va javob yig\'iladi', (t) async {
      final ex = unit.sections.first.exercises[1];
      await t.pumpWidget(_wrap(
          ExercisePlayer(exercise: ex, sectionTitle: 'Lug\'at')));
      await t.pump();

      // "cat" -> 3 ta harf plitkasi
      expect(find.text('c'), findsOneWidget);
      expect(find.text('a'), findsOneWidget);
      expect(find.text('t'), findsOneWidget);

      await t.tap(find.text('c'));
      await t.pump();
      await t.tap(find.text('a'));
      await t.pump();
      await t.tap(find.text('t'));
      await t.pump();

      // To'g'ri yig'ildi -> natijaga o'tadi
      await t.pump(const Duration(milliseconds: 1100));
      await t.pump();
      expect(find.text('Mashqlar ro\'yxatiga qaytish'), findsOneWidget);
    });
  });

  group('ExercisePlayer — moslash', () {
    testWidgets('ikki ustun ko\'rinadi', (t) async {
      final ex = unit.sections.first.exercises[2];
      await t.pumpWidget(_wrap(
          ExercisePlayer(exercise: ex, sectionTitle: 'Lug\'at')));
      await t.pump();

      expect(find.text('one'), findsOneWidget);
      expect(find.text('first'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
    });
  });

  group('ExercisePlayer — o\'qish', () {
    testWidgets('matn va tarjima ko\'rinadi, tugma bor', (t) async {
      final ex = unit.sections.first.exercises[3];
      await t.pumpWidget(_wrap(
          ExercisePlayer(exercise: ex, sectionTitle: 'Lug\'at')));
      await t.pump();

      expect(find.text('I am from Spain.'), findsOneWidget);
      expect(find.text('Men Ispaniyadanman.'), findsOneWidget);
      expect(find.text('O\'qib chiqdim'), findsOneWidget);
      // O'qish sahnasida ham "Nima qilinadi" bor: savol yo'qligi va
      // nima qilish aytiladi (mashqlarning uchdan biri shunday).
      expect(find.text('Nima qilinadi'), findsOneWidget);
      expect(find.textContaining('Bu yerda savol yo\'q'), findsOneWidget);
    });
  });

  group('Ma\'lumotnoma ekranlari', () {
    testWidgets('qoida ekrani matn va ogohlantirishni ko\'rsatadi', (t) async {
      await t.pumpWidget(_wrap(RuleScreen(section: unit.sections[1])));
      await t.pump();

      expect(find.text('to be'), findsOneWidget);
      expect(find.text('Qoida tushuntirishi'), findsOneWidget);
      expect(find.text('Ehtiyot bo\'ling'), findsOneWidget);
      expect(
          find.text(
              '📖 Kitobda: Enterprise 1 · Grammar (grammatika kitobi), 4-bet'),
          findsOneWidget);
      // Sahifa nima ekani birinchi qatorda aytiladi.
      expect(find.textContaining('Bu yerda:'), findsOneWidget);
      // Rangli quti nima ekani sarlavhada yoziladi.
      expect(find.text('Diqqat!'), findsOneWidget);
    });

    testWidgets('so\'z yasalishi ekrani juftlarni ko\'rsatadi', (t) async {
      await t.pumpWidget(_wrap(WordFormationScreen(unit: unit)));
      await t.pump();

      expect(find.text('-er qo\'shimchasi'), findsOneWidget);
      expect(find.text('farm'), findsOneWidget);
      expect(find.text('farmer'), findsOneWidget);
      expect(find.text('farm + er'), findsOneWidget);
    });

    testWidgets('gap qoliplari ekrani formula va misolni ko\'rsatadi',
        (t) async {
      await t.pumpWidget(_wrap(SentencePatternsScreen(unit: unit)));
      await t.pump();

      expect(find.text('I\'m a + KASB'), findsOneWidget);
      expect(find.text('I\'m a doctor.'), findsOneWidget);
      expect(find.text('Men shifokorman.'), findsOneWidget);
    });

    testWidgets('lug\'at ekrani so\'zlarni va yodlash tugmasini ko\'rsatadi',
        (t) async {
      await t.pumpWidget(_wrap(UnitVocabularyScreen(unit: unit)));
      await t.pump();

      expect(find.text('Test boshlash (4 so\'z)'), findsOneWidget);
      expect(find.textContaining('Bu yerda: shu unit (bob) so\'zlari'),
          findsOneWidget);
      expect(find.text('farmer'), findsOneWidget);
      expect(find.text('dehqon'), findsOneWidget);
    });
  });

  group("Kitob yo'li: betma-bet ketma-ket", () {
    testWidgets("keyingi bet tugmasi ikkinchi betga o'tkazadi, oxirida imtihon",
        (t) async {
      _tall(t);
      await t.pumpWidget(_wrap(BookPagesScreen(unit: unit)));
      await t.pump();
      // Ro'yxat boshida yo'l tushuntirilgan, oxirida imtihon bor.
      expect(find.textContaining("Kitob yo'li"), findsOneWidget);
      expect(find.text('Hamma betlar tugadimi? Endi imtihon'), findsOneWidget);

      // Birinchi bet (Coursebook 7) -> "Keyingi bet" -> Grammar 4.
      await t.tap(find.textContaining('Coursebook').last);
      await t.pumpAndSettle();
      expect(find.text('Bet 1 / 2'), findsOneWidget);
      expect(find.text('Hamma betlar tugadimi? Endi imtihon'), findsNothing);
      await t.tap(find.text('Keyingi bet'));
      await t.pumpAndSettle();
      expect(find.text('Bet 2 / 2'), findsOneWidget);
      expect(find.text('Oldingi bet'), findsOneWidget);
      // Oxirgi betda unit imtihoni chiqadi.
      await t.scrollUntilVisible(
          find.text('Hamma betlar tugadimi? Endi imtihon'), 300);
      expect(find.text('Hamma betlar tugadimi? Endi imtihon'), findsOneWidget);
    });
  });
}
