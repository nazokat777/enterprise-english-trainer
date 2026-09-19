import 'dart:math';

import '../drill/drill_item.dart';
import '../mastery.dart';
import '../services/tts.dart';
import 'word_lesson.dart';

/// SO'Z DARSI DVIGATELI — Duolingo uslubidagi qisqa seans.
///
/// Tartib (har so'z uchun uch bosqich, bosqichlar raundlarga bo'lingan):
///   1-raund: inglizcha -> o'zbekcha TANISh (4 variant)
///   2-raund: o'zbekcha -> inglizcha TANLASh (4 variant)
///   3-raund: o'zbekcha -> inglizchani HARFLAB yig'ish
///
/// Xato qilingan so'z ShU raundda, 2 savoldan keyin QAYTADI — o'sha
/// shaklda. Seans hamma savolga to'g'ri javob berilganda tugaydi,
/// shuning uchun oxirida har so'z uch shaklda ham "o'tilgan" bo'ladi
/// va `ItemMastery.isStrong` ga yetadi.
class LessonSession {
  final WordLesson lesson;
  final MasteryStore mastery;

  /// Chalg'ituvchi variantlar uchun kengroq havza (unitning boshqa
  /// so'zlari). Faqat 7 so'zdan variant yasalsa, javob "qolganini
  /// chiqarib tashlash" bilan topiladi.
  final List<DrillSource> pool;

  /// ARALASH TAKROR (interleaving): oldingi darslardan o'chib
  /// ketayotgan 1-3 so'z shu darsning savollari orasiga qo'shiladi —
  /// ishlab chiqarish shaklida, bittadan. Yangi so'zlar orasida eski
  /// so'zni eslab aytish uni yangidan mustahkamlaydi (spacing +
  /// interleaving effekti) va o'quvchiga qo'shimcha seans yuklamaydi.
  final List<DrillSource> extras;

  /// Raundlar (shakl ketma-ketligi). Odatda `rounds`; qutqaruvda
  /// faqat ishlab chiqarish — tanish shakllari eslab aytishga
  /// hech narsa qo'shmaydi.
  final List<AskFormat> formats;

  /// So'zning neural ovozi bormi — 3-raundda har ikkinchi so'z
  /// "eshitib yoz" shaklida so'raladi (fonologik xotira: so'z
  /// ko'rinishi bilan birga OVOZI ham yodlanadi). Ovozsiz so'z
  /// odatdagidek harflab yoziladi.
  final bool Function(String en) hasAudio;

  /// TALAFFUZ raundi qo'shilsinmi — brauzer nutq tanishni
  /// qo'llab-quvvatlasa (Chrome/Edge/Safari). Ovoz chiqarib aytish =
  /// ishlab chiqarish effekti + artikulyatsiya xotirasi: so'z og'iz
  /// bilan ham "yoziladi". 3-raunddan keyin, kontekstdan oldin.
  final bool canSpeak;

  final Random _rnd;
  final List<DrillQuestion> _queue = [];
  int _pos = 0;
  int _answered = 0;
  int _mistakes = 0;

  /// Shu seansda xato qilingan so'zlar — yakunda eslatma taklifi uchun.
  final Set<String> mistakenIds = {};

  /// 4-raund — KONTEKST: misol gapdagi bo'shliqni to'ldirish. Faqat
  /// gap bor so'zlar uchun (qolganlariga `buildQuestion` null beradi).
  static const List<AskFormat> rounds = [
    AskFormat.choice,
    AskFormat.produce,
    AskFormat.build,
    AskFormat.cloze,
  ];

  LessonSession({
    required this.lesson,
    required this.mastery,
    this.pool = const [],
    this.extras = const [],
    this.formats = rounds,
    this.canSpeak = false,
    bool Function(String en)? hasAudio,
    Random? random,
  })  : hasAudio = hasAudio ?? Tts.instance.hasNeural,
        _rnd = random ?? Random() {
    _fill();
    _sprinkle();
  }

  /// Eski so'zlar 2-raunddan boshlab tasodifiy joylarga.
  void _sprinkle() {
    if (extras.isEmpty || _queue.isEmpty) return;
    final n = lesson.sources.length;
    for (final e in extras) {
      final q = buildQuestion(e, AskFormat.produce, [e, ...pool, ...lesson.sources], _rnd) ??
          buildQuestion(e, AskFormat.build, [e], _rnd);
      if (q == null) continue;
      final at = n + _rnd.nextInt((_queue.length - n).clamp(1, 1 << 30));
      _queue.insert(at.clamp(0, _queue.length), q);
    }
  }

  /// Aralash takrordagi so'zlar nechta.
  int get extraCount => extras.length;

  /// Haqiqiy raundlar: `formats` + (qo'llansa) talaffuz `build`dan keyin.
  List<AskFormat> get _rounds {
    if (!canSpeak || formats.contains(AskFormat.speak)) return formats;
    final i = formats.indexOf(AskFormat.build);
    if (i < 0) return formats;
    return [...formats.sublist(0, i + 1), AskFormat.speak, ...formats.sublist(i + 1)];
  }

  void _fill() {
    final src = lesson.sources;
    for (final f in _rounds) {
      final round = <DrillQuestion>[];
      for (var i = 0; i < src.length; i++) {
        final s = src[i];
        var fmt = f;
        if (f == AskFormat.build && i.isOdd && hasAudio(s.en)) {
          fmt = AskFormat.listen;
        }
        final q = buildQuestion(s, fmt, _poolFor(s), _rnd) ??
            (fmt == AskFormat.listen
                ? buildQuestion(s, f, _poolFor(s), _rnd)
                : null);
        if (q != null) round.add(q);
      }
      round.shuffle(_rnd);
      _queue.addAll(round);
    }
  }

  /// Chalg'ituvchilar AVVAL shu darsning so'zlaridan: o'quvchi aynan
  /// hozir o'rganayotgan 7 so'zni bir-biridan ajratishni o'rgansin.
  /// Dars kichik bo'lsa (4 tadan kam) unit lug'ati qo'shiladi.
  List<DrillSource> _poolFor(DrillSource s) {
    final mates = lesson.sources.where((e) => e.itemId != s.itemId).toList();
    if (mates.length >= 3) return [s, ...mates];
    final all = [...lesson.sources, ...pool];
    return all.length > 1 ? all : [s];
  }

  /// Hozirgi savol; tugagan bo'lsa `null`.
  DrillQuestion? get current => _pos < _queue.length ? _queue[_pos] : null;

  bool get isDone => current == null;

  /// 0..1 — seans qanchasi o'tildi (xatolar navbatni uzaytiradi).
  double get progress => _queue.isEmpty ? 1 : _answered / _queue.length;

  int get remaining => _queue.length - _pos;
  int get mistakes => _mistakes;

  /// Qaysi raund ketyapti (1..3) — sarlavha uchun.
  int get round {
    final q = current;
    if (q == null) return _rounds.length;
    final f = q.format == AskFormat.listen ? AskFormat.build : q.format;
    return _rounds.indexOf(f) + 1;
  }

  /// Talaffuzni o'tkazib yuborish (mikrofon yo'q/ishlamadi) — xato
  /// hisoblanmaydi, mastery'ga yozilmaydi, navbatga qaytmaydi.
  void skip() {
    if (current == null) return;
    _answered += 1;
    _pos += 1;
  }

  Future<void> answer(bool ok) async {
    final q = current;
    if (q == null) return;
    final src = _sourceOf(q.itemId);
    await mastery.record(q.itemId, q.format,
        ok: ok, en: src?.en ?? '', uz: src?.uz ?? '');
    _answered += 1;
    if (!ok) {
      _mistakes += 1;
      mistakenIds.add(q.itemId);
      _requeue(q);
    }
    _pos += 1;
  }

  /// Xato so'z 2 savoldan keyin o'sha shaklda qaytadi — yangi
  /// variantlar bilan (javobning o'rnini yodlab olib bo'lmasin).
  DrillSource? _sourceOf(String id) {
    for (final e in lesson.sources) {
      if (e.itemId == id) return e;
    }
    for (final e in extras) {
      if (e.itemId == id) return e;
    }
    return null;
  }

  void _requeue(DrillQuestion q) {
    final src = _sourceOf(q.itemId)!;
    // Eshitib yozish xato bo'lsa ham shu shaklda qaytadi (ovoz bor).
    final next = buildQuestion(src, q.format, _poolFor(src), _rnd) ?? q;
    final at = (_pos + 3).clamp(0, _queue.length);
    _queue.insert(at, next);
  }
}
