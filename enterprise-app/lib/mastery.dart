import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// O'ZLAShTIRISH YADROSI — "bu odam nimani biladi, nimani bilmaydi".
//
// Nega alohida model kerak edi:
//
// * `Progress.completed` faqat "mashq ochilganmi" ni biladi — bandlar
//   darajasida emas. Ya'ni 12 bandli mashqning qaysi 3 tasi
//   yodlanmaganini ilova ayta olmasdi.
// * `WordSrs` faqat LUG'AT so'zlari uchun. Grammatika bandlari,
//   gap tuzish, tinglash — hech qayerda hisoblanmasdi.
//
// Asosiy g'oya (o'rganish ilmidan):
//
// 1. **Retrieval practice** — har takror ESLAB AYTISh bo'lsin, qayta
//    o'qish emas. Shuning uchun holat faqat SAVOLGA javob berilganda
//    o'zgaradi.
// 2. **Turli shakl** — bitta band bir necha ko'rinishda so'raladi
//    (tanish, bo'shliq, ishlab chiqarish). Bitta shaklda to'g'ri
//    javob "bilaman" degani emas: o'quvchi savol KO'RINIShINI yodlab
//    olishi mumkin. Shuning uchun `strong` bo'lish uchun kamida ikki
//    XIL shakl va ulardan biri ishlab chiqarish bo'lishi shart.
// 3. **Xato = qadam orqaga**, lekin jazo emas: `lapses` o'sadi va
//    band "zaif" ro'yxatiga tushadi.

// Savol shakli — oson tanishdan qiyin ishlab chiqarishgacha.
enum AskFormat {
  /// Variantlardan tanlash (tanish).
  choice,

  /// Juftlarni moslash (tanish).
  match,

  /// Gapdagi bo'shliqni to'ldirish (yarim ishlab chiqarish).
  cloze,

  /// Harflardan/so'zlardan yig'ish (ishlab chiqarish).
  build,

  /// Tinglab yozish (ishlab chiqarish + tinglash).
  listen,

  /// O'zbekchadan inglizchaga (eng qiyin — to'liq eslab aytish).
  produce,
}

// Ishlab chiqarish shakllari — "tanidim" emas, "o'zim ayta olaman".
const Set<AskFormat> kProductionFormats = {
  AskFormat.build,
  AskFormat.listen,
  AskFormat.produce,
};

// Bitta bandning o'zlashtirish holati.
class ItemMastery {
  /// Nechta to'g'ri javob (jami).
  int correct;

  /// Nechta xato — "bu menga qiyin" tarixi.
  int lapses;

  /// Qaysi shakllarda to'g'ri javob berilgan.
  final Set<AskFormat> passed;

  /// Oxirgi marta qachon so'ralgan (ms).
  int lastAskedMs;

  /// XOTIRA JADVALI (spaced repetition) — keyingi takrorlashgacha kun.
  ///
  /// Ilgari band `isStrong` bo'lgach ilova uni QAYTA HECH SO'RAMASDI —
  /// unutish egri chizig'i (Ebbinghaus) esa 2-3 kundan keyin yodlangan
  /// so'zning yarmini o'chiradi. Endi har to'g'ri javob intervalni
  /// zinapoya bo'ylab oshiradi (1 -> 3 -> 7 -> 14 -> 30 -> 60 -> 120
  /// kun), xato esa 1 kunga qaytaradi. Interval oshgani sari so'z
  /// "o'sadi" (`stage`) — o'quvchi o'z xotirasi o'sishini KO'RADI.
  int interval;

  /// Keyingi takrorlash vaqti (ms). 0 = hali rejalashtirilmagan.
  int dueMs;

  /// O'quvchining O'Z eslatmasi (mnemonika) — "generation effect":
  /// o'zi o'ylab topgan bog'lanish tayyor berilganidan 2-3 barobar
  /// mustahkam yodda qoladi.
  String hook;

  /// Ko'rsatish uchun o'zbekcha ma'no (qutqaruv seansi qaytadan
  /// kitobni yuklamasdan savol tuza olsin).
  String en;
  String uz;

  ItemMastery({
    this.correct = 0,
    this.lapses = 0,
    Set<AskFormat>? passed,
    this.lastAskedMs = 0,
    this.interval = 0,
    this.dueMs = 0,
    this.hook = '',
    this.en = '',
    this.uz = '',
  }) : passed = passed ?? <AskFormat>{};

  /// Interval zinapoyasi (kun).
  static const List<int> ladder = [1, 3, 7, 14, 30, 60, 120];

  /// Xotira bosqichi 0..4: 🌱 urug' -> 🌿 nihol -> 🌳 daraxt ->
  /// 💎 kristall -> 🏆 abadiy. Interval bo'yicha.
  int get stage {
    if (interval >= 60) return 4;
    if (interval >= 14) return 3;
    if (interval >= 7) return 2;
    if (interval >= 3) return 1;
    return 0;
  }

  static const List<String> stageEmoji = ['🌱', '🌿', '🌳', '💎', '🏆'];
  static const List<String> stageName = [
    'Urug\'',
    'Nihol',
    'Daraxt',
    'Kristall',
    'Abadiy',
  ];

  String get stageIcon => stageEmoji[stage];

  /// O'chib ketish arafasida: muddati o'tgan va hali "abadiy" emas.
  bool isFading(int nowMs) =>
      dueMs > 0 && nowMs >= dueMs && !isNew && stage < 4;

  /// Necha kun kechikkan (0 = hali muddati kelmagan).
  int overdueDays(int nowMs) =>
      dueMs == 0 || nowMs < dueMs ? 0 : (nowMs - dueMs) ~/ 86400000;

  /// Javobdan keyin jadvalni yangilaydi.
  ///
  /// Ishlab chiqarish shakli (yozish, eshitib yozish) tanishdan
  /// kuchliroq dalil — u zinapoyada bir pog'ona ko'proq ko'taradi.
  void schedule(bool ok, AskFormat format, int nowMs) {
    if (!ok) {
      interval = 1;
    } else {
      // Bir seansda so'z 3 marta so'raladi — har biri alohida "kun"
      // hisoblanmasin: intervalning yarmi o'tmagan bo'lsa, jadval
      // o'zgarmaydi (Anki ham erta takrorni sanamaydi).
      final early = dueMs > 0 && nowMs < dueMs - interval * 43200000;
      if (early) return;
      var i = ladder.indexWhere((d) => d > interval);
      if (i < 0) i = ladder.length - 1;
      if (kProductionFormats.contains(format) && i + 1 < ladder.length) {
        i += 1;
      }
      interval = ladder[i];
    }
    dueMs = nowMs + interval * 86400000;
  }

  /// Hali umuman so'ralmagan.
  bool get isNew => correct == 0 && lapses == 0;

  /// O'ZLAShTIRILGAN: kamida ikki xil shaklda to'g'ri, ulardan biri
  /// ishlab chiqarish.
  ///
  /// Faqat "bir marta to'g'ri" mezoni yetarli emas edi: o'quvchi
  /// variantlardan tanlashni yodlab olishi mumkin, lekin so'zni o'zi
  /// ayta olmasligi mumkin.
  bool get isStrong =>
      passed.length >= 2 && passed.any(kProductionFormats.contains);

  /// Qiyin: kamida ikki marta xato qilingan va hali mustahkam emas.
  bool get isWeak => lapses >= 2 && !isStrong;

  /// QISMAN baho (0..1) — halqa uchun.
  ///
  /// `isStrong` faqat "tugadi"ni biladi. Agar halqa faqat shunga
  /// qarasa, o'quvchi olti marta to'g'ri javob berib ham 0% ni
  /// ko'radi — mehnat natijasi ko'rinmasa, motivatsiya so'nadi
  /// (nevrologiya: mukofot signali harakat bilan bog'lanishi kerak).
  /// Shuning uchun har o'tilgan SHAKL ham hisobga olinadi.
  double get score {
    if (isStrong) return 1;
    return (passed.length * 0.4).clamp(0.0, 0.8);
  }

  /// Ro'yxatni tartiblash uchun: katta = ko'proq ish kerak.
  double get needScore {
    if (isStrong) return 0;
    return lapses * 10 + (2 - passed.length) * 3 + (isNew ? 1 : 0);
  }

  Map<String, dynamic> toJson() => {
        'c': correct,
        'l': lapses,
        'f': passed.map((e) => e.index).toList(),
        't': lastAskedMs,
        if (interval > 0) 'iv': interval,
        if (dueMs > 0) 'd': dueMs,
        if (hook.isNotEmpty) 'h': hook,
        if (en.isNotEmpty) 'e': en,
        if (uz.isNotEmpty) 'u': uz,
      };

  factory ItemMastery.fromJson(Map<String, dynamic> j) => ItemMastery(
        correct: (j['c'] as num?)?.toInt() ?? 0,
        lapses: (j['l'] as num?)?.toInt() ?? 0,
        passed: {
          for (final i in (j['f'] as List? ?? []))
            if ((i as num).toInt() < AskFormat.values.length)
              AskFormat.values[i.toInt()],
        },
        lastAskedMs: (j['t'] as num?)?.toInt() ?? 0,
        interval: (j['iv'] as num?)?.toInt() ?? 0,
        dueMs: (j['d'] as num?)?.toInt() ?? 0,
        hook: (j['h'] as String?) ?? '',
        en: (j['e'] as String?) ?? '',
        uz: (j['u'] as String?) ?? '',
      );
}

// Bandlarning o'zlashtirish holatini saqlaydigan ombor.
//
// Kalit: `<daraja>::<band id>`. Band id lari:
//   `t::<mashq progressId>::<band raqami>` — mashq bandi
//   `w::<so'z>`                            — lug'at so'zi
class MasteryStore extends ChangeNotifier {
  final Map<String, ItemMastery> _items = {};
  SharedPreferences? _prefs;
  String _level = 'beginner';

  static const _key = 'mastery';

  /// Nechta band kuzatilyapti (test uchun).
  int get trackedCount => _items.length;

  Future<void> load({String level = 'beginner'}) async {
    _level = level;
    _prefs = await SharedPreferences.getInstance();
    _items.clear();
    final raw = _prefs?.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        (json.decode(raw) as Map).forEach((k, v) {
          _items[k as String] =
              ItemMastery.fromJson((v as Map).cast<String, dynamic>());
        });
      } catch (_) {
        // Buzilgan yozuv ilovani yiqitmasin — noldan boshlanadi.
        _items.clear();
      }
    }
  }

  void setLevel(String level) {
    _level = level;
    notifyListeners();
  }

  String _k(String itemId) => '$_level::$itemId';

  ItemMastery of(String itemId) =>
      _items.putIfAbsent(_k(itemId), () => ItemMastery());

  /// Javob yozildi. [ok] — to'g'rimi, [format] — qaysi ko'rinishda.
  Future<void> record(String itemId, AskFormat format,
      {required bool ok, String en = '', String uz = '', int? nowMs}) async {
    final m = of(itemId);
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    m.lastAskedMs = now;
    if (en.isNotEmpty) m.en = en;
    if (uz.isNotEmpty) m.uz = uz;
    m.schedule(ok, format, now);
    if (ok) {
      m.correct += 1;
      m.passed.add(format);
    } else {
      m.lapses += 1;
      // Xatodan keyin shu shakl "o'tilgan" hisoblanmaydi: band shu
      // ko'rinishda qayta so'ralishi kerak.
      m.passed.remove(format);
    }
    await _save();
    notifyListeners();
  }

  /// Berilgan bandlar ichida nechtasi o'zlashtirilgan.
  int strongCount(Iterable<String> itemIds) =>
      itemIds.where((id) => of(id).isStrong).length;

  /// 0..1 — shu to'plamning o'zlashtirilish ulushi.
  double ratio(Iterable<String> itemIds) {
    final list = itemIds.toList();
    if (list.isEmpty) return 1;
    return strongCount(list) / list.length;
  }

  /// Eng ko'p ish talab qiladigan bandlar (zaifdan boshlab).
  List<String> weakest(Iterable<String> itemIds, {int limit = 20}) {
    final list = itemIds.where((id) => !of(id).isStrong).toList()
      ..sort((a, b) => of(b).needScore.compareTo(of(a).needScore));
    return list.take(limit).toList();
  }

  /// QISMAN baholi ulush (0..1) — seans halqasi uchun.
  ///
  /// `ratio` faqat TUGAGAN bandlarni sanaydi; bu esa har bir to'g'ri
  /// javobni ko'rsatadi.
  double progressScore(Iterable<String> itemIds) {
    final list = itemIds.toList();
    if (list.isEmpty) return 1;
    var sum = 0.0;
    for (final id in list) {
      sum += of(id).score;
    }
    return sum / list.length;
  }

  /// Hammasi o'zlashtirilganmi — "100% javob berilgunicha" mezoni.
  bool allStrong(Iterable<String> itemIds) =>
      itemIds.every((id) => of(id).isStrong);

  /// O'quvchining o'z eslatmasini saqlaydi.
  Future<void> setHook(String itemId, String hook) async {
    of(itemId).hook = hook.trim();
    await _save();
    notifyListeners();
  }

  /// O'ChIB KETAYoTGAN so'zlar (joriy daraja) — eng kechikkanidan.
  ///
  /// Faqat lug'at so'zlari (`w::`): mashq bandlari kitob mashqida
  /// takrorlanadi, ular uchun alohida qutqaruv seansi tuzilmaydi.
  List<String> fadingIds({int limit = 10, int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final prefix = '$_level::w::';
    final list = _items.entries
        .where((e) =>
            e.key.startsWith(prefix) &&
            e.value.isFading(now) &&
            e.value.uz.isNotEmpty)
        .toList()
      ..sort((a, b) => a.value.dueMs.compareTo(b.value.dueMs));
    return list
        .take(limit)
        .map((e) => e.key.substring('$_level::'.length))
        .toList();
  }

  int fadingCount({int? nowMs}) => fadingIds(limit: 1 << 20, nowMs: nowMs).length;

  /// Xotira bog'i: har bosqichda nechta so'z (joriy daraja, lug'at).
  List<int> garden() {
    final out = List<int>.filled(ItemMastery.stageEmoji.length, 0);
    final prefix = '$_level::w::';
    for (final e in _items.entries) {
      if (!e.key.startsWith(prefix) || e.value.isNew) continue;
      out[e.value.stage] += 1;
    }
    return out;
  }

  Future<void> reset() async {
    _items.clear();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(
        _key, json.encode(_items.map((k, v) => MapEntry(k, v.toJson()))));
  }
}
