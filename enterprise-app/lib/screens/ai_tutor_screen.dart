import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/ai_tutor_service.dart';
import '../services/speech.dart';
import '../services/tts.dart';
import '../services/tutor_prefs.dart';
import '../theme.dart';
import '../widgets/pressable3d.dart';

/// 👨‍🏫 MR. VAYSAQI — AI o'qituvchi bilan inglizcha suhbat.
///
/// Nima uchun kerak: kitob mashqlari "tanish va yodlash"; tirik
/// suhbat esa o'rganilgan so'zni ISHLATISh — bu xotira uchun eng
/// kuchli bosqich (production + immediate feedback). Xato jazolanmaydi:
/// suhbat davom etadi, tuzatish xabar ostida yumshoq chiqadi.
class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final List<ChatMessage> _msgs = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  String? _error;

  /// Zaxira provayder ishlaganda bildirish ("Gemini limiti — Groq javob berdi").
  String? _info;

  /// Ovoz: brauzer nutq tanish (web). Erkin rejimda javobdan keyin
  /// o'zi qayta tinglaydi; "bosib turing"da tugma bosilganda.
  final Speech _speech = Speech();
  bool _listening = false;
  StreamSubscription<String>? _speechSub;

  String get _histKey => 'tutor_history::${progress.currentLevel}';

  @override
  void initState() {
    super.initState();
    tutorPrefs.load();
    _load();
  }

  @override
  void dispose() {
    _speechSub?.cancel();
    _speech.stop();
    _input.dispose();
    _scroll.dispose();
    Tts.instance.stop();
    super.dispose();
  }

  void _listen() {
    if (!Speech.supported || _busy) return;
    Tts.instance.stop();
    final free = tutorPrefs.voiceMode == 'free';
    _speechSub?.cancel();
    setState(() => _listening = true);
    _speechSub = _speech
        .start(continuous: free, lang: 'en-US')
        .listen((text) {
      if (!mounted) return;
      if (free) _speech.stop();
      setState(() => _listening = false);
      _send(text);
    }, onError: (_) {
      if (mounted) setState(() => _listening = false);
    }, onDone: () {
      if (mounted) setState(() => _listening = false);
    });
  }

  void _stopListening() {
    _speechSub?.cancel();
    _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_histKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (json.decode(raw) as List)
          .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      setState(() => _msgs.addAll(list));
      _jump();
    } catch (_) {}
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    final keep = _msgs.length > 40 ? _msgs.sublist(_msgs.length - 40) : _msgs;
    await p.setString(_histKey, json.encode(keep.map((m) => m.toJson()).toList()));
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    if (AiTutorService.rankedAttempts(progress.aiKeys).isEmpty) return;
    _input.clear();
    final now = DateTime.now().millisecondsSinceEpoch;
    final userMsg = ChatMessage(fromUser: true, text: text, timeMs: now);
    setState(() {
      _error = null;
      _busy = true;
      _msgs.add(userMsg);
    });
    _jump();
    try {
      final words = mastery.learnedWords(limit: 25).map((e) => e.$2).toList();
      final (reply, via) = await AiTutorService.sendWithFallback(
        keys: progress.aiKeys,
        preferred: progress.aiProvider,
        strictness: tutorPrefs.strictness,
        openMode: tutorPrefs.openMode,
        noteLang: tutorPrefs.noteLang,
        level: progress.currentLevel,
        history: _msgs.sublist(0, _msgs.length - 1),
        userText: text,
        words: words,
      );
      if (!mounted) return;
      setState(() {
        // Tanlangan provayderning birinchi modeli emas — qaysi model
        // javob berganini bildirib qo'yamiz (limit tugagan bo'lishi mumkin).
        final ranked = AiTutorService.rankedAttempts(progress.aiKeys);
        final primary =
            ranked.isEmpty ? '' : AiTutorService.attemptLabel(ranked.first);
        _info = via == primary
            ? null
            : 'Javob berdi: $via (eng zo\'r model limiti tugagan bo\'lishi mumkin)';
        // Tuzatish foydalanuvchi xabari ostida ko'rinadi.
        _msgs[_msgs.length - 1] = userMsg.withFeedback(reply);
        _msgs.add(ChatMessage(
            fromUser: false,
            text: reply.reply,
            timeMs: DateTime.now().millisecondsSinceEpoch));
        _busy = false;
      });
      // Har inglizcha gap = harakat: XP va kombo (xato bo'lsa ham —
      // gapirishga urinish o'zi mukofot).
      final bonus = rewards.onAnswer(true, baseXp: 3);
      await progress.addXp(3 + bonus);
      await _save();
      _jump();
      await Tts.instance.speak(reply.reply, id: 'tutor');
      // Erkin suhbat: javob o'qilgach yana tinglaydi — qo'l tegmasdan.
      if (mounted &&
          tutorPrefs.voice &&
          tutorPrefs.voiceMode == 'free' &&
          Speech.supported) {
        _listen();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is TutorException ? e.message : 'Ulanib bo\'lmadi: $e';
      });
    }
  }

  Future<void> _clear() async {
    setState(() => _msgs.clear());
    final p = await SharedPreferences.getInstance();
    await p.remove(_histKey);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        if (AiTutorService.rankedAttempts(progress.aiKeys).isEmpty) {
          return const _NoKey();
        }
        return Column(
          children: [
            _Header(onClear: _msgs.isEmpty ? null : _clear),
            Expanded(
              child: _msgs.isEmpty
                  ? _Starters(onPick: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _msgs.length + (_busy ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _msgs.length) return const _Typing();
                        return _Bubble(msg: _msgs[i]);
                      },
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ),
            if (_info != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(_info!,
                    style: TextStyle(
                        color: AppColors.muted(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ),
            _InputBar(
              controller: _input,
              busy: _busy,
              onSend: () => _send(),
              mic: tutorPrefs.voice && Speech.supported,
              listening: _listening,
              pushToTalk: tutorPrefs.voiceMode != 'free',
              onMicStart: _listen,
              onMicStop: _stopListening,
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback? onClear;
  const _Header({this.onClear});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
        child: Row(
          children: [
            const _Avatar(size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mr. Vaysaqi', style: AppTheme.heading(context)),
                  Text('Ingliz tili o\'qituvchisi · inglizcha yozing, xatoni yumshoq to\'g\'irlaydi',
                      maxLines: 2,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.muted(context))),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Suhbatni tozalash',
                onPressed: onClear,
                icon: const Icon(Icons.delete_sweep_rounded),
              ),
          ],
        ),
      );
}

class _Avatar extends StatelessWidget {
  final double size;
  const _Avatar({this.size = 36});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.brandPurple, AppColors.actionBlue]),
          shape: BoxShape.circle,
        ),
        child: Center(
            child: Text('👨‍🏫', style: TextStyle(fontSize: size * 0.55))),
      );
}

/// Boshlang'ich mavzular — "nima yozsam ekan" to'sig'ini olib tashlaydi.
class _Starters extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _Starters({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final words = mastery.learnedWords(limit: 3).map((e) => e.$2).toList();
    final starters = <String>[
      'Hello! My name is ... and I am from Uzbekistan.',
      'Can we talk about my family?',
      'What is your favourite food?',
      'Let\'s talk about my day.',
      if (words.isNotEmpty) 'Can you ask me questions with the words: ${words.join(', ')}?',
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(child: _Avatar(size: 72)),
        const SizedBox(height: 12),
        const Center(
          child: Text('Hello! I am Mr. Vaysaqi. 👋',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Inglizcha yozing — oddiy gap ham bo\'ladi. Xato bo\'lsa, '
            'xabaringiz ostida to\'g\'ri variant va izoh chiqadi. Har xabar +3 XP.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, height: 1.45, color: AppColors.muted(context)),
          ),
        ),
        const SizedBox(height: 20),
        Text('Boshlash uchun bosing:',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.muted(context))),
        const SizedBox(height: 8),
        for (final s in starters)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => onPick(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                          size: 18, color: AppColors.brandPurple),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final me = msg.fromUser;
    final bg = me
        ? AppColors.brandPurple
        : Theme.of(context).colorScheme.surface;
    final fg = me ? Colors.white : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            me ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                me ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!me) ...[
                const _Avatar(size: 28),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(me ? 16 : 4),
                      bottomRight: Radius.circular(me ? 4 : 16),
                    ),
                  ),
                  child: Text(msg.text,
                      style: TextStyle(
                          fontSize: 15, height: 1.4, color: fg,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              if (!me) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Eshitish',
                  onPressed: () => Tts.instance.speak(msg.text, id: 'tutor'),
                  icon: const Icon(Icons.volume_up_rounded,
                      size: 20, color: AppColors.actionBlue),
                ),
              ],
            ],
          ),
          // TUZATISh — foydalanuvchi xabari ostida, yumshoq.
          if (me && msg.correction.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.coin.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.coin.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('✏️', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(msg.correction,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  if (msg.noteUz.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(msg.noteUz,
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppColors.muted(context))),
                  ],
                ],
              ),
            )
          else if (me && msg.praise)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('👏 Zo\'r!',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success)),
            ),
        ],
      ),
    );
  }
}

/// "yozmoqda..." nuqtalari.
class _Typing extends StatefulWidget {
  const _Typing();
  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(count: 60);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const _Avatar(size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _a,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brandPurple.withValues(
                            alpha: 0.3 +
                                0.7 *
                                    (((_a.value * 3 - i) % 3).abs() < 1
                                        ? 1 - ((_a.value * 3 - i) % 3).abs()
                                        : 0)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  /// Mikrofon: [pushToTalk] — bosib turib gapirish; aks holda bosish
  /// tinglashni boshlaydi/to'xtatadi (erkin rejim).
  final bool mic;
  final bool listening;
  final bool pushToTalk;
  final VoidCallback? onMicStart;
  final VoidCallback? onMicStop;

  const _InputBar({
    required this.controller,
    required this.busy,
    required this.onSend,
    this.mic = false,
    this.listening = false,
    this.pushToTalk = true,
    this.onMicStart,
    this.onMicStop,
  });

  Widget _micButton() {
    final color = listening ? AppColors.danger : AppColors.homework;
    final btn = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: listening ? 54 : 46,
      height: listening ? 54 : 46,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: listening
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 4)]
            : null,
      ),
      child: Icon(listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
          color: Colors.white),
    );
    if (pushToTalk) {
      return GestureDetector(
        onTapDown: busy ? null : (_) => onMicStart?.call(),
        onTapUp: (_) => onMicStop?.call(),
        onTapCancel: onMicStop,
        onLongPressStart: busy ? null : (_) => onMicStart?.call(),
        onLongPressEnd: (_) => onMicStop?.call(),
        child: Tooltip(message: 'Bosib turib gapiring', child: btn),
      );
    }
    return GestureDetector(
      onTap: busy ? null : (listening ? onMicStop : onMicStart),
      child: Tooltip(
          message: listening ? 'Tinglashni to\'xtatish' : 'Gapirish', child: btn),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              if (mic) ...[
                _micButton(),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !busy,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Write in English...',
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: busy ? null : onSend,
                style: IconButton.styleFrom(
                    backgroundColor: AppColors.brandPurple),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      );
}

/// API kaliti yo'q — shu yerda kiritiladi (Sozlamalarga yugurmasdan).
class _NoKey extends StatefulWidget {
  const _NoKey();
  @override
  State<_NoKey> createState() => _NoKeyState();
}

class _NoKeyState extends State<_NoKey> {
  final _c = TextEditingController();
  bool _hide = true;
  String get _prov => progress.aiProvider;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: _Avatar(size: 72)),
          const SizedBox(height: 12),
          Text('Mr. Vaysaqi',
              textAlign: TextAlign.center, style: AppTheme.heading(context)),
          const SizedBox(height: 6),
          Text(
            'AI o\'qituvchi bilan inglizcha suhbat: siz yozasiz, u javob '
            'beradi, xatoni yumshoq to\'g\'irlaydi va o\'zbekcha izohlaydi.\n\n'
            'Ishlashi uchun AI provayderi va uning API kaliti kerak. Gemini va '
            'Groq bepul kalit beradi. Kalit faqat shu qurilmada saqlanadi.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13.5, height: 1.5, color: AppColors.muted(context)),
          ),
          const SizedBox(height: 18),
          ProviderPicker(
            value: _prov,
            onChanged: (p) async {
              await progress.setAiProvider(p);
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Kalit: ${AiTutorService.providers[_prov]!.$2}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _c,
            obscureText: _hide,
            decoration: InputDecoration(
              labelText: 'API kaliti',
              hintText: AiTutorService.providers[_prov]!.$3,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hide = !_hide),
                icon: Icon(_hide
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Pressable3D(
            color: AppColors.brandPurple,
            onPressed: () => progress.setAiKey(_prov, _c.text),
            child: const Center(
              child: Text('Saqlash va boshlash',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          ),
        ],
      );
}

/// Provayder tanlash (Claude / Gemini / Groq) — segment tugmalar.
class ProviderPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const ProviderPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final e in AiTutorService.providers.entries)
          ChoiceChip(
            label: Text(e.value.$1),
            selected: value == e.key,
            onSelected: (_) => onChanged(e.key),
            selectedColor: AppColors.brandPurple.withValues(alpha: 0.18),
            labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: value == e.key ? AppColors.brandPurple : null),
          ),
      ],
    );
  }
}
