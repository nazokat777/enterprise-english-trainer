import 'dart:math';

import '../mastery.dart';
import 'drill_item.dart';

/// SEANS BOSQIChI.
enum DrillPhase {
  /// Faqat SHU dars bandlari — 100% gacha.
  lesson,

  /// Shu darsgacha bo'lgan HAMMA mavzu aralashtirilib — 100% gacha.
  mixed,

  /// Tugadi.
  done,
}

/// DARS USTASI — "o'zlashtirgunicha qo'ymaydigan" seans dvigateli.
///
/// Egasi qo'ygan talab:
///   1) bugungi darsni 100% to'g'ri javob bergunicha qayta-qayta,
///   2) so'ng shu darsgacha bo'lgan hamma mavzu ARALAShTIRILIB, yana
///      100% gacha,
///   3) zerikarli bo'lmasin — savol ko'rinishi almashib tursin.
///
/// Nega shunday ishlaydi (o'rganish ilmi):
///
/// * **Retrieval practice** — har takror eslab aytish; qayta o'qish
///   emas.
/// * **Interleaving** — ikkinchi bosqichda mavzular aralashadi.
///   Blokda o'rganish sinovda yaxshi ko'rinadi, lekin bir haftadan
///   keyin unutiladi; aralashtirish aksincha.
/// * **Spacing within session** — xato qilingan band DARHOL emas,
///   bir necha savoldan keyin qaytadi.
/// * **Desirable difficulty** — band har safar BOShQA ko'rinishda
///   so'raladi, shuning uchun savol ko'rinishini yodlab olib bo'lmaydi.
class DrillSession {
  final MasteryStore mastery;
  final Random _rnd;

  /// Shu darsning birliklari.
  final List<DrillSource> lessonSources;

  /// Oldingi darslar birliklari (aralash bosqich uchun).
  final List<DrillSource> earlierSources;

  /// Aralash bosqichda nechta band so'raladi.
  final int mixedSize;

  /// BITTA SEANSDA shu darsdan nechta band olinadi.
  ///
  /// Nega chegara kerak: bitta unitda 578 tagacha band bor. Hammasini
  /// bir o'tirishda 100% qilish imkonsiz — o'quvchi charchaydi va
  /// tashlab ketadi. Seans qisqa va TUGAYDIGAN bo'lishi kerak: shunda
  /// har o'tirish "bajardim" hissi beradi (nevrologiya: aniq va
  /// yetib boradigan maqsad dopamin beradi, cheksiz ro'yxat esa
  /// aksincha).
  ///
  /// Dars baribir 100% gacha boradi — keyingi seans qolganini oladi.
  /// Unit tugmasidagi foiz butun darsni ko'rsatadi.
  final int lessonBatch;

  /// Shu seansda ishlanadigan bandlar (butun darsdan tanlangan).
  List<DrillSource> _batch = const [];

  /// Necha savoldan keyin moslash o'yini qo'yiladi.
  static const int matchEvery = 5;

  /// O'yindagi juftliklar soni.
  static const int matchPairs = 4;

  DrillPhase _phase = DrillPhase.lesson;
  final List<DrillQuestion> _queue = [];
  int _pos = 0;

  /// Shu seansda ketma-ket nechta to'g'ri javob (kombo).
  int _combo = 0;
  int _bestCombo = 0;

  /// Aralash bosqich uchun tanlangan birliklar.
  List<DrillSource> _mixedPicked = const [];

  DrillSession({
    required this.mastery,
    required this.lessonSources,
    this.earlierSources = const [],
    this.mixedSize = 8,
    this.lessonBatch = 10,
    Random? random,
  }) : _rnd = random ?? Random() {
    _pickBatch();
    _fillLesson();
  }

  /// Darsdan shu seansga bandlarni tanlaydi: avval ZAIF va YANGI.
  void _pickBatch() {
    final left =
        lessonSources.where((e) => !mastery.of(e.itemId).isStrong).toList()
          ..sort((a, b) => mastery
              .of(b.itemId)
              .needScore
              .compareTo(mastery.of(a.itemId).needScore));
    _batch = left.take(lessonBatch).toList();
  }

  /// Butun darsning o'zlashtirilishi (tugmadagi foiz uchun).
  double get lessonProgress =>
      mastery.ratio(lessonSources.map((e) => e.itemId));

  DrillPhase get phase => _phase;
  int get combo => _combo;
  int get bestCombo => _bestCombo;

  /// Hozirgi savol. Seans tugagan bo'lsa `null`.
  DrillQuestion? get current =>
      _pos < _queue.length ? _queue[_pos] : null;

  /// Joriy bosqichdagi birliklar.
  List<DrillSource> get _active =>
      _phase == DrillPhase.lesson ? _batch : _mixedPicked;

  /// Joriy bosqichning o'zlashtirilish ulushi (0..1) — halqa uchun.
  ///
  /// QISMAN baholi: har to'g'ri javob halqani siljitadi. Ilgari faqat
  /// TUGAGAN bandlar sanalardi va o'quvchi olti marta to'g'ri javob
  /// berib ham 0% ni ko'rardi.
  double get progress =>
      mastery.progressScore(_active.map((e) => e.itemId));

  /// Nechta band qoldi.
  int get remaining =>
      _active.where((e) => !mastery.of(e.itemId).isStrong).length;

  /// Javob berildi. Keyingi savolga o'tadi va kerak bo'lsa bosqichni
  /// almashtiradi.
  Future<void> answer(bool ok) async {
    final q = current;
    if (q == null) return;

    await mastery.record(q.itemId, q.format, ok: ok);

    if (ok) {
      _combo += 1;
      if (_combo > _bestCombo) _bestCombo = _combo;
    } else {
      _combo = 0;
      // XATO BAND DARHOL EMAS, bir necha savoldan keyin qaytadi:
      // darhol qaytarilsa javob qisqa muddatli xotiradan olinadi va
      // hech narsa yodlanmaydi (spacing effect).
      _requeue(q);
    }

    _pos += 1;
    if (_pos >= _queue.length) _advance();
  }

  /// Xato qilingan bandni navbatga QAYTARADI — boshqa ko'rinishda.
  void _requeue(DrillQuestion q) {
    final src = _active.firstWhere((e) => e.itemId == q.itemId,
        orElse: () => _active.isNotEmpty ? _active.first : lessonSources.first);
    const gap = 3;
    final at = (_pos + gap).clamp(0, _queue.length);
    final next = _make(src, avoid: q.format);
    if (next != null) _queue.insert(at, next);
  }

  /// Bosqich tugadi — keyingisiga o'tadi yoki yana takrorlaydi.
  void _advance() {
    final left = _active.where((e) => !mastery.of(e.itemId).isStrong).toList();
    if (left.isNotEmpty) {
      // HALI 100% EMAS — qolganlarini yana so'raymiz.
      _queue
        ..clear()
        ..addAll(_questionsFor(left));
      _pos = 0;
      if (_queue.isNotEmpty) return;
    }
    if (_phase == DrillPhase.lesson) {
      _phase = DrillPhase.mixed;
      _fillMixed();
      _pos = 0;
      if (_queue.isEmpty) _phase = DrillPhase.done;
    } else {
      _phase = DrillPhase.done;
    }
  }

  void _fillLesson() {
    _queue
      ..clear()
      ..addAll(_questionsFor(_batch));
    _pos = 0;
    if (_queue.isEmpty) {
      _phase = DrillPhase.mixed;
      _fillMixed();
      if (_queue.isEmpty) _phase = DrillPhase.done;
    }
  }

  /// Aralash bosqich: eng zaif bandlarni oldinga qo'yib, oldingi
  /// darslardan tanlaydi.
  void _fillMixed() {
    if (earlierSources.isEmpty) {
      _mixedPicked = const [];
      _queue.clear();
      return;
    }
    final byNeed = List.of(earlierSources)
      ..sort((a, b) => mastery
          .of(b.itemId)
          .needScore
          .compareTo(mastery.of(a.itemId).needScore));
    // Zaiflardan ko'proq, lekin tasodifiylik ham bo'lsin — faqat
    // eng yomonlarini so'rash zerikarli va tushkun qiladi.
    final weak = byNeed.take(mixedSize).toList();
    final rest = byNeed.skip(mixedSize).toList()..shuffle(_rnd);
    _mixedPicked = [
      ...weak,
      ...rest.take((mixedSize / 2).round()),
    ]..shuffle(_rnd);
    _queue
      ..clear()
      ..addAll(_questionsFor(_mixedPicked));
  }

  List<DrillQuestion> _questionsFor(List<DrillSource> src) {
    final out = <DrillQuestion>[];
    for (final s in src) {
      final q = _make(s);
      if (q != null) out.add(q);
    }
    out.shuffle(_rnd);
    return _withMatchGames(out, src);
  }

  /// Har necha savoldan keyin MOSLASh o'yini qo'yiladi.
  ///
  /// Bir xil ko'rinish ketma-ket kelsa zerikarli bo'ladi va diqqat
  /// so'nadi. O'yin — nafas rostlash: tez, oson va yoqimli.
  List<DrillQuestion> _withMatchGames(
      List<DrillQuestion> qs, List<DrillSource> src) {
    final pairs = src
        .where((e) =>
            e.pair &&
            e.uz.trim().isNotEmpty &&
            e.en.trim().toLowerCase() != e.uz.trim().toLowerCase())
        .toList();
    if (pairs.length < matchPairs || qs.length <= matchEvery) return qs;

    final out = <DrillQuestion>[];
    for (var i = 0; i < qs.length; i++) {
      out.add(qs[i]);
      final last = i == qs.length - 1;
      if (!last && (i + 1) % matchEvery == 0) {
        out.add(_matchGame(pairs));
      }
    }
    return out;
  }

  DrillQuestion _matchGame(List<DrillSource> pool) {
    final picked = (List.of(pool)..shuffle(_rnd)).take(matchPairs).toList();
    return DrillQuestion(
      itemId: 'game::match',
      format: AskFormat.match,
      prompt: 'So\'zlarni ma\'nosiga moslang',
      answer: '',
      unit: picked.first.unit,
      topic: picked.first.topic,
      pairs: [
        for (final p in picked)
          DrillPair(itemId: p.itemId, en: p.en, uz: p.uz),
      ],
    );
  }

  /// Moslash o'yini yakunlandi.
  ///
  /// [clean] — birinchi urinishda topilgan juftlar. Qolganlari xato
  /// hisoblanadi va o'sha bandlar qayta so'raladi.
  Future<void> answerMatch(Set<String> clean) async {
    final q = current;
    if (q == null || q.format != AskFormat.match) return;

    for (final p in q.pairs) {
      final ok = clean.contains(p.itemId);
      await mastery.record(p.itemId, AskFormat.match, ok: ok);
    }
    if (clean.length == q.pairs.length) {
      _combo += 1;
      if (_combo > _bestCombo) _bestCombo = _combo;
    } else {
      _combo = 0;
    }
    _pos += 1;
    if (_pos >= _queue.length) _advance();
  }

  /// Band uchun KEYINGI mos ko'rinishni tanlaydi.
  ///
  /// Tartib: o'quvchi hali o'tmagan shakl birinchi. Ya'ni tanlashni
  /// bilsa, keyingi safar yozishga o'tadi — shunda "tanidim" emas,
  /// "o'zim ayta olaman" darajasiga yetadi.
  DrillQuestion? _make(DrillSource s, {AskFormat? avoid}) {
    final m = mastery.of(s.itemId);
    for (final f in _formatOrder(s)) {
      if (f == avoid) continue;
      if (m.passed.contains(f)) continue;
      final q = buildQuestion(s, f, _pool(s), _rnd);
      if (q != null) return q;
    }
    // Hammasi o'tilgan bo'lsa — mustahkamlash uchun ishlab chiqarish.
    for (final f in _formatOrder(s)) {
      if (f == avoid) continue;
      final q = buildQuestion(s, f, _pool(s), _rnd);
      if (q != null) return q;
    }
    return null;
  }

  List<DrillSource> _pool(DrillSource s) {
    final all = [...lessonSources, ...earlierSources];
    return all.length > 1 ? all : [s];
  }

  /// Shakllar tartibi.
  ///
  /// LUG'AT so'zlari uchun tartib INTERAKTIV testdan boshlanib,
  /// HARFLAB YOZISh bilan tugaydi (egasining talabi: "lug'atni
  /// ko'proq o'zbekchada so'rasin, user o'zi inglizcha harflab
  /// yozsin, shunda yodlanadi" — va bu interaktiv testlardan KEYIN
  /// qo'shilsin).
  ///
  /// Bu bejiz emas: avval tanish (oson, dopamin), so'ng eslab aytish
  /// (qiyin, mustahkam). Imlo bosqichisiz band `isStrong` bo'lolmaydi
  /// — ya'ni yozish MAJBURIY, faqat oxirida keladi.
  List<AskFormat> _formatOrder(DrillSource s) {
    final vocabLike = s.itemId.startsWith('w::') || s.isSingleWord;
    if (vocabLike) {
      return const [
        AskFormat.choice, // 1) inglizcha -> o'zbekcha (tanish)
        AskFormat.produce, // 2) o'zbekcha -> inglizcha (tanlash)
        AskFormat.build, // 3) o'zbekcha -> inglizchani HARFLAB yozish
        AskFormat.listen, // 4) eshitib yozish
        AskFormat.cloze,
      ];
    }
    return const [
      AskFormat.choice,
      AskFormat.cloze,
      AskFormat.build,
      AskFormat.produce,
      AskFormat.listen,
    ];
  }
}
