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
    _rolloverDay();
    _refreshStreak();
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
  void _refreshStreak() {
    if (lastActiveDate == null ||
        lastActiveDate == _today ||
        lastActiveDate == _yesterday) {
      return;
    }
    // Bir kundan ko'p o'tkazib yuborilgan.
    if (streakFreezeCount > 0) {
      streakFreezeCount -= 1; // muzlatgich streak'ni saqlaydi
    } else {
      currentStreak = 0; // seriya uzildi
    }
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
  Future<void> markDone(String id) async {
    completed.add('$currentLevel::$id');
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
  }
}
