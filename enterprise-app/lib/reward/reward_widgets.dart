import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'reward_engine.dart';

/// 0 dan sanab chiqadigan raqam (count-up) — natija ekranida.
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String suffix;
  final Duration duration;
  const CountUp(this.value,
      {super.key,
      this.style,
      this.suffix = '',
      this.duration = const Duration(milliseconds: 900)});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// Natija ekranidagi statistika: XP · eng katta kombo · xatosiz.
class ResultStatsRow extends StatelessWidget {
  final int xp;
  final bool clean;
  const ResultStatsRow({super.key, required this.xp, required this.clean});

  @override
  Widget build(BuildContext context) {
    final r = rewards;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Stat(
              icon: '⚡',
              label: 'XP',
              color: AppColors.coin,
              child: CountUp(xp,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            _Stat(
              icon: '🔥',
              label: 'kombo',
              color: const Color(0xFFF97316),
              child: CountUp(r.combo,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            _Stat(
              icon: clean ? '💎' : '🔁',
              label: clean ? 'xatosiz' : 'takror',
              color: clean ? AppColors.brandPurple : AppColors.homework,
              child: Text(clean ? '+3' : '—',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Daraja halqasi: "yana N XP" — Zeigarnik: tugallanmagan ish.
        const LevelBar(),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final Widget child;
  const _Stat(
      {required this.icon, required this.label, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          DefaultTextStyle(
              style: TextStyle(color: color, fontWeight: FontWeight.w900), child: child),
          Text(label,
              style: TextStyle(fontSize: 11, color: AppColors.muted(context))),
        ],
      ),
    );
  }
}

/// Daraja chizig'i: unvon + XP progress + "yana N XP".
class LevelBar extends StatelessWidget {
  final bool compact;
  const LevelBar({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        final r = rewards;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brandPurple,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('${r.level}-daraja',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 12 : 13,
                          color: AppColors.brandPurple)),
                ),
                Text('yana ${r.xpToNext} XP',
                    style: TextStyle(fontSize: 11, color: AppColors.muted(context))),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: r.levelProgress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: compact ? 6 : 8,
                  backgroundColor: AppColors.brandPurple.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(AppColors.brandPurple),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Header uchun daraja halqasi (kichik, raqam bilan).
class LevelRing extends StatelessWidget {
  final double size;
  const LevelRing({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        final r = rewards;
        return Tooltip(
          message: '${r.level}-daraja · ${r.title} · yana ${r.xpToNext} XP',
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: r.levelProgress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => CircularProgressIndicator(
                    value: v,
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.brandPurple.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(AppColors.brandPurple),
                  ),
                ),
                Text('${r.level}',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: size * 0.36,
                        color: AppColors.brandPurple)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Jonli streak olovi — pulsatsiya; 7+ kunda ko'k olov.
class StreakFlame extends StatefulWidget {
  final int days;
  const StreakFlame({super.key, required this.days});
  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        // Cheksiz emas: bir necha "nafas" oladi-da tinchiydi (testlarda
        // pumpAndSettle osilib qolmasin, batareya ham).
        ..repeat(reverse: true, count: 6);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.days;
    final emoji = d >= 30 ? '💠' : (d >= 7 ? '🔥' : (d >= 1 ? '🔥' : '🌱'));
    final color = d >= 30
        ? const Color(0xFF06B6D4)
        : (d >= 7 ? const Color(0xFFDC2626) : const Color(0xFFF97316));
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = Curves.easeInOut.transform(_c.value);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: d >= 1
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.15 + 0.25 * v),
                        blurRadius: 8 + 10 * v),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: d >= 1 ? 1 + 0.15 * v : 1,
                child: Text(emoji, style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 5),
              Text('$d',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14, color: color)),
            ],
          ),
        );
      },
    );
  }
}

/// "Bugungi topshiriqlar" kartasi — bosh ekranda.
class DailyQuestsCard extends StatelessWidget {
  const DailyQuestsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        final r = rewards;
        final done = r.quests.where((q) => q.done).length;
        final all = r.quests.length;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.brandPurple.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.brandPurple.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Bugungi topshiriqlar',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                  Text(done == all ? '🎁 sandiq ochildi' : '$done / $all  ·  🎁',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: done == all ? AppColors.success : AppColors.muted(context))),
                ],
              ),
              const SizedBox(height: 10),
              for (final q in r.quests) _QuestRow(q),
            ],
          ),
        );
      },
    );
  }
}

class _QuestRow extends StatelessWidget {
  final Quest q;
  const _QuestRow(this.q);
  @override
  Widget build(BuildContext context) {
    final color = q.done ? AppColors.success : AppColors.actionBlue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(q.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(q.titleUz,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              decoration: q.done ? TextDecoration.lineThrough : null)),
                    ),
                    Text(q.done ? 'bajarildi' : '${q.progress}/${q.target}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: q.ratio),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 5,
                      backgroundColor: color.withValues(alpha: 0.14),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('+${q.coins}🪙',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.coin)),
        ],
      ),
    );
  }
}

/// Yutuqlar ekrani — olingan/qulflangan medallar.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = rewards;
    final all = RewardEngine.allAchievements;
    final got = all.where((a) => r.achievements.contains(a.id)).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Yutuqlar')),
      body: ListenableBuilder(
        listenable: r,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$got / ${all.length} yutuq',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(
                            '${r.level}-daraja · ${r.title}\n'
                            '${r.correctTotal} to\'g\'ri · rekord kombo ${r.bestCombo} · '
                            '${r.chestsOpened} sandiq',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Text('🏆', style: TextStyle(fontSize: 44)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.86,
              ),
              itemCount: all.length,
              itemBuilder: (_, i) {
                final a = all[i];
                final has = r.achievements.contains(a.id);
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: has
                        ? AppColors.coin.withValues(alpha: 0.14)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: has
                            ? AppColors.coin
                            : AppColors.neutralShadow.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Opacity(
                        opacity: has ? 1 : 0.35,
                        child: Text(has ? a.emoji : '🔒',
                            style: const TextStyle(fontSize: 34)),
                      ),
                      const SizedBox(height: 6),
                      Text(a.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: has ? null : AppColors.muted(context))),
                      Text(a.desc,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5, color: AppColors.muted(context))),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Kichik yordamchi: tasodifiy rag'bat so'zi (har safar boshqa —
/// takrorlanmasligi ham kutilmaganlik).
String cheer(Random rng) {
  const w = [
    'Zo\'r!', 'Ajoyib!', 'Davom eting!', 'Qoyil!', 'Barakalla!',
    'Aynan shunday!', 'Tez-tez!', 'Oldinga!', 'Ustasiz!', 'Yana!',
  ];
  return w[rng.nextInt(w.length)];
}

/// OLTIN SAVOL — javobdan oldin e'lon: kutilish (anticipation) dofamini.
class GoldenBanner extends StatefulWidget {
  const GoldenBanner({super.key});
  @override
  State<GoldenBanner> createState() => _GoldenBannerState();
}

class _GoldenBannerState extends State<GoldenBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true, count: 10);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = Curves.easeInOut.transform(_c.value);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFFDE68A), Color(0xFFF59E0B)]),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                  color: AppColors.coin.withValues(alpha: 0.35 + 0.35 * v),
                  blurRadius: 14 + 14 * v,
                  spreadRadius: 1 + 2 * v),
            ],
          ),
          child: child,
        );
      },
      child: const Row(
        children: [
          Text('🌟', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Expanded(
            child: Text("OLTIN SAVOL — to'g'ri javob 3 barobar XP!",
                style: TextStyle(
                    color: Color(0xFF3B2A00),
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// "Deyarli!" — yaqin xato izohi (near-miss).
class NearMissNote extends StatelessWidget {
  const NearMissNote({super.key});
  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFF97316);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: const Row(
        children: [
          Text('🎯', style: TextStyle(fontSize: 18)),
          SizedBox(width: 10),
          Expanded(
            child: Text('Deyarli! Faqat bitta harf farq — bu band yana keladi.',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: c)),
          ),
        ],
      ),
    );
  }
}
