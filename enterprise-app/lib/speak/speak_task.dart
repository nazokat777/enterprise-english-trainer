import 'dart:async';

import 'package:flutter/material.dart';

import '../drill/drill_item.dart';
import '../services/speech.dart';
import '../services/tts.dart';
import '../theme.dart';
import 'speak_match.dart';

/// TALAFFUZ savoli — so'z ko'rsatiladi, o'quvchi mikrofonni bosib
/// aytadi, brauzer nutq tanish tekshiradi. Bo'lmasa "Namuna" (ovoz)
/// va "O'tkazib yuborish" bor: mikrofon yo'qligi jazolanmaydi.
class SpeakTask extends StatefulWidget {
  final DrillQuestion q;
  final bool locked;
  final ValueChanged<bool> onDone;
  final VoidCallback onSkip;

  const SpeakTask({
    super.key,
    required this.q,
    required this.locked,
    required this.onDone,
    required this.onSkip,
  });

  @override
  State<SpeakTask> createState() => _SpeakTaskState();
}

class _SpeakTaskState extends State<SpeakTask>
    with SingleTickerProviderStateMixin {
  final _speech = Speech();
  StreamSubscription<String>? _sub;
  Timer? _timeout;
  bool _listening = false;
  String _heard = '';
  int _tries = 0;
  bool? _ok;
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _timeout?.cancel();
    _sub?.cancel();
    _speech.stop();
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.locked || _ok != null) return;
    if (_listening) {
      _stop();
      return;
    }
    setState(() {
      _listening = true;
      _heard = '';
    });
    _sub?.cancel();
    _sub = _speech.start().listen(_onHeard, onError: (_) => _stop(),
        onDone: () {
      if (mounted && _listening) setState(() => _listening = false);
    });
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 7), _stop);
  }

  void _stop() {
    _timeout?.cancel();
    _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  void _onHeard(String t) {
    _timeout?.cancel();
    final ok = speechMatches(t, widget.q.answer);
    if (!mounted) return;
    setState(() {
      _heard = t;
      _listening = false;
      _tries += 1;
      if (ok) _ok = true;
    });
    _speech.stop();
    if (ok) widget.onDone(true);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final muted = AppColors.muted(context);
    final accent = _listening ? AppColors.danger : AppColors.brandPurple;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ovoz chiqarib ayting',
              style: TextStyle(
                  fontSize: 13, color: muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border(context)),
              boxShadow: AppShadow.card(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.prompt,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800)),
                      if (q.promptUz.isNotEmpty)
                        Text(q.promptUz,
                            style: TextStyle(fontSize: 14, color: muted)),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Namuna',
                  onPressed: () =>
                      Tts.instance.speak(q.speak, id: q.itemId),
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ],
            ),
          ),
          const Spacer(),
          Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Container(
                padding:
                    EdgeInsets.all(_listening ? 10 + 8 * _pulse.value : 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.15),
                ),
                child: child,
              ),
              child: GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _ok == true
                        ? AppColors.successGradient
                        : _listening
                            ? const LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFF97316)])
                            : AppColors.brandGradient,
                    boxShadow: AppShadow.glow(accent),
                  ),
                  child: Icon(
                    _ok == true
                        ? Icons.check_rounded
                        : _listening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _ok == true
                  ? 'Zo\'r talaffuz!'
                  : _listening
                      ? 'Eshityapman...'
                      : _heard.isEmpty
                          ? 'Mikrofonni bosing va ayting'
                          : 'Eshitildi: "$_heard" - yana urinib ko\'ring',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ok == true
                      ? AppColors.success
                      : _heard.isEmpty || _listening
                          ? muted
                          : AppColors.danger),
            ),
          ),
          const SizedBox(height: 8),
          if (_ok == null)
            Center(
              child: TextButton.icon(
                onPressed: widget.locked ? null : widget.onSkip,
                icon: const Icon(Icons.skip_next_rounded, size: 18),
                label: Text(_tries >= 2
                    ? 'O\'tkazib yuborish'
                    : 'Mikrofon yo\'q - o\'tkazish'),
              ),
            ),
        ],
      ),
    );
  }
}
