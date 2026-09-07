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

  ItemMastery({
    this.correct = 0,
    this.lapses = 0,
    Set<AskFormat>? passed,
    this.lastAskedMs = 0,
  }) : passed = passed ?? <AskFormat>{};

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
      {required bool ok}) async {
    final m = of(itemId);
    m.lastAskedMs = DateTime.now().millisecondsSinceEpoch;
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
