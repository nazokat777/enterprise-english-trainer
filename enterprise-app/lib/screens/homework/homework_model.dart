import 'dart:math';

import '../../content.dart';

/// Homework savol turlari (Match alohida raund — bu enum'ga kirmaydi).
enum QuestionKind { choose, fill, construct }

/// O'tish chegarasi (foiz) va o'tgani uchun bonus XP.
const int kPassMark = 80;
const int kPassBonusXp = 10;

/// Misol gapdagi target so'zni `_____` ga almashtiradi.
/// So'z chegarasi (`\b`) bilan qidiradi — "present" so'zi "represent" ichida
/// almashmasligi uchun. Topilmasa `null` (savol Choose'ga tushadi).
String? fillBlank(String example, String word) {
  final e = example.trim();
  final t = word.trim();
  if (e.isEmpty || t.isEmpty) return null;
  final re = RegExp(r'\b' + RegExp.escape(t) + r'\b', caseSensitive: false);
  if (!re.hasMatch(e)) return null;
  // MUHIM: so'z gapda bir necha marta uchrasa, HAMMASI berkitiladi.
  // Ilgari faqat birinchisi almashtirilardi va javob gapning o'zida
  // ko'rinib turardi: "I'm _____, Steve Blair."
  return e.replaceAll(re, '_____');
}

/// Ko'p tanlovli savol uchun `count` ta noto'g'ri variant tanlaydi.
///
/// Kritik qoida: `uz` (yoki `en`) target bilan bir xil bo'lgan so'zlar
/// CHIQARIB TASHLANADI — beginner kontentida 11 ta takroriy tarjima bor
/// ("issiq", "suzish", ...), ular savolda ikkinchi to'g'ri javob yaratadi.
/// Iloji bo'lsa bir xil `pos` dagi so'zlar afzal ko'riladi.
List<Word> pickDistractors(Word target, List<Word> pool, int count, Random rnd) {
  final out = <Word>[];
  final seenUz = <String>{target.uz};
  final seenEn = <String>{target.en};

  void take(Iterable<Word> src) {
    final list = List.of(src)..shuffle(rnd);
    for (final x in list) {
      if (out.length >= count) return;
      if (x.id == target.id) continue;
      if (seenUz.contains(x.uz) || seenEn.contains(x.en)) continue;
      out.add(x);
      seenUz.add(x.uz);
      seenEn.add(x.en);
    }
  }

  if (target.pos.isNotEmpty) {
    take(pool.where((x) => x.pos == target.pos)); // avval bir xil turkum
  }
  take(pool); // keyin qolganlari
  return out;
}

/// Test yakuni.
class HwResult {
  final int earned; // olingan ball
  final int total; // jami ball
  final List<Word> wrongWords; // birinchi urinishda xato qilinganlar

  const HwResult({
    required this.earned,
    required this.total,
    this.wrongWords = const [],
  });

  /// Ko'rsatish uchun foiz (yaxlitlangan).
  int get percent => total == 0 ? 0 : ((earned / total) * 100).round();

  /// O'tdimi — BUTUN SON arifmetikasi bilan, `percent` orqali emas:
  /// 79.5% yaxlitlanib 80 bo'lib qolmasin.
  bool get passed => total > 0 && earned * 100 >= kPassMark * total;
}

/// Bitta savol (har doim bitta so'z haqida).
class HwQuestion {
  final QuestionKind kind;
  final Word word;

  /// Choose uchun — o'zbekcha variantlar; Fill uchun — inglizcha variantlar;
  /// Construct uchun — bo'sh.
  final List<String> options;

  /// Fill uchun `_____` li gap; boshqa turlarda `null`.
  final String? sentence;

  const HwQuestion({
    required this.kind,
    required this.word,
    this.options = const [],
    this.sentence,
  });

  /// To'g'ri javob matni.
  String get answer => kind == QuestionKind.choose ? word.uz : word.en;
}

/// Butun test rejasi: savollar + (ixtiyoriy) oxirgi Match raundi.
class HwPlan {
  final List<HwQuestion> questions;
  final List<Word> matchRound; // bo'sh bo'lishi mumkin

  const HwPlan({required this.questions, required this.matchRound});

  /// Jami ball: har savol 1, Match'da har juft 1.
  int get totalPoints => questions.length + matchRound.length;
}

/// Unit so'zlaridan test rejasini quradi.
///
/// [unitWords] — unitning barcha so'zlari (chegara YO'Q, hammasi savolga
/// aylanadi). [levelWords] — distraktor uchun kengroq havza.
HwPlan buildPlan(List<Word> unitWords, List<Word> levelWords, Random rnd) {
  // Takrorlarni olib tashlash (bir so'z ikki pack'da bo'lishi mumkin).
  final uniq = <String, Word>{};
  for (final x in unitWords) {
    uniq[x.id] = x;
  }
  final words = uniq.values.toList()..shuffle(rnd);
  if (words.isEmpty) {
    return const HwPlan(questions: [], matchRound: []);
  }

  // Distraktor havzasi: avval unit, keyin butun daraja.
  final pool = <String, Word>{};
  for (final x in [...words, ...levelWords]) {
    pool[x.id] = x;
  }
  final distractorPool = pool.values.toList();

  final questions = <HwQuestion>[
    for (var i = 0; i < words.length; i++)
      _makeQuestion(words[i], i, distractorPool, rnd),
  ];

  // Match: kamida 4 so'z bo'lsa, 5 tagacha juft.
  final matchRound = words.length >= 4
      ? (List.of(words)..shuffle(rnd)).take(min(5, words.length)).toList()
      : <Word>[];

  return HwPlan(questions: questions, matchRound: matchRound);
}

/// Bitta so'z uchun savol turini aniqlaydi (indeks bo'yicha — takrorlanadigan).
HwQuestion _makeQuestion(Word x, int i, List<Word> pool, Random rnd) {
  HwQuestion construct() => HwQuestion(kind: QuestionKind.construct, word: x);

  // Har uchinchi savol — Construct (xilma-xillik uchun).
  if (i % 3 == 2) return construct();

  final blank = fillBlank(x.example, x.en);
  final distractors = pickDistractors(x, pool, 3, rnd);

  // Bitta ham distraktor topilmasa ko'p tanlovli savol ma'nosiz.
  if (distractors.isEmpty) return construct();

  if (blank != null) {
    final options = [x.en, ...distractors.map((d) => d.en)]..shuffle(rnd);
    return HwQuestion(
      kind: QuestionKind.fill,
      word: x,
      options: options,
      sentence: blank,
    );
  }

  final options = [x.uz, ...distractors.map((d) => d.uz)]..shuffle(rnd);
  return HwQuestion(kind: QuestionKind.choose, word: x, options: options);
}
