import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/main.dart' as app;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    await app.progress.load();
    unit = BookUnit.fromJson(json.decode(_unitJson) as Map<String, dynamic>);
  });

  group('BookUnitScreen', () {
    testWidgets('unit sarlavhasi va statistika ko\'rinadi', (t) async {
      await t.pumpWidget(_wrap(BookUnitScreen(unit: unit)));
      await t.pump();

      expect(find.text('Unit 1 — Hi!'), findsOneWidget);
      expect(find.text('bo\'lim'), findsOneWidget);
      expect(find.text('mashq'), findsOneWidget);
    });

    testWidgets('bo\'limlar turi bo\'yicha guruhlanadi', (t) async {
      await t.pumpWidget(_wrap(BookUnitScreen(unit: unit)));
      await t.pump();

      expect(find.text('Lug\'at'), findsWidgets);
      expect(find.text('Grammatika — qoida'), findsOneWidget);
    });

    testWidgets('ma\'lumotnoma bo\'limlari bor', (t) async {
      await t.pumpWidget(_wrap(BookUnitScreen(unit: unit)));
      await t.pump();

      expect(find.text('So\'z yasalishi'), findsOneWidget);
      expect(find.text('Gap qoliplari'), findsOneWidget);
      expect(find.text('Unit lug\'ati'), findsOneWidget);
    });
  });

  group('BookGroupScreen', () {
    testWidgets('mashqlar va manba kitob belgisi ko\'rinadi', (t) async {
      final g = unit.groupedSections().first;
      await t.pumpWidget(_wrap(BookGroupScreen(group: g)));
      await t.pump();

      expect(find.text('Ex. 5'), findsOneWidget);
      expect(find.text('Ex. 6'), findsOneWidget);
      expect(find.text('Coursebook, 7-bet'), findsOneWidget);
      // O'yin turi belgilari
      expect(find.text('Tanlash'), findsOneWidget);
      expect(find.text('Yig\'ish'), findsOneWidget);
      expect(find.text('Moslash'), findsOneWidget);
      expect(find.text('O\'qish'), findsOneWidget);
    });
  });

  group('ExercisePlayer — tanlash', () {
    testWidgets('savol, variantlar va izoh ko\'rinadi', (t) async {
      final ex = unit.sections.first.exercises[0];
      await t.pumpWidget(_wrap(
          ExercisePlayer(exercise: ex, sectionTitle: 'Lug\'at')));
      await t.pump();

      expect(find.text('orange'), findsOneWidget);
      expect(find.text('Izoh matni'), findsOneWidget);
      expect(find.text('a'), findsOneWidget);
      expect(find.text('an'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('to\'g\'ri javob keyingi savolga o\'tkazadi', (t) async {
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
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('barcha savol tugagach natija ekrani chiqadi', (t) async {
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

      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Bo\'limga qaytish'), findsOneWidget);
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
      expect(find.text('Bo\'limga qaytish'), findsOneWidget);
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
    });
  });

  group('Ma\'lumotnoma ekranlari', () {
    testWidgets('qoida ekrani matn va ogohlantirishni ko\'rsatadi', (t) async {
      await t.pumpWidget(_wrap(RuleScreen(section: unit.sections[1])));
      await t.pump();

      expect(find.text('to be'), findsOneWidget);
      expect(find.text('Qoida tushuntirishi'), findsOneWidget);
      expect(find.text('Ehtiyot bo\'ling'), findsOneWidget);
      expect(find.text('📖 Grammar, 4-bet'), findsOneWidget);
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

      expect(find.text('Yodlashni boshlash (4 so\'z)'), findsOneWidget);
      expect(find.text('farmer'), findsOneWidget);
      expect(find.text('dehqon'), findsOneWidget);
    });
  });
}
