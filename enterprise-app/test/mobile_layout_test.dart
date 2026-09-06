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

/// Ilova asosan TELEFONDA ishlatiladi. Bu yerda har bir asosiy ekran
/// 375x812 (iPhone) va 320x640 (eng tor android) o'lchamida chiziladi va
/// hech qaysisida "RenderFlex overflowed" chizig'i chiqmasligi tekshiriladi.
///
/// Qobiqning yuqori panelida aynan shunday xato bor edi (47 piksel), uni
/// faqat brauzerda ochib ko'rgandagina sezish mumkin edi.
const _unitJson = '''
{
 "unit": 1,
 "title": "Hi! — juda uzun sarlavha, tor ekranda sinovdan o'tsin",
 "module": 1,
 "sections": [
  {
   "id": "s1", "kind": "vocabulary", "title": "Vocabulary", "titleUz": "Lug'at",
   "book": "coursebook", "bookPage": 7,
   "rule": {
     "titleUz": "Qoida",
     "explanationUz": "Izoh.\\n  ┌──────────────┬──────────────────────┐\\n  │ Name:        │ Diana Frances        │\\n  └──────────────┴──────────────────────┘",
     "table": [
       {"subject": "I", "full": "I am", "short": "I'm",
        "negLong": "I am not", "negShort": "I'm not",
        "interrogative": "Am I ...?"}
     ],
     "rules": [
       {"uzRule": "Qoida matni", "enRule": "Rule text",
        "examples": ["a teacher", "an actor"],
        "examplesUz": ["o'qituvchi", "aktyor"]}
     ],
     "noteEn": "We always write I with a capital letter.",
     "listEn": ["I", "you", "he", "she", "it", "we", "you", "they"]
   },
   "exercises": [
    {"ref": "5", "kind": "choice", "instructionUz": "Ma'nosini tanlang.",
     "explanationUz": "Izoh matni", "audio": false,
     "book": "coursebook", "bookPage": 7,
     "tasks": [
      {"prompt": "orange", "answer": "an", "options": ["a", "an"], "whyUz": "o — unli"}
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
  }
 ],
 "wordFormation": [
   {"ruleUz": "Qoida", "explanationUz": "Izoh",
    "items": [{"base": "act", "baseUz": "harakat", "derived": "actor",
               "derivedUz": "aktyor", "note": "-or"}]}
 ],
 "sentencePatterns": [
   {"formula": "I'm a + KASB", "exampleEn": "I'm a doctor.",
    "exampleUz": "Men shifokorman.", "explanationUz": "Izoh"}
 ],
 "vocabulary": [
  {"en": "farmer", "uz": "dehqon"},
  {"en": "doctor", "uz": "shifokor"}
 ]
}
''';

/// Testlar ro'yxati main() ning O'ZIDA tuziladi, shuning uchun unit
/// setUpAll dan oldin — modul darajasida — tayyorlanadi.
final BookUnit unit =
    BookUnit.fromJson(json.decode(_unitJson) as Map<String, dynamic>);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    await app.progress.load();
  });

  /// Ekranni berilgan o'lchamda chizadi va overflow bo'lmaganini tekshiradi.
  Future<void> expectFits(WidgetTester t, Widget screen, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: screen));
    await t.pump();
    expect(t.takeException(), isNull);
  }

  const phone = Size(375, 812);
  const narrow = Size(320, 640);

  final screens = <String, Widget Function()>{
    'unit ekrani': () => BookUnitScreen(unit: unit),
    'betlar ro\'yxati': () => BookPagesScreen(unit: unit),
    'bet ekrani': () => BookPageScreen(page: unit.pages().first),
    'qoida ekrani': () => RuleScreen(section: unit.sections.first),
    'so\'z yasalishi': () => WordFormationScreen(unit: unit),
    'gap qoliplari': () => SentencePatternsScreen(unit: unit),
    'lug\'at ekrani': () => UnitVocabularyScreen(unit: unit),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} — 375px', (t) async {
      await expectFits(t, entry.value(), phone);
    });
    testWidgets('${entry.key} — 320px', (t) async {
      await expectFits(t, entry.value(), narrow);
    });
  }

  for (final ex in unit.sections.first.exercises) {
    testWidgets('mashq (${ex.kind}) — 375px', (t) async {
      await expectFits(
          t, ExercisePlayer(exercise: ex, sectionTitle: 'Lug\'at'), phone);
    });
    testWidgets('mashq (${ex.kind}) — 320px', (t) async {
      await expectFits(
          t, ExercisePlayer(exercise: ex, sectionTitle: 'Lug\'at'), narrow);
    });
  }

  _sectionStyleTests();
}

/// Har bir bo'lim turi o'z belgisiga ega bo'lishi kerak. Ilgari eksportdagi
/// 24 turdan faqat 13 tasi sanalgan edi va qolgan 160 ta bo'lim ma'nosiz
/// kulrang doira belgisini olardi.
void _sectionStyleTests() {
  const kinds = [
    'lead_in', 'vocabulary', 'reading', 'grammar_theory', 'grammar',
    'grammar_exercise', 'language_development', 'practice', 'pronunciation',
    'listening', 'video', 'speaking', 'communication', 'game', 'quiz',
    'culture', 'writing', 'story', 'reference', 'module_cover', 'revision',
    'test', 'words_of_wisdom', 'wisdom',
  ];

  testWidgets('barcha bo\'lim turlari o\'z belgisiga ega', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    for (final k in kinds) {
      expect(sectionStyle(ctx, k).icon, isNot(Icons.circle_outlined),
          reason: '$k turi uchun belgi yo\'q');
    }
  });
}
