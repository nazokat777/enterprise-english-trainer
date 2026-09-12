import 'package:flutter/material.dart';

import '../content.dart';
import '../main.dart';
import '../theme.dart';
import '../services/tts.dart';
import '../widgets/explain_text.dart';

/// Daraja bo'yicha ma'lumotnoma: grammatika mavzulari va so'z oilalari.
///
/// Bu ikki ro'yxat asset'larda ANChADAN BERI bor edi (`grammar.json`,
/// `word_formation.json`) va ilova ularni yuklardi ham — lekin hech bir
/// ekran ko'rsatmasdi, ya'ni o'quvchi ularni umuman ko'rmasdi.
///
/// Kitob bo'limidagi `RuleScreen`/`WordFormationScreen` dan farqi: ular
/// BITTA unitga tegishli, bu yerda esa butun daraja bo'yicha umumiy
/// ro'yxat — takrorlash uchun qulay.

/// Ro'yxat bo'sh bo'lganda ko'rsatiladigan xabar.
Widget _empty(BuildContext context, IconData icon, String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.muted(context)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center, style: AppTheme.body(context)),
          ],
        ),
      ),
    );

// ═══════════════════ Grammatika mavzulari ═══════════════════
class LevelGrammarScreen extends StatelessWidget {
  const LevelGrammarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topics = repo.forLevel(progress.currentLevel).grammar;
    if (topics.isEmpty) {
      return _empty(context, Icons.rule_rounded,
          'Bu daraja uchun grammatika mavzulari hali yo\'q.');
    }
    // Unit bo'yicha sarlavhalar — 200+ mavzu orasida yo'l topish uchun.
    final rows = <Widget>[];
    var lastUnit = -1;
    for (final t in topics) {
      if (t.unit != lastUnit) {
        lastUnit = t.unit;
        rows.add(_UnitDivider(unit: t.unit));
      }
      rows.add(_TopicCard(topic: t));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _Header(
            title: 'Grammatika',
            subtitle: "${topics.length} ta qoida — uchala kitobdan, unit bo'yicha",
            icon: Icons.rule_rounded,
            color: AppColors.actionBlue,
          );
        }
        return rows[i - 1];
      },
    );
  }
}

class _TopicCard extends StatelessWidget {
  final GrammarTopic topic;
  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(topic.topic,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  color: AppColors.actionBlue)),
          if (topic.ruleUz.isNotEmpty) ...[
            const SizedBox(height: 7),
            ExplainText(topic.ruleUz,
                style: const TextStyle(fontSize: 13.5, height: 1.55)),
          ],
          if (topic.examples.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final e in topic.examples) _Example(text: e),
          ],
          if (topic.source.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('📖 ${topic.source}',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.brandPurple)),
          ],
        ],
      ),
    );
  }
}

class _UnitDivider extends StatelessWidget {
  final int unit;
  const _UnitDivider({required this.unit});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.actionBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(unit > 0 ? '$unit-unit' : 'Umumiy',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: AppColors.actionBlue)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Divider(color: AppColors.actionBlue.withValues(alpha: 0.25))),
        ],
      ),
    );
  }
}

/// Misol gap — bosilganda ovoz chiqarib o'qiladi.
class _Example extends StatelessWidget {
  final String text;
  const _Example({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => Tts.instance.speak(text, id: text),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.volume_up_rounded,
                  size: 15, color: AppColors.actionBlue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13.5, fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════ So'z oilalari ═══════════════════
class LevelWordFormationScreen extends StatelessWidget {
  const LevelWordFormationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final families = repo.forLevel(progress.currentLevel).families;
    if (families.isEmpty) {
      return _empty(context, Icons.account_tree_rounded,
          'Bu daraja uchun so\'z oilalari hali yo\'q.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: families.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _Header(
            title: 'So\'z yasalishi',
            subtitle: '${families.length} ta so\'z oilasi — '
                'bitta o\'zakdan yasalgan shakllar',
            icon: Icons.account_tree_rounded,
            color: AppColors.success,
          );
        }
        return _FamilyCard(family: families[i - 1]);
      },
    );
  }
}

class _FamilyCard extends StatelessWidget {
  final WordFamily family;
  const _FamilyCard({required this.family});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sarlavha qatori tor ekranda sig'masligi mumkin — `Wrap`.
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () =>
                    Tts.instance.speak(family.base, id: family.base),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(family.base,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.success)),
                    const SizedBox(width: 5),
                    const Icon(Icons.volume_up_rounded,
                        size: 14, color: AppColors.success),
                  ],
                ),
              ),
              if (family.uz.isNotEmpty)
                Text(family.uz,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.muted(context))),
            ],
          ),
          if (family.forms.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in family.forms) _FormChip(text: f),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FormChip extends StatelessWidget {
  final String text;
  const _FormChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: () => Tts.instance.speak(text, id: text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.success)),
      ),
    );
  }
}

// ═══════════════════ Umumiy sarlavha ═══════════════════
class _Header extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: dark
                            ? AppColors.darkHeading
                            : AppColors.lightHeading)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.muted(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
