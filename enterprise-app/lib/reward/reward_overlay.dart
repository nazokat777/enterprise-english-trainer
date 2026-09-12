import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'confetti.dart';
import 'reward_engine.dart';
import 'sfx.dart';

/// Global mukofot qatlami — Navigator USTIDA turadi (MaterialApp.builder).
///
/// Kichik effektlar (uchuvchi XP, kombo meteri, vignette) parallel;
/// katta hodisalar (daraja, sandiq, yutuq) NAVBAT bilan, bittadan.
class RewardOverlay extends StatefulWidget {
  final Widget child;
  const RewardOverlay({super.key, required this.child});

  @override
  State<RewardOverlay> createState() => _RewardOverlayState();
}

class _RewardOverlayState extends State<RewardOverlay>
    with TickerProviderStateMixin {
  StreamSubscription<RewardEvent>? _sub;
  final List<Widget> _floaters = [];
  final List<RewardEvent> _queue = [];
  RewardEvent? _modal;
  Widget? _banner;
  Timer? _bannerTimer;
  int _floaterId = 0;
  final _rng = Random();

  // Kombo meteri
  late final AnimationController _comboPop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _vignette =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed && rewards.combo >= 10) {
          _vignette.forward(from: 0);
        }
      });
  late final AnimationController _wrongFlash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void initState() {
    super.initState();
    _sub = rewards.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _bannerTimer?.cancel();
    _comboPop.dispose();
    _shake.dispose();
    _vignette.dispose();
    _wrongFlash.dispose();
    super.dispose();
  }

  void _onEvent(RewardEvent e) {
    if (!mounted) return;
    final sfx = Sfx.instance;
    switch (e.kind) {
      case RewardKind.xp:
        if (e.crit) {
          sfx.crit();
          _shake.forward(from: 0);
        } else {
          sfx.correct(rewards.combo);
        }
        _float(e.crit ? '+${e.amount} KRIT!' : '+${e.amount} ⚡', crit: e.crit);
        _comboPop.forward(from: 0);
        if (rewards.combo >= 10 && !_vignette.isAnimating) {
          _vignette.forward(from: 0);
        }
        setState(() {});
      case RewardKind.wrong:
        sfx.wrong();
        _wrongFlash.forward(from: 0);
        setState(() {});
      case RewardKind.nearMiss:
        sfx.tick();
        _float('Deyarli! 1 harf farq', color: const Color(0xFFF97316), big: true);
      case RewardKind.speed:
        _float('TEZ! +${e.amount} ⚡', color: const Color(0xFF06B6D4));
      case RewardKind.comeback:
        _float('QAYTISh! +${e.amount} ⚡', color: AppColors.brandPurple, big: true);
      case RewardKind.gem:
        sfx.coin();
        progress.addCoins(e.amount);
        _float('+${e.amount} 🪙', color: AppColors.coin);
      case RewardKind.comboTick:
        break;
      case RewardKind.combo:
        sfx.combo();
        _shake.forward(from: 0);
        _float(
          '${e.level} KOMBO  +${e.amount} ⚡',
          color: _heatColor(rewards.comboHeat),
          big: true,
        );
        if (e.level >= 10) _burst(count: 60);
      case RewardKind.record:
        _showBanner(_RecordBanner(text: 'Yangi rekord: ${e.amount} kombo!'));
      case RewardKind.dailyGoal:
        sfx.quest();
        progress.addCoins(e.amount);
        _burst(count: 140);
        _showBanner(_GoalBanner(coins: e.amount));
      case RewardKind.chest:
      case RewardKind.levelUp:
      case RewardKind.achievement:
      case RewardKind.league:
        _queue.add(e);
        _pump();
      case RewardKind.quest:
        sfx.quest();
        progress.addCoins(e.quest!.coins);
        progress.addXp(e.quest!.xp);
        _showBanner(_QuestBanner(quest: e.quest!));
    }
  }

  void _pump() {
    if (_modal != null || _queue.isEmpty) return;
    final e = _queue.removeAt(0);
    switch (e.kind) {
      case RewardKind.levelUp:
        Sfx.instance.levelUp();
      case RewardKind.chest:
        Sfx.instance.chest();
      case RewardKind.achievement:
        Sfx.instance.achievement();
      case RewardKind.league:
        Sfx.instance.levelUp();
      default:
        break;
    }
    setState(() => _modal = e);
  }

  void _closeModal() {
    setState(() => _modal = null);
    // Ketma-ket modal orasida nafas.
    Future.delayed(const Duration(milliseconds: 250), _pump);
  }

  void _float(
    String text, {
    bool crit = false,
    Color? color,
    bool big = false,
  }) {
    final id = _floaterId++;
    final dx = (_rng.nextDouble() - 0.5) * 120;
    final dy = (_rng.nextDouble() - 0.5) * 60;
    late Widget w;
    w = _Floater(
      key: ValueKey(id),
      text: text,
      dx: dx,
      dy: dy,
      crit: crit,
      big: big,
      color: color ?? (crit ? AppColors.coin : AppColors.success),
      onDone: () {
        if (mounted) setState(() => _floaters.remove(w));
      },
    );
    setState(() => _floaters.add(w));
  }

  void _burst({int count = 120}) {
    final id = _floaterId++;
    late Widget w;
    w = _TimedRemove(
      key: ValueKey('b$id'),
      duration: const Duration(milliseconds: 1900),
      onDone: () {
        if (mounted) setState(() => _floaters.remove(w));
      },
      child: ConfettiBurst(count: count),
    );
    setState(() => _floaters.add(w));
  }

  void _showBanner(Widget b) {
    _bannerTimer?.cancel();
    setState(() => _banner = b);
    _bannerTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  static Color _heatColor(double h) {
    if (h < 0.25) return AppColors.actionBlue;
    if (h < 0.5) return AppColors.coin;
    if (h < 0.85) return const Color(0xFFF97316);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          // Xato: qisqa qizil chaqnash (chetlarda).
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _wrongFlash,
              builder: (_, _) {
                final v = sin(_wrongFlash.value * pi);
                if (v <= 0) return const SizedBox.shrink();
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.1,
                      colors: [
                        Colors.transparent,
                        AppColors.danger.withValues(alpha: 0.28 * v),
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          // Kombo 10+: ekran cheti "yonadi".
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _vignette,
              builder: (_, _) {
                if (rewards.combo < 10) return const SizedBox.shrink();
                final v = sin(_vignette.value * pi);
                final c = _heatColor(rewards.comboHeat);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.05,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        c.withValues(alpha: 0.10 + 0.22 * v),
                      ],
                      stops: const [0, 0.6, 1],
                    ),
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          ..._floaters,
          // Kombo meteri (tepada o'rtada).
          Positioned(
            top: MediaQuery.paddingOf(context).top + 6,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Material(
                type: MaterialType.transparency,
                child: Center(
                  child: _ComboMeter(pop: _comboPop, shake: _shake),
                ),
              ),
            ),
          ),
          if (_banner != null)
            Positioned(
              // Pastda — o'yin maydonini (so'z, variantlar) to'smasin.
              bottom: MediaQuery.paddingOf(context).bottom + 84,
              left: 0,
              right: 0,
              child: Center(
                child: _SlideIn(
                  key: ValueKey(_banner.hashCode),
                  child: GestureDetector(
                    onTap: () => setState(() => _banner = null),
                    child: _banner!,
                  ),
                ),
              ),
            ),
          if (_modal != null) _buildModal(_modal!),
        ],
      ),
    );
  }

  Widget _buildModal(RewardEvent e) {
    return switch (e.kind) {
      RewardKind.levelUp => _LevelUpModal(
        key: ValueKey('lvl${e.level}'),
        level: e.level,
        title: e.text,
        onClose: _closeModal,
      ),
      RewardKind.chest => _ChestModal(
        key: ValueKey('chest${e.hashCode}'),
        big: e.big,
        onClose: _closeModal,
      ),
      RewardKind.league => _LeagueModal(
          key: ValueKey('lg${e.level}'),
          index: e.level,
          name: e.text,
          onClose: _closeModal),
      RewardKind.achievement => _AchievementModal(
        key: ValueKey('ach${e.achievement!.id}'),
        a: e.achievement!,
        onClose: _closeModal,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ═══════════════ Uchuvchi XP ═══════════════

class _Floater extends StatefulWidget {
  final String text;
  final double dx;
  final double dy;
  final bool crit;
  final bool big;
  final Color color;
  final VoidCallback onDone;
  const _Floater({
    super.key,
    required this.text,
    required this.dx,
    this.dy = 0,
    required this.crit,
    required this.big,
    required this.color,
    required this.onDone,
  });

  @override
  State<_Floater> createState() => _FloaterState();
}

class _FloaterState extends State<_Floater>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.big || widget.crit ? 1400 : 1000),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        final rise = Curves.easeOutCubic.transform(t) * 140;
        final scale = widget.crit || widget.big
            ? Curves.elasticOut.transform(min(1, t * 2.2)) *
                  (widget.crit ? 1.35 : 1.15)
            : 0.8 + 0.3 * Curves.easeOutBack.transform(min(1, t * 3));
        final alpha = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
        return Positioned(
          left: size.width / 2 - 120 + widget.dx,
          width: 240,
          top: size.height * 0.42 - rise + widget.dy,
          child: IgnorePointer(
            child: Opacity(
              opacity: alpha.clamp(0, 1),
              child: Transform.scale(
                scale: scale,
                child: Material(
                  type: MaterialType.transparency,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.crit ? 18 : 12,
                        vertical: widget.crit ? 8 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.55),
                            blurRadius: widget.crit ? 28 : 12,
                            spreadRadius: widget.crit ? 4 : 0,
                          ),
                        ],
                      ),
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: widget.crit ? 22 : (widget.big ? 17 : 15),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimedRemove extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final VoidCallback onDone;
  const _TimedRemove({
    super.key,
    required this.child,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_TimedRemove> createState() => _TimedRemoveState();
}

class _TimedRemoveState extends State<_TimedRemove> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer(widget.duration, widget.onDone);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(child: widget.child);
}

// ═══════════════ Kombo meteri ═══════════════

class _ComboMeter extends StatelessWidget {
  final AnimationController pop;
  final AnimationController shake;
  const _ComboMeter({required this.pop, required this.shake});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (_, _) {
        final c = rewards.combo;
        if (c < 2) return const SizedBox.shrink();
        final heat = rewards.comboHeat;
        final color = _RewardOverlayState._heatColor(heat);
        final flame = c >= 20
            ? '🌋'
            : (c >= 10 ? '🔥🔥' : (c >= 5 ? '🔥' : '🌟'));
        return AnimatedBuilder(
          animation: Listenable.merge([pop, shake]),
          builder: (_, _) {
            final s = 1 + 0.25 * sin(pop.value * pi) * (0.6 + heat);
            final sh = sin(shake.value * pi * 6) * (1 - shake.value) * 6;
            return Transform.translate(
              offset: Offset(sh, 0),
              child: Transform.scale(
                scale: s,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35 + 0.4 * heat),
                        blurRadius: 14 + 20 * heat,
                        spreadRadius: 1 + 3 * heat,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(flame, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        '$c',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'kombo',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════ Bannerlar ═══════════════

class _SlideIn extends StatefulWidget {
  final Widget child;
  const _SlideIn({super.key, required this.child});
  @override
  State<_SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<_SlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return AnimatedBuilder(
      animation: a,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 40 * (1 - a.value)),
        child: Opacity(opacity: _c.value.clamp(0, 1), child: child),
      ),
      child: widget.child,
    );
  }
}

class _QuestBanner extends StatelessWidget {
  final Quest quest;
  const _QuestBanner({required this.quest});
  @override
  Widget build(BuildContext context) {
    return _BannerCard(
      color: AppColors.brandPurple,
      leading: Text(quest.emoji, style: const TextStyle(fontSize: 22)),
      title: 'Topshiriq bajarildi!',
      subtitle: '${quest.titleUz}  ·  +${quest.coins} 🪙  +${quest.xp} ⚡',
    );
  }
}

class _GoalBanner extends StatelessWidget {
  final int coins;
  const _GoalBanner({required this.coins});
  @override
  Widget build(BuildContext context) {
    return _BannerCard(
      color: AppColors.success,
      leading: const Text('🎯', style: TextStyle(fontSize: 22)),
      title: 'Kunlik maqsad bajarildi!',
      subtitle: 'Streak saqlandi  ·  +$coins 🪙',
    );
  }
}

class _RecordBanner extends StatelessWidget {
  final String text;
  const _RecordBanner({required this.text});
  @override
  Widget build(BuildContext context) {
    return _BannerCard(
      color: const Color(0xFFF97316),
      leading: const Text('🏅', style: TextStyle(fontSize: 22)),
      title: text,
      subtitle: 'Shaxsiy rekordingiz yangilandi',
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Color color;
  final Widget leading;
  final String title;
  final String subtitle;
  const _BannerCard({
    required this.color,
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════ Modallar ═══════════════

class _ModalScrim extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _ModalScrim({required this.child, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.62),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Spring" bilan chiqadigan karta.
class _Pop extends StatefulWidget {
  final Widget child;
  const _Pop({required this.child});
  @override
  State<_Pop> createState() => _PopState();
}

class _PopState extends State<_Pop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
      child: widget.child,
    );
  }
}

class _LevelUpModal extends StatefulWidget {
  final int level;
  final String title;
  final VoidCallback onClose;
  const _LevelUpModal({
    super.key,
    required this.level,
    required this.title,
    required this.onClose,
  });
  @override
  State<_LevelUpModal> createState() => _LevelUpModalState();
}

class _LevelUpModalState extends State<_LevelUpModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _ModalScrim(
          child: _Pop(
            child: Container(
              width: 320,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPurple.withValues(alpha: 0.6),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'DARAJA OShDI!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _glow,
                    builder: (_, child) => Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.coin.withValues(
                              alpha: 0.5 + 0.4 * _glow.value,
                            ),
                            blurRadius: 30 + 20 * _glow.value,
                            spreadRadius: 2 + 6 * _glow.value,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.level}',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brandPurple,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Yangi unvon ochildi',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.brandPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: widget.onClose,
                      child: const Text('Davom etamiz!'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: ConfettiBurst(count: 160)),
      ],
    );
  }
}

class _ChestModal extends StatefulWidget {
  final bool big;
  final VoidCallback onClose;
  const _ChestModal({super.key, required this.big, required this.onClose});
  @override
  State<_ChestModal> createState() => _ChestModalState();
}

class _ChestModalState extends State<_ChestModal>
    with SingleTickerProviderStateMixin {
  ChestReward? _reward;
  bool _opening = false;
  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening || _reward != null) return;
    setState(() => _opening = true);
    Sfx.instance.tick();
    // Kutish = kutilish (anticipation) — dofamin aynan shu yerda.
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    final r = rewards.openChest();
    if (r.xp > 0) progress.addXp(r.xp);
    if (r.coins > 0) progress.addCoins(r.coins);
    if (r.freeze) progress.grantFreeze();
    Sfx.instance.coin();
    setState(() => _reward = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _reward;
    return Stack(
      children: [
        _ModalScrim(
          child: _Pop(
            child: Container(
              width: 320,
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.big ? 'KATTA SANDIQ!' : 'SIRLI SANDIQ',
                    style: TextStyle(
                      color: AppColors.muted(context),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _open,
                    child: AnimatedBuilder(
                      animation: _wobble,
                      builder: (_, child) {
                        final t = _wobble.value;
                        final rot = r == null && !_opening
                            ? sin(t * pi * 2) * 0.08
                            : (_opening && r == null
                                  ? sin(t * pi * 12) * 0.12
                                  : 0.0);
                        return Transform.rotate(angle: rot, child: child);
                      },
                      child: AnimatedScale(
                        scale: r == null ? 1 : 1.15,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.elasticOut,
                        child: Text(
                          r == null ? (widget.big ? '🎁' : '📦') : '🎉',
                          style: const TextStyle(fontSize: 92),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (r == null) ...[
                    Text(
                      _opening
                          ? 'Ochilmoqda...'
                          : 'Ochish uchun sandiqni bosing',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.big
                          ? 'Bugungi uchala topshiriq bajarildi!'
                          : 'Ketma-ket to\'g\'ri javoblar uchun',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted(context),
                        fontSize: 13,
                      ),
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        if (r.coins > 0)
                          _RewardChip('+${r.coins} 🪙', AppColors.coin),
                        if (r.xp > 0)
                          _RewardChip('+${r.xp} ⚡', AppColors.actionBlue),
                        if (r.freeze)
                          _RewardChip(
                            '🧊 Streak muzlatgich',
                            const Color(0xFF06B6D4),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: widget.onClose,
                        child: const Text('Zo\'r!'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (r != null) const Positioned.fill(child: ConfettiBurst(count: 90)),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String text;
  final Color color;
  const _RewardChip(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return _Pop(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _AchievementModal extends StatelessWidget {
  final Achievement a;
  final VoidCallback onClose;
  const _AchievementModal({super.key, required this.a, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _ModalScrim(
          onTap: onClose,
          child: _Pop(
            child: Container(
              width: 320,
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.coin, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.coin.withValues(alpha: 0.45),
                    blurRadius: 36,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'YUTUQ OChILDI',
                    style: TextStyle(
                      color: AppColors.coin,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.coin.withValues(alpha: 0.6),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        a.emoji,
                        style: const TextStyle(fontSize: 54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    a.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted(context)),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coin,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: onClose,
                      child: const Text('Olindi!'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: ConfettiBurst(count: 80)),
      ],
    );
  }
}

class _LeagueModal extends StatelessWidget {
  final int index;
  final String name;
  final VoidCallback onClose;
  const _LeagueModal(
      {super.key, required this.index, required this.name, required this.onClose});

  static const _colors = [
    Color(0xFFB45309), Color(0xFF9CA3AF), Color(0xFFF59E0B), Color(0xFF2563EB),
    Color(0xFFDC2626), Color(0xFF16A34A), Color(0xFF7C3AED), Color(0xFFE5E7EB),
    Color(0xFF111827), Color(0xFF06B6D4),
  ];
  static const _icons = ['🥉', '🥈', '🥇', '💙', '❤️‍🔥', '💚', '💜', '🤍', '🖤', '💎'];

  @override
  Widget build(BuildContext context) {
    final c = _colors[index.clamp(0, _colors.length - 1)];
    return Stack(
      children: [
        _ModalScrim(
          child: _Pop(
            child: Container(
              width: 320,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c, c.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 4),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("LIGA KO'TARILDI!",
                      style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          fontSize: 13)),
                  const SizedBox(height: 12),
                  Text(_icons[index.clamp(0, _icons.length - 1)],
                      style: const TextStyle(fontSize: 76)),
                  const SizedBox(height: 10),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 30)),
                  const SizedBox(height: 4),
                  Text('${index + 1} / ${RewardEngine.leagues.length} liga',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: c == const Color(0xFFE5E7EB) ? Colors.black : c,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      onPressed: onClose,
                      child: const Text('Oldinga!'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: ConfettiBurst(count: 160)),
      ],
    );
  }
}
