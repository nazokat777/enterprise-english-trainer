import 'package:enterprise_english/lessons/lesson_session.dart';
import 'package:enterprise_english/lessons/word_lesson.dart';
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/memory/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const day = 86400000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ItemMastery.schedule', () {
    test('birinchi to\'g\'ri javob 1 kun, ishlab chiqarish 3 kun', () {
      final a = ItemMastery()..schedule(true, AskFormat.choice, 0);
      expect(a.interval, 1);
      expect(a.dueMs, day);
      final b = ItemMastery()..schedule(true, AskFormat.produce, 0);
      expect(b.interval, 3);
    });

    test('bir seansdagi takror javoblar intervalni oshirmaydi', () {
      final m = ItemMastery()..schedule(true, AskFormat.choice, 0);
      m.schedule(true, AskFormat.produce, 60000);
      m.schedule(true, AskFormat.build, 120000);
      expect(m.interval, 1, reason: 'erta takror sanalmaydi');
    });

    test('muddati kelganda zinapoya bo\'ylab o\'sadi, xato 1 kunga qaytaradi',
        () {
      final m = ItemMastery()..schedule(true, AskFormat.choice, 0);
      m.schedule(true, AskFormat.choice, day); // 1 -> 3
      expect(m.interval, 3);
      m.schedule(true, AskFormat.produce, 4 * day); // 3 -> 14 (ishlab chiqarish +1)
      expect(m.interval, 14);
      expect(m.stage, 3);
      m.schedule(false, AskFormat.choice, 18 * day);
      expect(m.interval, 1);
      expect(m.stage, 0);
    });

    test('isFading: muddati o\'tgan va abadiy emas', () {
      final m = ItemMastery(correct: 1)..schedule(true, AskFormat.choice, 0);
      expect(m.isFading(day - 1), isFalse);
      expect(m.isFading(day), isTrue);
      expect(m.overdueDays(3 * day), 2);
      final forever = ItemMastery(correct: 1, interval: 120, dueMs: 1);
      expect(forever.stage, 4);
      expect(forever.isFading(day), isFalse);
    });

    test('json: interval, muddat, eslatma, en/uz saqlanadi', () {
      final m = ItemMastery(correct: 2, interval: 7, dueMs: 5, hook: 'x', en: 'a', uz: 'b');
      final r = ItemMastery.fromJson(m.toJson());
      expect(r.interval, 7);
      expect(r.dueMs, 5);
      expect(r.hook, 'x');
      expect(r.en, 'a');
      expect(r.uz, 'b');
    });
  });

  group('MasteryStore', () {
    late MasteryStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = MasteryStore();
      await store.load();
    });

    test('fadingIds faqat lug\'at so\'zlari, eng kechikkanidan', () async {
      await store.record('w::apple', AskFormat.produce,
          ok: true, en: 'apple', uz: 'olma', nowMs: 0);
      await store.record('w::pear', AskFormat.produce,
          ok: true, en: 'pear', uz: 'nok', nowMs: day);
      await store.record('t::ex1::1', AskFormat.produce, ok: true, nowMs: 0);
      expect(store.fadingIds(nowMs: 2 * day), isEmpty);
      expect(store.fadingIds(nowMs: 5 * day), ['w::apple', 'w::pear']);
      expect(store.fadingCount(nowMs: 5 * day), 2);
      expect(store.garden(), [0, 2, 0, 0, 0]);
    });

    test('setHook saqlanadi va qayta yuklanadi', () async {
      await store.record('w::apple', AskFormat.choice, ok: true, nowMs: 0);
      await store.setHook('w::apple', ' olma - Apple kompaniyasi ');
      final again = MasteryStore();
      await again.load();
      expect(again.of('w::apple').hook, 'olma - Apple kompaniyasi');
    });

    test('MemoryRescue.lesson va extras', () async {
      await store.record('w::apple', AskFormat.produce,
          ok: true, en: 'apple', uz: 'olma', nowMs: 0);
      await store.record('w::pear', AskFormat.produce,
          ok: true, en: 'pear', uz: 'nok', nowMs: 0);
      expect(MemoryRescue.lesson(store, nowMs: 0), isNull);
      final l = MemoryRescue.lesson(store, nowMs: 10 * day)!;
      expect(l.words.map((w) => w.en), ['apple', 'pear']);
      expect(l.words.first.itemId, 'w::apple');

      final current = WordLesson(
          index: 1, unit: 1, words: const [LessonWord(en: 'apple', uz: 'olma')]);
      final ex = MemoryRescue.extras(store, current, nowMs: 10 * day);
      expect(ex.map((e) => e.itemId), ['w::pear'],
          reason: 'darsdagi so\'z aralash takrorga kirmaydi');
    });

    test('tonightIds: bugun so\'ralgan, zaif so\'zlar', () async {
      const now = 10 * day + 3600000;
      await store.record('w::apple', AskFormat.choice,
          ok: false, en: 'apple', uz: 'olma', nowMs: now);
      await store.record('w::pear', AskFormat.choice,
          ok: true, en: 'pear', uz: 'nok', nowMs: now);
      await store.record('w::old', AskFormat.choice,
          ok: true, en: 'old', uz: 'eski', nowMs: now - 2 * day);
      expect(store.tonightIds(nowMs: now), ['w::apple', 'w::pear']);
      expect(MemoryRescue.tonight(store, nowMs: now)!.words.length, 2);
      expect(MemoryRescue.isEvening(DateTime(2026, 1, 1, 21)), isTrue);
      expect(MemoryRescue.isEvening(DateTime(2026, 1, 1, 12)), isFalse);
    });

    test('3-raundda ovozi bor har ikkinchi so\'z eshitib yoziladi', () async {
      final lesson = WordLesson(index: 1, unit: 1, words: const [
        LessonWord(en: 'cat', uz: 'mushuk'),
        LessonWord(en: 'dog', uz: 'it'),
        LessonWord(en: 'cow', uz: 'sigir'),
        LessonWord(en: 'hen', uz: 'tovuq'),
      ]);
      final s = LessonSession(
          lesson: lesson, mastery: store, hasAudio: (_) => true);
      final formats = <AskFormat>[];
      while (!s.isDone) {
        formats.add(s.current!.format);
        await s.answer(true);
      }
      expect(formats.where((f) => f == AskFormat.listen).length, 2);
      expect(formats.where((f) => f == AskFormat.build).length, 2);
      final none = LessonSession(
          lesson: lesson, mastery: store, hasAudio: (_) => false);
      expect(none.round, 1);
    });

    test('talaffuz raundi: canSpeak bo\'lsa build\'dan keyin, skip xato emas', () async {
      final lesson = WordLesson(index: 1, unit: 1, words: const [
        LessonWord(en: 'cat', uz: 'mushuk'),
        LessonWord(en: 'dog', uz: 'it'),
        LessonWord(en: 'cow', uz: 'sigir'),
        LessonWord(en: 'hen', uz: 'tovuq'),
      ]);
      final off = LessonSession(lesson: lesson, mastery: store, hasAudio: (_) => false);
      final on = LessonSession(
          lesson: lesson, mastery: store, hasAudio: (_) => false, canSpeak: true);
      expect(on.remaining, off.remaining + 4);
      final rounds = <int>[];
      var skipped = 0;
      while (!on.isDone) {
        final q = on.current!;
        if (q.format == AskFormat.speak) {
          rounds.add(on.round);
          on.skip();
          skipped++;
        } else {
          await on.answer(true);
        }
      }
      expect(skipped, 4);
      expect(rounds.toSet(), {4}); // choice, produce, build, SPEAK
      expect(on.mistakes, 0);
      expect(store.of('w::cat').passed.contains(AskFormat.speak), isFalse);
      expect(on.progress, 1);
    });

    test('LessonSession extras navbatga qo\'shiladi', () async {
      final lesson = WordLesson(index: 1, unit: 1, words: const [
        LessonWord(en: 'cat', uz: 'mushuk'),
        LessonWord(en: 'dog', uz: 'it'),
        LessonWord(en: 'cow', uz: 'sigir'),
        LessonWord(en: 'hen', uz: 'tovuq'),
      ]);
      final s = LessonSession(lesson: lesson, mastery: store);
      final base = s.remaining;
      await store.record('w::pear', AskFormat.produce,
          ok: true, en: 'pear', uz: 'nok', nowMs: 0);
      final s2 = LessonSession(
        lesson: lesson,
        mastery: store,
        extras: MemoryRescue.extras(store, lesson, nowMs: 10 * day),
      );
      expect(s2.extraCount, 1);
      expect(s2.remaining, base + 1);
    });
  });
}
