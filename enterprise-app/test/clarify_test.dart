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
    expect(c.stem, '1');
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
    expect(c.question, 'Qaysi artikl to\'g\'ri?');
    expect(c.hint, contains('an'));
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
        'Javobni yozing');
    expect(
        clarify(task(prompt: 'Men talabaman', answer: 'I am a student'),
                kind: ExKind.text)
            .question,
        'So\'zlardan gap tuzing');
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
