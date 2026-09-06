import 'dart:math';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../content.dart';
import '../../srs.dart';
import '../../theme.dart';
import '../../services/tts.dart';
import '../../widgets/correct_burst.dart';
import '../../widgets/pressable3d.dart';

/// Bitta pack'ni 4 bosqichda o'rgatuvchi interaktiv oqim:
/// Tanishtirish → Moslash → Audio+Imlo → So'z-bo'lak yig'ish → Tugatish.
/// Bo'sh bosqichlar (masalan ibora yo'q bo'lsa) avtomatik o'tkaziladi.
class PackFlow extends StatefulWidget {
  final Unit unit;
  final VocabPack pack;
  final List<Word> words;
  const PackFlow({
    super.key,
    required this.unit,
    required this.pack,
    required this.words,
  });

  @override
  State<PackFlow> createState() => _PackFlowState();
}

enum _Step { intro, match, spell, build, done }

class _PackFlowState extends State<PackFlow> {
  _Step _step = _Step.intro;
  int _sessionXp = 0;

  List<Word> get _words => widget.words;
  List<Word> get _singleWords =>
      _words.where((w) => !w.en.trim().contains(' ')).toList();
  List<Word> get _phrases =>
      _words.where((w) => w.en.trim().contains(' ')).toList();

  @override
  void dispose() {
    Tts.instance.stop();
    super.dispose();
  }

  Future<void> _review(Word w, Quality q) async {
    await progress.reviewWord(w.id, q);
    final g = xpForQuality(q);
    if (g > 0 && mounted) setState(() => _sessionXp += g);
  }

  void _next() {
    setState(() {
      switch (_step) {
        case _Step.intro:
          _step = _Step.match;
          break;
        case _Step.match:
          _step = _singleWords.isNotEmpty ? _Step.spell : _stepAfterSpell();
          break;
        case _Step.spell:
          _step = _stepAfterSpell();
          break;
        case _Step.build:
          _step = _Step.done;
          break;
        case _Step.done:
          break;
      }
      if (_step == _Step.done) _finish();
    });
  }

  _Step _stepAfterSpell() => _phrases.isNotEmpty ? _Step.build : _Step.done;

  void _finish() {
    if (!progress.isDone(widget.pack.id)) {
      progress.addXp(5); // pack tugatgani uchun bonus
      progress.markDone(widget.pack.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pack.name),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.coin.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('⚡ $_sessionXp XP',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.coin,
                      fontSize: 13)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_step != _Step.intro && _step != _Step.done) _stepStrip(),
            Expanded(child: _stageBody()),
          ],
        ),
      ),
    );
  }

  Widget _stageBody() {
    switch (_step) {
      case _Step.intro:
        return _IntroStage(words: _words, onDone: _next);
      case _Step.match:
        return MatchStage(words: _words, onReview: _review, onDone: _next);
      case _Step.spell:
        return SpellStage(words: _singleWords, onReview: _review, onDone: _next);
      case _Step.build:
        return BuildStage(words: _phrases, onReview: _review, onDone: _next);
      case _Step.done:
        return _DoneStage(xp: _sessionXp, onClose: () => Navigator.pop(context));
    }
  }

  Widget _stepStrip() {
    const items = [
      (_Step.match, Icons.compare_arrows_rounded, 'Moslash'),
      (_Step.spell, Icons.spellcheck_rounded, 'Imlo'),
      (_Step.build, Icons.extension_rounded, 'Yig\'ish'),
    ];
    final order = [_Step.match, _Step.spell, _Step.build];
    final cur = order.indexOf(_step);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _dot(items[i].$2, items[i].$3, i <= cur, i == cur),
            if (i < items.length - 1)
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: i < cur ? AppColors.brandPurple : Colors.black12,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _dot(IconData icon, String label, bool active, bool current) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active ? AppColors.brandPurple : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
                color: active ? AppColors.brandPurple : Colors.black26, width: 2),
          ),
          child: Icon(icon, size: 18, color: active ? Colors.white : Colors.black38),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: current ? FontWeight.w800 : FontWeight.w500,
                color: active ? AppColors.brandPurple : Colors.black45)),
      ],
    );
  }
}

// ═══════════════ Umumiy: audio tugma + bold misol ═══════════════
class RoundPlay extends StatelessWidget {
  final String text;
  final double size;
  const RoundPlay({super.key, required this.text, this.size = 44});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.actionBlue,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Tts.instance.speak(text, id: text),
        child: SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Misol gapda target so'zni bold qiladi.
Widget boldExample(String example, String target, TextStyle base) {
  if (example.trim().isEmpty) return const SizedBox.shrink();
  final lower = example.toLowerCase();
  final t = target.toLowerCase();
  final idx = lower.indexOf(t);
  if (idx < 0 || t.isEmpty) {
    return Text(example, style: base);
  }
  return RichText(
    text: TextSpan(style: base, children: [
      TextSpan(text: example.substring(0, idx)),
      TextSpan(
          text: example.substring(idx, idx + t.length),
          style: base.copyWith(fontWeight: FontWeight.w800, color: AppColors.brandPurple)),
      TextSpan(text: example.substring(idx + t.length)),
    ]),
  );
}

// ═══════════════ 1) Tanishtirish ═══════════════
class _IntroStage extends StatefulWidget {
  final List<Word> words;
  final VoidCallback onDone;
  const _IntroStage({required this.words, required this.onDone});
  @override
  State<_IntroStage> createState() => _IntroStageState();
}

class _IntroStageState extends State<_IntroStage> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  void _speak() => Tts.instance.speak(widget.words[_i].en, id: 'intro');

  @override
  Widget build(BuildContext context) {
    final w = widget.words[_i];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              const Text('👋 Tanishuv',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              Text('${_i + 1} / ${widget.words.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.brandPurple)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.3 : 0.05),
                      blurRadius: 14),
                ],
              ),
              // Tor ekranda (320x640) yoki katta shrift rejimida kartochka
              // ichidagi matn sig'masdi va pastdan chiqib ketardi.
              // `Center` + `SingleChildScrollView`: joy yetsa markazda
              // turadi, yetmasa aylanadi.
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🇬🇧', style: TextStyle(fontSize: 20)),
                      if (w.pos.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.brandPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(w.pos,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.brandPurple,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(w.en,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: dark ? AppColors.darkHeading : AppColors.lightHeading)),
                  if (w.phonetic.isNotEmpty)
                    Text('/${w.phonetic}/',
                        style: const TextStyle(color: Colors.black45, fontSize: 15)),
                  const SizedBox(height: 12),
                  RoundPlay(text: w.en),
                  const SizedBox(height: 16),
                  Text(w.uz,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.success)),
                  if (w.hasExample) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    boldExample(w.example, w.en,
                        TextStyle(fontSize: 15, height: 1.4, color: dark ? AppColors.darkInk : AppColors.lightInk)),
                  ],
                ],
              ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: Pressable3D(
              color: AppColors.actionBlue,
              onPressed: () {
                if (_i + 1 < widget.words.length) {
                  setState(() => _i++);
                  _speak();
                } else {
                  widget.onDone();
                }
              },
              child: Center(
                child: Text(
                    _i + 1 < widget.words.length ? 'Keyingi so\'z' : 'Mashqni boshlash',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════ 2) Moslash ═══════════════
class MatchStage extends StatefulWidget {
  final List<Word> words;
  final Future<void> Function(Word, Quality) onReview;
  final VoidCallback onDone;
  const MatchStage({
    super.key,
    required this.words,
    required this.onReview,
    required this.onDone,
  });
  @override
  State<MatchStage> createState() => _MatchStageState();
}

class _MatchStageState extends State<MatchStage> {
  final _rnd = Random();
  late List<Word> _left;
  late List<Word> _right;
  String? _selLeft;
  final Set<String> _matched = {};
  String? _wrongId;

  /// Qaysi so'zda xato moslash bo'lgan.
  ///
  /// XATO: ilgari xato urinish HECH QAYERDA hisobga olinmasdi — so'zni
  /// besh marta xato moslab, oltinchisida topsangiz ham u "yaxshi
  /// bilinadi" deb yozilardi. Shu sababli "Qiyin so'zlar" ro'yxatiga
  /// aynan yodlanmayotgan so'zlar tushmasdi.
  final Set<String> _missed = {};

  @override
  void initState() {
    super.initState();
    _left = List.of(widget.words)..shuffle(_rnd);
    _right = List.of(widget.words)..shuffle(_rnd);
  }

  Future<void> _tapRight(Word r) async {
    if (_selLeft == null || _matched.contains(r.id)) return;
    if (_selLeft == r.id) {
      final missed = _missed.contains(r.id);
      setState(() {
        _matched.add(r.id);
        _selLeft = null;
      });
      final w = widget.words.firstWhere((e) => e.id == r.id);
      await widget.onReview(w, missed ? Quality.hard : Quality.good);
      Tts.instance.speak(w.en, id: w.id);
      if (_matched.length == widget.words.length) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.onDone();
        });
      }
    } else {
      // Xato TANLANGAN so'zga yoziladi (bosilganiga emas) — o'quvchi
      // aynan o'sha so'zning ma'nosini bilmayapti.
      final missedId = _selLeft!;
      progress.recordMiss(missedId);
      setState(() {
        _missed.add(missedId);
        _wrongId = r.id;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _wrongId = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('So\'zlarni ma\'nosiga moslang',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (final w in _left)
                        _tile(
                          label: w.en,
                          done: _matched.contains(w.id),
                          selected: _selLeft == w.id,
                          onTap: () {
                            if (_matched.contains(w.id)) return;
                            setState(() => _selLeft = w.id);
                            Tts.instance.speak(w.en, id: w.id);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      for (final w in _right)
                        _tile(
                          label: w.uz,
                          done: _matched.contains(w.id),
                          wrong: _wrongId == w.id,
                          onTap: () => _tapRight(w),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile({
    required String label,
    required VoidCallback onTap,
    bool done = false,
    bool selected = false,
    bool wrong = false,
  }) {
    Color border = Colors.black12;
    Color bg = Theme.of(context).colorScheme.surface;
    if (done) {
      border = AppColors.success;
      bg = AppColors.success.withValues(alpha: 0.12);
    } else if (wrong) {
      border = AppColors.danger;
      bg = AppColors.danger.withValues(alpha: 0.12);
    } else if (selected) {
      border = AppColors.brandPurple;
      bg = AppColors.brandPurple.withValues(alpha: 0.10);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: done ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: border, width: 1.8),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    decoration: done ? null : null,
                    color: done ? AppColors.success : null)),
          ),
        ),
      ),
    );
  }
}

// ═══════════════ 3) Audio + Imlo ═══════════════
class SpellStage extends StatefulWidget {
  final List<Word> words;
  final Future<void> Function(Word, Quality) onReview;
  final VoidCallback onDone;
  const SpellStage({
    super.key,
    required this.words,
    required this.onReview,
    required this.onDone,
  });
  @override
  State<SpellStage> createState() => _SpellStageState();
}

class _SpellStageState extends State<SpellStage> {
  final _rnd = Random();
  int _i = 0;
  late List<String> _target;
  late List<_LetterTile> _tiles;
  final List<int> _picked = [];
  bool? _result;
  int _wrongTries = 0;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  void _load(int i) {
    final word = widget.words[i];
    _target = word.en.trim().split('');
    var scrambled = List.of(_target)..shuffle(_rnd);
    if (scrambled.join() == _target.join() && _target.length > 1) {
      scrambled.shuffle(_rnd);
    }
    _tiles = List.generate(scrambled.length, (k) => _LetterTile(scrambled[k], k));
    _picked.clear();
    _result = null;
    _wrongTries = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => Tts.instance.speak(word.en, id: 'spell'));
  }

  void _tap(int tileIdx) {
    if (_result != null || _picked.contains(tileIdx)) return;
    setState(() {
      _picked.add(tileIdx);
    });
    if (_picked.length == _target.length) _check();
  }

  Future<void> _check() async {
    final built = _picked.map((k) => _tiles[k].ch).join();
    final ok = built.toLowerCase() == _target.join().toLowerCase();
    setState(() => _result = ok);
    if (ok) {
      final word = widget.words[_i];
      await widget.onReview(word, _wrongTries == 0 ? Quality.good : Quality.hard);
      if (mounted) showCorrectBurst(context);
      Future.delayed(const Duration(milliseconds: 900), _advance);
    } else {
      _wrongTries++;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _picked.clear();
          _result = null;
        });
      });
    }
  }

  void _advance() {
    if (!mounted) return;
    if (_i + 1 < widget.words.length) {
      setState(() => _i++);
      _load(_i);
    } else {
      widget.onDone();
    }
  }

  void _undo() {
    if (_result != null || _picked.isEmpty) return;
    setState(() => _picked.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.words[_i];
    final built = _picked.map((k) => _tiles[k].ch).join();
    final borderColor = _result == null
        ? Colors.black26
        : _result!
            ? AppColors.success
            : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🎧 Eshiting va yozing',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              Text('${_i + 1} / ${widget.words.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.brandPurple)),
            ],
          ),
          const SizedBox(height: 8),
          Text(word.uz, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          RoundPlay(text: word.en, size: 56),
          const SizedBox(height: 20),
          // Yig'ilayotgan so'z
          Container(
            height: 64,
            alignment: Alignment.center,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Text(built.isEmpty ? '_ _ _' : built,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 2)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: _result == false
                ? const Text('❌ Qayta urinib ko\'ring',
                    style: TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w700))
                : (_picked.isNotEmpty && _result == null
                    ? TextButton.icon(
                        onPressed: _undo,
                        icon: const Icon(Icons.backspace_outlined, size: 18),
                        label: const Text('Orqaga'))
                    : const SizedBox()),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < _tiles.length; i++)
                _letterButton(i, used: _picked.contains(i)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _letterButton(int i, {required bool used}) {
    return GestureDetector(
      onTap: () => _tap(i),
      child: AnimatedOpacity(
        opacity: used ? 0.25 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: AppColors.brandPurple.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Center(
            child: Text(_tiles[i].ch,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class _LetterTile {
  final String ch;
  final int id;
  _LetterTile(this.ch, this.id);
}

// ═══════════════ 4) So'z-bo'lak yig'ish (iboralar) ═══════════════
class BuildStage extends StatefulWidget {
  final List<Word> words;
  final Future<void> Function(Word, Quality) onReview;
  final VoidCallback onDone;
  const BuildStage({
    super.key,
    required this.words,
    required this.onReview,
    required this.onDone,
  });
  @override
  State<BuildStage> createState() => _BuildStageState();
}

class _BuildStageState extends State<BuildStage> {
  final _rnd = Random();
  int _i = 0;
  late List<String> _target;
  late List<_LetterTile> _blocks;
  final List<int> _picked = [];
  bool? _result;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  void _load(int i) {
    _target = widget.words[i].en.trim().split(RegExp(r'\s+'));
    var scrambled = List.of(_target)..shuffle(_rnd);
    if (scrambled.join(' ') == _target.join(' ') && _target.length > 1) {
      scrambled.shuffle(_rnd);
    }
    _blocks = List.generate(scrambled.length, (k) => _LetterTile(scrambled[k], k));
    _picked.clear();
    _result = null;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Tts.instance.speak(widget.words[i].en, id: 'build'));
  }

  void _tap(int idx) {
    if (_result != null || _picked.contains(idx)) return;
    setState(() => _picked.add(idx));
    if (_picked.length == _target.length) _check();
  }

  Future<void> _check() async {
    final built = _picked.map((k) => _blocks[k].ch).join(' ');
    final ok = built.toLowerCase() == _target.join(' ').toLowerCase();
    setState(() => _result = ok);
    if (ok) {
      await widget.onReview(widget.words[_i], Quality.good);
      if (mounted) showCorrectBurst(context);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        if (_i + 1 < widget.words.length) {
          setState(() => _i++);
          _load(_i);
        } else {
          widget.onDone();
        }
      });
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _picked.clear();
          _result = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.words[_i];
    final built = _picked.map((k) => _blocks[k].ch).join(' ');
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🧩 Iborani yig\'ing',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              Text('${_i + 1} / ${widget.words.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.brandPurple)),
            ],
          ),
          const SizedBox(height: 8),
          Text(word.uz, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          RoundPlay(text: word.en, size: 50),
          const SizedBox(height: 18),
          Container(
            constraints: const BoxConstraints(minHeight: 60),
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: _result == null
                      ? Colors.black26
                      : _result!
                          ? AppColors.success
                          : AppColors.danger,
                  width: 2),
            ),
            child: Text(built.isEmpty ? '…' : built,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < _blocks.length; i++)
                GestureDetector(
                  onTap: () => _tap(i),
                  child: AnimatedOpacity(
                    opacity: _picked.contains(i) ? 0.25 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.brandPurple.withValues(alpha: 0.35),
                            width: 1.5),
                      ),
                      child: Text(_blocks[i].ch,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════ Tugatish ═══════════════
class _DoneStage extends StatefulWidget {
  final int xp;
  final VoidCallback onClose;
  const _DoneStage({required this.xp, required this.onClose});
  @override
  State<_DoneStage> createState() => _DoneStageState();
}

class _DoneStageState extends State<_DoneStage> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circle =
        CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut));
    final text =
        CurvedAnimation(parent: _c, curve: const Interval(0.4, 0.8, curve: Curves.easeOut));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: circle,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.success),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 72),
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: text,
              child: Column(
                children: [
                  const Text('Barakalla! 🎉',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success)),
                  const SizedBox(height: 8),
                  const Text('Pack tugatildi',
                      style: TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.coin.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('+${widget.xp} XP',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.coin)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: Pressable3D(
                color: AppColors.brandPurple,
                shadowColor: const Color(0xFF5B22B5),
                onPressed: widget.onClose,
                child: const Center(
                  child: Text('Unitga qaytish',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
