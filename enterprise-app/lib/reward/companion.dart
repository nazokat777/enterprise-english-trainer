import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'reward_engine.dart';

// ═══════════════════ HAMROH (maskot) ═══════════════════

/// Hamrohning bosqichi — daraja bilan evolyutsiya. O'quvchi "uni
/// o'stiryapman" deb his qiladi: g'amxo'rlik instinkti + endowment.
class MascotStage {
  final String emoji;
  final String name;
  final int minLevel;
  const MascotStage(this.emoji, this.name, this.minLevel);

  static const List<MascotStage> stages = [
    MascotStage('🥚', 'Tuxum', 1),
    MascotStage('🐣', 'Jo\'ja', 2),
    MascotStage('🐥', 'Polapon', 4),
    MascotStage('🐤', 'Yosh qush', 7),
    MascotStage('🦜', 'To\'tiqush', 10),
    MascotStage('🦉', 'Boyqush', 15),
    MascotStage('🦅', 'Burgut', 22),
    MascotStage('🐉', 'Ajdar', 30),
  ];

  static MascotStage forLevel(int level) {
    var s = stages.first;
    for (final st in stages) {
      if (level >= st.minLevel) s = st;
    }
    return s;
  }

  static MascotStage? nextAfter(int level) {
    for (final st in stages) {
      if (st.minLevel > level) return st;
    }
    return null;
  }
}

enum Mood { sleepy, calm, happy, fired }

Mood mascotMood() {
  final r = rewards;
  if (r.combo >= 5) return Mood.fired;
  if (r.idleToday) return Mood.sleepy;
  if (r.todayCorrect >= 15) return Mood.happy;
  return Mood.calm;
}

/// Kontekstli gap — har ochilishda boshqa (kutilmaganlik).
String mascotLine(Random rng) {
  final r = rewards;
  final m = mascotMood();
  final h = DateTime.now().hour;
  final pool = <String>[];
  switch (m) {
    case Mood.sleepy:
      pool.addAll([
        'Bugun hali boshlamadik... bitta mashq? 🥺',
        '${r.petName.isNotEmpty ? r.petName : 'Men'} seni kutyapti. 5 daqiqa yetadi!',
        'Streak ${progress.currentStreak} kun — uni saqlaymizmi?',
        h < 12 ? 'Xayrli tong! Ertalabki miya eng tez o\'rganadi.' : 'Kech bo\'lmasdan bitta dars qilaylik.',
      ]);
    case Mood.calm:
      pool.addAll([
        'Yaxshi ketyapmiz! Yana ${r.xpToNext} XP — keyingi daraja.',
        'Bugun ${r.todayCorrect} ta to\'g\'ri. Davom!',
        'Kunlik topshiriqlar seni kutyapti 🎯',
        if (r.spinAvailable)
          "G'ildirak tayyor — aylantir! 🎡"
        else if (!r.spinDoneToday)
          "Yana ${r.spinRemaining} ta to'g'ri javob — g'ildirak ochiladi."
        else
          "Ertaga yana g'ildirak bor. Bugun yana bitta mashq?",
      ]);
    case Mood.happy:
      pool.addAll([
        'Bugun zo\'r kun! ${r.todayXp} XP 🎉',
        'Men sen bilan faxrlanaman!',
        'Rekord kombo: ${r.bestCombo}. Uni yangilaymizmi?',
        'Shu tezlikda ${MascotStage.nextAfter(r.level)?.name ?? 'afsona'} bo\'laman!',
      ]);
    case Mood.fired:
      pool.addAll([
        '${r.combo} KOMBO! To\'xtama! 🔥',
        'Yonib ketdik! Yana bitta!',
        'Hozir eng yaxshi paytimiz — davom!',
      ]);
  }
  if (r.isHappyHour) pool.add('BAXTLI SOAT — hamma XP ikki barobar! ⚡⚡');
  return pool[rng.nextInt(pool.length)];
}

/// Hamroh kartasi — bosh ekranda.
class MascotCard extends StatefulWidget {
  final bool compact;
  const MascotCard({super.key, this.compact = false});
  @override
  State<MascotCard> createState() => _MascotCardState();
}

class _MascotCardState extends State<MascotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true, count: 8);
  final _rng = Random();
  String _line = '';
  Mood? _lastMood;

  @override
  void initState() {
    super.initState();
    _line = mascotLine(_rng);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _poke() {
    setState(() => _line = mascotLine(_rng));
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        final st = MascotStage.forLevel(rewards.level);
        final next = MascotStage.nextAfter(rewards.level);
        final mood = mascotMood();
        // Kayfiyat o'zgarsa gap ham o'zgarsin (uyqudan uyg'ongach
        // "kutyapman" deb turmasin).
        if (_lastMood != null && _lastMood != mood) {
          _line = mascotLine(_rng);
        }
        _lastMood = mood;
        final sleepy = mood == Mood.sleepy;
        return GestureDetector(
          onTap: _poke,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: sleepy
                    ? [const Color(0xFF64748B), const Color(0xFF334155)]
                    : mood == Mood.fired
                        ? [const Color(0xFFF97316), const Color(0xFFDC2626)]
                        : [AppColors.brandPurple, AppColors.actionBlue],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                    color: (sleepy ? Colors.black : AppColors.brandPurple)
                        .withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, child) {
                    final v = Curves.easeInOut.transform(_c.value);
                    final bounce = sleepy ? 0.0 : -6.0 * v;
                    final tilt = sleepy ? 0.25 : (mood == Mood.fired ? (v - 0.5) * 0.3 : 0.0);
                    return Transform.translate(
                      offset: Offset(0, bounce),
                      child: Transform.rotate(angle: tilt, child: child),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(st.emoji, style: const TextStyle(fontSize: 52)),
                      if (sleepy)
                        const Positioned(
                            left: -10, top: -10,
                            child: Text('💤', style: TextStyle(fontSize: 18))),
                      if (mood == Mood.fired)
                        const Positioned(
                            right: -10, top: -8,
                            child: Text('🔥', style: TextStyle(fontSize: 20))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(rewards.petName.isNotEmpty ? rewards.petName : st.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15)),
                          if (rewards.petName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('· ${st.name}',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                          const SizedBox(width: 8),
                          if (next != null)
                            Flexible(
                              child: Text('${next.emoji} ${next.minLevel}-darajada',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Text(_line,
                            style: const TextStyle(
                                color: Color(0xFF1F2430),
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════ STREAK XAVFI ═══════════════════

/// Bugun 0 XP bo'lsa: yo'qotish qo'rquvi — yarim tungacha hisoblagich.
class StreakDangerCard extends StatefulWidget {
  const StreakDangerCard({super.key});
  @override
  State<StreakDangerCard> createState() => _StreakDangerCardState();
}

class _StreakDangerCardState extends State<StreakDangerCard> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        if (!rewards.idleToday || progress.currentStreak == 0) {
          return const SizedBox.shrink();
        }
        final d = rewards.untilMidnight;
        final h = d.inHours;
        final m = d.inMinutes % 60;
        final urgent = h < 3;
        final color = urgent ? AppColors.danger : const Color(0xFFF97316);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Text(urgent ? '🚨' : '⏳', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${progress.currentStreak} kunlik streak xavf ostida',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14, color: color)),
                    Text(
                        'Yarim tungacha $h soat $m daqiqa. Bitta mashq yetadi.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════ FAOLLIK XARITASI ═══════════════════

class ActivityHeatmap extends StatelessWidget {
  final int weeks;
  const ActivityHeatmap({super.key, this.weeks = 12});

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        // Oxirgi kun — bugun, ustun = hafta (Dushanbadan).
        final start = today.subtract(Duration(days: weeks * 7 - 1 + (today.weekday - 1)));
        final activeDays = rewards.dayXp.values.where((v) => v > 0).length;
        final totalXp = rewards.dayXp.values.fold<int>(0, (a, b) => a + b);
        // Haftalik o'sish — "o'tgan haftadan ko'proq" (o'z-o'zi bilan
        // raqobat: ijtimoiy taqqoslashsiz, lekin xuddi shunday kuchli).
        final (cur, prev) = rewards.weeklyXp();
        final delta = prev == 0 ? null : ((cur - prev) * 100 / prev).round();
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.neutralShadow.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Faollik xaritasi',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                  Text('$activeDays kun · $totalXp XP',
                      style: TextStyle(fontSize: 11, color: AppColors.muted(context))),
                  if (delta != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (delta >= 0 ? AppColors.success : AppColors.homework)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text('${delta >= 0 ? '+' : ''}$delta% hafta',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: delta >= 0 ? AppColors.success : AppColors.homework)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, c) {
                  final cell = ((c.maxWidth - (weeks - 1) * 3) / weeks).clamp(6.0, 14.0);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var w = 0; w < weeks; w++)
                        Column(
                          children: [
                            for (var d = 0; d < 7; d++)
                              Builder(builder: (_) {
                                final day = start.add(Duration(days: w * 7 + d));
                                final future = day.isAfter(today);
                                final xp = rewards.dayXp[_key(day)] ?? 0;
                                final isToday = day == today;
                                final level = xp == 0 ? 0 : (xp < 20 ? 1 : (xp < 50 ? 2 : (xp < 100 ? 3 : 4)));
                                final color = future
                                    ? Colors.transparent
                                    : level == 0
                                        ? AppColors.neutralShadow.withValues(alpha: 0.35)
                                        : AppColors.success.withValues(alpha: 0.25 + 0.19 * level);
                                return Container(
                                  width: cell,
                                  height: cell,
                                  margin: const EdgeInsets.only(bottom: 3),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(3),
                                    border: isToday
                                        ? Border.all(color: AppColors.brandPurple, width: 1.5)
                                        : null,
                                  ),
                                );
                              }),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════ BAXTLI SOAT ═══════════════════

class HappyHourBadge extends StatefulWidget {
  const HappyHourBadge({super.key});
  @override
  State<HappyHourBadge> createState() => _HappyHourBadgeState();
}

class _HappyHourBadgeState extends State<HappyHourBadge> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '$h s $m d' : '$m daqiqa';
  }

  @override
  Widget build(BuildContext context) {
    final r = rewards;
    final on = r.isHappyHour;
    final color = on ? const Color(0xFFDC2626) : AppColors.coin;
    return Tooltip(
      message: on
          ? 'Baxtli soat: hamma XP ×2 — ${_fmt(r.happyHourCountdown)} qoldi'
          : 'Baxtli soat (×2 XP) ${r.happyHour}:00 da — ${_fmt(r.happyHourCountdown)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: on ? 1 : 0.14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: on
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)]
              : null,
        ),
        // Tor ekranda (320px) sig'masa kichrayadi — hech qachon oshib
        // ketmaydi.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(on ? '⚡⚡' : '⏰', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                  on
                      ? '×2 ${r.happyHourCountdown.inMinutes}d'
                      : '×2 ${r.happyHour}:00',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: on ? Colors.white : color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════ KUNLIK G'ILDIRAK ═══════════════════

/// Bosh ekrandagi karta: ochilgan bo'lsa "Aylantir", bo'lmasa "yana N".
class SpinCard extends StatelessWidget {
  final VoidCallback onSpin;
  const SpinCard({super.key, required this.onSpin});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        final r = rewards;
        if (r.spinDoneToday) return const SizedBox.shrink();
        final ready = r.spinAvailable;
        final color = ready ? const Color(0xFFEC4899) : AppColors.muted(context);
        return GestureDetector(
          onTap: ready ? onSpin : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: ready ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: color.withValues(alpha: ready ? 0.6 : 0.25)),
            ),
            child: Row(
              children: [
                const Text('🎡', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ready ? 'Kunlik g\'ildirak tayyor!' : 'Kunlik g\'ildirak',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 14, color: color)),
                      Text(
                          ready
                              ? '100 tangagacha yutish mumkin — aylantiring'
                              : 'Yana ${r.spinRemaining} ta to\'g\'ri javob — ochiladi',
                          style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
                    ],
                  ),
                ),
                if (ready)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Text('Aylantir',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// G'ildirak — CustomPainter, 8 sektor; aylanib sektorda to'xtaydi.
class SpinWheelDialog extends StatefulWidget {
  const SpinWheelDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const SpinWheelDialog(),
      );

  @override
  State<SpinWheelDialog> createState() => _SpinWheelDialogState();
}

class _SpinWheelDialogState extends State<SpinWheelDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  int _target = -1;
  bool _spinning = false;
  bool _done = false;
  double _angle = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning || _done) return;
    final idx = rewards.spin();
    if (idx < 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _spinning = true;
      _target = idx;
    });
    final n = RewardEngine.spinSectors.length;
    final sector = 2 * pi / n;
    // Ko'rsatkich tepada (−π/2). Sektor markazi ko'rsatkichga kelsin.
    final finalAngle = -pi / 2 - (idx + 0.5) * sector;
    final turns = 6 * 2 * pi;
    final start = _angle;
    final end = finalAngle - turns - (start % (2 * pi));
    final anim = Tween<double>(begin: start, end: start + end).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeOutQuart));
    anim.addListener(() => setState(() => _angle = anim.value));
    await _c.forward(from: 0);
    final s = RewardEngine.spinSectors[idx];
    if (s.xp > 0) progress.addXp(s.xp);
    if (s.coins > 0) progress.addCoins(s.coins);
    if (s.freeze) progress.grantFreeze();
    if (mounted) {
      setState(() {
        _spinning = false;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectors = RewardEngine.spinSectors;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('KUNLIK G\'ILDIRAK',
                style: TextStyle(
                    color: Color(0xFFEC4899),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 13)),
            const SizedBox(height: 12),
            SizedBox(
              width: 260,
              height: 270,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 14,
                    child: Transform.rotate(
                      angle: _angle,
                      child: CustomPaint(
                        size: const Size(250, 250),
                        painter: _WheelPainter(sectors),
                      ),
                    ),
                  ),
                  // Ko'rsatkich
                  const Positioned(
                    top: 0,
                    child: Icon(Icons.arrow_drop_down_rounded,
                        size: 44, color: Color(0xFF1F2430)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_done && _target >= 0)
              Text('Yutuq: ${sectors[_target].label}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                onPressed: _done
                    ? () => Navigator.pop(context)
                    : (_spinning ? null : _spin),
                child: Text(_done ? 'Zo\'r!' : (_spinning ? 'Aylanyapti...' : 'AYLANTIR')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<SpinSector> sectors;
  _WheelPainter(this.sectors);

  static const _colors = [
    Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFFF59E0B),
    Color(0xFFEC4899), Color(0xFF06B6D4), Color(0xFFF97316), Color(0xFFDC2626),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final n = sectors.length;
    final sweep = 2 * pi / n;
    final p = Paint();
    for (var i = 0; i < n; i++) {
      p.color = _colors[i % _colors.length];
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * sweep, sweep, true, p);
      // Matn — sektor o'rtasida, radial.
      final a = (i + 0.5) * sweep;
      final tp = TextPainter(
        text: TextSpan(
          text: sectors[i].label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 0.7);
      canvas.save();
      canvas.translate(c.dx + cos(a) * r * 0.62, c.dy + sin(a) * r * 0.62);
      canvas.rotate(a);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    p
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(c, r - 1.5, p);
    p
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(c, 16, p);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => false;
}

// ═══════════════════ TANIShUV (onboarding) ═══════════════════

/// Birinchi ochilishda: tuxum "chiqadi", o'quvchi unga ISM qo'yadi.
/// O'zi nomlagan narsa — o'ziniki (IKEA effekti). Ism keyin hamma
/// gaplarda ishlatiladi.
class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key});

  static Future<void> showIfNeeded(BuildContext context) async {
    if (!rewards.loaded || rewards.onboarded) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OnboardingSheet(),
    );
  }

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true, count: 12);
  static const _suggest = ['Bilimjon', 'Zukko', 'Ozod', 'Nodir', 'Lola', 'Umid'];

  @override
  void dispose() {
    _ctrl.dispose();
    _c.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final n = _ctrl.text.trim();
    if (n.isEmpty) return;
    await rewards.setPetName(n);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) => Transform.rotate(
                  angle: (Curves.easeInOut.transform(_c.value) - 0.5) * 0.35,
                  child: child),
              child: const Text('🥚', style: TextStyle(fontSize: 84)),
            ),
            const SizedBox(height: 10),
            const Text('Sizga hamroh tuxum keldi!',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              'Siz o\'rgangan sari u o\'sadi: jo\'ja, boyqush, burgut... '
              'ajdargacha. Unga ism qo\'ying.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted(context), fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 14,
              onSubmitted: (_) => _done(),
              decoration: InputDecoration(
                hintText: 'Hamroh ismi',
                counterText: '',
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final n in _suggest)
                  ActionChip(
                    label: Text(n),
                    onPressed: () => setState(() => _ctrl.text = n),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                onPressed: _ctrl.text.trim().isEmpty ? null : _done,
                child: const Text('Boshlaymiz!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
