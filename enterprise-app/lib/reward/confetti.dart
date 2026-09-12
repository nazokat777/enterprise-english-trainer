import 'dart:math';

import 'package:flutter/material.dart';

/// Paketsiz konfetti — CustomPainter. `progress` 0..1.
class ConfettiPainter extends CustomPainter {
  final double progress;
  final List<ConfettiParticle> particles;
  ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final t = progress;
      final x = size.width * p.x0 + p.vx * t * size.width;
      final y = size.height * p.y0 + p.vy * t * size.height + 0.9 * t * t * size.height;
      if (y > size.height + 20) continue;
      final alpha = (1 - t).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + t * p.spin);
      if (p.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter old) => old.progress != progress;
}

class ConfettiParticle {
  final double x0, y0, vx, vy, rot, spin, size;
  final Color color;
  final bool circle;
  ConfettiParticle(this.x0, this.y0, this.vx, this.vy, this.rot, this.spin, this.size,
      this.color, this.circle);
}

List<ConfettiParticle> makeConfetti(Random rng, {int count = 120, Offset? origin}) {
  const colors = [
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
  ];
  return List.generate(count, (_) {
    final ang = rng.nextDouble() * pi * 2;
    final sp = 0.25 + rng.nextDouble() * 0.6;
    return ConfettiParticle(
      origin?.dx ?? 0.5,
      origin?.dy ?? 0.45,
      cos(ang) * sp,
      sin(ang) * sp - 0.55,
      rng.nextDouble() * pi,
      (rng.nextDouble() - 0.5) * 12,
      6 + rng.nextDouble() * 8,
      colors[rng.nextInt(colors.length)],
      rng.nextBool(),
    );
  });
}

/// Bir martalik konfetti portlashi (o'zini yig'ishtiradi).
class ConfettiBurst extends StatefulWidget {
  final Duration duration;
  final int count;
  final Offset origin;
  const ConfettiBurst({
    super.key,
    this.duration = const Duration(milliseconds: 1800),
    this.count = 120,
    this.origin = const Offset(0.5, 0.45),
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<ConfettiParticle> _p =
      makeConfetti(Random(), count: widget.count, origin: widget.origin);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: ConfettiPainter(progress: _c.value, particles: _p),
          size: Size.infinite,
        ),
      ),
    );
  }
}
