import 'package:flutter/material.dart';

import '../theme.dart';
import 'drill_screen.dart';
import 'weak_topics.dart';

/// ZAIF MAVZULAR bo'limi — "qaysi joyini o'zlashtirolmayapti".
///
/// Har bir mavzu (Grammatika, Lug'at, O'qish...) bo'yicha
/// o'zlashtirish foizi va bitta bosishda aynan shu mavzu ustida
/// mashq. Ilgari ilova buni bilardi (band darajasidagi hisob), lekin
/// KO'RSATMASDI.
class WeakTopicsSection extends StatefulWidget {
  const WeakTopicsSection({super.key});

  @override
  State<WeakTopicsSection> createState() => _WeakTopicsSectionState();
}

class _WeakTopicsSectionState extends State<WeakTopicsSection> {
  List<WeakTopic>? _topics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await weakTopics();
    if (mounted) setState(() => _topics = t);
  }

  Future<void> _drill(WeakTopic t) async {
    final src = weakestOf(t);
    if (src.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillScreen(
          title: t.topic,
          lessonSources: src,
        ),
      ),
    );
    if (mounted) _load(); // qaytganda foizlar yangilansin
  }

  @override
  Widget build(BuildContext context) {
    final t = _topics;
    if (t == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (t.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Zaif mavzular', style: AppTheme.heading(context)),
        const SizedBox(height: 2),
        Text(
          'Eng ko\'p qiynalayotgan joylaringiz. Bosing — aynan shu '
          'mavzu ustida mashq boshlanadi.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted(context)),
        ),
        const SizedBox(height: 12),
        for (final x in t) _TopicCard(topic: x, onTap: () => _drill(x)),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  final WeakTopic topic;
  final VoidCallback onTap;
  const _TopicCard({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = (topic.ratio * 100).round();
    // Rang o'zlashtirishga qarab: qizil emas — tushkunlik tug'dirmasin.
    final color = pct >= 70
        ? AppColors.success
        : (pct >= 40 ? AppColors.coin : AppColors.homework);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(topic.topic,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                    Text('$pct%',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: color)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: topic.ratio,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${topic.left} ta savol qoldi',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.muted(context))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
