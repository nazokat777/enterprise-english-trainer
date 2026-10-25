import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../drill/drill_item.dart';
import '../drill/drill_screen.dart' show InstructionLine, instructionOf;
import '../main.dart';
import '../mastery.dart';
import '../reward/confetti.dart';
import '../reward/sfx.dart';
import '../theme.dart';
import '../widgets/pressable3d.dart';

/// ⚡ BLITZ — 60 soniya, iloji boricha ko'p so'z.
///
/// Nevrobiologiya: vaqt bosimi + tez qaror = "oqim" (flow) holati;
/// o'z rekordi bilan bellashish (self-competition) tashqi
/// liderjadvaldan xavfsizroq va kuchliroq motivator. Har javob
/// darhol keyingisiga o'tadi — dofamin sikli 1-2 soniya.
/// Pedagogika: tez eslab aytish (rapid retrieval) so'zni "avtomatik"
/// darajaga olib chiqadi — gapda o'ylamasdan ishlatish shu yerdan.
class BlitzScreen extends StatefulWidget {
  final List<DrillSource> sources;
  final String label;

  /// Rekord kaliti (unit yoki daraja bo'yicha alohida).
  final String recordKey;

  const BlitzScreen({
    super.key,
    required this.sources,
    required this.label,
    required this.recordKey,
  });

  static const int seconds = 60;

  /// Saqlangan rekord.
  static Future<int> bestOf(String key) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('blitz_best::$key') ?? 0;
  }

  @override
  State<BlitzScreen> createState() => _BlitzScreenState();
}

enum _Phase { ready, play, done }

class _BlitzScreenState extends State<BlitzScreen>
    with SingleTickerProviderStateMixin {
  final _rnd = Random();
  _Phase _phase = _Phase.ready;
  int _left = BlitzScreen.seconds;
  Timer? _timer;
  DrillQuestion? _q;
  String? _picked;
  int _score = 0;
  int _streak = 0;
  int _correct = 0;
  int _wrong = 0;
  int _best = 0;
  bool _newRecord = false;
  final List<DrillSource> _bag = [];

  late final AnimationController _pop;

  /// Ko'paytirgich: 5+ ketma-ket = x2, 10+ = x3.
  int get _mult => _streak >= 10 ? 3 : _streak >= 5 ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    BlitzScreen.bestOf(widget.recordKey).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pop.dispose();
    super.dispose();
  }

  void _start() {
    rewards.tick();
    setState(() {
      _phase = _Phase.play;
      _left = BlitzScreen.seconds;
      _score = _streak = _correct = _wrong = 0;
      _newRecord = false;
    });
    _next();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left -= 1);
      if (_left <= 0) _finish();
    });
  }

  /// Savollar xaltadan: hamma so'z bir marta chiqmaguncha takror yo'q.
  void _next() {
    if (_bag.isEmpty) {
      _bag.addAll(widget.sources);
      _bag.shuffle(_rnd);
    }
    DrillQuestion? q;
    for (var i = 0; i < 5 && q == null && _bag.isNotEmpty; i++) {
      final s = _bag.removeLast();
      final f = _rnd.nextBool() ? AskFormat.produce : AskFormat.choice;
      q = buildQuestion(s, f, widget.sources, _rnd) ??
          buildQuestion(s, AskFormat.choice, widget.sources, _rnd);
    }
    setState(() {
      _q = q;
      _picked = null;
    });
  }

  Future<void> _answer(String opt) async {
    final q = _q;
    if (q == null || _picked != null || _phase != _Phase.play) return;
    final ok = opt == q.answer;
    setState(() => _picked = opt);
    final src = widget.sources.firstWhere((e) => e.itemId == q.itemId,
        orElse: () => DrillSource(itemId: q.itemId, en: q.answer, uz: q.promptUz));
    unawaited(mastery.record(q.itemId, q.format,
        ok: ok, en: src.en, uz: src.uz));
    if (ok) {
      _streak += 1;
      _correct += 1;
      _score += _mult;
      Sfx.instance.correct(_streak);
      _pop.forward(from: 0);
      rewards.onAnswer(true, baseXp: 0);
    } else {
      _streak = 0;
      _wrong += 1;
      Sfx.instance.wrong();
      rewards.onAnswer(false, baseXp: 0);
    }
    await Future.delayed(Duration(milliseconds: ok ? 220 : 900));
    if (!mounted || _phase != _Phase.play) return;
    _next();
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final record = _score > _best;
    setState(() {
      _phase = _Phase.done;
      _newRecord = record;
      if (record) _best = _score;
    });
    if (record) {
      final p = await SharedPreferences.getInstance();
      await p.setInt('blitz_best::${widget.recordKey}', _score);
      Sfx.instance.levelUp();
    }
    // XP = ochko; rekord uchun +15.
    await progress.addXp(_score + (record ? 15 : 0));
    rewards.onExerciseDone(clean: _wrong == 0 && _correct > 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('⚡ Tezlik o\'yini · ${widget.label}',
            style: const TextStyle(fontSize: 16)),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.ready => _ready(context),
          _Phase.play => _play(context),
          _Phase.done => _done(context),
        },
      ),
    );
  }

  // Boshlash tugmasi ekran TAGIDA qotirilgan: qoidalar matni uzun bo'lib,
  // kichik telefonda tugma ekrandan tashqarida qolmasin.
  Widget _ready(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _readyBody(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 16),
            child: Pressable3D(
              color: AppColors.homework,
              onPressed: widget.sources.length < 4 ? null : _start,
              enabled: widget.sources.length >= 4,
              child: Center(
                child: Text(
                    widget.sources.length < 4
                        ? 'Kamida 4 ta so\'z kerak'
                        : 'BOShLASh',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1)),
              ),
            ),
          ),
        ],
      );

  Widget _readyBody(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
        children: [
          const SizedBox(height: 8),
          const Center(child: Text('⚡', style: TextStyle(fontSize: 64))),
          const SizedBox(height: 8),
          const Center(
            child: Text('60 soniya',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          // O'yin nima: vaqt tugamaguncha so'zning ma'nosini topish.
          const Text(
            "60 soniyada iloji boricha ko'p so'zning ma'nosini toping.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15.5, height: 1.4, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            "Har savolda bitta so'z beriladi - variantlardan to'g'risini "
            "bosing. Javob bergach, darhol keyingi so'z chiqadi.\n"
            "To'g'ri javob = 1 ball. Ketma-ket 5 ta to'g'ri bo'lsa, har "
            "javob 2 ball, 10 ta bo'lsa 3 ball. Xato qilsangiz, "
            "ketma-ket sanash qaytadan boshlanadi.\n"
            "Savollar ${widget.sources.length} ta so'zdan olinadi.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, height: 1.5, color: AppColors.muted(context)),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.coin.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                  _best > 0
                      ? '🏆 Eng yaxshi natijangiz: $_best ball'
                      : '🏆 Hali natija yo\'q',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).textTheme.bodyLarge?.color)),
            ),
          ),
        ],
      );

  Widget _play(BuildContext context) {
    final q = _q;
    final urgent = _left <= 10;
    final color = urgent ? AppColors.danger : AppColors.homework;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vaqt — oxirgi 10 soniyada qizil va urib turadi.
              // Expanded: tor ekran va katta shriftda yorliq o'raladi,
              // qator sig'maslikka uchramaydi.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedScale(
                      scale: urgent && _left.isOdd ? 1.15 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: Text('$_left',
                          style: TextStyle(
                              fontSize: 34,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: color,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                    ),
                    // Raqam nimani bildirishi.
                    Text('soniya qoldi',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ],
                ),
              ),
              if (_mult > 1)
                Tooltip(
                  message: "Ketma-ket to'g'ri javoblar uchun har javob "
                      '$_mult ball beradi',
                  child: Container(
                    margin: const EdgeInsets.only(right: 12, top: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      // Oq matn sariq fonda o'qilmasdi - to'q sariq.
                      color: AppColors.homework,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('x$_mult ball',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.35)
                        .chain(CurveTween(curve: Curves.easeOutBack))
                        .animate(ReverseAnimation(_pop)),
                    child: Text('$_score',
                        style: const TextStyle(
                            fontSize: 34,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: AppColors.success)),
                  ),
                  const Text('ball',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _left / BlitzScreen.seconds),
              duration: const Duration(milliseconds: 900),
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (q != null) ...[
          // Yo'nalish tasodifiy almashadi (inglizcha -> o'zbekcha yoki
          // aksincha) - shuning uchun HAR SAVOLDA aytiladi.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InstructionLine(instructionOf(q)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(q.prompt,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, height: 1.2)),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final o in q.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Opt(
                      text: o,
                      state: _picked == null
                          ? _OptState.idle
                          : o == q.answer
                              ? _OptState.right
                              : o == _picked
                                  ? _OptState.wrong
                                  : _OptState.dim,
                      onTap: () => _answer(o),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _done(BuildContext context) {
    final total = _correct + _wrong;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(28),
          children: [
            // NATIJA KARTASI — rekordda oltin gradient, aks holda olov.
            Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                gradient: _newRecord
                    ? AppColors.goldGradient
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF97316), Color(0xFFEA580C), Color(0xFFDB2777)]),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadow.glow(
                    _newRecord ? AppColors.coin : AppColors.homework, alpha: 0.45),
              ),
              child: Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) => Transform.scale(scale: v, child: child),
                    child: Text(_newRecord ? '🏆' : '⚡',
                        style: const TextStyle(fontSize: 60)),
                  ),
                  const SizedBox(height: 6),
                  Text(_newRecord ? 'YANGI REKORD!' : 'Vaqt tugadi',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: Colors.white)),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: _score),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, v, _) => Text('$v',
                        style: const TextStyle(
                            fontSize: 68,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                  Text('ball to\'pladingiz ($_correct ta to\'g\'ri javob)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.95))),
                  const SizedBox(height: 2),
                  Text(
                      '+${_score + (_newRecord ? 15 : 0)} ball hisobingizga '
                      "qo'shildi"
                      '${_newRecord ? " (shundan 15 ball - yangi rekord uchun)" : ""}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Stat(
                    label: "To'g'ri javob",
                    value: '$_correct',
                    color: AppColors.success),
                _Stat(label: 'Xato', value: '$_wrong', color: AppColors.danger),
                _Stat(
                    label: 'Aniqlik',
                    value: total == 0 ? '-' : '${(_correct * 100 / total).round()}%',
                    color: AppColors.actionBlue),
                _Stat(
                    label: 'Eng yaxshi natija',
                    value: '$_best',
                    color: AppColors.homework),
              ],
            ),
            const SizedBox(height: 8),
            // Raqamlar nimani bildirishi va keyin nima bo'lishi.
            Text(
              "Aniqlik - barcha javoblaringiz ichida to'g'rilarining ulushi. "
              "Adashgan so'zlar keyingi mashqlarda ko'proq so'raladi.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5, height: 1.4, color: AppColors.muted(context)),
            ),
            const SizedBox(height: 26),
            Pressable3D(
              color: AppColors.homework,
              onPressed: _start,
              child: const Center(
                child: Text('Yana bir marta',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context, _score),
              child: const Text('Orqaga qaytish'),
            ),
          ],
        ),
        if (_newRecord)
          const IgnorePointer(child: ConfettiBurst(count: 140)),
      ],
    );
  }
}

enum _OptState { idle, right, wrong, dim }

class _Opt extends StatelessWidget {
  final String text;
  final _OptState state;
  final VoidCallback onTap;
  const _Opt({required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      _OptState.idle => (Theme.of(context).colorScheme.surface, null),
      _OptState.right => (AppColors.success, Colors.white),
      _OptState.wrong => (AppColors.danger, Colors.white),
      _OptState.dim => (Theme.of(context).colorScheme.surface, AppColors.muted(context)),
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: state == _OptState.dim ? 0.45 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            alignment: Alignment.center,
            child: Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w700, color: fg)),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5, color: AppColors.muted(context))),
          ],
        ),
      );
}

/// Blitz uchun manba: o'rganilgan (isNew emas) lug'at so'zlari.
List<DrillSource> blitzSourcesFromMastery(MasteryStore m, {int limit = 60}) {
  final out = <DrillSource>[];
  for (final e in m.learnedWords(limit: limit)) {
    out.add(DrillSource(
        itemId: e.$1, en: e.$2, uz: e.$3, unit: 0, topic: 'Blitz'));
  }
  return out;
}
