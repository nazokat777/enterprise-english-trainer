import 'dart:math';

import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('daraja egri chizig\'i o\'sadi va 40 da to\'xtaydi', () {
    expect(RewardEngine.xpForLevel(1), 0);
    expect(RewardEngine.xpForLevel(2), 60);
    for (var l = 2; l < RewardEngine.maxLevel; l++) {
      expect(RewardEngine.xpForLevel(l + 1) > RewardEngine.xpForLevel(l), isTrue);
    }
    final e = RewardEngine(random: Random(1));
    e.onXp(1000000);
    expect(e.level, RewardEngine.maxLevel);
    expect(e.levelProgress, 1);
    expect(RewardEngine.titleFor(1), 'Yangi o\'quvchi');
    expect(RewardEngine.titleFor(40), 'Enterprise chempioni');
  });

  test('daraja oshganda levelUp hodisasi chiqadi', () async {
    final e = RewardEngine(random: Random(1));
    final events = <RewardEvent>[];
    e.events.listen(events.add);
    e.onXp(59);
    e.onXp(1);
    await Future<void>.delayed(Duration.zero);
    expect(e.level, 2);
    expect(events.where((x) => x.kind == RewardKind.levelUp).length, 1);
  });

  test('kombo bosqichlari bonus beradi, xato nolga tushiradi', () async {
    final e = RewardEngine(random: Random(7));
    final events = <RewardEvent>[];
    e.events.listen(events.add);
    var bonus = 0;
    for (var i = 0; i < 5; i++) {
      bonus += e.onAnswer(true, baseXp: 2);
    }
    await Future<void>.delayed(Duration.zero);
    expect(e.combo, 5);
    // 3 va 5 bosqichlari: 1 + 2 = 3 (krit bo'lsa yana +2 lar).
    expect(bonus >= 3, isTrue);
    expect(events.where((x) => x.kind == RewardKind.combo).length, 2);
    e.onAnswer(false);
    expect(e.combo, 0);
    expect(e.bestCombo, 5);
  });

  test('sandiq 5–9 to\'g\'ri javobda keladi', () async {
    for (final seed in [1, 2, 3, 4, 5]) {
      final e = RewardEngine(random: Random(seed));
      final events = <RewardEvent>[];
      e.events.listen(events.add);
      var n = 0;
      while (events.every((x) => x.kind != RewardKind.chest) && n < 20) {
        e.onAnswer(true);
        n++;
        await Future<void>.delayed(Duration.zero);
      }
      expect(n, inInclusiveRange(5, 9), reason: 'seed $seed');
      final r = e.openChest();
      expect(r.coins + r.xp > 0 || r.freeze, isTrue);
      expect(e.chestsOpened, 1);
    }
  });

  test('kunlik topshiriqlar 3 ta, bajarilganda mukofot va sandiq', () async {
    final e = RewardEngine(random: Random(3));
    e.tick();
    expect(e.quests.length, 3);
    final events = <RewardEvent>[];
    e.events.listen(events.add);
    // Hamma topshiriqni yopish uchun ko'p javob + XP + mashq + so'z.
    for (var i = 0; i < 60; i++) {
      e.onAnswer(true, baseXp: 2);
    }
    e.onXp(200);
    for (var i = 0; i < 5; i++) {
      e.onExerciseDone(clean: true);
    }
    e.onWordLearned(30);
    await Future<void>.delayed(Duration.zero);
    expect(e.quests.every((q) => q.done), isTrue);
    expect(events.where((x) => x.kind == RewardKind.quest).length, 3);
    expect(events.any((x) => x.kind == RewardKind.chest && x.big), isTrue);
    expect(e.allQuestsRewarded, isTrue);
  });

  test('yutuqlar bir marta ochiladi', () async {
    final e = RewardEngine(random: Random(9));
    final events = <RewardEvent>[];
    e.events.listen(events.add);
    e.onExerciseDone(clean: true);
    e.onExerciseDone(clean: true);
    await Future<void>.delayed(Duration.zero);
    expect(e.achievements.contains('first_ex'), isTrue);
    expect(events.where((x) => x.kind == RewardKind.achievement).length,
        e.achievements.length);
    for (var i = 0; i < 10; i++) {
      e.onAnswer(true);
    }
    expect(e.achievements.contains('c10'), isTrue);
    expect(e.achievements.contains('combo10'), isTrue);
  });

  test('saqlash va yuklash', () async {
    final e = RewardEngine(random: Random(5));
    await e.load();
    for (var i = 0; i < 7; i++) {
      e.onAnswer(true);
    }
    e.onXp(150);
    e.onExerciseDone(clean: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final e2 = RewardEngine(random: Random(5));
    await e2.load();
    expect(e2.totalXp, e.totalXp);
    expect(e2.correctTotal, 7);
    expect(e2.exercisesDone, 1);
    expect(e2.level, e.level);
    expect(e2.quests.length, 3);
    expect(e2.achievements, e.achievements);
    // Kombo sessiyaga tegishli — saqlanmaydi.
    expect(e2.combo, 0);
  });

  test('resetAll hammasini nolga tushiradi', () async {
    final e = RewardEngine(random: Random(2));
    await e.load();
    for (var i = 0; i < 12; i++) {
      e.onAnswer(true);
    }
    e.onXp(500);
    await e.resetAll();
    expect(e.totalXp, 0);
    expect(e.level, 1);
    expect(e.correctTotal, 0);
    expect(e.achievements, isEmpty);
    expect(e.quests.length, 3);
    expect(e.quests.every((q) => q.progress == 0), isTrue);
  });
}
