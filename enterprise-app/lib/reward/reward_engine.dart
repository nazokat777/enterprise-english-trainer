import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dofamin dvigateli — mukofot tizimining YADROSI.
///
/// Neyrobiologik asos (qisqa):
///  * KUTILMAGAN mukofot (variable ratio) dofaminni eng ko'p chiqaradi —
///    shuning uchun KRIT, gem va sandiq TASODIFIY.
///  * YAQIN MAQSAD (goal gradient) — kombo bosqichlari, kunlik
///    topshiriqlar, daraja halqasi "oz qoldi" hissini beradi.
///  * YIG'ISh (endowment) — yutuqlar (medallar) yo'qotgisi kelmaydigan
///    boylik.
///  * DARHOL javob — har hodisa `events` oqimiga tushadi; overlay uni
///    ovoz + harakat + rang bilan sezgi tajribasiga aylantiradi.
///
/// Dvigatel UI ni bilmaydi: faqat holat + hodisalar. Overlay
/// (`reward_overlay.dart`) va ovoz (`sfx.dart`) unga obuna bo'ladi.
class RewardEngine extends ChangeNotifier {
  RewardEngine({Random? random}) : _rng = random ?? Random() {
    _toChest = _rollChest();
  }

  final Random _rng;
  SharedPreferences? _prefs;

  // ─────────────── Holat ───────────────
  int totalXp = 0; // daraja hisobi uchun jami XP
  int coins = 0; // dvigatel bergan tangalar (Progress.coins ga QO'ShILADI)
  int correctTotal = 0;
  int wrongTotal = 0;
  int exercisesDone = 0;
  int perfectExercises = 0;
  int wordsLearned = 0;
  int bestCombo = 0;
  int bestDayXp = 0;
  int chestsOpened = 0;
  int critsTotal = 0;
  final Set<String> achievements = {};

  /// Sessiya kombosi (ilova yopilguncha; xato → 0).
  int combo = 0;

  /// Sandiqgacha qolgan to'g'ri javoblar (5–9 tasodifiy).
  int _toChest = 0;

  /// Bugungi topshiriqlar.
  String _questDay = '';
  List<Quest> quests = [];
  bool allQuestsRewarded = false;

  /// Bugungi XP (kunlik topshiriq + rekord uchun).
  int todayXp = 0;
  int todayCorrect = 0;
  int todayExercises = 0;
  int todayWords = 0;
  String _dayKey = '';

  /// Kutilayotgan, hali ochilmagan sandiq (UI navbatida).
  int pendingChests = 0;

  final _events = StreamController<RewardEvent>.broadcast();
  Stream<RewardEvent> get events => _events.stream;

  // ─────────────── Daraja ───────────────
  static const int maxLevel = 40;

  /// `level` darajaga yetish uchun kerak bo'lgan JAMI XP.
  static int xpForLevel(int level) =>
      level <= 1 ? 0 : (60 * pow(level - 1, 1.6)).round();

  int get level {
    var l = 1;
    while (l < maxLevel && totalXp >= xpForLevel(l + 1)) {
      l++;
    }
    return l;
  }

  int get levelStartXp => xpForLevel(level);
  int get nextLevelXp => level >= maxLevel ? xpForLevel(maxLevel) : xpForLevel(level + 1);
  double get levelProgress {
    final span = nextLevelXp - levelStartXp;
    if (span <= 0) return 1;
    return ((totalXp - levelStartXp) / span).clamp(0.0, 1.0);
  }

  int get xpToNext => max(0, nextLevelXp - totalXp);

  static const List<String> _titles = [
    'Yangi o\'quvchi', // 1
    'Qiziquvchi', // 2
    'Harakatchan', // 3
    'Intiluvchi', // 4
    'So\'z yig\'uvchi', // 5
    'Gap tuzuvchi', // 6
    'Qat\'iyatli', // 7
    'Tinimsiz', // 8
    'Bilimdon', // 9
    'Grammatika qo\'riqchisi', // 10
    'Lug\'at sohibi', // 12
    'Ravon so\'zlovchi', // 14
    'Mohir', // 16
    'Ustoz yordamchisi', // 18
    'Ustoz', // 20
    'Til bilimdoni', // 24
    'Til sarkardasi', // 28
    'Til ustasi', // 32
    'Afsona', // 36
    'Enterprise chempioni', // 40
  ];

  static String titleFor(int level) {
    const steps = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40];
    var i = 0;
    for (var k = 0; k < steps.length; k++) {
      if (level >= steps[k]) i = k;
    }
    return _titles[i];
  }

  String get title => titleFor(level);

  // ─────────────── Kombo bosqichlari ───────────────
  static const Map<int, int> comboBonus = {3: 1, 5: 2, 10: 5, 20: 10, 50: 25};

  /// Kombo "isishi" — 0..1 (UI rang/intensivlik uchun).
  double get comboHeat => (combo / 20).clamp(0.0, 1.0);

  // ─────────────── Yuklash / saqlash ───────────────
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String get _today => _fmt(DateTime.now());

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    totalXp = p.getInt('rw_xp') ?? 0;
    coins = p.getInt('rw_coins') ?? 0;
    correctTotal = p.getInt('rw_correct') ?? 0;
    wrongTotal = p.getInt('rw_wrong') ?? 0;
    exercisesDone = p.getInt('rw_ex') ?? 0;
    perfectExercises = p.getInt('rw_perfect') ?? 0;
    wordsLearned = p.getInt('rw_words') ?? 0;
    bestCombo = p.getInt('rw_bestCombo') ?? 0;
    bestDayXp = p.getInt('rw_bestDay') ?? 0;
    chestsOpened = p.getInt('rw_chests') ?? 0;
    critsTotal = p.getInt('rw_crits') ?? 0;
    achievements.addAll(p.getStringList('rw_ach') ?? []);
    _toChest = p.getInt('rw_toChest') ?? 0;
    pendingChests = p.getInt('rw_pending') ?? 0;
    _dayKey = p.getString('rw_day') ?? '';
    todayXp = p.getInt('rw_todayXp') ?? 0;
    todayCorrect = p.getInt('rw_todayCorrect') ?? 0;
    todayExercises = p.getInt('rw_todayEx') ?? 0;
    todayWords = p.getInt('rw_todayWords') ?? 0;
    _questDay = p.getString('rw_questDay') ?? '';
    allQuestsRewarded = p.getBool('rw_questsRewarded') ?? false;
    final q = p.getString('rw_quests');
    if (q != null) {
      quests = (json.decode(q) as List)
          .map((e) => Quest.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }
    if (_toChest <= 0) _toChest = _rollChest();
    tick();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setInt('rw_xp', totalXp);
    await p.setInt('rw_coins', coins);
    await p.setInt('rw_correct', correctTotal);
    await p.setInt('rw_wrong', wrongTotal);
    await p.setInt('rw_ex', exercisesDone);
    await p.setInt('rw_perfect', perfectExercises);
    await p.setInt('rw_words', wordsLearned);
    await p.setInt('rw_bestCombo', bestCombo);
    await p.setInt('rw_bestDay', bestDayXp);
    await p.setInt('rw_chests', chestsOpened);
    await p.setInt('rw_crits', critsTotal);
    await p.setStringList('rw_ach', achievements.toList());
    await p.setInt('rw_toChest', _toChest);
    await p.setInt('rw_pending', pendingChests);
    await p.setString('rw_day', _dayKey);
    await p.setInt('rw_todayXp', todayXp);
    await p.setInt('rw_todayCorrect', todayCorrect);
    await p.setInt('rw_todayEx', todayExercises);
    await p.setInt('rw_todayWords', todayWords);
    await p.setString('rw_questDay', _questDay);
    await p.setBool('rw_questsRewarded', allQuestsRewarded);
    await p.setString('rw_quests', json.encode(quests.map((q) => q.toJson()).toList()));
  }

  Future<void> resetAll() async {
    totalXp = 0;
    coins = 0;
    correctTotal = wrongTotal = exercisesDone = perfectExercises = 0;
    wordsLearned = bestCombo = bestDayXp = chestsOpened = critsTotal = 0;
    achievements.clear();
    combo = 0;
    _toChest = _rollChest();
    pendingChests = 0;
    todayXp = todayCorrect = todayExercises = todayWords = 0;
    _dayKey = '';
    _questDay = '';
    quests = [];
    allQuestsRewarded = false;
    tick();
    await _save();
    notifyListeners();
  }

  /// Kun almashishi: bugungi hisoblagichlar va topshiriqlar yangilanadi.
  void tick() {
    final t = _today;
    if (_dayKey != t) {
      _dayKey = t;
      todayXp = todayCorrect = todayExercises = todayWords = 0;
    }
    if (_questDay != t || quests.isEmpty) {
      _questDay = t;
      quests = _generateQuests();
      allQuestsRewarded = false;
    }
  }

  int _rollChest() => 5 + _rng.nextInt(5); // 5..9

  // ─────────────── Hodisalar ───────────────

  /// Bitta band javobi. `baseXp` — mashq bergan asosiy XP (odatda 2).
  /// Qaytaradi: dvigatel QO'ShGAN bonus XP (krit/kombo) — chaqiruvchi
  /// uni `Progress.addXp` ga uzatadi.
  int onAnswer(bool ok, {int baseXp = 2}) {
    tick();
    var bonus = 0;
    if (!ok) {
      wrongTotal++;
      combo = 0;
      _events.add(const RewardEvent.wrong());
      _save();
      notifyListeners();
      return 0;
    }
    correctTotal++;
    todayCorrect++;
    combo++;
    if (combo > bestCombo) {
      bestCombo = combo;
      // Har qadamda emas — faqat 5 ga karrali rekordlarda (spam bo'lmasin).
      if (combo >= 5 && combo % 5 == 0) {
        _events.add(RewardEvent.record('combo', combo));
      }
    }

    // Kutilmagan mukofot.
    final roll = _rng.nextDouble();
    final crit = roll < 0.12;
    final gem = !crit && roll < 0.16;
    if (crit) {
      critsTotal++;
      bonus += baseXp; // XP ×2
    }
    if (gem) {
      coins += 10;
      _events.add(const RewardEvent.gem(10));
    }
    _events.add(RewardEvent.xp(baseXp + bonus, crit: crit));

    // Kombo bosqichi.
    final cb = comboBonus[combo];
    if (cb != null) {
      bonus += cb;
      _events.add(RewardEvent.combo(combo, cb));
    } else if (combo > 1) {
      _events.add(RewardEvent.comboTick(combo));
    }

    // Sandiq.
    _toChest--;
    if (_toChest <= 0) {
      _toChest = _rollChest();
      pendingChests++;
      _events.add(const RewardEvent.chest());
    }

    _bumpQuest(QuestKind.correct, 1);
    _bumpQuest(QuestKind.combo, combo, absolute: true);
    _checkAchievements();
    _save();
    notifyListeners();
    return bonus;
  }

  /// Progress.addXp dan chaqiriladi — daraja hisobi.
  void onXp(int amount) {
    if (amount <= 0) return;
    tick();
    final before = level;
    totalXp += amount;
    todayXp += amount;
    if (todayXp > bestDayXp) bestDayXp = todayXp;
    _bumpQuest(QuestKind.xp, amount);
    final after = level;
    if (after > before) {
      _events.add(RewardEvent.levelUp(after, titleFor(after)));
      _checkAchievements();
    }
    _save();
    notifyListeners();
  }

  void onExerciseDone({required bool clean}) {
    tick();
    exercisesDone++;
    todayExercises++;
    if (clean) perfectExercises++;
    _bumpQuest(QuestKind.exercises, 1);
    if (clean) _bumpQuest(QuestKind.perfect, 1);
    _checkAchievements();
    _save();
    notifyListeners();
  }

  void onWordLearned([int n = 1]) {
    tick();
    wordsLearned += n;
    todayWords += n;
    _bumpQuest(QuestKind.words, n);
    _checkAchievements();
    _save();
    notifyListeners();
  }

  /// Streak (kun) o'zgarganda — yutuqlar uchun.
  void onStreak(int days) {
    _streakDays = days;
    _checkAchievements();
  }

  int _streakDays = 0;

  /// Sandiqni ochish — mukofot qaytaradi. UI "bosib ochish" dan keyin
  /// chaqiradi.
  ChestReward openChest() {
    if (pendingChests > 0) pendingChests--;
    chestsOpened++;
    final r = _rng.nextDouble();
    ChestReward reward;
    if (r < 0.05) {
      reward = const ChestReward(freeze: true);
    } else if (r < 0.45) {
      reward = ChestReward(coins: 5 + _rng.nextInt(26));
    } else if (r < 0.8) {
      reward = ChestReward(xp: 5 + _rng.nextInt(16));
    } else {
      reward = ChestReward(coins: 5 + _rng.nextInt(11), xp: 5 + _rng.nextInt(6));
    }
    coins += reward.coins;
    _checkAchievements();
    _save();
    notifyListeners();
    return reward;
  }

  // ─────────────── Kunlik topshiriqlar ───────────────
  List<Quest> _generateQuests() {
    final pool = <Quest>[
      Quest(QuestKind.correct, 15 + 5 * _rng.nextInt(4), coins: 15, xp: 10),
      Quest(QuestKind.combo, [5, 8, 10][_rng.nextInt(3)], coins: 20, xp: 10),
      Quest(QuestKind.exercises, 2 + _rng.nextInt(3), coins: 15, xp: 15),
      Quest(QuestKind.words, 5 + 5 * _rng.nextInt(3), coins: 15, xp: 10),
      Quest(QuestKind.xp, [30, 50, 80][_rng.nextInt(3)], coins: 10, xp: 5),
      Quest(QuestKind.perfect, 1 + _rng.nextInt(2), coins: 25, xp: 15),
    ];
    pool.shuffle(_rng);
    return pool.take(3).toList();
  }

  void _bumpQuest(QuestKind k, int n, {bool absolute = false}) {
    for (final q in quests) {
      if (q.kind != k || q.done) continue;
      q.progress = absolute ? max(q.progress, n) : q.progress + n;
      if (q.progress >= q.target) {
        q.progress = q.target;
        q.done = true;
        coins += q.coins;
        // XP ni Progress beradi (overlay orqali) — u qayta onXp ga
        // keladi, shuning uchun bu yerda qo'shilmaydi.
        _events.add(RewardEvent.quest(q));
      }
    }
    if (!allQuestsRewarded && quests.isNotEmpty && quests.every((q) => q.done)) {
      allQuestsRewarded = true;
      pendingChests++;
      _events.add(const RewardEvent.chest(big: true));
    }
  }

  // ─────────────── Yutuqlar ───────────────
  static const List<Achievement> allAchievements = [
    Achievement('first_ex', 'Birinchi qadam', 'Birinchi mashqni tugatdingiz', '🥇'),
    Achievement('c10', 'Isinish', '10 ta to\'g\'ri javob', '👍'),
    Achievement('c100', 'Yuzlik', '100 ta to\'g\'ri javob', '💯'),
    Achievement('c500', 'Besh yuz', '500 ta to\'g\'ri javob', '🏅'),
    Achievement('c1000', 'Minglik', '1000 ta to\'g\'ri javob', '🏆'),
    Achievement('c5000', 'Besh ming', '5000 ta to\'g\'ri javob', '👑'),
    Achievement('combo10', 'Olov', '10 lik kombo', '🔥'),
    Achievement('combo25', 'Yong\'in', '25 lik kombo', '🌋'),
    Achievement('combo50', 'To\'xtatib bo\'lmas', '50 lik kombo', '⚡'),
    Achievement('perfect5', 'Benuqson', '5 ta xatosiz mashq', '💎'),
    Achievement('perfect25', 'Kristall', '25 ta xatosiz mashq', '🔮'),
    Achievement('ex25', 'Mehnatkash', '25 ta mashq', '🔧'),
    Achievement('ex100', 'Marafonchi', '100 ta mashq', '🏃'),
    Achievement('ex500', 'Temir iroda', '500 ta mashq', '💪'),
    Achievement('words50', 'So\'z yig\'uvchi', '50 ta so\'z', '📚'),
    Achievement('words300', 'Lug\'at sohibi', '300 ta so\'z', '📖'),
    Achievement('words1000', 'Tirik lug\'at', '1000 ta so\'z', '🧠'),
    Achievement('lvl5', '5-daraja', '5-darajaga yetdingiz', '⭐'),
    Achievement('lvl10', '10-daraja', '10-darajaga yetdingiz', '🌟'),
    Achievement('lvl20', '20-daraja', '20-darajaga yetdingiz', '🌟'),
    Achievement('lvl40', 'Chempion', 'Eng yuqori daraja', '🏆'),
    Achievement('streak3', '3 kun', '3 kunlik streak', '🌱'),
    Achievement('streak7', 'Bir hafta', '7 kunlik streak', '🔥'),
    Achievement('streak30', 'Bir oy', '30 kunlik streak', '🌙'),
    Achievement('chest10', 'Xazina izlovchi', '10 ta sandiq', '🎁'),
    Achievement('crit25', 'Omadli', '25 ta KRIT', '🍀'),
    Achievement('day200', 'Kuchli kun', 'Bir kunda 200 XP', '🌞'),
    Achievement('owl', 'Tungi boyqush', 'Kechasi 23:00 dan keyin mashq', '🦉'),
    Achievement('lark', 'Erta turgan', 'Ertalab 6:00 gacha mashq', '🐦'),
  ];

  static Achievement? achievementById(String id) {
    for (final a in allAchievements) {
      if (a.id == id) return a;
    }
    return null;
  }

  void _checkAchievements() {
    void give(String id, bool cond) {
      if (!cond || achievements.contains(id)) return;
      achievements.add(id);
      final a = achievementById(id);
      if (a != null) _events.add(RewardEvent.achievement(a));
    }

    final h = DateTime.now().hour;
    give('first_ex', exercisesDone >= 1);
    give('c10', correctTotal >= 10);
    give('c100', correctTotal >= 100);
    give('c500', correctTotal >= 500);
    give('c1000', correctTotal >= 1000);
    give('c5000', correctTotal >= 5000);
    give('combo10', bestCombo >= 10);
    give('combo25', bestCombo >= 25);
    give('combo50', bestCombo >= 50);
    give('perfect5', perfectExercises >= 5);
    give('perfect25', perfectExercises >= 25);
    give('ex25', exercisesDone >= 25);
    give('ex100', exercisesDone >= 100);
    give('ex500', exercisesDone >= 500);
    give('words50', wordsLearned >= 50);
    give('words300', wordsLearned >= 300);
    give('words1000', wordsLearned >= 1000);
    give('lvl5', level >= 5);
    give('lvl10', level >= 10);
    give('lvl20', level >= 20);
    give('lvl40', level >= 40);
    give('streak3', _streakDays >= 3);
    give('streak7', _streakDays >= 7);
    give('streak30', _streakDays >= 30);
    give('chest10', chestsOpened >= 10);
    give('crit25', critsTotal >= 25);
    give('day200', todayXp >= 200);
    give('owl', correctTotal > 0 && h >= 23);
    give('lark', correctTotal > 0 && h < 6);
  }

  @override
  void dispose() {
    _events.close();
    super.dispose();
  }
}

// ═══════════════ Modellar ═══════════════

enum QuestKind { correct, combo, exercises, words, xp, perfect }

class Quest {
  final QuestKind kind;
  final int target;
  final int coins;
  final int xp;
  int progress;
  bool done;

  Quest(this.kind, this.target,
      {required this.coins, required this.xp, this.progress = 0, this.done = false});

  String get titleUz => switch (kind) {
        QuestKind.correct => '$target ta to\'g\'ri javob',
        QuestKind.combo => '$target lik kombo yig\'ing',
        QuestKind.exercises => '$target ta mashq tugating',
        QuestKind.words => '$target ta so\'z o\'rganing',
        QuestKind.xp => '$target XP to\'plang',
        QuestKind.perfect => '$target ta xatosiz mashq',
      };

  String get emoji => switch (kind) {
        QuestKind.correct => '👍',
        QuestKind.combo => '🔥',
        QuestKind.exercises => '📘',
        QuestKind.words => '🧠',
        QuestKind.xp => '⚡',
        QuestKind.perfect => '💎',
      };

  double get ratio => target == 0 ? 1 : (progress / target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'k': kind.name,
        't': target,
        'c': coins,
        'x': xp,
        'p': progress,
        'd': done,
      };

  static Quest fromJson(Map<String, dynamic> j) => Quest(
        QuestKind.values.firstWhere((k) => k.name == j['k'],
            orElse: () => QuestKind.correct),
        (j['t'] as num).toInt(),
        coins: (j['c'] as num).toInt(),
        xp: (j['x'] as num).toInt(),
        progress: (j['p'] as num?)?.toInt() ?? 0,
        done: j['d'] as bool? ?? false,
      );
}

class Achievement {
  final String id;
  final String title;
  final String desc;
  final String emoji;
  const Achievement(this.id, this.title, this.desc, this.emoji);
}

class ChestReward {
  final int coins;
  final int xp;
  final bool freeze;
  const ChestReward({this.coins = 0, this.xp = 0, this.freeze = false});
}

enum RewardKind {
  xp,
  wrong,
  gem,
  combo,
  comboTick,
  chest,
  levelUp,
  quest,
  achievement,
  record,
}

class RewardEvent {
  final RewardKind kind;
  final int amount;
  final bool crit;
  final bool big;
  final int level;
  final String text;
  final Quest? quest;
  final Achievement? achievement;

  const RewardEvent._(this.kind,
      {this.amount = 0,
      this.crit = false,
      this.big = false,
      this.level = 0,
      this.text = '',
      this.quest,
      this.achievement});

  const RewardEvent.xp(int amount, {bool crit = false})
      : this._(RewardKind.xp, amount: amount, crit: crit);
  const RewardEvent.wrong() : this._(RewardKind.wrong);
  const RewardEvent.gem(int coins) : this._(RewardKind.gem, amount: coins);
  const RewardEvent.combo(int combo, int bonus)
      : this._(RewardKind.combo, level: combo, amount: bonus);
  const RewardEvent.comboTick(int combo) : this._(RewardKind.comboTick, level: combo);
  const RewardEvent.chest({bool big = false}) : this._(RewardKind.chest, big: big);
  const RewardEvent.levelUp(int level, String title)
      : this._(RewardKind.levelUp, level: level, text: title);
  const RewardEvent.quest(Quest q) : this._(RewardKind.quest, quest: q);
  const RewardEvent.achievement(Achievement a)
      : this._(RewardKind.achievement, achievement: a);
  const RewardEvent.record(String what, int value)
      : this._(RewardKind.record, text: what, amount: value);
}
