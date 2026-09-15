import 'package:flutter/material.dart';

import '../theme.dart';

/// AURORA FON — yumshoq, xira rangli "bulutlar" (mesh gradient).
///
/// Nima uchun: tekis kulrang fon "ofis dasturi" hissini beradi; xira
/// brend gradientlari esa chuqurlik va zamonaviylik beradi (iOS/Arc
/// uslubi). Bulutlar STATIK — animatsiya testlarni osiltirmaydi va
/// batareyani yemaydi; harakat mikro-interaktsiyalarda.
class GeoBackground extends StatelessWidget {
  final Widget child;
  const GeoBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _AuroraPainter(isLight: isLight)),
          ),
        ),
        child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final bool isLight;
  _AuroraPainter({required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final a = isLight ? 0.22 : 0.16;
    void blob(Offset c, double r, Color color, double alpha) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          stops: const [0, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
    }

    blob(Offset(w * 0.12, h * 0.05), w * 0.45, AppColors.brandPurple, a);
    blob(Offset(w * 0.95, h * 0.15), w * 0.4, AppColors.brandCyan, a * 0.8);
    blob(Offset(w * 0.7, h * 0.95), w * 0.5, AppColors.brandIndigo, a * 0.7);
    blob(Offset(w * 0.05, h * 0.8), w * 0.35, AppColors.pink, a * 0.45);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.isLight != isLight;
}
