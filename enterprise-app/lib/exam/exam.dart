import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../book_content.dart';
import '../drill/drill_item.dart';
import '../mastery.dart';

/// 📝 YIG'MA IMTIHON — N-unit tugagach 1..N unitlarning HAMMASI.
///
/// Pedagogika (kumulyativ takror): har yangi unit oldingilarini ham
/// qayta so'raydi — Ebbinghaus unutish egri chizig'i kesiladi, bilim
/// "shu unitniki" emas, umumiy bo'lib qoladi. Imtihon uch qismdan:
///   1) Lug'at — o'zbekchadan inglizchaga (tanlash) va harflab yozish
///   2) Grammatika — kitob grammatika mashqlaridagi tanlov savollari
///   3) Gaplar — namunaviy gapni tinglab, klaviaturada yozish
/// Xato band navbat oxiriga qaytadi: imtihon HAMMASI to'g'ri
/// bo'lgunicha tugamaydi (mastery), baho esa BIRINCHI urinish bo'yicha.
/// Zaif bandlar saqlanadi va alohida "qayta ishlash" seansi bo'ladi.
enum ExamPart { words, grammar, sentences }

class ExamItem {
  final String id;
  final ExamPart part;
  final int unit;

  /// Mavzu (grammatika bo'limi sarlavhasi yoki "Lug'at").
  final String topic;

  /// Tanlov/yig'ish savoli (lug'at, grammatika).
  final DrillQuestion? q;

  /// Yozish savoli (gaplar).
  final ExTask? task;

  const ExamItem({
    required this.id,
    required this.part,
    required this.unit,
    required this.topic,
    this.q,
    this.task,
  });

  String get answer => q?.answer ?? task?.answer ?? '';
  String get promptUz => q?.promptUz ?? task?.promptUz ?? '';
}

class ExamPlan {
  final int uptoUnit;
  final List<ExamItem> items;
  const ExamPlan({required this.uptoUnit, required this.items});

  int count(ExamPart p) => items.where((e) => e.part == p).length;
}

/// Imtihon natijasi (saqlanadi).
class ExamResult {
  final int uptoUnit;
  final int score; // 0..100, birinchi urinish
  final int total;
  final int dateMs;
  final List<String> weakIds;
  final List<String> weakTopics;

  const ExamResult({
    required this.uptoUnit,
    required this.score,
    required this.total,
    required this.dateMs,
    this.weakIds = const [],
    this.weakTopics = const [],
  });

  bool get passed => score >= 90;

  Map<String, dynamic> toJson() => {
        'u': uptoUnit,
        's': score,
        't': total,
        'd': dateMs,
        'w': weakIds,
        'wt': weakTopics,
      };

  factory ExamResult.fromJson(Map<String, dynamic> j) => ExamResult(
        uptoUnit: (j['u'] as num).toInt(),
        score: (j['s'] as num).toInt(),
        total: (j['t'] as num?)?.toInt() ?? 0,
        dateMs: (j['d'] as num?)?.toInt() ?? 0,
        weakIds: ((j['w'] as List?) ?? const []).map((e) => '$e').toList(),
        weakTopics: ((j['wt'] as List?) ?? const []).map((e) => '$e').toList(),
      );
}

class ExamStore {
  static String _k(String level, int upto) => 'exam::$level::$upto';

  static Future<ExamResult?> load(String level, int upto) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k(level, upto));
    if (raw == null) return null;
    try {
      return ExamResult.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Faqat yaxshiroq natija saqlanadi; zaif ro'yxat esa har safar
  /// yangilanadi (oxirgi holat muhim).
  static Future<void> save(String level, ExamResult r) async {
    final p = await SharedPreferences.getInstance();
    final old = await load(level, r.uptoUnit);
    final best = old == null || r.score >= old.score
        ? r
        : ExamResult(
            uptoUnit: r.uptoUnit,
            score: old.score,
            total: old.total,
            dateMs: r.dateMs,
            weakIds: r.weakIds,
            weakTopics: r.weakTopics,
          );
    await p.setString(_k(level, r.uptoUnit), json.encode(best.toJson()));
  }
}

/// Imtihon rejasini kitobdan yig'adi.
class ExamBuilder {
  final BookRepository book;
  final MasteryStore mastery;
  final Random rnd;

  ExamBuilder({required this.book, required this.mastery, Random? random})
      : rnd = random ?? Random();

  /// Nechta savol (unit soniga qarab, lekin charchatmaydigan chegara).
  static int wordTarget(int n) => min(24, 6 + 3 * n);
  static int grammarTarget(int n) => min(18, 4 + 2 * n);
  static int sentenceTarget(int n) => min(8, 2 + n);

  Future<ExamPlan> build(int uptoUnit, {Set<String>? onlyIds}) async {
    final words = <DrillSource>[];
    final grammar = <ExamItem>[];
    final sentences = <ExamItem>[];
    final seenWord = <String>{};
    final seenSent = <String>{};

    for (final b in book.units) {
      if (b.isInfo || b.unit < 1 || b.unit > uptoUnit) continue;
      final u = await book.load(b.unit);
      if (u == null) continue;

      for (final v in u.vocabulary) {
        final en = v.en.trim(), uz = v.uz.trim();
        if (en.isEmpty || uz.isEmpty) continue;
        if (en.toLowerCase() == uz.toLowerCase()) continue;
        if (!seenWord.add(en.toLowerCase())) continue;
        words.add(DrillSource(
          itemId: 'w::${en.toLowerCase()}',
          en: en,
          uz: uz,
          unit: b.unit,
          topic: 'Lug\'at',
        ));
      }

      for (final s in u.sections) {
        if (!s.kind.startsWith('grammar')) continue;
        for (final e in s.exercises) {
          if (e.kind != ExKind.choice) continue;
          for (var i = 0; i < e.tasks.length; i++) {
            final t = e.tasks[i];
            if (t.options.length < 2 || t.answer.isEmpty) continue;
            if (t.prompt.trim().isEmpty) continue;
            final id = 't::${e.progressId}::$i';
            grammar.add(ExamItem(
              id: id,
              part: ExamPart.grammar,
              unit: b.unit,
              topic: s.titleUz.isNotEmpty ? s.titleUz : s.title,
              q: DrillQuestion(
                itemId: id,
                format: AskFormat.choice,
                prompt: t.prompt,
                promptUz: t.promptUz,
                answer: t.answer,
                options: List.of(t.options)..shuffle(rnd),
                unit: b.unit,
                topic: s.titleUz.isNotEmpty ? s.titleUz : s.title,
              ),
            ));
          }
        }
      }

      for (final sp in u.sentencePatterns) {
        final first =
            sp.exampleEn.split(RegExp(r'(?<=[.!?])\s+')).first.trim();
        final n = first.split(RegExp(r'\s+')).length;
        if (n < 3 || n > 9) continue;
        if (!seenSent.add(first.toLowerCase())) continue;
        final uz = sp.exampleUz.split(RegExp(r'(?<=[.!?])\s+')).first.trim();
        final id = 's::${first.toLowerCase()}';
        sentences.add(ExamItem(
          id: id,
          part: ExamPart.sentences,
          unit: b.unit,
          topic: sp.formula.isNotEmpty ? sp.formula : 'Gap',
          task: ExTask(
            prompt: '⌨️ Tinglang va yozing',
            promptUz: uz,
            answer: first,
            speak: first,
            speakAnswer: first,
            typed: true,
          ),
        ));
      }
    }

    // Zaif va uzoq so'ralmagan bandlar OLDIN (tashxis imtihoni).
    double need(String id) {
      final m = mastery.of(id);
      return m.needScore +
          (m.isFading(DateTime.now().millisecondsSinceEpoch) ? 5 : 0) +
          rnd.nextDouble();
    }

    final n = max(1, uptoUnit);
    List<T> pick<T>(List<T> src, String Function(T) idOf, int target) {
      var list = src;
      if (onlyIds != null) {
        list = src.where((e) => onlyIds.contains(idOf(e))).toList();
        return list;
      }
      list = List.of(src)..sort((a, b) => need(idOf(b)).compareTo(need(idOf(a))));
      return list.take(target).toList();
    }

    final pickedWords = pick(words, (s) => s.itemId, wordTarget(n));
    final pool = words.length >= 4 ? words : pickedWords;
    final wordItems = <ExamItem>[];
    for (var i = 0; i < pickedWords.length; i++) {
      final s = pickedWords[i];
      // Navbatma-navbat: tanlash (uz->en) va harflab yozish.
      final f = i.isEven ? AskFormat.produce : AskFormat.build;
      final q = buildQuestion(s, f, pool, rnd) ??
          buildQuestion(s, AskFormat.produce, pool, rnd);
      if (q == null) continue;
      wordItems.add(ExamItem(
          id: s.itemId, part: ExamPart.words, unit: s.unit, topic: 'Lug\'at', q: q));
    }

    final items = [
      ...wordItems,
      ...pick(grammar, (e) => e.id, grammarTarget(n))..shuffle(rnd),
      ...pick(sentences, (e) => e.id, sentenceTarget(n))..shuffle(rnd),
    ];
    return ExamPlan(uptoUnit: uptoUnit, items: items);
  }
}
