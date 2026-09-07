import 'dart:math';

import '../book_content.dart';
import '../mastery.dart';

/// BITTA SAVOL — darsdan yasalgan interaktiv topshiriq.
///
/// Bir xil BAND (`itemId`) bir necha xil ko'rinishda so'ralishi mumkin:
/// bugun variantdan tanlash, ertaga harflardan yig'ish. Shu sababli
/// savol va band alohida tushunchalar.
class DrillQuestion {
  /// O'zlashtirish hisobidagi band kaliti (`t::...` yoki `w::...`).
  final String itemId;

  /// Qaysi ko'rinishda so'ralyapti.
  final AskFormat format;

  /// Ekrandagi savol matni.
  final String prompt;

  /// Savol tagidagi o'zbekcha izoh (bo'lishi shart emas).
  final String promptUz;

  /// To'g'ri javob.
  final String answer;

  /// Tanlov variantlari (choice/cloze uchun; boshqalarda bo'sh).
  final List<String> options;

  /// Ovoz chiqariladigan matn (listen uchun savolning O'ZI).
  final String speak;

  /// Qaysi darsdan — aralash raundda manbani ko'rsatish uchun.
  final int unit;

  /// Bo'lim nomi — tashxis uchun ("Grammatika", "Lug'at").
  final String topic;

  const DrillQuestion({
    required this.itemId,
    required this.format,
    required this.prompt,
    required this.answer,
    this.promptUz = '',
    this.options = const [],
    this.speak = '',
    this.unit = 0,
    this.topic = '',
  });

  /// Harf yoki so'z bo'laklari (build uchun).
  List<String> get pieces => answer.trim().contains(' ')
      ? answer.trim().split(RegExp(r'\s+'))
      : answer.trim().split('');
}

/// Bitta o'rganish birligi — savolga aylanishi mumkin bo'lgan manba.
///
/// Kitobdan ikki xil manba keladi:
///   * mashq bandi (savol + javob),
///   * unit lug'ati (inglizcha + o'zbekcha).
class DrillSource {
  final String itemId;
  final String en;
  final String uz;

  /// Bo'shliqli gap (bo'lsa) — cloze uchun.
  final String sentence;

  /// Tayyor variantlar (kitobdagi mashqdan) — bo'lsa ishlatiladi.
  final List<String> options;

  final int unit;
  final String topic;

  const DrillSource({
    required this.itemId,
    required this.en,
    required this.uz,
    this.sentence = '',
    this.options = const [],
    this.unit = 0,
    this.topic = '',
  });

  /// Javob bitta so'zmi — harflardan yig'ish uchun mos.
  bool get isSingleWord => !en.trim().contains(' ');
}

/// Bo'shliq belgisi — kitobdagi mashqlarda ham shu ishlatiladi.
const String kBlank = '_____';

/// Darsdan o'rganish birliklarini yig'adi.
///
/// Mashqning HAR BIR bandi alohida birlik: 12 bandli mashqning qaysi
/// 3 tasi yodlanmagani shundan bilinadi. Ilgari hisob faqat mashq
/// darajasida edi.
List<DrillSource> sourcesFromUnit(BookUnit u) {
  final out = <DrillSource>[];
  final seen = <String>{};

  for (final s in u.sections) {
    for (final e in s.exercises) {
      for (var i = 0; i < e.tasks.length; i++) {
        final t = e.tasks[i];
        final id = 't::${e.progressId}::$i';
        final pair = _pairOf(e.kind, t);
        if (pair == null) continue;
        if (!seen.add(pair.$1.toLowerCase())) continue;
        out.add(DrillSource(
          itemId: id,
          en: pair.$1,
          uz: pair.$2,
          sentence: _sentenceOf(t, pair.$1),
          options: e.kind == ExKind.choice ? t.options : const [],
          unit: u.unit,
          topic: s.titleUz,
        ));
      }
    }
  }

  // Unit lug'ati — kitob oxiridagi so'z ro'yxati.
  for (final v in u.vocabulary) {
    final en = v.en.trim();
    if (en.isEmpty || v.uz.trim().isEmpty) continue;
    if (!seen.add(en.toLowerCase())) continue;
    out.add(DrillSource(
      itemId: 'w::${en.toLowerCase()}',
      en: en,
      uz: v.uz.trim(),
      unit: u.unit,
      topic: 'Lug\'at',
    ));
  }
  return out;
}

/// Banddan (inglizcha, o'zbekcha) juftini ajratadi.
///
/// Har bir band savolga yaramaydi: javobi yo'q yoki tarjimasi yo'q
/// bandlar tashlab yuboriladi — aks holda "javobsiz savol" chiqadi.
(String, String)? _pairOf(ExKind kind, ExTask t) {
  switch (kind) {
    case ExKind.match:
      if (t.left.trim().isEmpty || t.right.trim().isEmpty) return null;
      return (t.left.trim(), t.right.trim());
    case ExKind.study:
      if (t.en.trim().isEmpty || t.uz.trim().isEmpty) return null;
      return (t.en.trim(), t.uz.trim());
    case ExKind.choice:
    case ExKind.text:
      if (t.answer.trim().isEmpty) return null;
      final uz = t.promptUz.trim().isNotEmpty ? t.promptUz.trim() : '';
      return (t.answer.trim(), uz);
  }
}

/// Javob o'rniga bo'shliq qo'yilgan gap.
String _sentenceOf(ExTask t, String answer) {
  final p = t.prompt.trim();
  if (p.isEmpty || answer.isEmpty) return '';
  // Savolda javob ALLAQAChON bo'shliq bilan berilgan bo'lishi mumkin.
  if (p.contains(kBlank) || p.contains('___')) return p;
  final re = RegExp(r'\b' + RegExp.escape(answer) + r'\b', caseSensitive: false);
  if (!re.hasMatch(p)) return '';
  return p.replaceAll(re, kBlank);
}

/// Bitta birlikdan berilgan ko'rinishda savol yasaydi.
///
/// [pool] — chalg'ituvchi variantlar uchun boshqa birliklar.
/// Mos savol yasab bo'lmasa `null` qaytadi (masalan cloze uchun gap
/// yo'q) — chaqiruvchi boshqa ko'rinishni tanlaydi.
DrillQuestion? buildQuestion(
  DrillSource s,
  AskFormat format,
  List<DrillSource> pool,
  Random rnd,
) {
  final q = _build(s, format, pool, rnd);
  if (q == null) return null;
  // UMUMIY QO'RIQChI: savol javobning O'ZI bo'lib qolmasin.
  //
  // "golf", "Dublin", "Morrison" kabi o'zlashma so'z va atoqli otlarda
  // o'zbekcha tarjima inglizchasi bilan AYNAN bir xil. Bunday bandda
  // har qanday savol "javobni ko'chir" ga aylanadi.
  if (_norm(q.prompt) == _norm(q.answer)) return null;
  return q;
}

String _norm(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

DrillQuestion? _build(
  DrillSource s,
  AskFormat format,
  List<DrillSource> pool,
  Random rnd,
) {
  switch (format) {
    case AskFormat.choice:
      // O'zbekchasi yo'q band bu ko'rinishga YARAMAYDI: javob ham,
      // savol ham inglizcha bo'lib qoladi va javob savolning O'ZIDA
      // ko'rinib turadi.
      if (s.uz.trim().isEmpty) return null;
      final opts = _options(s, pool, rnd, useUz: true);
      if (opts.length < 2) return null;
      return DrillQuestion(
        itemId: s.itemId,
        format: format,
        prompt: s.en,
        promptUz: '',
        answer: s.uz,
        options: opts,
        speak: s.en,
        unit: s.unit,
        topic: s.topic,
      );

    case AskFormat.match:
      // Moslash bir nechta juftni talab qiladi — seans darajasida
      // yig'iladi, bitta birlikdan yasalmaydi.
      return null;

    case AskFormat.cloze:
      if (s.sentence.isEmpty) return null;
      final opts = _options(s, pool, rnd, useUz: false);
      if (opts.length < 2) return null;
      return DrillQuestion(
        itemId: s.itemId,
        format: format,
        prompt: s.sentence,
        promptUz: s.uz,
        answer: s.en,
        options: opts,
        unit: s.unit,
        topic: s.topic,
      );

    case AskFormat.build:
      if (s.en.trim().length < 2) return null;
      // Savol O'ZBEKChA bo'lishi SHART. Aks holda savol matni
      // javobning o'zi bo'lib qoladi — o'quvchi shunchaki ko'chiradi
      // va hech narsa yodlanmaydi.
      if (s.uz.trim().isEmpty) return null;
      return DrillQuestion(
        itemId: s.itemId,
        format: format,
        prompt: s.uz,
        answer: s.en,
        speak: s.en,
        unit: s.unit,
        topic: s.topic,
      );

    case AskFormat.listen:
      if (s.en.trim().isEmpty) return null;
      // Tinglab yozishda savol matni ko'rsatilmaydi (faqat ovoz va
      // o'zbekcha izoh), shuning uchun tarjima bo'lmasa ham bo'ladi.
      // Lekin javob juda uzun bo'lsa eshitib yozib bo'lmaydi.
      if (s.en.trim().split(RegExp(r'\s+')).length > 6) return null;
      return DrillQuestion(
        itemId: s.itemId,
        format: format,
        prompt: 'Eshiting va yozing',
        promptUz: s.uz,
        answer: s.en,
        speak: s.en,
        unit: s.unit,
        topic: s.topic,
      );

    case AskFormat.produce:
      if (s.uz.trim().isEmpty) return null;
      final opts = _options(s, pool, rnd, useUz: false);
      if (opts.length < 2) return null;
      return DrillQuestion(
        itemId: s.itemId,
        format: format,
        prompt: s.uz,
        answer: s.en,
        options: opts,
        unit: s.unit,
        topic: s.topic,
      );
  }
}

/// To'g'ri javob + chalg'ituvchilar.
///
/// Chalg'ituvchi javobga TENG bo'lmasligi kerak — aks holda ikkita
/// to'g'ri variant chiqadi va savolning javobi yo'q bo'lib qoladi.
List<String> _options(
  DrillSource s,
  List<DrillSource> pool,
  Random rnd, {
  required bool useUz,
}) {
  final answer = (useUz ? s.uz : s.en).trim();
  if (answer.isEmpty) return const [];

  // Kitobning O'Z variantlari bo'lsa — ular eng tabiiy chalg'ituvchi.
  if (!useUz && s.options.length >= 2 && s.options.contains(answer)) {
    return List.of(s.options)..shuffle(rnd);
  }

  final seen = <String>{answer.toLowerCase()};
  final out = <String>[answer];
  final others = List.of(pool)..shuffle(rnd);
  for (final o in others) {
    if (out.length >= 4) break;
    if (o.itemId == s.itemId) continue;
    final v = (useUz ? o.uz : o.en).trim();
    if (v.isEmpty || !seen.add(v.toLowerCase())) continue;
    out.add(v);
  }
  if (out.length < 2) return const [];
  return out..shuffle(rnd);
}
