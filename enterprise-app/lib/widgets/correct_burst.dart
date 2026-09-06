import 'package:flutter/material.dart';
import '../theme.dart';

/// To'g'ri javobda pastdan katta yashil "To'g'ri" chiqadi (dizayn spec).
/// Overlay orqali ko'rsatiladi va o'zini avtomatik olib tashlaydi.
///
/// Belgi MATN emas, IKONKA. Ilgari matnda "✓" (U+2713) turardi, lekin
/// sarlavha shrifti Geist da bu belgi YO'Q — shrift tarmoqdan yuklanib
/// bo'lgach belgi o'rniga bo'sh quti chiqardi.
void showCorrectBurst(BuildContext context, {String text = "To'g'ri"}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Burst(text: text, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Burst extends StatefulWidget {
  final String text;
  final VoidCallback onDone;
  const _Burst({required this.text, required this.onDone});

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 950))
        ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // MUHIM: Positioned Overlay'ning BEVOSITA bolasi bo'lishi shart.
    // Uni IgnorePointer/AnimatedBuilder ichiga solib qo'yilsa,
    // "Incorrect use of ParentDataWidget" xatosi chiqadi.
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).size.height * 0.32,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // 0→0.25 kirish (pastdan, elastik), 0.75→1 chiqish (yuqoriga, fade).
            final enter =
                Curves.easeOutBack.transform((t / 0.25).clamp(0.0, 1.0));
            final exit = t > 0.75 ? (t - 0.75) / 0.25 : 0.0;
            final opacity = (1 - exit).clamp(0.0, 1.0);
            final dy = (1 - enter) * 60 - exit * 40;
            final scale = 0.7 + 0.3 * enter;
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.text,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_rounded,
                              color: Colors.white, size: 26),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
