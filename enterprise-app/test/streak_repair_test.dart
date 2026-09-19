import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/stats.dart';

/// Streak tiklash: uzilish aniqlanadi, 2 kun ichida coin evaziga qaytadi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String f(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Progress> boot(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    app.rewards = RewardEngine();
    await app.rewards.load();
    final p = Progress();
    await p.load();
    return p;
  }

  test('3 kun oldin faol, 12 kunlik seriya -> uzildi, tiklash mumkin', () async {
    final p = await boot({
      'streak': 12,
      'coins': 500,
      'lastActive': f(DateTime.now().subtract(const Duration(days: 3))),
    });
    expect(p.currentStreak, 0);
    expect(p.lostStreak, 12);
    expect(p.canRepairStreak, isTrue);
    expect(p.repairCost, 170);

    expect(await p.repairStreak(), isTrue);
    expect(p.currentStreak, 12);
    expect(p.coins, 330);
    expect(p.canRepairStreak, isFalse);
  });

  test('bugun ishlagan bo\'lsa, tiklash bugunni ham qo\'shadi', () async {
    final p = await boot({
      'streak': 5,
      'coins': 500,
      'lastActive': f(DateTime.now().subtract(const Duration(days: 4))),
    });
    await p.addXp(10);
    expect(p.currentStreak, 1);
    expect(await p.repairStreak(), isTrue);
    expect(p.currentStreak, 6);
  });

  test('coin yetmasa tiklanmaydi; muzlatgich bo\'lsa uzilmaydi', () async {
    final p = await boot({
      'streak': 5,
      'coins': 10,
      'lastActive': f(DateTime.now().subtract(const Duration(days: 4))),
    });
    expect(p.canRepairStreak, isTrue);
    expect(await p.repairStreak(), isFalse);
    expect(p.currentStreak, 0);

    final q = await boot({
      'streak': 5,
      'freezes': 1,
      'lastActive': f(DateTime.now().subtract(const Duration(days: 4))),
    });
    expect(q.currentStreak, 5);
    expect(q.lostStreak, 0);
  });

  test('2 kundan keyin taklif o\'chadi; qisqa seriya (<3) taklif qilinmaydi', () async {
    final p = await boot({
      'lostStreak': 9,
      'lostStreakDate': f(DateTime.now().subtract(const Duration(days: 3))),
      'lastActive': f(DateTime.now()),
    });
    expect(p.canRepairStreak, isFalse);

    final q = await boot({
      'streak': 2,
      'lastActive': f(DateTime.now().subtract(const Duration(days: 4))),
    });
    expect(q.lostStreak, 0);
  });
}
