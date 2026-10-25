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

/// "Ex. 5" / "Ex. muqova" o'rniga o'zbekcha nom: "5-mashq" / "Muqova".
///
/// Kitobsiz o'quvchi "Ex." ni tushunmaydi. Raqamli ref ("5", "2a") -
/// "5-mashq"; boshqa ref ("muqova", "Nazariya-1", "WoW") - o'zi, bosh
/// harf bilan.
///
/// Ma'lumotdagi ba'zi "ref" lar kitobda yozilmagan ICHKI yorliqlar
/// ("12-thereis", "Pf-u3-burjlar", "Modul1a"): kitobsiz o'quvchi ularni
/// tushunmaydi, shuning uchun raqamli qismi qoldirilib ("12-mashq"),
/// tushunarsizlari esa umumiy "Mashq" deb ko'rsatiladi.
String exerciseRefUz(String ref) {
  final r = ref.trim();
  if (r.isEmpty) return 'Mashq';
  String cap(String s) => s[0].toUpperCase() + s.substring(1);
  // "5", "2a"
  if (RegExp(r'^\d+[a-zA-Z]?$').hasMatch(r)) return '$r-mashq';
  // "5a-mashq" - allaqachon o'zbekcha.
  if (RegExp(r'^\d+[a-zA-Z]?-mashq$').hasMatch(r)) return r;
  // "3-A", "3-B": bitta mashqning qismlari.
  var m = RegExp(r'^(\d+[a-zA-Z]?)-([A-Za-z])$').firstMatch(r);
  if (m != null) return '${m[1]}-mashq (${m[2]!.toUpperCase()})';
  // "3-4": ketma-ket mashqlar.
  if (RegExp(r'^\d+[a-zA-Z]?-\d+[a-zA-Z]?$').hasMatch(r)) return '$r-mashqlar';
  // "12-thereis", "5-davomi", "13-qaydlar": raqam + ichki yorliq.
  m = RegExp(r"^(\d+[a-zA-Z]?)-[A-Za-z][A-Za-z'-]*$").firstMatch(r);
  if (m != null) return '${m[1]}-mashq';
  // "5 (2)", "12 (3-4)".
  m = RegExp(r'^(\d+[a-zA-Z]?)\s*(\(.*\))$').firstMatch(r);
  if (m != null) return '${m[1]}-mashq ${m[2]}';
  // "Nazariya-1" -> "Nazariya 1".
  m = RegExp(r"^([A-Za-z']{4,})-(\d+)$").firstMatch(r);
  if (m != null) return '${cap(m[1]!)} ${m[2]}';
  // "Past-simple-shakl" -> "Past simple shakl" (har bo'lak 3+ harfli so'z);
  // "Qoida-pp-ps", "Wl-Story-3---Episode-1" kabilar - ichki yorliq.
  if (r.contains('-')) {
    final parts = r.split('-');
    final words = parts.every((p) => RegExp(r"^[A-Za-z']{3,}$").hasMatch(p));
    return words ? cap(parts.join(' ')) : 'Mashq';
  }
  // "Modul1a", "Mundarija2": harf+raqam aralash - ichki yorliq.
  if (RegExp(r'\d').hasMatch(r)) return 'Mashq';
  return cap(r);
}

/// Kitob manzilini kitobsiz odamga ham tushunarli qiladi:
/// "3-unit · Enterprise 1 · Coursebook · 7-bet · Ex. 5" ->
/// "3-unit (bob) · Enterprise 1 · Coursebook (asosiy darslik) · 7-bet ·
/// 5-mashq".
///
/// IDEMPOTENT: allaqachon izohlangan matnga qayta tegmaydi (kitob
/// nomlari `book_content.dart` da o'zgarsa ham ikki marta izoh chiqmaydi).
String friendlyRef(String s) {
  if (s.isEmpty) return s;
  var r = s;
  r = r.replaceAllMapped(
    RegExp(r'Ex\.\s*([^·]*?)\s*(?=·|$)'),
    (m) => exerciseRefUz(m[1] ?? ''),
  );
  // Faqat BIRINCHI marta izohlanadi: bet yorlig'ida kitob nomi yana
  // uchrashi mumkin ("Coursebook - old muqova"), uni qayta izohlash
  // "Coursebook (asosiy darslik) · Coursebook (asosiy darslik) - ..."
  // kabi takror beradi. Izohlangan matnga qayta tegilmaydi.
  if (!r.contains('Coursebook (asosiy darslik)')) {
    r = r.replaceFirstMapped(RegExp(r'\bCoursebook\b'),
        (_) => 'Coursebook (asosiy darslik)');
  }
  if (!r.contains('Workbook (mashq daftari)')) {
    r = r.replaceFirstMapped(
        RegExp(r'\bWorkbook\b'), (_) => 'Workbook (mashq daftari)');
  }
  // "Grammar", "Grammar 2", "Grammar Book" - izoh nomning oxiriga.
  if (!r.contains('(grammatika kitobi)')) {
    r = r.replaceFirstMapped(
        RegExp(r'\bGrammar(?: Book|\s+\d+)?(?! Book)(?![A-Za-z])'),
        (m) => '${m[0]} (grammatika kitobi)');
  }
  r = r.replaceAllMapped(
      RegExp(r'(\d+)-unit\b(?! \()'), (m) => '${m[1]}-unit (bob)');
  return r;
}

/// Mashqning "Kitobda: ..." manzili (QuestionCard va sarlavha uchun).
///
/// Ilovaning o'zi yasagan mashqlarda (Diktant, grammatika testi, xatolar
/// daftari, rol o'ynash: `book == 'quiz'`) kitobda manzil YO'Q - bo'sh
/// qaytadi, aks holda "Test · xatolar · Ex. 1" kabi ma'nosiz qator chiqadi.
String exerciseSource(BookExercise ex, String unitLabel) {
  if (ex.book == 'quiz') return '';
  var loc = unitLabel.isNotEmpty
      ? ex.locationLabel(unitLabel)
      : ex.locationLabel('');
  if (loc.startsWith(' · ')) loc = loc.substring(3);
  return friendlyRef(loc);
}

/// Savol matnini ko'rsatish uchun tozalaydi (javob solishtirishga
/// TEGMAYDI - faqat ekran uchun).
///
///  * kitobdagi qator raqami ("1  She had...", "3 B: ...") olib tashlanadi;
///  * 4 va undan ko'p nuqta ("............") bo'sh joy belgisi "_____" ga.
String cleanPrompt(String s) {
  var r = s.trim();
  r = r.replaceFirst(RegExp(r'^\d{1,3}\s{2,}(?=\S)'), '');
  r = r.replaceFirst(RegExp(r'^\d{1,3}\s+(?=[A-Z]:)'), '');
  r = r.replaceAll(RegExp(r'\.{4,}'), '_____');
  return r;
}

/// Ko'rsatma rasm / audio / jadval / namunaga tayanadimi - kitobsiz
/// o'quvchi uchun shu haqda ogohlantirish kerak.
bool leansOnBook(String instructionUz) => RegExp(
        r'rasm|namuna|kitob|jadval|tingla|eshit|audio|diagramma|xarita',
        caseSensitive: false)
    .hasMatch(instructionUz);

/// Kitobga tayanadigan mashq uchun qisqa maslahat (kitobi yo'q odam
/// nima qilishini bilsin).
String bookNote(ExKind kind) => switch (kind) {
      ExKind.choice || ExKind.text =>
        'Bu savol kitobdagi rasm yoki audioga tayanishi mumkin. Kitobingiz '
            'bo\'lmasa, gapni o\'qib o\'zingiz hal qiling yoki "Bilmayman" ni '
            'bosing.',
      ExKind.match =>
        'Bu mashq kitobdagi rasmga tayanishi mumkin. Rasm bo\'lmasa, '
            'so\'zlarning ma\'nosiga qarab moslang.',
      ExKind.study => '',
    };

/// Ko'rsatmadan o'zbekcha savol yasaydi (birinchi jumla, qisqartirilgan).
///
/// Birinchi jumla juda qisqa bo'lsa ("Rasmlarga qarang."), ikkinchisi ham
/// qo'shiladi - aks holda kartada ma'nosiz bo'lak qoladi.
String _fromInstruction(String instructionUz) {
  var s = instructionUz.trim();
  if (s.isEmpty) return '';
  // Kitobga havolalarni olib tashlaymiz: "namunadagidek", "1-5 gaplarni".
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  final dot = s.indexOf(RegExp(r'[.!?]'));
  if (dot > 12) {
    var end = dot + 1;
    if (end < 40) {
      // Keyingi jumla ham tugallangan bo'lsa va sig'sa - qo'shamiz.
      final rest = s.substring(end);
      final next = rest.indexOf(RegExp(r'[.!?]'));
      if (next > 0 && end + next + 1 <= 120) end = end + next + 1;
    }
    s = s.substring(0, end).trim();
  }
  if (s.length > 120) s = '${s.substring(0, 117)}...';
  return s;
}

/// Band turiga qarab standart savol.
String _byKind(ExKind kind, ExTask t) {
  if (t.typed) return 'Javobni klaviaturada yozing';
  return switch (kind) {
    ExKind.choice => 'To\'g\'ri javobni tanlang',
    ExKind.match => 'Chap va o\'ng ustundagi mos so\'zlarni juftlang',
    ExKind.text => t.answer.trim().contains(' ')
        ? 'Pastdagi so\'zlarni bosib gap tuzing'
        : 'Harflarni bosib so\'zni yig\'ing',
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
  final shown = cleanPrompt(prompt);
  final note = leansOnBook(instructionUz) ? bookNote(kind) : '';
  String join(String a, String b) =>
      [a, b].where((e) => e.isNotEmpty).join(' ');

  // 1) T / F — tugmada o'zbekcha yozuv turadi.
  if (_isTrueFalse(options)) {
    String uz(String o) =>
        o.trim().toUpperCase().startsWith('T') ? 'To\'g\'ri' : 'Noto\'g\'ri';
    return ClearTask(
      question: 'Quyidagi gap to\'g\'rimi?',
      stem: shown,
      options: options.map(uz).toList(),
      answer: uz(t.answer),
      hint: join(
        'Gap rost bo\'lsa "To\'g\'ri", xato bo\'lsa "Noto\'g\'ri" ni tanlang.',
        'Savol kitobdagi matn yoki audioga tayansa, bilmasangiz "Bilmayman" '
            'ni bosing.',
      ),
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
      // Faqat qator raqamidan iborat bosh ("1") - ma'nosiz, ko'rsatilmaydi.
      final stem = cleanPrompt(split.stem);
      return ClearTask(
        question: _fromInstruction(instructionUz).isNotEmpty
            ? _fromInstruction(instructionUz)
            : 'Qaysi variant to\'g\'ri?',
        stem: RegExp(r'^\d{1,3}$').hasMatch(stem) ? '' : stem,
        options: full,
        answer: answerFull,
        hint: note,
      );
    }
    // Variantlar matni topilmadi (kitobdagi rasmga havola) - hech bo'lmasa
    // nima qilish kerakligi aytiladi.
    return ClearTask(
      question: _fromInstruction(instructionUz).isNotEmpty
          ? _fromInstruction(instructionUz)
          : 'Kitobdagi rasm/kartalardan mos harfni tanlang',
      stem: shown,
      options: options,
      answer: t.answer.trim(),
      hint: 'Bu savol kitobdagi rasmga tayanadi. Kitobingiz bo\'lmasa '
          '"Bilmayman" ni bosing - javob ko\'rsatiladi va savol keyin qaytadi.',
    );
  }

  // 3) Artikl tanlash - savol aniq aytiladi.
  if (_isArticles(options)) {
    final opts = options.map((o) => o == '-' ? '(hech narsa)' : o).join(' / ');
    return ClearTask(
      question: 'Qaysi so\'z to\'g\'ri: $opts?',
      stem: shown,
      options: options,
      answer: t.answer.trim(),
      hint: join(
        'Bu - artikl (ot oldidan keladigan kichik so\'z: a, an, the). '
            'Unli tovush oldidan "an", undosh oldidan "a"; aniq narsaga "the".',
        note,
      ),
    );
  }

  // 4) Odatiy hol - savol ko'rsatmadan yoki tur bo'yicha.
  final q = _fromInstruction(instructionUz);
  return ClearTask(
    question: q.isNotEmpty ? q : _byKind(kind, t),
    stem: shown,
    options: options,
    answer: t.answer.trim(),
    hint: note,
  );
}
