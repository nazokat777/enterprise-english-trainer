import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_english/book_content.dart';

/// Eksport skripti chiqaradigan shakldagi namuna.
const _sample = '''
{
 "unit": 1,
 "title": "Hi!",
 "module": 1,
 "sections": [
  {
   "id": "u1-cb-6-0",
   "kind": "lead_in",
   "title": "Lead-in",
   "titleUz": "Kirish",
   "book": "coursebook",
   "bookPage": 6,
   "exercises": [
    {
     "ref": "1",
     "kind": "choice",
     "instructionEn": "Look at the pictures.",
     "instructionUz": "Rasmlarga qarang.",
     "explanationUz": "Izoh",
     "audio": false,
     "book": "coursebook",
     "bookPage": 6,
     "tasks": [
      {"prompt": "Rasm A", "answer": "Brazil", "promptUz": "Braziliya",
       "options": ["Spain", "Brazil"], "whyUz": "sabab"}
     ]
    },
    {
     "ref": "2",
     "kind": "text",
     "instructionEn": "Write.",
     "instructionUz": "Yozing.",
     "audio": true,
     "book": "coursebook",
     "bookPage": 6,
     "tasks": [
      {"prompt": "13", "answer": "thirteen", "alt": ["thirteen "]}
     ]
    },
    {
     "ref": "3",
     "kind": "match",
     "instructionUz": "Moslang.",
     "book": "coursebook",
     "bookPage": 6,
     "tasks": [
      {"left": "one", "right": "first"},
      {"left": "two", "right": "second"}
     ]
    },
    {
     "ref": "4",
     "kind": "study",
     "instructionUz": "O'qing.",
     "book": "coursebook",
     "bookPage": 6,
     "tasks": [
      {"en": "I am from Spain.", "uz": "Men Ispaniyadanman.", "note": "izoh"}
     ]
    }
   ]
  },
  {
   "id": "u1-gr-4-1",
   "kind": "grammar_theory",
   "titleUz": "Qoida",
   "book": "grammar",
   "bookPage": 4,
   "exercises": [],
   "rule": {"explanationUz": "Qoida matni"}
  }
 ],
 "wordFormation": [
  {"ruleUz": "-er qo'shimchasi", "explanationUz": "izoh",
   "items": [{"base": "farm", "derived": "farmer", "derivedUz": "dehqon", "note": "farm + er"}],
   "book": "coursebook", "bookPage": 6}
 ],
 "sentencePatterns": [
  {"formula": "I'm a + KASB", "exampleEn": "I'm a doctor.", "exampleUz": "Men shifokorman.",
   "explanationUz": "izoh", "book": "coursebook", "bookPage": 6}
 ],
 "vocabulary": [
  {"en": "farmer", "uz": "dehqon"},
  {"en": "doctor", "uz": "shifokor"}
 ]
}
''';

void main() {
  final unit = BookUnit.fromJson(
      json.decode(_sample) as Map<String, dynamic>);

  group('BookUnit', () {
    test('asosiy maydonlar o\'qiladi', () {
      expect(unit.unit, 1);
      expect(unit.title, 'Hi!');
      expect(unit.module, 1);
      expect(unit.sections.length, 2);
      expect(unit.vocabulary.length, 2);
      expect(unit.wordFormation.length, 1);
      expect(unit.sentencePatterns.length, 1);
    });

    test('mashqlar soni to\'g\'ri hisoblanadi', () {
      expect(unit.exerciseCount, 4);
    });

    test('javob talab qiladigan bandlar sanaladi (study kirmaydi)', () {
      // choice 1 + text 1 + match 2 = 4; study sanalmaydi.
      expect(unit.answerableCount, 4);
    });

    test('bo\'limlar turi bo\'yicha guruhlanadi', () {
      final groups = unit.groupedSections();
      expect(groups.length, 2);
      expect(groups.first.kind, 'lead_in');
      expect(groups.first.titleUz, 'Kirish');
    });
  });

  group('BookSection', () {
    test('qoidali bo\'limda rule bor, mashq yo\'q', () {
      final s = unit.sections[1];
      expect(s.kind, 'grammar_theory');
      expect(s.rule, isNotNull);
      expect(s.exercises, isEmpty);
      expect(s.hasRule, isTrue);
    });

    test('manba kitob va bet saqlanadi', () {
      expect(unit.sections.first.book, 'coursebook');
      expect(unit.sections.first.bookPage, 6);
      expect(unit.sections.first.sourceLabel, 'Coursebook, 6-bet');
    });
  });

  group('BookExercise', () {
    final ex = unit.sections.first.exercises;

    test('4 xil o\'yin turi to\'g\'ri o\'qiladi', () {
      expect(ex[0].kind, ExKind.choice);
      expect(ex[1].kind, ExKind.text);
      expect(ex[2].kind, ExKind.match);
      expect(ex[3].kind, ExKind.study);
    });

    test('audio bayrog\'i o\'qiladi', () {
      expect(ex[0].audio, isFalse);
      expect(ex[1].audio, isTrue);
    });

    test('study mashqi javob talab qilmaydi', () {
      expect(ex[3].isAnswerable, isFalse);
      expect(ex[0].isAnswerable, isTrue);
    });

    test('noma\'lum kind study ga tushadi (kontent yo\'qolmaydi)', () {
      final e = BookExercise.fromJson({
        'ref': 'x',
        'kind': 'allaqachon-yo-q-tur',
        'tasks': [
          {'en': 'text'}
        ],
      });
      expect(e.kind, ExKind.study);
    });
  });

  group('ExTask', () {
    test('choice bandi variantlari bilan o\'qiladi', () {
      final t = unit.sections.first.exercises[0].tasks.first;
      expect(t.prompt, 'Rasm A');
      expect(t.answer, 'Brazil');
      expect(t.promptUz, 'Braziliya');
      expect(t.options, ['Spain', 'Brazil']);
      expect(t.whyUz, 'sabab');
    });

    test('javob tekshiruvi bo\'sh joy va katta-kichik harfga befarq', () {
      final t = unit.sections.first.exercises[1].tasks.first;
      expect(t.isCorrect('thirteen'), isTrue);
      expect(t.isCorrect('  THIRTEEN '), isTrue);
      expect(t.isCorrect('thirty'), isFalse);
    });

    test('muqobil javob ham qabul qilinadi', () {
      final t = ExTask.fromJson({
        'prompt': 'p',
        'answer': 'We are not Portuguese.',
        'alt': ['We aren\'t Portuguese.'],
      });
      expect(t.isCorrect('We aren\'t Portuguese.'), isTrue);
      expect(t.isCorrect('We are not Portuguese.'), isTrue);
    });

    test('tinish belgilari javobga xalaqit bermaydi', () {
      final t = ExTask.fromJson({'prompt': 'p', 'answer': 'She is from Budapest.'});
      expect(t.isCorrect('She is from Budapest'), isTrue,
          reason: 'nuqta qo\'yilmasa ham to\'g\'ri');
    });

    test('match bandi left/right o\'qiydi', () {
      final t = unit.sections.first.exercises[2].tasks;
      expect(t[0].left, 'one');
      expect(t[0].right, 'first');
      expect(t.length, 2);
    });

    test('study bandi en/uz o\'qiydi', () {
      final t = unit.sections.first.exercises[3].tasks.first;
      expect(t.en, 'I am from Spain.');
      expect(t.uz, 'Men Ispaniyadanman.');
      expect(t.note, 'izoh');
    });

    test('yig\'ish uchun bo\'laklar: ibora -> so\'zlar, so\'z -> harflar', () {
      final phrase = ExTask.fromJson({'prompt': 'p', 'answer': 'I am here'});
      expect(phrase.buildPieces, ['I', 'am', 'here']);
      expect(phrase.buildSeparator, ' ');

      final word = ExTask.fromJson({'prompt': 'p', 'answer': 'cat'});
      expect(word.buildPieces, ['c', 'a', 't']);
      expect(word.buildSeparator, '');
    });
  });
}
