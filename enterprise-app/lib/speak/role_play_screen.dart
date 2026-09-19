import 'dart:async';

import 'package:flutter/material.dart';

import '../book_content.dart';
import '../main.dart';
import '../reward/confetti.dart';
import '../services/speech.dart';
import '../services/tts.dart';
import '../theme.dart';
import '../widgets/correct_burst.dart';
import '../widgets/pressable3d.dart';
import 'speak_match.dart';

/// Dialog satri: "Tony: Excuse me." -> speaker "Tony", text "Excuse me."
class DialogueLine {
  final String speaker;
  final String en;
  final String uz;
  const DialogueLine(this.speaker, this.en, this.uz);

  static final _re = RegExp(r'^([A-Z][\w .\-]{0,24}?):\s+(.+)$');

  static DialogueLine? parse(ExTask t) {
    final m = _re.firstMatch(t.en.trim());
    if (m == null) return null;
    var uz = t.uz.trim();
    final mu = RegExp(r'^[^:]{1,26}:\s+(.+)$').firstMatch(uz);
    if (mu != null) uz = mu.group(1)!;
    return DialogueLine(m.group(1)!.trim(), m.group(2)!.trim(), uz);
  }

  /// Mashq dialogmi: 2+ so'zlovchi, 3+ satr.
  static List<DialogueLine> of(BookExercise e) {
    final lines = e.tasks.map(parse).whereType<DialogueLine>().toList();
    final speakers = lines.map((l) => l.speaker).toSet();
    if (lines.length < 3 || speakers.length < 2 || speakers.length > 4) {
      return const [];
    }
    return lines;
  }
}

/// ROL O'YNASH — dialogda bitta rolni o'quvchi o'ynaydi: ilova boshqa
/// qahramon satrlarini o'qiydi (neural ovoz), o'quvchi o'z satrini
/// ovoz chiqarib aytadi, brauzer nutq tanish tekshiradi.
///
/// Xotira ilmi: gapni "o'qib tanish" passiv; ROLDA AYTISH - ishlab
/// chiqarish + kontekst + hissiyot (haqiqiy suhbat simulyatsiyasi).
/// "Matnni yashirish" rejimida faqat o'zbekcha ko'rinadi - inglizcha
/// gapni eslab aytish (to'liq recall).
class RolePlayScreen extends StatefulWidget {
  final BookExercise exercise;
  final String title;
  const RolePlayScreen({super.key, required this.exercise, required this.title});

  @override
  State<RolePlayScreen> createState() => _RolePlayScreenState();
}

class _RolePlayScreenState extends State<RolePlayScreen> {
  late final List<DialogueLine> _lines = DialogueLine.of(widget.exercise);
  late final List<String> _speakers =
      _lines.map((l) => l.speaker).toSet().toList();
  String? _role; // tanlangan rol
  bool _hideText = false;
  int _i = 0; // joriy satr
  bool _listening = false;
  String _heard = '';
  bool? _lineOk;
  int _said = 0; // o'quvchi to'g'ri aytgan satrlar
  int _mine = 0; // o'quvchi satrlari jami
  bool _done = false;
  final _speech = Speech();
  StreamSubscription<String>? _sub;
  Timer? _timer;

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _speech.stop();
    Tts.instance.stop();
    super.dispose();
  }

  void _start(String role) {
    setState(() {
      _role = role;
      _mine = _lines.where((l) => l.speaker == role).length;
      _i = 0;
    });
    _advance();
  }

  /// Ilova satrlarini o'qiydi, o'quvchi satrida to'xtaydi.
  Future<void> _advance() async {
    while (_i < _lines.length && _lines[_i].speaker != _role) {
      final l = _lines[_i];
      await _say(l.en, '${widget.exercise.ref}::$_i');
      if (!mounted) return;
      setState(() => _i++);
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (!mounted) return;
    if (_i >= _lines.length) {
      setState(() => _done = true);
      await progress.addXp(10);
      rewards.onExerciseDone(clean: _said == _mine);
      return;
    }
    setState(() {
      _heard = '';
      _lineOk = null;
    });
  }

  /// Aytib bo'lguncha kutadi (speakingId null bo'lguncha, ko'pi 12 s).
  Future<void> _say(String text, String id) async {
    final tts = Tts.instance;
    final c = Completer<void>();
    void onChange() {
      if (tts.speakingId.value == null && !c.isCompleted) c.complete();
    }

    tts.speakingId.addListener(onChange);
    unawaited(tts.speak(text, id: id));
    // speak() sinxron bo'lmagan - biroz kutib, keyin tugashini kuzatamiz.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (tts.speakingId.value == null && !c.isCompleted) c.complete();
    await c.future.timeout(const Duration(seconds: 12), onTimeout: () {});
    tts.speakingId.removeListener(onChange);
  }

  void _listen() {
    if (_listening || _lineOk == true) return;
    setState(() {
      _listening = true;
      _heard = '';
    });
    _sub?.cancel();
    _sub = _speech.start().listen(_onHeard, onError: (_) => _stopListen(),
        onDone: () {
      if (mounted && _listening) setState(() => _listening = false);
    });
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 10), _stopListen);
  }

  void _stopListen() {
    _timer?.cancel();
    _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _onHeard(String t) async {
    _timer?.cancel();
    _speech.stop();
    final ok = speechMatches(t, _lines[_i].en);
    if (!mounted) return;
    setState(() {
      _heard = t;
      _listening = false;
      _lineOk = ok ? true : null;
    });
    if (ok) {
      _said++;
      showCorrectBurst(context);
      final bonus = rewards.onAnswer(true, baseXp: 3);
      await progress.addXp(3 + bonus);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _i++);
      await _advance();
    }
  }

  Future<void> _skipLine() async {
    _stopListen();
    rewards.onAnswer(false);
    setState(() => _i++);
    await _advance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_role != null && !_done)
            IconButton(
              tooltip: _hideText ? 'Matnni ko\'rsatish' : 'Matnni yashirish',
              onPressed: () => setState(() => _hideText = !_hideText),
              icon: Icon(_hideText
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded),
            ),
        ],
      ),
      body: _role == null
          ? _pickRole(context)
          : _done
              ? _finished(context)
              : _play(context),
    );
  }

  // ───────────── Rol tanlash ─────────────
  Widget _pickRole(BuildContext context) {
    final muted = AppColors.muted(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Kim bo\'lib gapirasiz?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Ilova boshqa qahramonning gaplarini o\'qiydi, siz o\'z satrlaringizni '
          'ovoz chiqarib aytasiz. Mikrofon kerak.',
          style: TextStyle(fontSize: 13.5, color: muted),
        ),
        const SizedBox(height: 18),
        for (final s in _speakers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Pressable3D(
              color: AppColors.brandPurple,
              shadowColor: const Color(0xFF5B22B5),
              onPressed: () => _start(s),
              child: Center(
                child: Text(
                  '$s  ·  ${_lines.where((l) => l.speaker == s).length} satr',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text('Dialog:', style: TextStyle(fontSize: 12.5, color: muted)),
        const SizedBox(height: 6),
        for (final l in _lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${l.speaker}: ',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: l.en),
            ])),
          ),
      ],
    );
  }

  // ───────────── O'yin ─────────────
  Widget _play(BuildContext context) {
    final muted = AppColors.muted(context);
    final cur = _lines[_i];
    final mine = cur.speaker == _role;
    return Column(
      children: [
        LinearProgressIndicator(
          value: _i / _lines.length,
          minHeight: 6,
          backgroundColor: AppColors.brandPurple.withValues(alpha: 0.12),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            itemCount: _i + 1,
            itemBuilder: (context, k) {
              if (k >= _lines.length) return const SizedBox.shrink();
              final l = _lines[k];
              final isMe = l.speaker == _role;
              final current = k == _i;
              final hidden = current && isMe && _hideText;
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 10),
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe ? AppColors.brandGradient : null,
                    color: isMe ? null : AppColors.surface(context),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: isMe ? null : Border.all(color: AppColors.border(context)),
                    boxShadow: current
                        ? AppShadow.glow(
                            isMe ? AppColors.brandPurple : AppColors.brandCyan,
                            alpha: 0.35)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.speaker,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isMe ? Colors.white70 : muted)),
                      const SizedBox(height: 2),
                      Text(
                        hidden ? '· · ·' : l.en,
                        style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: isMe ? Colors.white : null),
                      ),
                      if (l.uz.isNotEmpty)
                        Text(l.uz,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: isMe ? Colors.white70 : muted)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Pastki panel: ilova gapiryapti / mikrofon.
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border(top: BorderSide(color: AppColors.border(context))),
          ),
          child: mine
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _listen,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _lineOk == true
                              ? AppColors.successGradient
                              : _listening
                                  ? const LinearGradient(colors: [
                                      Color(0xFFEF4444),
                                      Color(0xFFF97316)
                                    ])
                                  : AppColors.brandGradient,
                          boxShadow: AppShadow.glow(_listening
                              ? AppColors.danger
                              : AppColors.brandPurple),
                        ),
                        child: Icon(
                          _lineOk == true
                              ? Icons.check_rounded
                              : _listening
                                  ? Icons.graphic_eq_rounded
                                  : Icons.mic_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lineOk == true
                          ? 'Zo\'r!'
                          : _listening
                              ? 'Eshityapman...'
                              : _heard.isEmpty
                                  ? 'Sizning navbatingiz - mikrofonni bosib ayting'
                                  : 'Eshitildi: "$_heard" - yana urinib ko\'ring',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _lineOk == true
                              ? AppColors.success
                              : _heard.isEmpty || _listening
                                  ? muted
                                  : AppColors.danger),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => Tts.instance
                              .speak(cur.en, id: '${widget.exercise.ref}::$_i'),
                          icon: const Icon(Icons.volume_up_rounded, size: 18),
                          label: const Text('Namuna'),
                        ),
                        TextButton.icon(
                          onPressed: _skipLine,
                          icon: const Icon(Icons.skip_next_rounded, size: 18),
                          label: const Text('O\'tkazish'),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text('${cur.speaker} gapiryapti...',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: muted, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ───────────── Yakun ─────────────
  Widget _finished(BuildContext context) {
    final perfect = _said == _mine && _mine > 0;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: perfect ? AppColors.successGradient : AppColors.brandGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadow.glow(
                    perfect ? AppColors.success : AppColors.brandPurple),
              ),
              child: Column(
                children: [
                  Text(perfect ? '🎭' : '🎬', style: const TextStyle(fontSize: 52)),
                  const SizedBox(height: 8),
                  Text(perfect ? 'Ajoyib rol!' : 'Dialog tugadi',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('$_said / $_mine satr to\'g\'ri aytildi',
                      style: const TextStyle(color: Colors.white70, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Pressable3D(
              color: AppColors.brandPurple,
              shadowColor: const Color(0xFF5B22B5),
              onPressed: () {
                setState(() {
                  _done = false;
                  _said = 0;
                  _i = 0;
                });
                _advance();
              },
              child: const Center(
                child: Text('Yana bir bor',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
            Pressable3D(
              color: AppColors.success,
              shadowColor: const Color(0xFF0F7A37),
              onPressed: () => Navigator.pop(context),
              child: const Center(
                child: Text('Tayyor',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
        if (perfect) const IgnorePointer(child: ConfettiBurst(count: 100)),
      ],
    );
  }
}
