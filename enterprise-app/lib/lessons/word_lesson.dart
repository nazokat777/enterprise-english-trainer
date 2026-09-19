import '../book_content.dart';
import '../drill/drill_item.dart';

/// SO'Z DARSI — unit lug'atining kichik bo'lagi (Duolingo uslubi).
///
/// Nega kerak bo'ldi: unit lug'atida 140-190 so'z bor. Ularni bir
/// qopga solib tasodifiy so'rash o'quvchini chalg'itadi — so'z avval
/// KO'RSATILMAY turib so'raladi. Duolingo ham, xotira ilmi ham bir
/// xil gapiradi: 5-7 ta yangi birlik, avval tanishuv, so'ng shu
/// birliklar bir necha shaklda, xatolar shu zahoti qaytib.
class WordLesson {
  /// Unit ichidagi tartib raqami (1 dan).
  final int index;

  /// Qaysi unit.
  final int unit;

  /// Darsdagi so'zlar (5-8 ta).
  final List<LessonWord> words;

  const WordLesson({
    required this.index,
    required this.unit,
    required this.words,
  });

  /// O'zlashtirish kalitlari.
  List<String> get itemIds => words.map((w) => w.itemId).toList();

  /// Savol dvigateli uchun manbalar.
  List<DrillSource> get sources => [
        for (final w in words)
          DrillSource(
            itemId: w.itemId,
            en: w.en,
            uz: w.uz,
            // KONTEKST: misol gapdagi so'z bo'shliq bo'ladi — so'z gap
            // ichida eslanadi (kontekstli xotira). Gap bo'lmasa cloze
            // raundi shu so'z uchun tashlab ketiladi.
            sentence: w.clozeSentence,
            unit: unit,
            topic: 'Lug\'at',
          ),
      ];
}

/// Darsdagi bitta so'z — tanishuv kartasi uchun misol gap bilan.
class LessonWord {
  final String en;
  final String uz;

  /// Kitobdan topilgan misol gap (bo'lmasa bo'sh).
  final String exampleEn;
  final String exampleUz;

  const LessonWord({
    required this.en,
    required this.uz,
    this.exampleEn = '',
    this.exampleUz = '',
  });

  String get itemId => 'w::${en.trim().toLowerCase()}';

  /// Misol gapda so'z `_____` bilan almashtirilgan; gap yo'q yoki
  /// so'z gapda topilmasa — bo'sh.
  String get clozeSentence {
    if (exampleEn.isEmpty) return '';
    final re = RegExp(r'\b' + RegExp.escape(en.trim()) + r'\b',
        caseSensitive: false);
    if (!re.hasMatch(exampleEn)) return '';
    return exampleEn.replaceFirst(re, kBlank);
  }
}

/// Bitta darsda nechta so'z.
const int kLessonSize = 7;

/// Unit lug'atini darslarga bo'ladi.
///
/// Lug'at kitobdagi BET tartibida — demak darslar ham kitob bilan
/// birga yuradi: 1-dars = unitning birinchi betlari.
List<WordLesson> lessonsOf(BookUnit u) {
  final words = <LessonWord>[];
  final seen = <String>{};
  for (final v in u.vocabulary) {
    final en = v.en.trim();
    final uz = v.uz.trim();
    if (en.isEmpty || uz.isEmpty) continue;
    if (!seen.add(en.toLowerCase())) continue;
    // Inglizchasi bilan o'zbekchasi bir xil so'z ("golf", "Dublin")
    // yodlashga hech narsa bermaydi.
    if (en.toLowerCase() == uz.toLowerCase()) continue;
    final ex = _exampleFor(u, en);
    words.add(LessonWord(
      en: en,
      uz: uz,
      exampleEn: ex?.$1 ?? '',
      exampleUz: ex?.$2 ?? '',
    ));
  }
  if (words.isEmpty) return const [];

  // Teng bo'laklarga bo'lish: oxirgi dars 3 tadan kam qolmasin.
  final n = (words.length / kLessonSize).ceil();
  final size = (words.length / n).ceil();
  final out = <WordLesson>[];
  for (var i = 0; i < n; i++) {
    final chunk = words.skip(i * size).take(size).toList();
    if (chunk.isEmpty) break;
    out.add(WordLesson(index: i + 1, unit: u.unit, words: chunk));
  }
  return out;
}

/// So'z uchrayotgan qisqa misol gapni kitob mashqlaridan topadi.
///
/// Tanishuv kartasida so'z GAP IChIDA ko'rinsa, ma'no va ishlatilishi
/// birga yodlanadi (kontekstli o'rganish). Uzun gap kartaga sig'maydi
/// va diqqatni tortib ketadi — 12 so'zdan uzuni olinmaydi.
(String, String)? _exampleFor(BookUnit u, String word) {
  final re = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
  (String, String)? fallback;
  for (final s in u.sections) {
    for (final e in s.exercises) {
      for (final t in e.tasks) {
        for (final (en, uz) in [
          (t.en, t.uz),
          (t.prompt, t.promptUz),
        ]) {
          final a = en.trim();
          if (a.isEmpty || !re.hasMatch(a)) continue;
          if (a.contains('___') || a.contains(kBlank)) continue;
          final n = a.split(RegExp(r'\s+')).length;
          if (n < 3 || n > 12) continue;
          // HAQIQIY GAP bo'lsin: "Diego — Origin" kabi sarlavha/yorliq
          // (harfli so'z 3 tadan kam yoki tinishsiz qisqa parcha) emas.
          final alpha = a
              .split(RegExp(r'\s+'))
              .where((w) => RegExp(r'[A-Za-z]').hasMatch(w))
              .length;
          final ends = RegExp(r'[.?!]$').hasMatch(a);
          if (alpha < 3 || (!ends && alpha < 5)) continue;
          // So'zning o'zi gap bo'lsa — misol emas.
          if (a.toLowerCase() == word.toLowerCase()) continue;
          final b = uz.trim();
          if (b.isNotEmpty) return (a, b);
          fallback ??= (a, '');
        }
      }
    }
  }
  return fallback;
}
