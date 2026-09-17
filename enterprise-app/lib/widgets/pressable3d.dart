import 'package:flutter/material.dart';
import '../theme.dart';

/// Neomorfik "3D" tugma (dizayn spec): tag ostida qattiq soya
/// (box-shadow 0 4px 0 0 #C9CDE3) — bosilganda 4px pastga tushadi va
/// soya yo'qoladi ("bosilgan" his).
class Pressable3D extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color color; // tugma yuzasi rangi
  final Color? shadowColor; // 3D soya rangi (null → neutralShadow)
  final EdgeInsets padding;
  final double radius;
  final bool enabled;

  const Pressable3D({
    super.key,
    required this.child,
    required this.onPressed,
    this.color = AppColors.actionBlue,
    this.shadowColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.radius = AppRadius.lg,
    this.enabled = true,
  });

  @override
  State<Pressable3D> createState() => _Pressable3DState();
}

class _Pressable3DState extends State<Pressable3D> {
  bool _down = false;
  bool _over = false;

  bool get _active => widget.enabled && widget.onPressed != null;

  void _hover(bool v) {
    if (!_active) return;
    setState(() => _over = v);
  }

  void _set(bool v) {
    if (!_active) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    // Soya rangi: berilmasa — tugma rangining to'qroq tusi (oq/yuza
    // tugmalar uchun neytral). Ustiga yumshoq "ambient" soya qo'shiladi.
    final isNeutral = widget.color.computeLuminance() > 0.7;
    final shadow = widget.shadowColor ??
        (isNeutral
            ? AppColors.neutralShadow
            : Color.lerp(widget.color, Colors.black, 0.28)!);
    const depth = 4.0;

    return Opacity(
      opacity: _active ? 1 : 0.5,
      child: MouseRegion(
        cursor: _active ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => _hover(true),
        onExit: (_) => _hover(false),
        child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: _active ? widget.onPressed : null,
        // Bosilganda butun tugma pastga siljiydi (soya "yeb qo'yiladi").
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _down ? depth : (_over ? -1 : 0), 0),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: _down
                ? []
                : [
                    BoxShadow(
                      color: shadow,
                      offset: const Offset(0, depth),
                      blurRadius: 0,
                    ),
                    if (!isNeutral)
                      BoxShadow(
                        color: widget.color.withValues(alpha: _over ? 0.45 : 0.28),
                        offset: const Offset(0, 10),
                        blurRadius: 22,
                        spreadRadius: -6,
                      ),
                  ],
          ),
          padding: widget.padding,
          child: Center(widthFactor: 1, child: widget.child),
        ),
      ),
      ),
    );
  }
}
