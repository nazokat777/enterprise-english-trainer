import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/stats.dart';

/// Streak (kunlik seriya) va muzlatgich mantiqi.
///
/// Muzlatgich — coin evaziga sotib olinadigan narsa (200 coin), shuning
/// uchun uni behuda sarflab yuborish foydalanuvchi uchun sezilarli
/// yo'qotish.
String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _daysAgo(int n) => _fmt(DateTime.now().subtract(Duration(days: n)));

Future<Progress> _load({
  required String? lastActive,
  int streak = 5,
  int freezes = 0,
}) async {
  final values = <String, Object>{'streak': streak, 'freezes': freezes};
  if (lastActive != null) values['lastActive'] = lastActive;
  SharedPreferences.setMockInitialValues(values);
  final p = Progress();
  await p.load();
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kecha faol bo\'lgan — seriya saqlanadi', () async {
    final p = await _load(lastActive: _daysAgo(1));
    expect(p.currentStreak, 5);
  });

  test('bugun faol bo\'lgan — seriya saqlanadi', () async {
    final p = await _load(lastActive: _daysAgo(0));
    expect(p.currentStreak, 5);
  });

  test('kun o\'tkazib yuborilgan, muzlatgich yo\'q — seriya uziladi', () async {
    final p = await _load(lastActive: _daysAgo(3));
    expect(p.currentStreak, 0);
  });

  test('kun o\'tkazib yuborilgan, muzlatgich bor — seriya saqlanadi', () async {
    final p = await _load(lastActive: _daysAgo(3), freezes: 2);
    expect(p.currentStreak, 5);
    expect(p.streakFreezeCount, 1);
  });

  test('ishlatilgan muzlatgich DISKKA yoziladi', () async {
    // Muzlatgich coin evaziga sotib olinadi (200 coin). Ilgari u faqat
    // XOTIRADA kamayardi — `_refreshStreak()` saqlamasdi. Ilovani qayta
    // ochganda hisob eski holiga qaytardi, ya'ni bitta muzlatgich
    // CHEKSIZ marta ishlatilardi.
    final p = await _load(lastActive: _daysAgo(3), freezes: 2);
    expect(p.streakFreezeCount, 1);

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getInt('freezes'), 1,
        reason: 'ishlatilgan muzlatgich saqlanishi kerak');
  });

  test('muzlatgich bir kunda faqat bir marta yechiladi', () async {
    // Ilovani kun davomida bir necha marta ochish — oddiy hol.
    await _load(lastActive: _daysAgo(3), freezes: 2);

    final p2 = Progress();
    await p2.load();
    expect(p2.streakFreezeCount, 1, reason: 'ikkinchi muzlatgich yechilmasin');
    expect(p2.currentStreak, 5);
  });
}
