import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_english/srs.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  test('yangi so\'z, birinchi to\'g\'ri javob → interval 1, rep 1', () {
    final w = WordSrs();
    expect(w.isNew, isTrue);
    w.review(Quality.good, now: now);
    expect(w.interval, 1);
    expect(w.repetitions, 1);
    expect(w.nextReviewAt, DateTime(2026, 1, 2));
    expect(w.isNew, isFalse);
  });

  test('ikkinchi to\'g\'ri javob → interval 6', () {
    final w = WordSrs()
      ..review(Quality.good, now: now)
      ..review(Quality.good, now: now);
    expect(w.interval, 6);
    expect(w.repetitions, 2);
  });

  test('uchinchi to\'g\'ri → interval = round(interval * EF)', () {
    final w = WordSrs()
      ..review(Quality.good, now: now)
      ..review(Quality.good, now: now);
    final efBefore = w.easeFactor; // "good" (q=4) EF ni o'zgartirmaydi → 2.5
    w.review(Quality.good, now: now);
    expect(w.interval, (6 * efBefore).round()); // 15
    expect(w.repetitions, 3);
  });

  test('xato (Bilmadim) → reset: interval 1, rep 0, EF kamayadi (>=1.3)', () {
    final w = WordSrs()
      ..review(Quality.good, now: now)
      ..review(Quality.good, now: now);
    final efBefore = w.easeFactor;
    w.review(Quality.unknown, now: now); // q=1
    expect(w.interval, 1);
    expect(w.repetitions, 0);
    expect(w.easeFactor, lessThan(efBefore));
    expect(w.easeFactor, greaterThanOrEqualTo(1.3));
  });

  test('EF 1.3 dan pastga tushmaydi (ko\'p xato)', () {
    final w = WordSrs();
    for (var i = 0; i < 10; i++) {
      w.review(Quality.unknown, now: now);
    }
    expect(w.easeFactor, greaterThanOrEqualTo(1.3));
  });

  test('"Oson" (q=5) EF ni oshiradi', () {
    final w = WordSrs()..review(Quality.easy, now: now);
    expect(w.easeFactor, greaterThan(2.5));
  });

  test('isDue: muddat kelganda true', () {
    final w = WordSrs()..review(Quality.good, now: now); // next = jan 2
    expect(w.isDue(DateTime(2026, 1, 1, 12)), isFalse);
    expect(w.isDue(DateTime(2026, 1, 3)), isTrue);
  });

  test('recallProbability: interval nuqtasida ~0.9', () {
    final w = WordSrs()
      ..review(Quality.good, now: now)
      ..review(Quality.good, now: now); // interval 6, lastReviewed = jan1
    final r = w.recallProbability(DateTime(2026, 1, 7)); // +6 kun
    expect(r, closeTo(0.9, 0.02));
  });

  test('isKnown: interval >= 21 → mature', () {
    final w = WordSrs(interval: 25, nextReviewAt: now);
    expect(w.isKnown, isTrue);
  });

  test('toJson/fromJson round-trip', () {
    final w = WordSrs()..review(Quality.good, now: now);
    final w2 = WordSrs.fromJson(w.toJson());
    expect(w2.interval, w.interval);
    expect(w2.repetitions, w.repetitions);
    expect(w2.easeFactor, w.easeFactor);
    expect(w2.nextReviewAt, w.nextReviewAt);
  });
}
