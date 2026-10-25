import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/teach/clarify.dart';

/// Mavhumlikni yo'qotish: T/F, a)/b) va artikl bandlari tushunarli bo'ladi.
void main() {
  ExTask task({
    String prompt = '',
    List<String> options = const [],
    String answer = '',
    bool typed = false,
  }) =>
      ExTask(prompt: prompt, options: options, answer: answer, typed: typed);

  test('T/F tugmalari o\'zbekcha bo\'ladi', () {
    final c = clarify(
      task(
          prompt: 'Omar is twenty-six years old.',
          options: ['T', 'F'],
          answer: 'F'),
      kind: ExKind.choice,
      instructionUz: 'Tinglang va belgilang.',
    );
    expect(c.options, ['To\'g\'ri', 'Noto\'g\'ri']);
    expect(c.answer, 'Noto\'g\'ri');
    expect(c.question, 'Quyidagi gap to\'g\'rimi?');
    expect(c.stem, 'Omar is twenty-six years old.');
  });

  test('savol ichidagi a)/b) variantlari tugmaga chiqadi', () {
    final c = clarify(
      task(
        prompt: '1  a) Susie is going cycling in her free time.   '
            'b) Susie goes cycling in her free time.',
        options: ['a', 'b'],
        answer: 'b',
      ),
      kind: ExKind.choice,
      instructionUz: 'To\'g\'ri gapni belgilang, namunadagidek.',
    );
    expect(c.options.length, 2);
    expect(c.options.first, startsWith('Susie is going'));
    expect(c.answer, 'Susie goes cycling in her free time.');
    // Faqat qator raqamidan iborat bosh ("1") ekranda ko'rsatilmaydi.
    expect(c.stem, '');
    expect(c.question, contains('To\'g\'ri gapni belgilang'));
  });

  test('variant matni topilmasa ham nima qilish aytiladi', () {
    final c = clarify(
      task(prompt: 'Look at the picture.', options: ['a', 'b', 'c'], answer: 'c'),
      kind: ExKind.choice,
      instructionUz: '',
    );
    expect(c.question, isNotEmpty);
    expect(c.hint, isNotEmpty);
    expect(c.options, ['a', 'b', 'c']);
  });

  test('artikl bandida savol va maslahat', () {
    final c = clarify(
      task(prompt: 'artist', options: ['a', 'an'], answer: 'an'),
      kind: ExKind.choice,
    );
    expect(c.question, 'Qaysi so\'z to\'g\'ri: a / an?');
    expect(c.hint, contains('an'));
    // "artikl" atamasi izohlanadi - o'zbek tilida artikl yo'q.
    expect(c.hint, contains('artikl (ot oldidan'));
    expect(c.options, ['a', 'an']);
  });

  test('ko\'rsatma bo\'lmasa tur bo\'yicha savol', () {
    expect(
        clarify(task(prompt: 'cat', options: ['mushuk', 'it'], answer: 'mushuk'),
                kind: ExKind.choice)
            .question,
        'To\'g\'ri javobni tanlang');
    expect(
        clarify(task(prompt: 'mushuk', answer: 'cat', typed: true),
                kind: ExKind.text)
            .question,
        'Javobni klaviaturada yozing');
    expect(
        clarify(task(prompt: 'Men talabaman', answer: 'I am a student'),
                kind: ExKind.text)
            .question,
        'Pastdagi so\'zlarni bosib gap tuzing');
    expect(
        clarify(task(prompt: 'mushuk', answer: 'cat'), kind: ExKind.text)
            .question,
        'Harflarni bosib so\'zni yig\'ing');
  });

  test('kitobga tayangan ko\'rsatmada maslahat bor', () {
    final c = clarify(
      task(prompt: 'Look.', options: ['mushuk', 'it'], answer: 'it'),
      kind: ExKind.choice,
      instructionUz: 'Rasmlarga qarang. Tinglang va belgilang.',
    );
    // Birinchi jumla qisqa - ikkinchisi ham olinadi.
    expect(c.question, 'Rasmlarga qarang. Tinglang va belgilang.');
    expect(c.hint, contains('Kitobingiz bo\'lmasa'));

    // Kitobga tayanmasa - maslahat yo'q.
    final plain = clarify(
      task(prompt: 'cat', options: ['mushuk', 'it'], answer: 'mushuk'),
      kind: ExKind.choice,
      instructionUz: 'Ma\'nosini tanlang.',
    );
    expect(plain.hint, isEmpty);
  });

  test('qator raqami va nuqtalar ekran uchun tozalanadi', () {
    expect(cleanPrompt('1  She had three older sisters.'),
        'She had three older sisters.');
    expect(cleanPrompt('3 B: Yes, ____ do.'), 'B: Yes, ____ do.');
    expect(cleanPrompt('she ............ as a nanny'),
        'she _____ as a nanny');
    // Bitta bo'shliqli raqam (haqiqiy son) o'zgarmaydi.
    expect(cleanPrompt('3 books'), '3 books');
  });

  test('kitob manzili kitobsiz odamga ham tushunarli', () {
    expect(
        friendlyRef('3-unit · Enterprise 1 · Coursebook · 7-bet · Ex. 5'),
        '3-unit (bob) · Enterprise 1 · Coursebook (asosiy darslik) · 7-bet · '
        '5-mashq');
    expect(friendlyRef('Enterprise 2 · Workbook · 9-bet · Ex. muqova'),
        'Enterprise 2 · Workbook (mashq daftari) · 9-bet · Muqova');
    expect(friendlyRef('Enterprise 1 · Grammar · 12-bet'),
        'Enterprise 1 · Grammar (grammatika kitobi) · 12-bet');
    expect(friendlyRef('Grammar 2, 10-bet'),
        'Grammar 2 (grammatika kitobi), 10-bet');
    expect(friendlyRef('Grammar Book, 34-bet, nazariya'),
        'Grammar Book (grammatika kitobi), 34-bet, nazariya');
    // Ikki marta izohlanmaydi.
    for (final s in const [
      '1-unit · Enterprise 1 · Coursebook · 7-bet',
      'Enterprise 1 · Grammar · 12-bet',
      'Grammar Book, 34-bet, nazariya',
      'Grammar 2, 10-bet',
      'Enterprise 2 · Workbook · 9-bet · Ex. muqova',
    ]) {
      final once = friendlyRef(s);
      expect(friendlyRef(once), once, reason: s);
    }
  });

  test('ichki yorliqlar ("12-thereis", "Pf-u3-burjlar") ekranga chiqmaydi', () {
    // Raqamli ref - "N-mashq".
    expect(exerciseRefUz('5'), '5-mashq');
    expect(exerciseRefUz('2a'), '2a-mashq');
    expect(exerciseRefUz('5a-mashq'), '5a-mashq');
    // Raqam + ichki yorliq - faqat raqam.
    expect(exerciseRefUz('12-thereis'), '12-mashq');
    expect(exerciseRefUz('5-davomi'), '5-mashq');
    expect(exerciseRefUz('7a-qolgan'), '7a-mashq');
    // Bir mashqning qismlari va oraliq.
    expect(exerciseRefUz('3-A'), '3-mashq (A)');
    expect(exerciseRefUz('3-4'), '3-4-mashqlar');
    expect(exerciseRefUz('5 (2)'), '5-mashq (2)');
    // Oddiy so'zlar o'zi qoladi.
    expect(exerciseRefUz('muqova'), 'Muqova');
    expect(exerciseRefUz('Nazariya-2'), 'Nazariya 2');
    expect(exerciseRefUz('Past-simple-shakl'), 'Past simple shakl');
    // Tushunarsiz ichki yorliqlar - umumiy "Mashq".
    expect(exerciseRefUz('Pf-u3-burjlar'), 'Mashq');
    expect(exerciseRefUz('Qoida-pp-ps'), 'Mashq');
    expect(exerciseRefUz('Modul1a'), 'Mashq');
    expect(exerciseRefUz('Wl-3'), 'Mashq');
    expect(exerciseRefUz('Wl-Story-3---Episode-1'), 'Mashq');
    expect(exerciseRefUz(''), 'Mashq');
  });

  test('bet yorlig\'idagi kitob nomi ikki marta izohlanmaydi', () {
    const s = 'Kirish qismi · Enterprise 1 · Coursebook · '
        'Coursebook - old muqova · Ex. muqova';
    final once = friendlyRef(s);
    expect(once,
        'Kirish qismi · Enterprise 1 · Coursebook (asosiy darslik) · '
        'Coursebook - old muqova · Muqova');
    expect(friendlyRef(once), once);
  });

  test('sun\'iy (quiz) mashqda kitob manzili yo\'q', () {
    final ex = BookExercise(
        ref: '1', kind: ExKind.text, tasks: const [], book: 'quiz',
        pageLabel: 'xatolar');
    expect(exerciseSource(ex, '3-unit'), '');
    final real = BookExercise(
        ref: '5', kind: ExKind.text, tasks: const [], book: 'coursebook',
        bookPage: 7);
    expect(exerciseSource(real, '3-unit'), contains('Coursebook (asosiy darslik)'));
    expect(exerciseSource(real, '3-unit'), endsWith('5-mashq'));
  });

  test('uzun ko\'rsatma qisqartiriladi', () {
    final long = 'Birinchi jumla shu yerda tugaydi. ${'Juda uzun matn ' * 20}';
    final c = clarify(task(prompt: 'x', options: ['a1', 'b1'], answer: 'a1'),
        kind: ExKind.choice, instructionUz: long);
    expect(c.question, 'Birinchi jumla shu yerda tugaydi.');
  });

  test('splitLabelled', () {
    final r = splitLabelled('2  a) He work.  b) He works.');
    expect(r.stem, '2');
    expect(r.parts['a'], 'He work.');
    expect(r.parts['b'], 'He works.');
    expect(splitLabelled('No labels here').parts, isEmpty);
  });
}
