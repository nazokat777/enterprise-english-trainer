import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'srs.dart';

/// Ko'nikma turlari (progress bar uchun).
enum Skill { listening, grammar, vocab, reading, speaking }

/// Foydalanuvchi holati + retention yadrosi (streak, kunlik maqsad, XP/coin).
/// Mahalliy saqlanadi (shared_preferences) — offline ishlaydi.
class Progress extends ChangeNotifier {
  int xp = 0;
  int coins = 0;
  int currentStreak = 0;
  int longestStreak = 0;
  int streakFreezeCount = 0;
  String? lastActiveDate; // 'YYYY-MM-DD'
  int dailyGoal = 20; // 10/20/30/50 XP
  int todayXp = 0;
  String _todayKey = '';
  bool darkMode = false;
  String currentLevel = 'beginner'; // beginner | elementary
  final Map<String, int> skills = {}; // Skill.name -> 0..100

  // Per-so'z SM-2 holati (kalit: 'level::wordId') va tugatilgan pack/mashqlar.
  final Map<String, WordSrs> srsMap = {};
  final Set<String> completed = {};

  /// TAKRORLASh kerak bo'lgan mashqlar.
  ///
  /// Mashq tugatilgani — uni O'ZLAShTIRILGANI degani emas. Xato qilib,
  /// keyin to'g'ri topilgan band ham "tugatildi" ga kirardi va yashil
  /// belgi qo'yilardi. Endi xatosiz o'tilmagan mashq shu ro'yxatda
  /// qoladi va ro'yxatda "takrorlash" deb belgilanadi.
  final Set<String> needsReview = {};

  SharedPreferences? _prefs;

  static const int freezeCost = 200; // coin
  static const List<int> goalOptions = [10, 20, 30, 50];
  // Ligalar (simulyatsiya) — 10 daraja.
  static const List<String> leagues = [
    'Bronze', 'Silver', 'Gold', 'Sapphire', 'Ruby',
    'Emerald', 'Amethyst', 'Pearl', 'Obsidian', 'Diamond',
  ];

  String get league => leagues[(xp ~/ 500).clamp(0, leagues.length - 1)];
  double get dailyProgress =>
      dailyGoal == 0 ? 0 : (todayXp / dailyGoal).clamp(0.0, 1.0);
  bool get dailyGoalMet => todayXp >= dailyGoal;
  int skillPercent(Skill s) => skills[s.name] ?? 0;

  // --- Sana yordamchilari ---
  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String get _today => _fmt(DateTime.now());
  String get _yesterday => _fmt(DateTime.now().subtract(const Duration(days: 1)));

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    xp = p.getInt('xp') ?? 0;
    coins = p.getInt('coins') ?? 0;
    currentStreak = p.getInt('streak') ?? 0;
    longestStreak = p.getInt('longestStreak') ?? 0;
    streakFreezeCount = p.getInt('freezes') ?? 0;
    lastUnitNo = p.getInt('lastUnitNo') ?? 0;
    lastExerciseId = p.getString('lastExerciseId') ?? '';
    lastLabel = p.getString('lastLabel') ?? '';
    reviewUnits
      ..clear()
      ..addAll((p.getStringList('reviewUnits') ?? [])
          .map(int.tryParse)
          .whereType<int>());
    unitDone.clear();
    final ud = p.getString('unitDone');
    if (ud != null && ud.isNotEmpty) {
      (json.decode(ud) as Map).forEach((k, v) {
        final n = int.tryParse(k as String);
        if (n != null) unitDone[n] = (v as num).toInt();
      });
    }
    lastActiveDate = p.getString('lastActive');
    dailyGoal = p.getInt('dailyGoal') ?? 20;
    todayXp = p.getInt('todayXp') ?? 0;
    _todayKey = p.getString('todayKey') ?? '';
    darkMode = p.getBool('dark') ?? false;
    currentLevel = p.getString('level') ?? 'beginner';
    final sk = p.getString('skills');
    if (sk != null) {
      (json.decode(sk) as Map)
          .forEach((k, v) => skills[k as String] = (v as num).toInt());
    }
    final srsRaw = p.getString('srs');
    if (srsRaw != null) {
      (json.decode(srsRaw) as Map).forEach((k, v) =>
          srsMap[k as String] = WordSrs.fromJson((v as Map).cast<String, dynamic>()));
    }
    completed.addAll(p.getStringList('completed') ?? []);
    needsReview.addAll(p.getStringList('needsReview') ?? []);
    _rolloverDay();
    await _refreshStreak();
    notifyListeners();
  }

  /// Yangi kun bo'lsa — bugungi XP nolga tushadi.
  void _rolloverDay() {
    if (_todayKey != _today) {
      _todayKey = _today;
      todayXp = 0;
    }
  }

  /// Ilova ochilganda: streak uzilganini tekshirish (freeze bilan himoya).
  ///
  /// MUHIM: natija DARHOL saqlanadi. Ilgari o'zgarish faqat xotirada
  /// qolardi va ilova qayta ochilganda hisob eski holiga qaytardi —
  /// ya'ni 200 coinga sotib olingan bitta muzlatgich cheksiz marta
  /// ishlatilardi.
  Future<void> _refreshStreak() async {
    if (lastActiveDate == null ||
        lastActiveDate == _today ||
        lastActiveDate == _yesterday) {
      return;
    }
    // Bir kundan ko'p o'tkazib yuborilgan.
    if (streakFreezeCount > 0) {
      streakFreezeCount -= 1; // muzlatgich streak'ni saqlaydi
      // O'tkazib yuborilgan kunlar YOPILDI. Bu qator bo'lmasa, ilova
      // shu kuni yana ochilganda ikkinchi muzlatgich ham yechilardi.
      lastActiveDate = _yesterday;
    } else {
      currentStreak = 0; // seriya uzildi
    }
    await _save();
  }

  /// Bugungi faollik uchun streak'ni yangilaydi.
  void _touchStreakToday() {
    if (lastActiveDate == _today) return; // bugun allaqachon hisoblangan
    if (lastActiveDate == _yesterday || lastActiveDate == null) {
      currentStreak = (lastActiveDate == _yesterday) ? currentStreak + 1 : 1;
    } else {
      // Gap bo'lgan (load'da freeze/reset qilingan) — bugundan davom.
      currentStreak = currentStreak > 0 ? currentStreak + 1 : 1;
    }
    lastActiveDate = _today;
    if (currentStreak > longestStreak) longestStreak = currentStreak;
  }

  Future<void> addXp(int amount, {Skill? skill}) async {
    _rolloverDay();
    xp += amount;
    todayXp += amount;
    coins += amount ~/ 10; // har 10 XP → 1 coin
    _touchStreakToday();
    if (skill != null) {
      skills[skill.name] = min(100, (skills[skill.name] ?? 0) + 2);
    }
    await _save();
    notifyListeners();
  }

  Future<void> setDailyGoal(int g) async {
    dailyGoal = g;
    await _save();
    notifyListeners();
  }

  Future<void> toggleDark() async {
    darkMode = !darkMode;
    await _save();
    notifyListeners();
  }

  Future<void> setLevel(String level) async {
    currentLevel = level;
    await _save();
    notifyListeners();
  }

  /// Streak muzlatgichini coin evaziga sotib olish.
  Future<bool> buyStreakFreeze() async {
    if (coins < freezeCost) return false;
    coins -= freezeCost;
    streakFreezeCount += 1;
    await _save();
    notifyListeners();
    return true;
  }

  // --- "Davom etish": oxirgi ochilgan mashq ---
  //
  // 51 unit va 1545 mashq ichida o'quvchi qayerda qolganini O'ZI
  // eslab qolishi kerak edi. Xotirasi yomon odam uchun bu ilovadan
  // foydalanishning eng katta to'sig'i.
  int lastUnitNo = 0;
  String lastExerciseId = '';
  String lastLabel = '';

  Future<void> rememberExercise(
      {required int unit, required String id, required String label}) async {
    if (lastExerciseId == id) return; // o'zgarmagan — yozishning hojati yo'q
    lastUnitNo = unit;
    lastExerciseId = id;
    lastLabel = label;
    await _save();
    notifyListeners();
  }

  /// Butun jarayonni boshidan boshlash.
  ///
  /// Sozlamalarda kerak: oiladagi boshqa odam ilovani noldan
  /// boshlamoqchi bo'lsa, brauzer xotirasini qo'lda tozalashdan
  /// boshqa yo'l yo'q edi.
  Future<void> resetAll() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    xp = 0;
    coins = 0;
    todayXp = 0;
    currentStreak = 0;
    longestStreak = 0;
    streakFreezeCount = 0;
    lastUnitNo = 0;
    lastExerciseId = '';
    lastLabel = '';
    unitDone.clear();
    reviewUnits.clear();
    // null = hali hech qachon ishlatilmagan; load() shunga qaraydi.
    lastActiveDate = null;
    completed.clear();
    needsReview.clear();
    srsMap.clear();
    notifyListeners();
  }

  // --- SM-2 so'z takrorlash ---
  WordSrs srsFor(String wordId) =>
      srsMap.putIfAbsent('$currentLevel::$wordId', () => WordSrs());

  /// Muddati kelgan so'zlar soni (joriy daraja) — sidebar Due badge.
  int dueCount() {
    final now = DateTime.now();
    final prefix = '$currentLevel::';
    return srsMap.entries
        .where((e) => e.key.startsWith(prefix) && e.value.isDue(now))
        .length;
  }

  /// Muddati kelgan so'zlar — eng KECHIKKANIDAN boshlab.
  ///
  /// `dueCount()` allaqachon bor edi ("sidebar Due badge" uchun deb
  /// yozilgan), lekin uni HECH BIR ekran ko'rsatmasdi va muddati
  /// kelgan so'zlarni mashq qilishning yo'li ham yo'q edi — ya'ni
  /// butun takrorlash jadvali ko'rinmas bo'lib qolgandi.
  List<String> dueWordIds({int limit = 20}) {
    final now = DateTime.now();
    final prefix = '$currentLevel::';
    final due = srsMap.entries
        .where((e) => e.key.startsWith(prefix) && e.value.isDue(now))
        .toList()
      ..sort((a, b) {
        final x = a.value.nextReviewAt;
        final y = b.value.nextReviewAt;
        if (x == null && y == null) return 0;
        if (x == null) return -1;
        if (y == null) return 1;
        return x.compareTo(y);
      });
    return due
        .take(limit)
        .map((e) => e.key.substring(prefix.length))
        .toList();
  }

  /// Kitob mashqida XATO qilingan so'zni belgilaydi.
  ///
  /// Bu yerda to'liq SM-2 takrorlash O'TKAZILMAYDI: lug'at mashqlarining
  /// jadvali (interval, keyingi takror sanasi) buzilmasligi kerak.
  /// Faqat "necha marta unutildi" hisobi oshadi — "Qiyin so'zlar"
  /// ro'yxati aynan shundan tuziladi.
  Future<void> recordMiss(String wordId) async {
    final srs = srsFor(wordId);
    srs.lapses += 1;
    // "Qayta o'zlashtirdim" seriyasi UZILADI. Aks holda ilgari
    // o'zlashtirilgan (repetitions >= 3) so'z endi unutilgan bo'lsa
    // ham "Qiyin so'zlar" ro'yxatiga qaytmasdi.
    srs.repetitions = 0;
    await _save();
    notifyListeners();
  }

  /// QIYIN so'zlar — o'quvchi qayta-qayta unutayotganlari.
  ///
  /// Eng qiyinidan boshlab tartiblanadi. Ro'yxat "qaysi so'z ustida
  /// qo'shimcha ishlash kerak" degan savolga javob beradi.
  List<String> hardWordIds({int limit = 50}) {
    final prefix = '$currentLevel::';
    final hard = srsMap.entries
        .where((e) => e.key.startsWith(prefix) && e.value.isHard)
        .toList()
      ..sort((a, b) => b.value.difficulty.compareTo(a.value.difficulty));
    return hard
        .take(limit)
        .map((e) => e.key.substring(prefix.length))
        .toList();
  }

  /// Qiyin so'zlar soni — ekranda ko'rsatish uchun.
  int hardCount() {
    final prefix = '$currentLevel::';
    return srsMap.entries
        .where((e) => e.key.startsWith(prefix) && e.value.isHard)
        .length;
  }

  /// So'zga javob berildi: SM-2 yangilanadi + baho bo'yicha XP.
  Future<void> reviewWord(String wordId, Quality q,
      {Skill skill = Skill.vocab}) async {
    srsFor(wordId).review(q);
    final gain = xpForQuality(q);
    if (gain > 0) {
      await addXp(gain, skill: skill); // saqlaydi + notify (srsMap ham)
    } else {
      await _save();
      notifyListeners();
    }
  }

  bool isDone(String id) => completed.contains('$currentLevel::$id');

  /// Takrorlash kerak bo'lgan mashqlar soni (joriy daraja).
  int needsReviewCount() =>
      needsReview.where((k) => k.startsWith('$currentLevel::')).length;

  /// Mashq TAKRORLAShNI talab qiladimi (xato bilan tugatilgan).
  bool needsRepeat(String id) => needsReview.contains('$currentLevel::$id');

  Future<void> markDone(String id) async {
    completed.add('$currentLevel::$id');
    await _save();
    notifyListeners();
  }

  /// Mashq yakuni: xatosiz o'tilgan bo'lsa ro'yxatdan chiqadi, aks
  /// holda "takrorlash kerak" bo'lib qoladi.
  /// Har bir unitda nechta mashq tugatilgani.
  ///
  /// Unit kartochkasida "12 / 57 mashq" ko'rsatish uchun. Buni
  /// hisoblashning boshqa yo'li — HAMMA unitni yuklab, har bir
  /// mashqni tekshirish; ro'yxat ekranida bu sekin bo'lardi.
  final Map<int, int> unitDone = {};

  int doneInUnit(int unit) => unitDone[unit] ?? 0;

  /// Takrorlash kerak bo'lgan mashqlar QAYSI unitlarda.
  ///
  /// TEZLIK: takrorlash ekrani ilgari BARCHA 51 unitni o'qirdi
  /// (~7 soniya). Endi faqat kerakli unitlar yuklanadi.
  final Set<int> reviewUnits = {};

  Future<void> markExerciseResult(String id,
      {required bool clean, int unit = 0}) async {
    final key = '$currentLevel::$id';
    // Faqat BIRINCHI marta tugatilganda sanaymiz.
    if (unit > 0 && !completed.contains(key)) {
      unitDone[unit] = (unitDone[unit] ?? 0) + 1;
    }
    completed.add(key);
    if (clean) {
      needsReview.remove(key);
    } else {
      needsReview.add(key);
      if (unit > 0) reviewUnits.add(unit);
    }
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setInt('xp', xp);
    await p.setInt('coins', coins);
    await p.setInt('streak', currentStreak);
    await p.setInt('longestStreak', longestStreak);
    await p.setInt('freezes', streakFreezeCount);
    await p.setInt('lastUnitNo', lastUnitNo);
    await p.setString('lastExerciseId', lastExerciseId);
    await p.setString('lastLabel', lastLabel);
    await p.setStringList(
        'reviewUnits', reviewUnits.map((e) => '$e').toList());
    await p.setString('unitDone',
        json.encode(unitDone.map((k, v) => MapEntry('$k', v))));
    if (lastActiveDate != null) await p.setString('lastActive', lastActiveDate!);
    await p.setInt('dailyGoal', dailyGoal);
    await p.setInt('todayXp', todayXp);
    await p.setString('todayKey', _todayKey);
    await p.setBool('dark', darkMode);
    await p.setString('level', currentLevel);
    await p.setString('skills', json.encode(skills));
    await p.setString('srs',
        json.encode(srsMap.map((k, v) => MapEntry(k, v.toJson()))));
    await p.setStringList('completed', completed.toList());
    await p.setStringList('needsReview', needsReview.toList());
  }
}
