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

  /// Qutqarilgan (o'chib ketishdan qaytarilgan) so'zlar — jami.
  int wordsRescued = 0;

  /// O'tilgan yig'ma imtihonlar (unit raqami bo'yicha).
  final Set<int> examsPassed = {};
  int bestCombo = 0;
  int bestDayXp = 0;
  int chestsOpened = 0;
  int critsTotal = 0;
  final Set<String> achievements = {};

  /// Sessiya kombosi (ilova yopilguncha; xato → 0).
  int combo = 0;

  /// Oldingi javob xato edimi — "qaytish" bonusi uchun.
  bool _lastWrong = false;

  /// Tez javoblar soni (statistika).
  int speedTotal = 0;

  /// Oltin savollar: kutilish (anticipation) — javobdan OLDIN e'lon
  /// qilinadi, XP ×3.
  static const double goldenChance = 0.08;
  static const int goldenMultiplier = 3;

  /// Keyingi savol oltinmi — sahna boshida bir marta so'raladi.
  bool rollGolden() => _rng.nextDouble() < goldenChance;

  /// Sandiqgacha qolgan to'g'ri javoblar (5–9 tasodifiy).
  int _toChest = 0;

  /// Kunlik maqsad bugun nishonlanganmi (bir marta).
  String _goalDay = '';

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

  /// Kunlik XP tarixi ('YYYY-MM-DD' → XP), oxirgi 90 kun — issiqlik
  /// xaritasi uchun. Ko'rinadigan sarmoya = tashlab ketish qiyin.
  final Map<String, int> dayXp = {};

  /// Kunlik g'ildirak qaysi kuni aylantirilgan.
  String _spinDay = '';

  /// Oxirgi ko'rilgan liga (ko'tarilishni aniqlash uchun).
  int _leagueSeen = 0;

  /// Hamrohning ISMI — o'quvchi o'zi qo'yadi (IKEA effekti: o'zi
  /// yaratgan narsa qadrli). Bo'sh = hali tanishuv o'tmagan.
  String petName = '';
  bool get onboarded => petName.isNotEmpty;

  /// Holat diskdan yuklanganmi — tanishuv faqat shundan keyin.
  bool get loaded => _prefs != null;

  /// Tugatilgan unitlar (nishonlash bir marta).
  final Set<int> unitsCompleted = {};

  /// Streak sandig'i berilgan kunlar (3/7/14/30/60/100).
  final Set<int> streakChestsGiven = {};

  // ─── Sessiya (peak-end: oxiri yaxshi tugasin) ───
  DateTime? _sessionStart;
  DateTime? _lastActivity;
  int sessionXp = 0;
  int sessionCorrect = 0;
  int sessionWrong = 0;
  int sessionExercises = 0;
  int sessionBestCombo = 0;
  bool _recapPending = false;
  static const Duration sessionGap = Duration(minutes: 10);

  /// TANAFFUS — 20 daqiqa uzluksiz ishlagach BIR marta (sessiya
  /// davomida) "dam oling" xabari. Xotira ilmi: taqsimlangan mashq
  /// (spacing) uzluksizdan kuchli; qisqa tanaffus konsolidatsiyaga
  /// yordam beradi va charchoqdan tashlab ketishni kamaytiradi.
  static const Duration breakAfter = Duration(minutes: 20);
  bool _breakShown = false;

  void _touchSession() {
    final now = DateTime.now();
    if (_lastActivity == null || now.difference(_lastActivity!) > sessionGap) {
      _sessionStart = now;
      sessionXp = sessionCorrect = sessionWrong = sessionExercises = 0;
      sessionBestCombo = 0;
      _recapPending = false;
      _breakShown = false;
    }
    _lastActivity = now;
    if (!_breakShown &&
        _sessionStart != null &&
        now.difference(_sessionStart!) >= breakAfter) {
      _breakShown = true;
      _events.add(const RewardEvent._(RewardKind.breakTime));
    }
  }

  Duration get sessionDuration => _sessionStart == null
      ? Duration.zero
      : (_lastActivity ?? DateTime.now()).difference(_sessionStart!);

  /// Bosh ekran so'raydi: ko'rsatiladigan yakun bormi (bir marta).
  SessionRecap? takeRecap() {
    if (!_recapPending || sessionExercises < 2) return null;
    _recapPending = false;
    return SessionRecap(
      minutes: max(1, sessionDuration.inMinutes),
      xp: sessionXp,
      correct: sessionCorrect,
      wrong: sessionWrong,
      exercises: sessionExercises,
      bestCombo: sessionBestCombo,
    );
  }

  // ─── Va'da vaqti (implementation intention) ───
  /// "Ertaga soat N da" — o'quvchi o'zi tanlaydi; niyat aniq vaqtga
  /// bog'lansa bajarilishi 2 barobar oshadi (Gollwitzer).
  int? commitHour;
  String _commitAskedDay = '';
  bool get commitAskedToday => _commitAskedDay == _today;
  Future<void> setCommitHour(int? h) async {
    commitHour = h;
    _commitAskedDay = _today;
    await _save();
    notifyListeners();
  }

  /// Va'da vaqti kelib, bugun hali ishlanmagan bo'lsa.
  bool get commitDue =>
      commitHour != null && idleToday && DateTime.now().hour >= commitHour!;

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
    wordsRescued = p.getInt('rw_rescued') ?? 0;
    examsPassed
      ..clear()
      ..addAll((p.getStringList('rw_exams') ?? []).map(int.parse));
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
    _goalDay = p.getString('rw_goalDay') ?? '';
    _spinDay = p.getString('rw_spinDay') ?? '';
    _leagueSeen = p.getInt('rw_league') ?? 0;
    petName = p.getString('rw_pet') ?? '';
    commitHour = p.getInt('rw_commit');
    _commitAskedDay = p.getString('rw_commitDay') ?? '';
    unitsCompleted.addAll((p.getStringList('rw_units') ?? []).map(int.parse));
    streakChestsGiven.addAll((p.getStringList('rw_streakChests') ?? []).map(int.parse));
    final dx = p.getString('rw_dayXp');
    if (dx != null) {
      (json.decode(dx) as Map).forEach((k, v) => dayXp[k as String] = (v as num).toInt());
    }
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
    await p.setInt('rw_rescued', wordsRescued);
    await p.setStringList('rw_exams', examsPassed.map((e) => '$e').toList());
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
    await p.setString('rw_goalDay', _goalDay);
    await p.setString('rw_spinDay', _spinDay);
    await p.setInt('rw_league', _leagueSeen);
    await p.setString('rw_pet', petName);
    if (commitHour != null) {
      await p.setInt('rw_commit', commitHour!);
    } else {
      await p.remove('rw_commit');
    }
    await p.setString('rw_commitDay', _commitAskedDay);
    await p.setStringList('rw_units', unitsCompleted.map((e) => '$e').toList());
    await p.setStringList('rw_streakChests', streakChestsGiven.map((e) => '$e').toList());
    await p.setString('rw_dayXp', json.encode(dayXp));
    await p.setBool('rw_questsRewarded', allQuestsRewarded);
    await p.setString('rw_quests', json.encode(quests.map((q) => q.toJson()).toList()));
  }

  Future<void> resetAll() async {
    totalXp = 0;
    coins = 0;
    correctTotal = wrongTotal = exercisesDone = perfectExercises = 0;
    wordsLearned = bestCombo = bestDayXp = chestsOpened = critsTotal = 0;
    wordsRescued = 0;
    examsPassed.clear();
    achievements.clear();
    combo = 0;
    _toChest = _rollChest();
    pendingChests = 0;
    todayXp = todayCorrect = todayExercises = todayWords = 0;
    _dayKey = '';
    _questDay = '';
    _goalDay = '';
    _spinDay = '';
    _leagueSeen = 0;
    petName = '';
    commitHour = null;
    _commitAskedDay = '';
    unitsCompleted.clear();
    streakChestsGiven.clear();
    dayXp.clear();
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
  int onAnswer(bool ok, {int baseXp = 2, Duration? elapsed, bool nearMiss = false}) {
    tick();
    _touchSession();
    var bonus = 0;
    if (!ok) {
      wrongTotal++;
      sessionWrong++;
      combo = 0;
      _lastWrong = true;
      // "Deyarli!" — yaqin xato: miya buni deyarli g'alaba deb o'qiydi
      // (near-miss effekti); umidsizlik o'rniga "yana bir urinish".
      _events.add(nearMiss ? const RewardEvent.nearMiss() : const RewardEvent.wrong());
      _save();
      notifyListeners();
      return 0;
    }
    correctTotal++;
    // QAYTISh: xatodan keyingi birinchi to'g'ri javob — alohida
    // mukofot. Muvaffaqiyatsizlikdan keyin tashlab ketish eng ko'p
    // shu nuqtada bo'ladi; darhol tiklanish hissi uni yopadi.
    if (_lastWrong) {
      _lastWrong = false;
      bonus += 1;
      _events.add(const RewardEvent.comeback(1));
    }
    // TEZLIK: 3 soniyadan tez — ravonlik (fluency) mukofoti.
    if (elapsed != null && elapsed.inMilliseconds < 3000 && baseXp > 0) {
      speedTotal++;
      bonus += 1;
      _events.add(const RewardEvent.speed(1));
    }
    todayCorrect++;
    sessionCorrect++;
    combo++;
    if (combo > sessionBestCombo) sessionBestCombo = combo;
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
    if (isHappyHour) bonus += baseXp; // baxtli soat: yana ×2
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
    _touchSession();
    sessionXp += amount;
    totalXp += amount;
    todayXp += amount;
    if (todayXp > bestDayXp) bestDayXp = todayXp;
    dayXp[_today] = (dayXp[_today] ?? 0) + amount;
    _trimDayXp();
    _bumpQuest(QuestKind.xp, amount);
    final after = level;
    if (after > before) {
      _events.add(RewardEvent.levelUp(after, titleFor(after)));
      _checkAchievements();
    }
    final lg = leagueIndex;
    if (lg > _leagueSeen) {
      _leagueSeen = lg;
      if (lg > 0) _events.add(RewardEvent.league(lg, leagues[lg]));
    }
    _save();
    notifyListeners();
  }

  void onExerciseDone({required bool clean}) {
    tick();
    _touchSession();
    sessionExercises++;
    _recapPending = true;
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

  /// Xotira qutqaruvi tugadi — [n] ta so'z unutilishdan qaytarildi.
  /// Tanga: har so'zga 1 (yo'qotishdan saqlab qolish — alohida mukofot).
  void onRescue(int n) {
    tick();
    wordsRescued += n;
    coins += n;
    _bumpQuest(QuestKind.words, n);
    _checkAchievements();
    _save();
    notifyListeners();
  }

  /// Yig'ma imtihon (1..N) 90%+ bilan o'tildi — 50 tanga, yutuqlar.
  void onExamPassed(int uptoUnit) {
    tick();
    if (!examsPassed.add(uptoUnit)) {
      _save();
      return;
    }
    coins += 50;
    _checkAchievements();
    _save();
    notifyListeners();
  }

  /// Kunlik maqsadga yetildi — kuniga BIR marta nishonlanadi.
  void onDailyGoal() {
    tick();
    if (_goalDay == _today) return;
    _goalDay = _today;
    coins += 10;
    _events.add(const RewardEvent.dailyGoal(10));
    _save();
    notifyListeners();
  }

  /// Streak (kun) o'zgarganda — yutuqlar + streak sandig'i.
  static const List<int> streakChestDays = [3, 7, 14, 30, 60, 100];
  void onStreak(int days) {
    _streakDays = days;
    for (final d in streakChestDays) {
      if (days >= d && !streakChestsGiven.contains(d)) {
        streakChestsGiven.add(d);
        pendingChests++;
        _events.add(RewardEvent.chest(big: d >= 7));
        _events.add(RewardEvent.streakMilestone(d));
      }
    }
    _checkAchievements();
  }

  Future<void> setPetName(String name) async {
    petName = name.trim();
    await _save();
    notifyListeners();
  }

  /// Unit to'liq tugadi — bir marta nishonlanadi (+50 tanga).
  void onUnitComplete(int unit, String label) {
    if (unitsCompleted.contains(unit)) return;
    unitsCompleted.add(unit);
    coins += 50;
    _events.add(RewardEvent.unitComplete(unit, label));
    _save();
    notifyListeners();
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


  // ─────────────── Liga ───────────────
  static const List<String> leagues = [
    'Bronze', 'Silver', 'Gold', 'Sapphire', 'Ruby',
    'Emerald', 'Amethyst', 'Pearl', 'Obsidian', 'Diamond',
  ];
  int get leagueIndex => (totalXp ~/ 500).clamp(0, leagues.length - 1);
  String get league => leagues[leagueIndex];
  int get xpToNextLeague =>
      leagueIndex >= leagues.length - 1 ? 0 : (leagueIndex + 1) * 500 - totalXp;

  // ─────────────── Baxtli soat (×2 XP) ───────────────
  /// Sanaga bog'liq deterministik soat (08..21). Har kuni boshqa —
  /// o'quvchi "qachon?" deb ilovani ochib ko'radi.
  int happyHourFor(DateTime d) {
    final h = (d.year * 31 + d.month * 7 + d.day * 13) % 14; // 0..13
    return 8 + h;
  }

  int get happyHour => happyHourFor(DateTime.now());
  bool get isHappyHour => DateTime.now().hour == happyHour;

  /// Baxtli soat boshlanishigacha (yoki tugashigacha) qolgan vaqt.
  Duration get happyHourCountdown {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, happyHour);
    if (isHappyHour) return start.add(const Duration(hours: 1)).difference(now);
    if (now.isBefore(start)) return start.difference(now);
    // Bugungisi o'tib ketgan — ertangisi.
    final t = now.add(const Duration(days: 1));
    return DateTime(t.year, t.month, t.day, happyHourFor(t)).difference(now);
  }

  bool get happyHourPassedToday => DateTime.now().hour > happyHour;

  // ─────────────── Kunlik g'ildirak ───────────────
  static const int spinUnlockCorrect = 5;
  bool get spinDoneToday => _spinDay == _today;
  bool get spinAvailable => !spinDoneToday && todayCorrect >= spinUnlockCorrect;
  int get spinRemaining => max(0, spinUnlockCorrect - todayCorrect);

  /// G'ildirak sektorlari (tartib UI bilan bir xil). Og'irliklar:
  /// kichiklar tez-tez, katta mukofot kam — variable ratio.
  static const List<SpinSector> spinSectors = [
    SpinSector('+5 🪙', coins: 5, weight: 22),
    SpinSector('+10 ⚡', xp: 10, weight: 20),
    SpinSector('+15 🪙', coins: 15, weight: 16),
    SpinSector('+25 ⚡', xp: 25, weight: 14),
    SpinSector('+30 🪙', coins: 30, weight: 10),
    SpinSector('❄ Muzlatgich', freeze: true, weight: 6),
    SpinSector('+50 ⚡', xp: 50, weight: 8),
    SpinSector('JEKPOT 100 🪙', coins: 100, weight: 4),
  ];

  /// Aylantirish — sektor indeksini qaytaradi (UI o'sha sektorga
  /// aylantirib to'xtaydi), mukofot darhol yoziladi.
  int spin() {
    tick();
    if (spinDoneToday) return -1;
    _spinDay = _today;
    final total = spinSectors.fold<int>(0, (a, b) => a + b.weight);
    var r = _rng.nextInt(total);
    var idx = 0;
    for (var i = 0; i < spinSectors.length; i++) {
      r -= spinSectors[i].weight;
      if (r < 0) {
        idx = i;
        break;
      }
    }
    coins += spinSectors[idx].coins;
    _save();
    notifyListeners();
    return idx;
  }

  // ─────────────── Faollik xaritasi ───────────────
  void _trimDayXp() {
    if (dayXp.length <= 100) return;
    final keys = dayXp.keys.toList()..sort();
    for (final k in keys.take(dayXp.length - 90)) {
      dayXp.remove(k);
    }
  }

  /// Oxirgi 7 kun XP va undan oldingi 7 kun XP — haftalik o'sish.
  (int, int) weeklyXp() {
    final now = DateTime.now();
    var cur = 0, prev = 0;
    for (var i = 0; i < 14; i++) {
      final d = now.subtract(Duration(days: i));
      final v = dayXp[_fmt(d)] ?? 0;
      if (i < 7) {
        cur += v;
      } else {
        prev += v;
      }
    }
    return (cur, prev);
  }

  /// Bugungi faollik yo'qmi (streak xavfi).
  bool get idleToday => (dayXp[_today] ?? 0) == 0;

  /// Yarim tungacha qolgan vaqt.
  Duration get untilMidnight {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1).difference(n);
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
    Achievement('rescue25', 'Qutqaruvchi', '25 ta so\'z unutilishdan qaytarildi', '🛟'),
    Achievement('rescue200', 'Xotira qo\'riqchisi', '200 ta so\'z qutqarildi', '🛡️'),
    Achievement('exam1', 'Birinchi imtihon', 'Yig\'ma imtihondan o\'tdingiz', '📝'),
    Achievement('exam5', 'Imtihon ustasi', '5 ta yig\'ma imtihon', '🎓'),
    Achievement('exam15', 'Bitiruvchi', '15 ta yig\'ma imtihon', '🏛️'),
    Achievement('lvl5', '5-daraja', '5-darajaga yetdingiz', '⭐'),
    Achievement('lvl10', '10-daraja', '10-darajaga yetdingiz', '🌟'),
    Achievement('lvl20', '20-daraja', '20-darajaga yetdingiz', '🌟'),
    Achievement('lvl40', 'Chempion', 'Eng yuqori daraja', '🏆'),
    Achievement('streak3', '3 kun', '3 kunlik streak', '🌱'),
    Achievement('streak7', 'Bir hafta', '7 kunlik streak', '🔥'),
    Achievement('streak30', 'Bir oy', '30 kunlik streak', '🌙'),
    Achievement('chest10', 'Bonus ovchisi', '10 ta bonus box', '🎁'),
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
    give('rescue25', wordsRescued >= 25);
    give('rescue200', wordsRescued >= 200);
    give('exam1', examsPassed.isNotEmpty);
    give('exam5', examsPassed.length >= 5);
    give('exam15', examsPassed.length >= 15);
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

class SessionRecap {
  final int minutes, xp, correct, wrong, exercises, bestCombo;
  const SessionRecap(
      {required this.minutes,
      required this.xp,
      required this.correct,
      required this.wrong,
      required this.exercises,
      required this.bestCombo});
  int get accuracy =>
      correct + wrong == 0 ? 100 : (correct * 100 / (correct + wrong)).round();
}

class SpinSector {
  final String label;
  final int coins;
  final int xp;
  final bool freeze;
  final int weight;
  const SpinSector(this.label,
      {this.coins = 0, this.xp = 0, this.freeze = false, required this.weight});
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
  dailyGoal,
  league,
  speed,
  comeback,
  nearMiss,
  unitComplete,
  streakMilestone,

  /// Tanaffus tavsiyasi: 20+ daqiqa uzluksiz — "2 daqiqa dam".
  breakTime,
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
  const RewardEvent.unitComplete(int unit, String label)
      : this._(RewardKind.unitComplete, level: unit, text: label);
  const RewardEvent.streakMilestone(int days)
      : this._(RewardKind.streakMilestone, amount: days);
  const RewardEvent.speed(int bonus) : this._(RewardKind.speed, amount: bonus);
  const RewardEvent.comeback(int bonus) : this._(RewardKind.comeback, amount: bonus);
  const RewardEvent.nearMiss() : this._(RewardKind.nearMiss);
  const RewardEvent.league(int index, String name)
      : this._(RewardKind.league, level: index, text: name);
  const RewardEvent.dailyGoal(int coins) : this._(RewardKind.dailyGoal, amount: coins);
  const RewardEvent.record(String what, int value)
      : this._(RewardKind.record, text: what, amount: value);
}
