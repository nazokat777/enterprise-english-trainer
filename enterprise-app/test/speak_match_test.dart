import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_english/speak/speak_match.dart';

/// Talaffuz tekshiruvi: nutq tanish natijasi kutilgan so'zga mosmi.
void main() {
  test('aniq va katta-kichik harf / tinish farqi', () {
    expect(speechMatches('Cat', 'cat'), isTrue);
    expect(speechMatches('good morning.', 'Good morning'), isTrue);
    expect(speechMatches("I'm fine", "I'm fine"), isTrue);
  });

  test('ortiqcha so\'z (artikl) ichida bo\'lsa ham to\'g\'ri', () {
    expect(speechMatches('a computer', 'computer'), isTrue);
    expect(speechMatches('the good morning everyone', 'good morning'), isTrue);
  });

  test('bitta harf farqi uzun so\'zda kechiriladi, qisqada yo\'q', () {
    expect(speechMatches('colour', 'color'), isTrue);
    expect(speechMatches('teacher', 'teachers'), isTrue);
    expect(speechMatches('cut', 'cat'), isFalse);
    expect(speechMatches('dog', 'dot'), isFalse);
  });

  test('boshqa so\'z / bo\'sh - xato', () {
    expect(speechMatches('mouse', 'horse'), isFalse);
    expect(speechMatches('', 'cat'), isFalse);
    expect(speechMatches('banana', 'apple'), isFalse);
  });
}
