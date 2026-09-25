import 'package:flutter/material.dart';

import '../theme.dart';

/// SAVOL KARTASI — "nima so'ralyapti" har doim ko'rinib turadi.
///
/// Ustoz bilan sinovda ma'lum bo'ldi: ilova inglizcha matn va tugmalarni
/// ko'rsatardi, lekin NIMA qilish kerakligi faqat kichkina ko'rsatmada
/// yozilardi. Kitobi yo'q odam tushunmasdi. Endi har bandda yashil
/// "Nima qilinadi" qatori va kerak bo'lsa maslahat turadi.
class QuestionCard extends StatelessWidget {
  /// O'zbekcha savol — nima qilish kerak.
  final String question;

  /// Qo'shimcha maslahat (ixtiyoriy).
  final String hint;

  /// Manba: "Coursebook 10-bet · 7-mashq" (ixtiyoriy).
  final String source;

  const QuestionCard({
    super.key,
    required this.question,
    this.hint = '',
    this.source = '',
  });

  @override
  Widget build(BuildContext context) {
    if (question.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
      decoration: BoxDecoration(
        color: AppColors.actionBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
            left: BorderSide(color: AppColors.actionBlue, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('❓', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nima qilinadi',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.actionBlue,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      question,
                      style: const TextStyle(
                          fontSize: 14, height: 1.45, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hint.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              hint,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.muted(context)),
            ),
          ],
          if (source.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              source,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.muted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
