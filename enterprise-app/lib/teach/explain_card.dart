import 'package:flutter/material.dart';

import '../theme.dart';
import 'explain.dart';

/// TUShUNTIRISh KARTASI — javobdan keyin "nega shunday" izohi.
///
/// Ilgari izoh faqat kitobda `whyUz` bo'lgan bandlarda chiqardi (yarmida
/// yo'q edi) — o'quvchi xato qilib, sababini bilmay ketaverardi. Endi
/// `explainAnswer` har doim kamida bitta izoh beradi.
class ExplainCard extends StatelessWidget {
  final List<Explanation> items;
  final bool correct;

  /// Karta tepasidagi qalin natija qatori ("To'g'ri!" / "Noto'g'ri. ...").
  /// Bo'sh bo'lsa chiqmaydi. Ilgari to'g'ri/noto'g'ri faqat RANG bilan
  /// aytilardi - yangi o'quvchi uni sezmasdi.
  final String verdict;

  const ExplainCard({
    super.key,
    required this.items,
    required this.correct,
    this.verdict = '',
  });

  /// Qulay konstruktor: javob va to'g'ri variantdan izoh yasaydi.
  ///
  /// [showAnswer] - xato bo'lsa natija qatorida to'g'ri javob ham yoziladi
  /// (ekranda u boshqa joyda ko'rinib tursa, o'chiring). [willRepeat] -
  /// "Bu savol keyinroq yana so'raladi" (mashqlarda shunday).
  factory ExplainCard.forAnswer({
    Key? key,
    required String correct,
    String given = '',
    String whyUz = '',
    String ruleUz = '',
    String uz = '',
    String Function(String word)? lookup,
    required bool isCorrect,
    bool showAnswer = true,
    bool willRepeat = false,
  }) =>
      ExplainCard(
        key: key,
        correct: isCorrect,
        verdict: isCorrect
            ? 'To\'g\'ri!'
            : [
                // To'g'ri/Noto'g'ri tugmali savolda "To'g'ri javob: To'g'ri"
                // chalkash - u yerda gapning o'zi haqida aytiladi.
                if (_isTrueFalse(correct))
                  'Noto\'g\'ri javob. Gap aslida '
                      '${correct.trim().startsWith('No') ? 'noto\'g\'ri' : 'to\'g\'ri'}.'
                else ...[
                  'Noto\'g\'ri.',
                  if (showAnswer && correct.trim().isNotEmpty)
                    'To\'g\'ri javob: ${correct.trim()}.',
                ],
                if (willRepeat) 'Bu savol keyinroq yana so\'raladi.',
              ].join(' '),
        items: explainAnswer(
          correct: correct,
          given: given,
          whyUz: whyUz,
          ruleUz: ruleUz,
          uz: uz,
          lookup: lookup,
          isCorrect: isCorrect,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && verdict.isEmpty) return const SizedBox.shrink();
    final c = correct ? AppColors.success : AppColors.danger;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(left: BorderSide(color: c, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (verdict.isNotEmpty) ...[
            Text(
              verdict,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w900,
                color: c,
              ),
            ),
            if (items.isNotEmpty) const SizedBox(height: 8),
          ],
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_emoji(items[i].source),
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: c,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i].text,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static bool _isTrueFalse(String s) {
    final t = s.trim();
    return t == 'To\'g\'ri' || t == 'Noto\'g\'ri';
  }

  static String _emoji(String source) => switch (source) {
        'book' => '📘',
        'rule' => '📐',
        'diff' => '💡',
        'tr' => '💬',
        _ => '✅',
      };
}
