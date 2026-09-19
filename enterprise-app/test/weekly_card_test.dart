import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/reward/weekly_card.dart';

/// Haftalik hisobot: o'tgan hafta XP, faol kunlar, o'sish, yopish.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String f(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  test('lastWeek/weekBefore: dushanbadan yakshanbagacha 7 kun', () {
    // 2026-09-16 chorshanba. O'tgan hafta: 09-07 (du) .. 09-13 (ya).
    final now = DateTime(2026, 9, 16);
    final data = {
      f(DateTime(2026, 9, 7)): 10,
      f(DateTime(2026, 9, 9)): 30,
      f(DateTime(2026, 9, 13)): 5,
      f(DateTime(2026, 9, 1)): 100, // undan oldingi hafta
      f(DateTime(2026, 9, 15)): 999, // joriy hafta - kirmasin
    };
    expect(WeeklyCard.lastWeek(data, now), [10, 0, 30, 0, 0, 0, 5]);
    expect(WeeklyCard.weekBefore(data, now), [0, 100, 0, 0, 0, 0, 0]);
    expect(WeeklyCard.weekKey(now), '2026-09-14');
  });

  testWidgets('karta ko\'rsatiladi va yopilgach qayta chiqmaydi', (t) async {
    SharedPreferences.setMockInitialValues({});
    app.rewards = RewardEngine();
    await app.rewards.load();
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1 + 7));
    app.rewards.dayXp[f(monday)] = 40;
    app.rewards.dayXp[f(monday.add(const Duration(days: 2)))] = 60;

    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: WeeklyCard()))));
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(find.text('O\'tgan hafta hisoboti'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('2/7'), findsOneWidget);

    await t.tap(find.byIcon(Icons.close_rounded));
    await t.pump();
    expect(find.text('O\'tgan hafta hisoboti'), findsNothing);

    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: WeeklyCard(key: ValueKey(2))))));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('O\'tgan hafta hisoboti'), findsNothing);
  });
}
