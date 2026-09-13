import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/mistakes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('xatolar daftari: qo\'shish, takror sanash, to\'g\'ri topilsa o\'chish, saqlash', () async {
    SharedPreferences.setMockInitialValues({});
    final m = MistakeStore();
    await m.load();
    const t = ExTask(prompt: 'She ___ a doctor.', answer: 'is', options: ['is', 'are', 'am']);
    await m.add(t, source: 'Grammar 5-bet');
    await m.add(t, source: 'Grammar 5-bet');
    expect(m.items.length, 1);
    expect(m.items.first.times, 2);
    expect(m.quizTasks().length, 1);
    final m2 = MistakeStore();
    await m2.load();
    expect(m2.items.length, 1, reason: 'diskdan yuklanadi');
    await m2.resolve(t);
    expect(m2.items, isEmpty);
    // Darajaga bog'liq: boshqa darajada bo'sh.
    await m.add(t, source: 'x');
    m.setLevel('elementary');
    expect(m.items, isEmpty);
  });
}
