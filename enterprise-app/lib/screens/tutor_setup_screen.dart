import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/ai_tutor_service.dart';
import '../services/speech.dart';
import '../services/tutor_prefs.dart';
import 'ai_tutor_screen.dart';

/// MR. VAYSAQI — SOZLASh EKRANI.
///
/// "O'qituvchingiz qanchalik qattiqqo'l bo'lsin?" — slayder bilan yuz
/// jonli o'zgaradi (qosh, og'iz, fon rangi). Tanlov o'quvchiniki:
/// jahldor ustoz kimnidir uyg'otadi, do'stona ustoz kimnidir
/// tinchlantiradi. Ovoz rejimi, 18+ ochiq rejim, izoh tili shu yerda.
class TutorSetupScreen extends StatefulWidget {
  const TutorSetupScreen({super.key});

  @override
  State<TutorSetupScreen> createState() => _TutorSetupScreenState();
}

class _TutorSetupScreenState extends State<TutorSetupScreen> {
  @override
  void initState() {
    super.initState();
    tutorPrefs.load();
  }

  /// Fon rangi: 0 qizil (jahl) ... 3 yashil (do'st).
  static Color bgFor(double t) {
    const stops = [
      Color(0xFFFF6B5A), // jahldor
      Color(0xFFF59E0B), // qattiq
      Color(0xFF3B82F6), // muloyim
      Color(0xFF22C55E), // do'stona
    ];
    final x = (t.clamp(0, 3)).toDouble();
    final i = x.floor().clamp(0, 2);
    return Color.lerp(stops[i], stops[i + 1], x - i)!;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tutorPrefs, progress]),
      builder: (context, _) {
        final p = tutorPrefs;
        final bg = bgFor(p.strictness.toDouble());
        final hasKey = progress.activeAiKey.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          color: bg,
          // Slider/Switch Material ota kerak — ekran qayerda ochilishidan
          // qat'i nazar o'zi bilan olib yuradi.
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  Row(
                    children: [
                      _Pill(
                        onTap: () => Navigator.maybePop(context),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Orqaga',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (p.openMode)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: _Pill(
                            child: Text(
                              '18+',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      _LangToggle(value: p.noteLang, onChanged: p.setNoteLang),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'O\'qituvchingiz qanchalik\nqattiqqo\'l bo\'lsin?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TutorFace(
                      mood: p.strictness.toDouble(),
                      size: min(300, MediaQuery.of(context).size.width - 80),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StrictSlider(
                    value: p.strictness,
                    onChanged: p.setStrictness,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    p.strictDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _VoiceModeSwitch(
                    value: p.voiceMode,
                    onChanged: p.setVoiceMode,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    !Speech.supported
                        ? 'Bu brauzerda mikrofon orqali nutq tanish yo\'q — yozib suhbatlashasiz (Chrome/Edge/Safari da ovoz ishlaydi).'
                        : p.voiceMode == 'free'
                        ? 'U doimo tinglab turadi.'
                        : 'Mikrofon tugmasini bosib turib gapiring.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: _Pill(
                      onTap: () => p.setOpenMode(!p.openMode),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '18+ Ochiq rejim',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: p.openMode,
                            onChanged: p.setOpenMode,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF7F1D1D),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (p.openMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Qo\'pol hazil va so\'kinishga ruxsat. Haqorat, kamsitish yo\'q.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  _StartButton(
                    color: bg,
                    label: hasKey
                        ? 'Gaplashishni boshlash'
                        : 'API kalitini kiritish',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: Text(
                              'Mr. Vaysaqi · ${p.strictLabel}${p.openMode ? ' · 18+' : ''}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          body: const AiTutorScreen(),
                        ),
                      ),
                    ),
                  ),
                  if (!hasKey)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Provayder: ${AiTutorService.providers[progress.aiProvider]!.$1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// JONLI YUZ — qosh burchagi, og'iz shakli va ko'z qorachig'i kayfiyatga
/// qarab. 0 = g'azab (qoshlar ichkariga qiya, og'iz ochiq baqirayapti),
/// 3 = quvonch (qoshlar ko'tarilgan, keng tabassum).
class TutorFace extends StatefulWidget {
  final double mood; // 0..3
  final double size;
  const TutorFace({super.key, required this.mood, this.size = 280});

  @override
  State<TutorFace> createState() => _TutorFaceState();
}

class _TutorFaceState extends State<TutorFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(count: 400);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.mood),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, m, _) => AnimatedBuilder(
        animation: _blink,
        builder: (context, _) {
          // Ko'z pirpirashi: siklning oxirgi 6 % ida.
          final t = _blink.value;
          final blink = t > 0.94
              ? (1 - ((t - 0.94) / 0.06 - 0.5).abs() * 2)
              : 0.0;
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _FacePainter(mood: m, blink: blink.clamp(0, 1)),
          );
        },
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  final double mood; // 0..3
  final double blink; // 0..1
  _FacePainter({required this.mood, required this.blink});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final k = (mood / 3).clamp(0.0, 1.0); // 0 g'azab .. 1 quvonch
    final ink = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.fill;
    final white = Paint()..color = Colors.white;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // Ko'zlar
    final eyeR = w * 0.085;
    final ly = h * 0.36, lx = w * 0.36, rx = w * 0.64;
    for (final cx in [lx, rx]) {
      canvas.drawCircle(Offset(cx, ly + 6), eyeR, shadow);
      // Pirpirash: ko'z balandligi kamayadi.
      final eh = eyeR * (1 - 0.9 * blink);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, ly),
          width: eyeR * 2,
          height: eh * 2,
        ),
        white,
      );
      if (blink < 0.7) {
        // Qorachiq: g'azabda kichik va yuqoriga, quvonchda kattaroq.
        final pr = eyeR * (0.28 + 0.12 * k);
        final py = ly - eyeR * 0.15 * (1 - k);
        canvas.drawCircle(Offset(cx + eyeR * 0.15, py), pr, ink);
        canvas.drawCircle(
          Offset(cx + eyeR * 0.15 - pr * 0.35, py - pr * 0.35),
          pr * 0.3,
          white,
        );
      }
    }

    // Qoshlar: g'azabda ichkariga qiya (V), quvonchda yuqoriga ko'tarilgan yoy.
    final brow = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final tilt = (1 - k) * 0.55 - k * 0.15; // radian
    final lift = h * (0.14 + 0.06 * k);
    for (final (cx, dir) in [(lx, 1.0), (rx, -1.0)]) {
      final len = w * 0.16;
      final cy = ly - lift;
      // Ichki uch (burun tomoni) g'azabda PAST, quvonchda biroz yuqori —
      // ikki qosh oynadagidek simmetrik.
      final a = tilt * dir;
      final p1 = Offset(cx - cos(a) * len, cy - sin(a) * len);
      final p2 = Offset(cx + cos(a) * len, cy + sin(a) * len);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(cx, cy - h * 0.03 * k, p2.dx, p2.dy);
      canvas.drawPath(path, brow);
    }

    // Og'iz
    final my = h * 0.66;
    final mw = w * (0.22 + 0.12 * k);
    final mouth = Path();
    if (k < 0.5) {
      // G'azab: keng ochiq, pastga egilgan "baqiriq" og'iz.
      final open = h * (0.16 - 0.1 * k);
      mouth.moveTo(w / 2 - mw, my - open * 0.35);
      mouth.quadraticBezierTo(
        w / 2,
        my - open * 0.9,
        w / 2 + mw,
        my - open * 0.35,
      );
      mouth.quadraticBezierTo(
        w / 2,
        my + open * 1.1,
        w / 2 - mw,
        my - open * 0.35,
      );
      mouth.close();
      canvas.drawPath(mouth, ink);
      // Tishlar va til
      final teeth = Path()
        ..moveTo(w / 2 - mw * 0.75, my - open * 0.4)
        ..quadraticBezierTo(
          w / 2,
          my - open * 0.75,
          w / 2 + mw * 0.75,
          my - open * 0.4,
        )
        ..lineTo(w / 2 + mw * 0.75, my - open * 0.2)
        ..quadraticBezierTo(
          w / 2,
          my - open * 0.05,
          w / 2 - mw * 0.75,
          my - open * 0.2,
        )
        ..close();
      canvas.drawPath(teeth, white);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, my + open * 0.45),
          width: mw * 0.7,
          height: open * 0.5,
        ),
        Paint()..color = const Color(0xFFE8788B),
      );
    } else {
      // Tabassum: kengayadigan yoy; do'stona holatda ochiq kulgu.
      final s = (k - 0.5) * 2; // 0..1
      final depth = h * (0.05 + 0.13 * s);
      mouth.moveTo(w / 2 - mw, my - depth * 0.2);
      mouth.quadraticBezierTo(
        w / 2,
        my + depth * 1.6,
        w / 2 + mw,
        my - depth * 0.2,
      );
      if (s > 0.35) {
        mouth.quadraticBezierTo(
          w / 2,
          my + depth * 0.1,
          w / 2 - mw,
          my - depth * 0.2,
        );
        mouth.close();
        canvas.drawPath(mouth, ink);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w / 2, my + depth * 0.95),
            width: mw * 0.8,
            height: depth * 0.6,
          ),
          Paint()..color = const Color(0xFFE8788B),
        );
      } else {
        canvas.drawPath(
          mouth,
          Paint()
            ..color = const Color(0xFF111111)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.045
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.mood != mood || old.blink != blink;
}

class _StrictSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _StrictSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              TutorPrefs.strictLabels.first.toUpperCase(),
              style: _cap(Colors.white.withValues(alpha: 0.75)),
            ),
            Text(
              TutorPrefs.strictLabels[value].toUpperCase(),
              style: _cap(Colors.white, size: 15),
            ),
            Text(
              TutorPrefs.strictLabels.last.toUpperCase(),
              style: _cap(Colors.white.withValues(alpha: 0.75)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.45),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.2),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
            activeTickMarkColor: Colors.white70,
            inactiveTickMarkColor: Colors.white70,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            trackHeight: 6,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 3,
            divisions: 3,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }

  static TextStyle _cap(Color c, {double size = 12}) => TextStyle(
    color: c,
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.6,
  );
}

class _VoiceModeSwitch extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _VoiceModeSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String id, IconData icon, String label) {
      final sel = value == id;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: sel ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: sel ? const Color(0xFF7F1D1D) : Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: sel ? const Color(0xFF111111) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          seg('free', Icons.mic_rounded, 'Erkin suhbat'),
          seg('push', Icons.back_hand_rounded, 'Bosib turing'),
        ],
      ),
    );
  }
}

class _LangToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _LangToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String id, String flag, String label) {
      final sel = value == id;
      return GestureDetector(
        onTap: () => onChanged(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$flag $label',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: sel ? const Color(0xFF111111) : Colors.white,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('uz', '🇺🇿', 'UZ'), seg('en', '🇺🇸', 'EN')],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Pill({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.22),
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: child,
      ),
    ),
  );
}

class _StartButton extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _StartButton({
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: Colors.black38,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
          child: Text(
            label,
            style: TextStyle(
              color: Color.lerp(color, Colors.black, 0.35),
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ),
      ),
    ),
  );
}
