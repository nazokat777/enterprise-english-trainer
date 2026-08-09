import 'dart:convert';

import 'package:flutter/services.dart';

/// Mashqning o'yin turi. Kitobdagi 43 xil mashq shu 4 taga siqilgan
/// (normalizatsiya `ingest/export_pages.py` da bajariladi).
enum ExKind {
  /// Variantlardan birini tanlash.
  choice,

  /// Javobni harf yoki so'z bo'laklaridan yig'ish.
  text,

  /// Ikki ustunni juftlash.
  match,

  /// Javobsiz: qoida, dialog, namuna — faqat o'qish/eshitish.
  study,
}

ExKind _kindFrom(String? s) => switch (s) {
      'choice' => ExKind.choice,
      'text' => ExKind.text,
      'match' => ExKind.match,
      // Noma'lum tur — kontent yo'qolmasin, shunchaki o'qish rejimida ko'rsatiladi.
      _ => ExKind.study,
    };

/// Kitob nomlarining ko'rinadigan shakli.
const _bookLabel = {
  'coursebook': 'Coursebook',
  'workbook': 'Workbook',
  'grammar': 'Grammar',
};

/// Bo'lim turlarining o'zbekcha nomi (asset'da bo'lmasa — zaxira).
const _kindLabelUz = {
  'lead_in': 'Kirish',
  'vocabulary': 'Lug\'at',
  'reading': 'O\'qish',
  'grammar_theory': 'Grammatika — qoida',
  'grammar': 'Grammatika',
  'grammar_exercise': 'Grammatika — mashq',
  'pronunciation': 'Talaffuz',
  'listening': 'Tinglash',
  'speaking': 'Gapirish',
  'communication': 'Muloqot',
  'game': 'O\'yin',
  'writing': 'Yozish',
  'words_of_wisdom': 'Hikmatli so\'z',
};

/// Javob tekshirish uchun matnni soddalashtiradi:
/// katta-kichik harf, ortiqcha bo'sh joy va tinish belgilari hisobga olinmaydi.
String _canon(String s) {
  final lower = s.toLowerCase().replaceAll('’', '\'');
  final cleaned = lower.replaceAll(RegExp(r'[.,!?;:"]'), ' ');
  return cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Bitta savol-javob birligi (yoki study uchun bitta satr).
class ExTask {
  // choice / text uchun
  final String prompt;
  final String promptUz;
  final String answer;
  final List<String> options;
  final List<String> alt;
  final String whyUz;

  // match uchun
  final String left;
  final String right;

  // study uchun
  final String en;
  final String uz;
  final String note;

  /// Javob berilgunga qadar ovoz chiqariladigan matn (faqat SAVOL).
  /// Bo'sh bo'lsa — ovoz tugmasi ko'rsatilmaydi. Javobni hech qachon
  /// oldindan o'qimaydi (eksport skripti buni ta'minlaydi).
  final String speak;

  /// Rasm o'rnidagi belgi (emoji yoki asset yo'li).
  final String visual;

  const ExTask({
    this.prompt = '',
    this.promptUz = '',
    this.answer = '',
    this.options = const [],
    this.alt = const [],
    this.whyUz = '',
    this.left = '',
    this.right = '',
    this.en = '',
    this.uz = '',
    this.note = '',
    this.speak = '',
    this.visual = '',
  });

  factory ExTask.fromJson(Map<String, dynamic> j) => ExTask(
        prompt: j['prompt'] as String? ?? '',
        promptUz: j['promptUz'] as String? ?? '',
        answer: j['answer'] as String? ?? '',
        options:
            (j['options'] as List? ?? []).map((e) => e.toString()).toList(),
        alt: (j['alt'] as List? ?? []).map((e) => e.toString()).toList(),
        whyUz: j['whyUz'] as String? ?? '',
        left: j['left'] as String? ?? '',
        right: j['right'] as String? ?? '',
        en: j['en'] as String? ?? '',
        uz: j['uz'] as String? ?? '',
        note: j['note'] as String? ?? '',
        speak: j['speak'] as String? ?? '',
        visual: j['visual'] as String? ?? '',
      );

  /// Foydalanuvchi javobi to'g'rimi (asosiy yoki muqobil javob bilan).
  bool isCorrect(String given) {
    final g = _canon(given);
    if (g.isEmpty) return false;
    if (g == _canon(answer)) return true;
    return alt.any((a) => _canon(a) == g);
  }

  /// Yig'ish rejimida javob so'zlarga bo'linadimi (ibora) yoki harflarga (so'z).
  bool get isPhrase => answer.trim().contains(' ');

  String get buildSeparator => isPhrase ? ' ' : '';

  /// Yig'ish uchun aralashtiriladigan bo'laklar.
  List<String> get buildPieces => isPhrase
      ? answer.trim().split(RegExp(r'\s+'))
      : answer.trim().split('');

  /// Javobdan OLDIN ovoz chiqarish uchun matn.
  /// study bandida `en` (u savol emas, o'qish uchun matn),
  /// boshqalarida faqat aniq belgilangan `speak`.
  /// MUHIM: bu yerda hech qachon `answer` qaytarilmaydi — aks holda
  /// ovoz tugmasi javobni oshkor qilib qo'yadi.
  String get speakText => en.isNotEmpty ? en : speak;

  /// Ovoz tugmasi ko'rsatiladimi.
  bool get canSpeak => speakText.trim().isNotEmpty;
}

/// Bitta mashq (kitobdagi Ex. 5 kabi).
class BookExercise {
  final String ref;
  final ExKind kind;
  final String instructionEn;
  final String instructionUz;
  final String explanationUz;
  final bool audio;
  final String audioNoteUz;
  final String bookRef;
  final String book;
  final int bookPage;
  final List<ExTask> tasks;

  const BookExercise({
    required this.ref,
    required this.kind,
    required this.tasks,
    this.instructionEn = '',
    this.instructionUz = '',
    this.explanationUz = '',
    this.audio = false,
    this.audioNoteUz = '',
    this.bookRef = '',
    this.book = '',
    this.bookPage = 0,
  });

  factory BookExercise.fromJson(Map<String, dynamic> j) => BookExercise(
        ref: j['ref'] as String? ?? '',
        kind: _kindFrom(j['kind'] as String?),
        instructionEn: j['instructionEn'] as String? ?? '',
        instructionUz: j['instructionUz'] as String? ?? '',
        explanationUz: j['explanationUz'] as String? ?? '',
        audio: j['audio'] as bool? ?? false,
        audioNoteUz: j['audioNoteUz'] as String? ?? '',
        bookRef: j['bookRef'] as String? ?? '',
        book: j['book'] as String? ?? '',
        bookPage: (j['bookPage'] as num?)?.toInt() ?? 0,
        tasks: (j['tasks'] as List? ?? [])
            .map((e) => ExTask.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  /// Javob talab qiladimi (study — yo'q).
  bool get isAnswerable => kind != ExKind.study && tasks.isNotEmpty;

  /// Baholanadigan bandlar soni.
  int get answerableCount => isAnswerable ? tasks.length : 0;

  String get title => ref.isEmpty ? 'Mashq' : 'Ex. $ref';
}

/// Grammatika qoidasi (erkin tuzilma — asset'dan qanday kelsa shunday).
class BookRule {
  final Map<String, dynamic> raw;
  const BookRule(this.raw);

  String get explanationUz => raw['explanationUz'] as String? ?? '';
  String get titleUz => raw['titleUz'] as String? ?? '';
  String get warningUz => raw['warningUz'] as String? ?? '';
  String get noteUz => raw['noteUz'] as String? ?? '';
}

/// Unitning bir bo'limi (bitta kitobning bitta betidagi bo'lim).
class BookSection {
  final String id;
  final String kind;
  final String title;
  final String titleUz;
  final String book;
  final int bookPage;
  final List<BookExercise> exercises;
  final BookRule? rule;

  const BookSection({
    required this.id,
    required this.kind,
    required this.title,
    required this.titleUz,
    required this.book,
    required this.bookPage,
    required this.exercises,
    this.rule,
  });

  factory BookSection.fromJson(Map<String, dynamic> j) => BookSection(
        id: j['id'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        title: j['title'] as String? ?? '',
        titleUz: (j['titleUz'] as String?)?.isNotEmpty == true
            ? j['titleUz'] as String
            : _kindLabelUz[j['kind']] ?? '',
        book: j['book'] as String? ?? '',
        bookPage: (j['bookPage'] as num?)?.toInt() ?? 0,
        exercises: (j['exercises'] as List? ?? [])
            .map((e) => BookExercise.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        rule: j['rule'] == null
            ? null
            : BookRule((j['rule'] as Map).cast<String, dynamic>()),
      );

  bool get hasRule => rule != null;

  /// "Coursebook, 6-bet" — o'quvchi kitobning qayerini ochishini biladi.
  String get sourceLabel =>
      '${_bookLabel[book] ?? book}, $bookPage-bet';

  int get answerableCount =>
      exercises.fold(0, (s, e) => s + e.answerableCount);
}

/// Bir turdagi bo'limlar guruhi (unit ekranida bitta karta bo'lib ko'rinadi).
class SectionGroup {
  final String kind;
  final String titleUz;
  final List<BookSection> sections;

  const SectionGroup({
    required this.kind,
    required this.titleUz,
    required this.sections,
  });

  int get exerciseCount =>
      sections.fold(0, (s, x) => s + x.exercises.length);
  int get answerableCount =>
      sections.fold(0, (s, x) => s + x.answerableCount);
  bool get hasRule => sections.any((s) => s.hasRule);
}

/// So'z yasalishi guruhi.
class WfGroup {
  final String ruleUz;
  final String explanationUz;
  final List<WfItem> items;
  final String book;
  final int bookPage;

  const WfGroup({
    required this.ruleUz,
    required this.explanationUz,
    required this.items,
    this.book = '',
    this.bookPage = 0,
  });

  factory WfGroup.fromJson(Map<String, dynamic> j) => WfGroup(
        ruleUz: j['ruleUz'] as String? ?? '',
        explanationUz: j['explanationUz'] as String? ?? '',
        book: j['book'] as String? ?? '',
        bookPage: (j['bookPage'] as num?)?.toInt() ?? 0,
        items: (j['items'] as List? ?? [])
            .map((e) => WfItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class WfItem {
  final String base, baseUz, derived, derivedUz, note;
  const WfItem({
    required this.base,
    required this.derived,
    this.baseUz = '',
    this.derivedUz = '',
    this.note = '',
  });

  factory WfItem.fromJson(Map<String, dynamic> j) => WfItem(
        base: j['base'] as String? ?? '',
        baseUz: j['baseUz'] as String? ?? '',
        derived: j['derived'] as String? ?? '',
        derivedUz: j['derivedUz'] as String? ?? '',
        note: j['note'] as String? ?? '',
      );
}

/// Gap qolipi.
class SentencePattern {
  final String formula, exampleEn, exampleUz, explanationUz, book;
  final int bookPage;

  const SentencePattern({
    required this.formula,
    required this.exampleEn,
    this.exampleUz = '',
    this.explanationUz = '',
    this.book = '',
    this.bookPage = 0,
  });

  factory SentencePattern.fromJson(Map<String, dynamic> j) => SentencePattern(
        formula: j['formula'] as String? ?? '',
        exampleEn: j['exampleEn'] as String? ?? '',
        exampleUz: j['exampleUz'] as String? ?? '',
        explanationUz: j['explanationUz'] as String? ?? '',
        book: j['book'] as String? ?? '',
        bookPage: (j['bookPage'] as num?)?.toInt() ?? 0,
      );
}

/// Sahifa lug'ati elementi.
class VocabEntry {
  final String en, uz;
  const VocabEntry({required this.en, required this.uz});

  factory VocabEntry.fromJson(Map<String, dynamic> j) => VocabEntry(
        en: j['en'] as String? ?? '',
        uz: j['uz'] as String? ?? '',
      );
}

/// Kitobning bitta uniti — uchala kitobdan yig'ilgan.
class BookUnit {
  final int unit;
  final String title;
  final int module;
  final List<BookSection> sections;
  final List<WfGroup> wordFormation;
  final List<SentencePattern> sentencePatterns;
  final List<VocabEntry> vocabulary;

  const BookUnit({
    required this.unit,
    required this.title,
    required this.module,
    required this.sections,
    required this.wordFormation,
    required this.sentencePatterns,
    required this.vocabulary,
  });

  factory BookUnit.fromJson(Map<String, dynamic> j) => BookUnit(
        unit: (j['unit'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        module: (j['module'] as num?)?.toInt() ?? 0,
        sections: (j['sections'] as List? ?? [])
            .map((e) => BookSection.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        wordFormation: (j['wordFormation'] as List? ?? [])
            .map((e) => WfGroup.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        sentencePatterns: (j['sentencePatterns'] as List? ?? [])
            .map((e) =>
                SentencePattern.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        vocabulary: (j['vocabulary'] as List? ?? [])
            .map((e) => VocabEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  int get exerciseCount =>
      sections.fold(0, (s, x) => s + x.exercises.length);

  int get answerableCount =>
      sections.fold(0, (s, x) => s + x.answerableCount);

  /// Bo'limlarni turi bo'yicha guruhlaydi (37 bo'lim -> ~13 karta).
  /// Tartib asset'dagi tartibda saqlanadi.
  List<SectionGroup> groupedSections() {
    final order = <String>[];
    final map = <String, List<BookSection>>{};
    for (final s in sections) {
      if (!map.containsKey(s.kind)) {
        order.add(s.kind);
        map[s.kind] = [];
      }
      map[s.kind]!.add(s);
    }
    return [
      for (final k in order)
        SectionGroup(
          kind: k,
          titleUz: map[k]!.first.titleUz.isNotEmpty
              ? (_kindLabelUz[k] ?? map[k]!.first.titleUz)
              : (_kindLabelUz[k] ?? k),
          sections: map[k]!,
        ),
    ];
  }
}

/// Unit'lar ro'yxatidagi qisqa yozuv (index.json).
class UnitBrief {
  final int unit, module, sections, exercises, tasks;
  final String title;

  const UnitBrief({
    required this.unit,
    required this.title,
    required this.module,
    required this.sections,
    required this.exercises,
    required this.tasks,
  });

  factory UnitBrief.fromJson(Map<String, dynamic> j) => UnitBrief(
        unit: (j['unit'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        module: (j['module'] as num?)?.toInt() ?? 0,
        sections: (j['sections'] as num?)?.toInt() ?? 0,
        exercises: (j['exercises'] as num?)?.toInt() ?? 0,
        tasks: (j['tasks'] as num?)?.toInt() ?? 0,
      );
}

/// Kitob kontentini asset'lardan yuklaydigan repozitoriy.
class BookRepository {
  static const _dir = 'assets/content/enterprise1';

  final List<UnitBrief> units = [];
  final Map<int, BookUnit> _cache = {};

  /// Mavjud unit'lar ro'yxatini yuklaydi. Fayl bo'lmasa — bo'sh qoladi
  /// (ilova baribir ishlaydi).
  Future<void> loadIndex() async {
    try {
      final s = await rootBundle.loadString('$_dir/index.json');
      final j = json.decode(s) as Map<String, dynamic>;
      units
        ..clear()
        ..addAll((j['units'] as List? ?? []).map(
            (e) => UnitBrief.fromJson((e as Map).cast<String, dynamic>())));
    } catch (_) {
      units.clear();
    }
  }

  /// Bitta unitni yuklaydi (keshlanadi).
  Future<BookUnit?> load(int unit) async {
    if (_cache.containsKey(unit)) return _cache[unit];
    try {
      final s = await rootBundle.loadString('$_dir/unit_$unit.json');
      final u = BookUnit.fromJson(json.decode(s) as Map<String, dynamic>);
      _cache[unit] = u;
      return u;
    } catch (_) {
      return null;
    }
  }
}
