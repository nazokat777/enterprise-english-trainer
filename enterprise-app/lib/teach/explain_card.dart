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

  const ExplainCard({super.key, required this.items, required this.correct});

  /// Qulay konstruktor: javob va to'g'ri variantdan izoh yasaydi.
  factory ExplainCard.forAnswer({
    Key? key,
    required String correct,
    String given = '',
    String whyUz = '',
    String ruleUz = '',
    String uz = '',
    String Function(String word)? lookup,
    required bool isCorrect,
  }) =>
      ExplainCard(
        key: key,
        correct: isCorrect,
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
    if (items.isEmpty) return const SizedBox.shrink();
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

  static String _emoji(String source) => switch (source) {
        'book' => '📘',
        'rule' => '📐',
        'diff' => '💡',
        'tr' => '💬',
        _ => '✅',
      };
}
