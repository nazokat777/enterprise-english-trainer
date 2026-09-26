import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_english/plan/study_plan.dart';

/// Mnemonika xaritasi: hajm, sur'at, kunlarga bo'lish, holat.
void main() {
  // 2 unit: 6 dars + 2 qoida, 4 dars + 1 qoida.
  BookVolume vol() => BookVolume(
        level: 'beginner',
        bookTitle: 'Test',
        uniqueWords: 60,
        units: [
          UnitVolume(
            unit: 1,
            label: '1-unit',
            title: 'Hi',
            lessons: [for (var i = 0; i < 6; i++) ['w::a$i', 'w::b$i']],
            words: 42,
            rules: const ['to be', 'a/an'],
            grammarExercises: 5,
          ),
          UnitVolume(
            unit: 2,
            label: '2-unit',
            title: 'Home',
            lessons: [for (var i = 0; i < 4; i++) ['w::c$i']],
            words: 28,
            rules: const ['plural'],
            grammarExercises: 3,
          ),
        ],
      );

  test('hajm yig\'indilari', () {
    final v = vol();
    expect(v.lessons, 10);
    expect(v.words, 70);
    expect(v.rules, 3);
    expect(v.grammarExercises, 8);
    expect(v.wordsPerLesson, 7);
  });

  test('bandlar kitob tartibida, qoidalar darslar orasida', () {
    final items = planItems(vol());
    expect(items.length, 13); // 10 dars + 3 qoida
    // 1-unitning qoidalari 2-unit darslaridan oldin.
    final firstU2 = items.indexWhere((e) => e.unit == 2);
    expect(items.take(firstU2).where((e) => e.kind == PlanKind.rule).length, 2);
    // Qoida unit boshida emas - avval so'zlar.
    expect(items.first.kind, PlanKind.lesson);
  });

  test('kunlarga bo\'lish: hamma band bir marta, tartib saqlanadi', () {
    final v = vol();
    for (final days in [1, 3, 5, 13, 30]) {
      final s = buildSchedule(v, days);
      expect(s.length, days);
      final flat = s.expand((d) => d).toList();
      expect(flat.length, 13, reason: '$days kun');
      expect(flat.map((e) => e.key).toList(),
          planItems(v).map((e) => e.key).toList());
    }
  });

  test('sur\'at va qiyinlik', () {
    final v = vol();
    final p = paceFor(v, 5);
    expect(p.lessonsPerDay, 2);
    expect(p.wordsPerDay, 14);
    expect(p.minutesPerDay, greaterThan(0));
    expect(paceFor(v, 1).minutesPerDay, greaterThan(paceFor(v, 10).minutesPerDay));
    expect(['Yengil', 'O\'rtacha', 'Og\'ir', 'Juda og\'ir'],
        contains(p.difficulty));
  });

  test('tavsiya: kuniga 45 daqiqadan oshmaydigan eng qisqa muddat', () {
    final big = BookVolume(
      level: 'x',
      bookTitle: 'x',
      uniqueWords: 3000,
      units: [
        UnitVolume(
          unit: 1,
          label: '',
          title: '',
          lessons: [for (var i = 0; i < 673; i++) const ['w']],
          words: 4665,
          rules: [for (var i = 0; i < 51; i++) 'r$i'],
        ),
      ],
    );
    final d = recommendedDays(big);
    expect(paceFor(big, d).minutesPerDay, lessThanOrEqualTo(45));
    final i = kPlanDurations.indexOf(d);
    if (i > 0) {
      expect(paceFor(big, kPlanDurations[i - 1]).minutesPerDay, greaterThan(45));
    }
  });

  test('holat va bugungi bandlar (ortda qolganlar bilan)', () {
    final s = buildSchedule(vol(), 5);
    final done = <String>{};
    bool isDone(PlanItem e) => done.contains(e.key);

    // 3-kun (index 2), hech narsa qilinmagan.
    var st = planStatus(s, 2, isDone);
    expect(st.done, 0);
    expect(st.expected, s[0].length + s[1].length);
    expect(st.behind, st.expected);
    final today = todayItems(s, 2, isDone);
    // Bugungi + ortda qolganlardan ko'pi bilan bugungi hajmcha.
    expect(today.length, lessThanOrEqualTo(s[2].length * 2));
    expect(today.last.key, s[2].last.key);

    // Hammasi bajarilgan - ortda qolgan yo'q.
    done.addAll(s[0].map((e) => e.key));
    done.addAll(s[1].map((e) => e.key));
    st = planStatus(s, 2, isDone);
    expect(st.behind, 0);
    expect(todayItems(s, 2, isDone).map((e) => e.key), s[2].map((e) => e.key));
  });

  test('StudyPlan: kun indeksi, tugash sanasi, saqlash', () {
    final p = StudyPlan(level: 'beginner', days: 60, start: '2026-09-01');
    expect(p.dayIndex(DateTime(2026, 9, 1, 23)), 0);
    expect(p.dayIndex(DateTime(2026, 9, 11)), 10);
    expect(p.dayIndex(DateTime(2027, 1, 1)), 59); // chegara
    expect(p.dayIndex(DateTime(2026, 8, 1)), 0);
    expect(ymd(p.finishDate), '2026-10-30');
    final back = StudyPlan.fromJson(p.toJson())!;
    expect(back.days, 60);
    expect(back.start, '2026-09-01');
    expect(StudyPlan.fromJson('buzuq'), isNull);
  });
}
