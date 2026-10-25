import 'package:flutter/material.dart';

import '../theme.dart';
import 'clarify.dart' show friendlyRef;

/// SAHIFA KIRISHI — sahifa tepasidagi "Bu yerda: ..." qatori.
///
/// Yangi o'quvchi 5 soniyada bilsin: bu sahifa NIMA, undan NIMA qilish
/// kerak. Matn "Bu yerda:" bilan boshlansa, shu so'z qalin chiqadi.
class PageIntro extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry margin;

  const PageIntro(
    this.text, {
    super.key,
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    const lead = 'Bu yerda:';
    final hasLead = text.startsWith(lead);
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.actionBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.actionBlue),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (hasLead)
                    const TextSpan(
                      text: lead,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  TextSpan(text: hasLead ? text.substring(lead.length) : text),
                ],
              ),
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

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

  /// Kitobdagi manzil: "3-unit · Enterprise 1 · Coursebook · 7-bet · Ex. 5"
  /// (ixtiyoriy; "Kitobda: ..." deb, kitob nomlari izohlangan holda chiqadi).
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
            // Kitobi yo'q odam ham bilsin: bu - kitobdagi manzil, uni
            // ochish shart emas (savol shu ekranda to'liq).
            Text(
              '📖 Kitobda: ${friendlyRef(source.trim())}',
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
