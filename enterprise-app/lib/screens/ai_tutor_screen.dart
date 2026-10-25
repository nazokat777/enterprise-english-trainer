import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../levels.dart';
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
    _silence?.cancel();
    _speechSub?.cancel();
    _speech.stop();
    _input.dispose();
    _scroll.dispose();
    Tts.instance.stop();
    super.dispose();
  }

  Timer? _silence;
  final StringBuffer _said = StringBuffer();

  /// Erkin rejimda gap bir necha bo'lak bo'lib keladi (har pauzada
  /// brauzer yakuniy natija beradi). Ilgari birinchi bo'lakdayoq
  /// tinglash to'xtardi va gapning qolgani eshitilmasdi. Endi bo'laklar
  /// yig'iladi, ~2 soniya jimlikdan keyin bir butun yuboriladi.
  void _listen() {
    if (!Speech.supported || _busy) return;
    Tts.instance.stop();
    final free = tutorPrefs.voiceMode == 'free';
    _speechSub?.cancel();
    _silence?.cancel();
    _said.clear();
    setState(() => _listening = true);

    void flush() {
      _silence?.cancel();
      final text = _said.toString().trim();
      _said.clear();
      _speech.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      if (text.isNotEmpty) _send(text);
    }

    _speechSub = _speech
        .start(continuous: free, lang: 'en-US')
        .listen((text) {
      if (!mounted) return;
      if (!free) {
        setState(() => _listening = false);
        _send(text);
        return;
      }
      if (_said.isNotEmpty) _said.write(' ');
      _said.write(text);
      _silence?.cancel();
      _silence = Timer(const Duration(milliseconds: 2000), flush);
    }, onError: (_) {
      if (free && _said.isNotEmpty) {
        flush();
      } else if (mounted) {
        setState(() => _listening = false);
      }
    }, onDone: () {
      if (free && _said.isNotEmpty) {
        flush();
      } else if (mounted) {
        setState(() => _listening = false);
      }
    });
  }

  void _stopListening() {
    _silence?.cancel();
    final rest = _said.toString().trim();
    _said.clear();
    _speechSub?.cancel();
    _speech.stop();
    if (mounted) setState(() => _listening = false);
    // Tugmani bosib to'xtatsa - shu paytgacha aytilgani yuboriladi.
    if (rest.isNotEmpty && mounted) _send(rest);
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
            : 'Bu javobni zaxira AI berdi (asosiy AI ning bepul limiti '
                'vaqtincha tugagan bo\'lishi mumkin). Suhbat odatdagidek '
                'davom etadi. (texnik: $via)';
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
        _error = e is TutorException
            ? e.message
            : 'AI xizmatiga ulanib bo\'lmadi. Internetni tekshirib, xabarni '
                'qayta yuboring. (texnik: ${AiTutorService.scrub(e)})';
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _Avatar(size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mr. Vaysaqi', style: AppTheme.heading(context)),
                      // Daraja kitob bilan birga: "Beginner" yolg'iz
                      // tushunarsiz.
                      Text(
                          'AI o\'qituvchi · Daraja: '
                          '${levelLabel(progress.currentLevel)} · '
                          '${levelBookTitle(progress.currentLevel).split(' - ').first}',
                          maxLines: 2,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.muted(context))),
                    ],
                  ),
                ),
                if (onClear != null)
                  Tooltip(
                    message: 'Suhbatni o\'chirish (yozishmalar tarixi o\'chadi)',
                    child: TextButton.icon(
                      onPressed: onClear,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                      label: const Text('Tozalash'),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(
                  'Shu darajaga mos oddiy inglizcha gapiradi, xatoingizni '
                  'to\'g\'irlaydi.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.muted(context))),
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
    // (inglizcha gap, o'zbekcha ma'nosi) - boshlovchi gapni tushunib bossin.
    final starters = <(String, String)>[
      (
        'Hello! I am a student from Uzbekistan.',
        'Salom! Men O\'zbekistonlik talabaman.'
      ),
      ('Can we talk about my family?', 'Oilam haqida gaplashamizmi?'),
      ('What is your favourite food?', 'Sevimli taomingiz nima?'),
      ('Let\'s talk about my day.', 'Kunim haqida gaplashaylik.'),
      if (words.isNotEmpty)
        (
          'Can you ask me questions with the words: ${words.join(', ')}?',
          'O\'rgangan so\'zlarim bilan menga savol bering.'
        ),
    ];
    final muted = AppColors.muted(context);
    final small = TextStyle(fontSize: 13, height: 1.45, color: muted);
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
            'Salom! Men Mr. Vaysaqi - AI (sun\'iy intellekt) o\'qituvchiman.',
            textAlign: TextAlign.center,
            style: small,
          ),
        ),
        const SizedBox(height: 12),
        // Nima qilish kerak - qisqa, 3 qator.
        Text(
          'Pastdagi katakka inglizcha gap yozing va yuborish tugmasini '
          'bosing (mikrofon tugmasi bo\'lsa, gapirib ham bo\'ladi).',
          textAlign: TextAlign.center,
          style: small,
        ),
        const SizedBox(height: 4),
        Text(
          'Xatoingiz bo\'lsa, xabaringiz ostida to\'g\'ri variant va '
          'o\'zbekcha izoh chiqadi.',
          textAlign: TextAlign.center,
          style: small,
        ),
        const SizedBox(height: 4),
        Text(
          'Har xabar uchun +3 ball. Mr. Vaysaqi javobini ovoz chiqarib ham '
          'o\'qiydi.',
          textAlign: TextAlign.center,
          style: small,
        ),
        const SizedBox(height: 20),
        Text('Nima yozishni bilmasangiz, birini bosing (u darhol yuboriladi):',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: muted)),
        const SizedBox(height: 8),
        for (final s in starters)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => onPick(s.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                          size: 18, color: AppColors.brandPurple),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.$1,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(s.$2,
                                style: TextStyle(fontSize: 12, color: muted)),
                          ],
                        ),
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
                  tooltip: 'Javobni eshitish (ovoz chiqarib o\'qiydi)',
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
                  // Bu AI ning yangi javobi emas - SIZNING gapingizning
                  // to'g'ri varianti ekani yorliq bilan aytiladi.
                  Row(
                    children: [
                      const Text('✏️', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text('To\'g\'ri variant:',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.muted(context))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(msg.correction,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800)),
                  if (msg.noteUz.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Izoh: ${msg.noteUz}',
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
              child: Text('👏 Zo\'r! Xatosiz yozdingiz',
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
          Flexible(
            child: Container(
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
                    const SizedBox(width: 8),
                    // Nuqtalar nima ekani yozib qo'yiladi.
                    Flexible(
                      child: Text('Mr. Vaysaqi yozmoqda...',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted(context))),
                    ),
                  ],
                ),
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

  /// Mikrofon holati - tooltip telefonda ko'rinmaydi, shuning uchun
  /// nima qilish kerakligi doim matn bilan yozib turiladi.
  String? get _status {
    if (!mic) return null;
    if (listening) return 'Eshityapman... inglizcha gapiring';
    return pushToTalk
        ? 'Gapirish uchun mikrofonni bosib turing'
        : 'Gapirish uchun mikrofonni bosing; javobdan keyin u o\'zi yonadi';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: listening
                            ? AppColors.danger
                            : AppColors.muted(context))),
              ),
            Row(
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
                      hintText: 'Inglizcha yozing... (Write in English)',
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
                  tooltip: 'Yuborish',
                  onPressed: busy ? null : onSend,
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.brandPurple),
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

  /// 2-qadam uchun: qaysi hisob bilan kiriladi.
  String get _signIn => switch (_prov) {
        'gemini' => 'Google hisobingiz (Gmail) bilan kiring.',
        'groq' => 'Ro\'yxatdan o\'ting yoki kiring (Google bilan ham bo\'ladi).',
        _ => 'Ro\'yxatdan o\'ting. Bu xizmat pullik: hisobga pul qo\'yish kerak.',
      };

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(context);
    final info = AiTutorService.providers[_prov]!;
    final name = AiTutorService.providerShort[_prov] ?? _prov;
    final empty = _c.text.trim().isEmpty;
    // Kalit odatda shu belgilar bilan boshlanadi ("AIza...", "gsk_...").
    final prefix = info.$3.replaceAll('...', '');
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Center(child: _Avatar(size: 72)),
        const SizedBox(height: 12),
        Text('Mr. Vaysaqi',
            textAlign: TextAlign.center, style: AppTheme.heading(context)),
        const SizedBox(height: 6),
        Text(
          'Mr. Vaysaqi - AI (sun\'iy intellekt) o\'qituvchi. Siz inglizcha '
          'yozasiz yoki gapirasiz, u javob beradi, xatoingizni to\'g\'irlaydi '
          'va o\'zbekcha tushuntiradi.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.5, color: muted),
        ),
        const SizedBox(height: 16),
        Text('Ishlashi uchun bepul \'AI kaliti\' kerak',
            textAlign: TextAlign.center,
            style: AppTheme.heading(context).copyWith(fontSize: 17)),
        const SizedBox(height: 4),
        Text(
          'AI kaliti - AI xizmatidan olinadigan uzun maxfiy kod (parol '
          'kabi). Uni olish bepul, taxminan 2 daqiqa oladi.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.45, color: muted),
        ),
        const SizedBox(height: 16),
        _Step(
          n: 1,
          title: 'AI xizmatini tanlang (boshlovchiga Gemini yetarli)',
          child: ProviderPicker(
            value: _prov,
            onChanged: (p) async {
              await progress.setAiProvider(p);
              if (mounted) setState(() {});
            },
          ),
        ),
        _Step(
          n: 2,
          title: 'Brauzerda quyidagi saytni oching. $_signIn',
          child: KeySiteLink(domain: info.$2),
        ),
        _Step(
          n: 3,
          title: '\'Create API key\' (kalit yaratish) tugmasini bosing va '
              'chiqqan kodni nusxalang (Copy).',
        ),
        _Step(
          n: 4,
          title: 'Kodni pastdagi katakka qo\'ying va \'Saqlash va boshlash\' '
              'ni bosing.',
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _c,
          obscureText: _hide,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Kodni shu yerga qo\'ying',
            hintText: info.$3,
            helperText: 'Bu - AI kaliti. $name kaliti \'$prefix\' bilan '
                'boshlanadi.',
            helperMaxLines: 2,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
            suffixIcon: IconButton(
              tooltip: _hide ? 'Kodni ko\'rsatish' : 'Kodni yashirish',
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
        const SizedBox(height: 6),
        Text(
          empty
              ? 'Avval kodni katakka qo\'ying.'
              : 'Tugmani bosing - suhbat darhol ochiladi.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: empty ? muted : AppColors.success),
        ),
        const SizedBox(height: 14),
        Text(
          'Kalitni hech kimga bermang. U faqat shu qurilmada saqlanadi. '
          'Yozganlaringiz tanlangan AI xizmatiga ($name) yuboriladi.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.4, color: muted),
        ),
      ],
    );
  }
}

/// Raqamlangan qadam: "1" doira + matn (+ ixtiyoriy tugma/tanlov).
class _Step extends StatelessWidget {
  final int n;
  final String title;
  final Widget? child;
  const _Step({required this.n, required this.title, this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: AppColors.brandPurple, shape: BoxShape.circle),
              child: Text('$n',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (child != null) ...[
                    const SizedBox(height: 8),
                    child!,
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

/// AI kaliti olinadigan sayt: bosilsa yangi oynada ochiladi; ochilmasa
/// manzil nusxalanadi (yalang domen "matn" bo'lib qolmasin).
class KeySiteLink extends StatelessWidget {
  final String domain;
  const KeySiteLink({super.key, required this.domain});

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse('https://$domain'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (opened) return;
    try {
      await Clipboard.setData(ClipboardData(text: domain));
    } catch (_) {}
    messenger?.showSnackBar(SnackBar(
        content: Text('Sayt ochilmadi. Manzil nusxalandi: $domain. '
            'Uni brauzer manzil qatoriga qo\'ying.')));
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _open(context),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(domain),
        ),
      );
}

/// Provayder tanlash (Gemini / Groq / Claude) — segment tugmalar.
///
/// [caption] berilsa, chiplar tepasida qisqa savol/izoh chiqadi.
class ProviderPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? caption;
  const ProviderPicker(
      {super.key, required this.value, required this.onChanged, this.caption});

  @override
  Widget build(BuildContext context) {
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
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
    if (caption == null) return chips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption!,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.muted(context))),
        const SizedBox(height: 8),
        chips,
      ],
    );
  }
}
