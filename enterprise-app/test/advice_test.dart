import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_english/memory/advice.dart';

/// Bugungi tavsiya tartibi: qutqarish > imtihon > keyingi dars > blitz/tez mashq.
void main() {
  test('tartib', () {
    expect(
        HomeAdvice.compute(fading: 5, examUnit: 2, examPassed: false, nextLesson: 'x', goalMet: false).emoji,
        '🛟');
    expect(
        HomeAdvice.compute(fading: 2, examUnit: 2, examPassed: false, nextLesson: 'x', goalMet: false).text,
        '1-2 unitlar imtihoni tayyor');
    expect(
        HomeAdvice.compute(fading: 0, examUnit: 2, examPassed: true, nextLesson: '2-unit, 3-dars', goalMet: false).text,
        'Keyingi: 2-unit, 3-dars');
    expect(
        HomeAdvice.compute(fading: 0, examUnit: 0, examPassed: false, nextLesson: null, goalMet: true).emoji,
        '⚡');
    expect(
        HomeAdvice.compute(fading: 0, examUnit: 0, examPassed: false, nextLesson: null, goalMet: false).emoji,
        '🚀');
  });
}
