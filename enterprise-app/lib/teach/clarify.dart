import '../book_content.dart';

/// MAVHUMLIKNI YO'QOTISH — har bir savol o'zini o'zi tushuntirsin.
///
/// Muammo (ustoz bilan sinovda ko'rilgan): ilova inglizcha so'z va "a",
/// "b", "T", "F" kabi tugmalarni ko'rsatardi — kitob qo'lida bo'lmagan
/// odam nima so'ralayotganini umuman tushunmasdi. Sabab: kitobda savol
/// RASMDA yoki "namunadagidek" ko'rsatmada turadi, eksportda esa faqat
/// band matni qolgan.
///
/// Bu yerda har band TOZALANADI:
///  * "a) ... b) ..." savol ichidan variantlar AJRATILADI (tugmada to'liq
///    gap turadi, quruq harf emas);
///  * T / F → "To'g'ri" / "Noto'g'ri";
///  * har bandga o'zbekcha SAVOL qatori qo'shiladi ("Nima so'ralyapti").
class ClearTask {
  /// O'zbekcha savol — nima qilish kerakligi (har doim to'ladi).
  final String question;

  /// Ko'rsatiladigan inglizcha matn (variantlar ajratilgandan keyin).
  final String stem;

  /// To'liq variantlar (quruq harf emas).
  final List<String> options;

  /// To'g'ri javob (variantlar ichidagi to'liq matn).
  final String answer;

  /// Qo'shimcha eslatma (masalan "T = to'g'ri, F = noto'g'ri").
  final String hint;

  const ClearTask({
    required this.question,
    required this.stem,
    required this.options,
    required this.answer,
    this.hint = '',
  });
}

/// Ko'rsatmadan o'zbekcha savol yasaydi (birinchi jumla, qisqartirilgan).
String _fromInstruction(String instructionUz) {
  var s = instructionUz.trim();
  if (s.isEmpty) return '';
  // Kitobga havolalarni olib tashlaymiz: "namunadagidek", "1-5 gaplarni".
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  final dot = s.indexOf(RegExp(r'[.!?]'));
  if (dot > 12) s = s.substring(0, dot + 1);
  if (s.length > 120) s = '${s.substring(0, 117)}...';
  return s;
}

/// Band turiga qarab standart savol.
String _byKind(ExKind kind, ExTask t) {
  if (t.typed) return 'Javobni yozing';
  return switch (kind) {
    ExKind.choice => 'To\'g\'ri javobni tanlang',
    ExKind.match => 'Juftlarni moslang',
    ExKind.text =>
      t.answer.trim().contains(' ') ? 'So\'zlardan gap tuzing' : 'So\'zni yig\'ing',
    ExKind.study => 'O\'qing va eslab qoling',
  };
}

/// "1  a) Susie is going... b) Susie goes..." ni bo'laklarga ajratadi.
///
/// Qaytadi: (savol boshi, {harf: matn}). Topilmasa - bo'sh xarita.
({String stem, Map<String, String> parts}) splitLabelled(String prompt) {
  final re = RegExp(r'([a-dA-D])\)\s*');
  final matches = re.allMatches(prompt).toList();
  if (matches.length < 2) return (stem: prompt, parts: const {});
  final stem = prompt.substring(0, matches.first.start).trim();
  final parts = <String, String>{};
  for (var i = 0; i < matches.length; i++) {
    final key = matches[i].group(1)!.toLowerCase();
    final from = matches[i].end;
    final to = i + 1 < matches.length ? matches[i + 1].start : prompt.length;
    final text = prompt.substring(from, to).trim();
    if (text.isNotEmpty) parts[key] = text;
  }
  return (stem: stem, parts: parts);
}

bool _isTrueFalse(List<String> options) =>
    options.length == 2 &&
    options.every((o) {
      final s = o.trim().toUpperCase();
      return s == 'T' || s == 'F' || s == 'TRUE' || s == 'FALSE';
    });

bool _isArticles(List<String> options) =>
    options.isNotEmpty &&
    options.every((o) => const {'a', 'an', 'the', '-'}
        .contains(o.trim().toLowerCase()));

/// Variantlar QURUQ harflarmi (a / b / c) — matn emas.
bool _isBareLetters(List<String> options) =>
    options.length >= 2 &&
    options.every((o) => RegExp(r'^[a-dA-D]$').hasMatch(o.trim()));

/// Bandni tushunarli holga keltiradi.
ClearTask clarify(
  ExTask t, {
  required ExKind kind,
  String instructionUz = '',
}) {
  final options = t.options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final prompt = t.prompt.trim();

  // 1) T / F — tugmada o'zbekcha yozuv turadi.
  if (_isTrueFalse(options)) {
    String uz(String o) =>
        o.trim().toUpperCase().startsWith('T') ? 'To\'g\'ri' : 'Noto\'g\'ri';
    return ClearTask(
      question: 'Quyidagi gap to\'g\'rimi?',
      stem: prompt,
      options: options.map(uz).toList(),
      answer: uz(t.answer),
      hint: 'Matnga ko\'ra: to\'g\'ri bo\'lsa "To\'g\'ri", noto\'g\'ri bo\'lsa '
          '"Noto\'g\'ri" ni tanlang.',
    );
  }

  // 2) Savol ichidagi a) / b) variantlari - tugmaga to'liq gap chiqadi.
  if (_isBareLetters(options)) {
    final split = splitLabelled(prompt);
    final full = [
      for (final o in options)
        split.parts[o.toLowerCase()] ?? o,
    ];
    final answerFull =
        split.parts[t.answer.trim().toLowerCase()] ?? t.answer.trim();
    if (split.parts.length >= 2) {
      return ClearTask(
        question: _fromInstruction(instructionUz).isNotEmpty
            ? _fromInstruction(instructionUz)
            : 'Qaysi variant to\'g\'ri?',
        stem: split.stem,
        options: full,
        answer: answerFull,
      );
    }
    // Variantlar matni topilmadi (kitobdagi rasmga havola) - hech bo'lmasa
    // nima qilish kerakligi aytiladi.
    return ClearTask(
      question: _fromInstruction(instructionUz).isNotEmpty
          ? _fromInstruction(instructionUz)
          : 'Kitobdagi variantlardan mosini tanlang',
      stem: prompt,
      options: options,
      answer: t.answer.trim(),
      hint: 'Bu band kitobdagi rasm/ro\'yxatga tegishli.',
    );
  }

  // 3) Artikl tanlash - savol aniq aytiladi.
  if (_isArticles(options)) {
    return ClearTask(
      question: 'Qaysi artikl to\'g\'ri?',
      stem: prompt,
      options: options,
      answer: t.answer.trim(),
      hint: 'Unli tovush oldidan "an", undosh oldidan "a"; aniq narsaga "the".',
    );
  }

  // 4) Odatiy hol - savol ko'rsatmadan yoki tur bo'yicha.
  final q = _fromInstruction(instructionUz);
  return ClearTask(
    question: q.isNotEmpty ? q : _byKind(kind, t),
    stem: prompt,
    options: options,
    answer: t.answer.trim(),
  );
}
