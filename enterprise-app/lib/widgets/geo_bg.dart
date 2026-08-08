import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Subtil geometrik naqsh (uchburchak / doira / X) — past opacity,
/// fon ustiga qo'yiladi. Rejimga moslashadi (light/dark).
class GeoBackground extends StatelessWidget {
  final Widget child;
  const GeoBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GeoPainter(isLight: isLight),
          ),
        ),
        child,
      ],
    );
  }
}

class _GeoPainter extends CustomPainter {
  final bool isLight;
  _GeoPainter({required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    // Deterministik "tasodifiy" joylashuv (seed qat'iy — qayta chizishda barqaror).
    final rnd = Random(7);
    final base = isLight ? AppColors.brandPurple : AppColors.darkHeading;
    final paint = Paint()
      ..color = base.withValues(alpha: isLight ? 0.05 : 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    const count = 26;
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 6 + rnd.nextDouble() * 16;
      switch (i % 3) {
        case 0: // doira
          canvas.drawCircle(Offset(x, y), r, paint);
          break;
        case 1: // uchburchak
          final p = Path()
            ..moveTo(x, y - r)
            ..lineTo(x - r, y + r)
            ..lineTo(x + r, y + r)
            ..close();
          canvas.drawPath(p, paint);
          break;
        case 2: // X
          canvas.drawLine(Offset(x - r, y - r), Offset(x + r, y + r), paint);
          canvas.drawLine(Offset(x + r, y - r), Offset(x - r, y + r), paint);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GeoPainter old) => old.isLight != isLight;
}
