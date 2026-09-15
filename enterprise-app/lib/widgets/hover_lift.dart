import 'package:flutter/material.dart';

import '../theme.dart';

/// HOVER + BOSISh mikro-harakati: sichqoncha ustiga kelganda karta
/// biroz ko'tariladi (scale 1.015, soya kuchayadi), bosilganda
/// kichrayadi (0.98). 160 ms — ko'z ilg'aydi, lekin kutdirmaydi.
///
/// Nevrobiologiya: interfeys "javob berganda" (feedback) boshqaruv hissi
/// (sense of agency) paydo bo'ladi — bu ilovada qolishning bir sababi.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double hoverScale;
  final double pressScale;
  final bool enabled;
  const HoverLift({
    super.key,
    required this.child,
    this.hoverScale = 1.015,
    this.pressScale = 0.98,
    this.enabled = true,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final scale = _down ? widget.pressScale : (_hover ? widget.hoverScale : 1.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: _hover && !_down
                  ? [
                      BoxShadow(
                        color: AppColors.brandPurple.withValues(alpha: 0.14),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// YUZA KARTASI — dizayn tizimining asosiy konteyneri: yuza rangi,
/// nozik chegara, yumshoq soya, katta radius.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.lg,
    this.color,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface(context)) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: gradient == null
            ? Border.all(color: AppColors.border(context))
            : null,
        boxShadow: AppShadow.card(context),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return onTap == null ? box : HoverLift(child: box);
  }
}

/// Gradientli matn (sarlavhalar uchun "wow" urg'u).
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final TextAlign? textAlign;
  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient = AppColors.brandGradient,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => gradient.createShader(r),
        child: Text(text,
            textAlign: textAlign,
            style: (style ?? const TextStyle()).copyWith(color: Colors.white)),
      );
}

/// Gradientli belgi doirasi (ikonka uchun).
class GradientBadge extends StatelessWidget {
  final Widget child;
  final double size;
  final Gradient gradient;
  const GradientBadge({
    super.key,
    required this.child,
    this.size = 44,
    this.gradient = AppColors.brandGradient,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: AppShadow.glow(gradient.colors.first, alpha: 0.3),
        ),
        child: Center(child: child),
      );
}
