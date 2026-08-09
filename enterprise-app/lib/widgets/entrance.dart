import 'dart:async';

import 'package:flutter/material.dart';

/// Element ekranga chiqqanda silliq paydo bo'lish: shaffoflik 0→1 va
/// pastdan biroz yuqoriga siljish. [delay] bilan bir nechta elementni
/// ketma-ket (staggered) jonlantirish mumkin.
class EntranceFade extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const EntranceFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 460),
    this.offsetY = 18,
  });

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<double> _slide =
      Tween<double>(begin: widget.offsetY, end: 0)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  /// Kechikish taymeri — dispose'da bekor qilinadi, aks holda widget
  /// yo'q qilingandan keyin ham osilib qoladi.
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(offset: Offset(0, _slide.value), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Bosilganda yengil kichrayadigan «tactile» effekt.
/// Listener ishlatadi — ichki InkWell bosishini to'smaydi.
class PressableScale extends StatefulWidget {
  final Widget child;
  final double scale;
  const PressableScale({super.key, required this.child, this.scale = 0.97});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
