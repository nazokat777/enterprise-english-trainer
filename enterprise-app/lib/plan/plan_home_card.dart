import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets/hover_lift.dart';
import 'mnemonics_screen.dart';
import 'study_plan.dart';

/// BOSh EKRAN: Mnemonika xaritasi kartasi.
///
/// Reja yo'q bo'lsa - kitob hajmi va "necha kunda tugatasiz?" taklifi.
/// Reja bo'lsa - "12-kun / 60", tugash sanasi, umumiy foiz va holat.
class PlanHomeCard extends StatefulWidget {
  const PlanHomeCard({super.key});

  @override
  State<PlanHomeCard> createState() => _PlanHomeCardState();
}

class _PlanHomeCardState extends State<PlanHomeCard> {
  BookVolume? _v;
  StudyPlan? _plan;

  @override
  void initState() {
    super.initState();
    _load();
    plans.addListener(_load);
    book.addListener(_load);
    mastery.addListener(_refresh);
  }

  @override
  void dispose() {
    plans.removeListener(_load);
    book.removeListener(_load);
    mastery.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final v = await plans.volume();
    final p = await plans.plan();
    if (!mounted) return;
    setState(() {
      _v = v;
      _plan = p;
    });
  }

  void _open() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Mnemonika')),
          body: const MnemonicsScreen(),
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    if (v == null || v.lessons == 0) return const SizedBox.shrink();
    final p = _plan;

    String title;
    String sub;
    double ratio = 0;
    if (p == null) {
      title = 'Mnemonika xaritasi';
      sub = '${fmt(v.uniqueWords)} so\'z · ${fmt(v.lessons)} dars · '
          '${v.rules} qoida. Kitobni necha kunda tugatasiz? Reja tuzing.';
    } else {
      final schedule = buildSchedule(v, p.days);
      final day = p.dayIndex(DateTime.now());
      final st = planStatus(schedule, day, plans.isDone);
      ratio = st.ratio;
      title = '${day + 1}-kun / ${p.days} · ${(st.ratio * 100).round()}%';
      sub = st.behind > 0
          ? '${st.behind} ta band ortda · tugash: ${uzDate(p.finishDate)}'
          : 'Reja bo\'yicha · tugash: ${uzDate(p.finishDate)}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HoverLift(
        child: SurfaceCard(
          onTap: _open,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F766E), Color(0xFF0891B2), Color(0xFF4F46E5)],
          ),
          child: Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5)),
                    const SizedBox(height: 3),
                    Text(sub,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12.5,
                            height: 1.35)),
                    if (p != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
