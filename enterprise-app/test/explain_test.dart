import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_english/teach/explain.dart';

/// Tushuntirish dvigateli: har xil xatoga to'g'ri qoida.
void main() {
  String t(String given, String correct) =>
      explainDiff(given, correct)?.title ?? '';

  test('artikl', () {
    expect(t('a apple', 'an apple'), 'Artikl: a yoki an');
    expect(t('an book', 'a book'), 'Artikl: a yoki an');
    expect(t('a sun is hot', 'the sun is hot'), 'Artikl: the');
  });

  test('to be', () {
    expect(t('he are a doctor', 'he is a doctor'), 'To be shakli');
    expect(t('they is here', 'they are here'), 'To be shakli');
    expect(t('I were there', 'I was there'), 'O\'tgan zamon: was / were');
  });

  test('fe\'l shakli', () {
    expect(t('he work here', 'he works here'), 'Fe\'lga -s');
    expect(t('they works here', 'they work here'), 'Ortiqcha -s');
    expect(t('I work yesterday', 'I worked yesterday'), 'O\'tgan zamon: -ed');
  });

  test('ko\'plik va imlo', () {
    expect(t('two childs', 'two children'), 'Tartibsiz ko\'plik');
    expect(t('I have a bok', 'I have a book'), 'Imlo');
  });

  test('predlog, olmosh, tartib', () {
    expect(t('I live at Tashkent', 'I live in Tashkent'), 'Predlog');
    expect(t('this is she book', 'this is her book'), 'Olmosh');
    expect(t('books read I', 'I read books'), 'So\'z tartibi');
  });

  test('so\'z soni', () {
    expect(t('I student', 'I am a student'), 'So\'z tushib qolgan');
    expect(t('I am a a student', 'I am a student'), 'Ortiqcha artikl');
  });

  test('bir xil javobga izoh yo\'q', () {
    expect(explainDiff('I am a student', 'I am a student.'), isNull);
    expect(explainDiff('', 'book'), isNull);
  });

  test('tarjima', () {
    // Banddagi tayyor tarjima.
    final withUz = explainAnswer(
        correct: 'an apple', given: 'a apple', uz: 'bitta olma');
    expect(withUz.first.source, 'tr');
    expect(withUz.first.text, contains('bitta olma'));

    // Lug'atdan so'zma-so'z (tarjima bo'lmaganda).
    const dict = {'book': 'kitob', 'read': "o'qimoq"};
    final looked = explainAnswer(
      correct: 'read a book',
      given: 'read a books',
      lookup: (w) => dict[w] ?? '',
    );
    expect(looked.first.source, 'tr');
    expect(looked.first.text, contains('kitob'));
    expect(looked.first.text, contains("o'qimoq"));

    // To'g'ri javobda ham tarjima chiqadi (ma'no mustahkamlanadi).
    final ok = explainAnswer(
        correct: 'an apple', given: 'an apple', isCorrect: true, uz: 'olma');
    expect(ok.single.source, 'tr');

    // Tarjima o'zi bilan bir xil bo'lsa - takrorlanmaydi.
    expect(translationOf('book', uz: 'book'), isNull);
    expect(translationOf('', uz: 'kitob'), isNull);
  });

  test('explainAnswer manbalar tartibi', () {
    final withBook = explainAnswer(
        correct: 'an apple', given: 'a apple', whyUz: 'Unli oldidan an.');
    // Tarjima birinchi (ma'no), keyin kitob izohi, keyin qoida.
    expect(withBook.map((e) => e.source), containsAll(['book', 'diff']));
    expect(withBook.first.source, 'tr');

    final onlyRule = explainAnswer(
        correct: 'zzz', given: 'zzz', isCorrect: true,
        ruleUz: 'Artikllar haqida qoida.');
    expect(onlyRule.single.source, 'rule');

    // Hech narsa bo'lmasa ham o'quvchi javobsiz qolmaydi.
    final fallback = explainAnswer(correct: 'Good morning', given: 'Hello');
    expect(fallback, isNotEmpty);
  });
}
