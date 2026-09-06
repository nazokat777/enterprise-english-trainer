import 'dart:math';

import 'package:flutter/material.dart';

import '../../content.dart';
import '../../main.dart';
import '../../srs.dart';
import '../../theme.dart';
import '../../services/tts.dart';
import '../../widgets/correct_burst.dart';
import '../../widgets/pressable3d.dart';
import '../pack/pack_flow.dart' show RoundPlay;
import 'homework_model.dart';

/// Unit bo'yicha baholi test: savollar → (match) → tuzatish → natija.
class HomeworkFlow extends StatefulWidget {
  final Unit unit;
  final List<Word> unitWords;
  final List<Word> levelWords;

  const HomeworkFlow({
    super.key,
    required this.unit,
    required this.unitWords,
    required this.levelWords,
  });

  @override
  State<HomeworkFlow> createState() => _HomeworkFlowState();
}

/// Oqim bosqichlari.
enum _Phase { question, match, correction, result }

class _HomeworkFlowState extends State<HomeworkFlow> {
  late HwPlan _plan;
  _Phase _phase = _Phase.question;

  int _index = 0; // joriy savol
  int _earned = 0; // olingan ball
  int _sessionXp = 0;
  final List<Word> _wrong = []; // birinchi urinishda xato qilinganlar

  @override
  void initState() {
    super.initState();
    _plan = buildPlan(widget.unitWords, widget.levelWords, Random());
  }

  @override
  void dispose() {
    Tts.instance.stop();
    super.dispose();
  }

  /// Savolga javob berildi: SRS + XP + ball.
  Future<void> _answered(Word word, bool correct) async {
    final q = correct ? Quality.good : Quality.unknown;
    await progress.reviewWord(word.id, q);
    if (!mounted) return;
    setState(() {
      if (correct) {
        _earned += 1;
        _sessionXp += xpForQuality(q);
      } else if (!_wrong.any((x) => x.id == word.id)) {
        // Bir so'z savolda ham, match'da ham xato bo'lishi mumkin —
        // tuzatish raundida ikki marta so'ralmasin.
        _wrong.add(word);
      }
    });
  }

  /// Keyingi savolga o'tish (yoki match/tuzatish/natijaga).
  void _next() {
    if (_index + 1 < _plan.questions.length) {
      setState(() => _index += 1);
    } else {
      _afterQuestions();
    }
  }

  void _afterQuestions() {
    if (_plan.matchRound.isNotEmpty) {
      setState(() => _phase = _Phase.match);
    } else {
      _afterMatch();
    }
  }

  /// Match tugadi: xato so'zlar bo'lsa tuzatish raundi, aks holda natija.
  void _afterMatch() {
    if (_wrong.isNotEmpty) {
      setState(() => _phase = _Phase.correction);
    } else {
      _finish();
    }
  }

  /// Match juftlari uchun ball (har juft 1) — SRS bilan birga.
  Future<void> _matchPair(Word word, bool correct) async {
    await progress.reviewWord(word.id, correct ? Quality.good : Quality.unknown);
    if (!mounted) return;
    setState(() {
      if (correct) {
        _earned += 1;
        _sessionXp += xpForQuality(Quality.good);
      } else if (!_wrong.any((x) => x.id == word.id)) {
        _wrong.add(word);
      }
    });
  }

  Future<void> _finish() async {
    final result = HwResult(
      earned: _earned,
      total: _plan.totalPoints,
      wrongWords: _wrong,
    );
    if (result.passed) {
      _sessionXp += kPassBonusXp;
      await progress.addXp(kPassBonusXp);
      if (!progress.isDone('hw::${widget.unit.id}')) {
        await progress.markDone('hw::${widget.unit.id}');
      }
    }
    if (mounted) setState(() => _phase = _Phase.result);
  }

  HwResult get _result => HwResult(
        earned: _earned,
        total: _plan.totalPoints,
        wrongWords: _wrong,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.coin.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '⚡ $_sessionXp XP',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.coin,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_plan.questions.isEmpty) {
      return const Center(child: Text('Bu unitda so\'z yo\'q'));
    }
    switch (_phase) {
      case _Phase.question:
        final q = _plan.questions[_index];
        return Column(
          children: [
            _progressBar(_index, _plan.questions.length),
            Expanded(
              child: _QuestionCard(
                key: ValueKey('q$_index'),
                question: q,
                onAnswered: (ok) => _answered(q.word, ok),
                onNext: _next,
              ),
            ),
          ],
        );
      case _Phase.match:
        return _MatchRound(
          words: _plan.matchRound,
          onPair: _matchPair,
          onDone: _afterMatch,
        );
      case _Phase.correction:
        return _CorrectionRound(
          words: List.of(_wrong),
          levelWords: widget.levelWords,
          onDone: _finish,
        );
      case _Phase.result:
        return _ResultView(
          result: _result,
          xp: _sessionXp,
          onClose: () => Navigator.pop(context),
          onRetry: _restart,
        );
    }
  }

  void _restart() {
    setState(() {
      _plan = buildPlan(widget.unitWords, widget.levelWords, Random());
      _phase = _Phase.question;
      _index = 0;
      _earned = 0;
      _sessionXp = 0;
      _wrong.clear();
    });
  }

  Widget _progressBar(int i, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : (i + 1) / total,
              minHeight: 6,
              backgroundColor: AppColors.homework.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.homework),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${i + 1} / $total',
              style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bitta savol: Choose/Fill — 4 variant; Construct — harf plitkalari.
class _QuestionCard extends StatefulWidget {
  final HwQuestion question;
  final ValueChanged<bool> onAnswered;
  final VoidCallback onNext;

  const _QuestionCard({
    super.key,
    required this.question,
    required this.onAnswered,
    required this.onNext,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  String? _chosen; // tanlangan variant (Choose/Fill)
  bool _locked = false; // javob berilgan — qayta bosib bo'lmaydi

  HwQuestion get q => widget.question;

  @override
  void initState() {
    super.initState();
    // Faqat Fill — so'z gapda yashiringan, eshitish yordam beradi.
    // Construct o'z ichida gapiradi (ikki marta o'qilmasin), Choose'da
    // inglizcha so'z ko'rinib turadi.
    if (q.kind == QuestionKind.fill) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Tts.instance.speak(q.word.en, id: 'hw'),
      );
    }
  }

  void _choose(String option) {
    if (_locked) return;
    final ok = option == q.answer;
    setState(() {
      _chosen = option;
      _locked = true;
    });
    widget.onAnswered(ok);
    if (ok) showCorrectBurst(context);
    Tts.instance.speak(q.word.en, id: 'hw');
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) widget.onNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (q.kind == QuestionKind.construct) {
      return _ConstructBody(
        word: q.word,
        onDone: (ok) {
          widget.onAnswered(ok);
          // Xato bo'lsa to'g'ri yozilishini o'qishga ulgursin.
          Future.delayed(Duration(milliseconds: ok ? 900 : 1700), () {
            if (mounted) widget.onNext();
          });
        },
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _prompt(context),
        const SizedBox(height: 18),
        Text(
          q.kind == QuestionKind.fill
              ? 'Bo\'sh joyni to\'ldiring'
              : 'Ma\'nosini tanlang',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 10),
        for (final o in q.options) _optionTile(o),
      ],
    );
  }

  /// Savol qismi: Choose — so'z; Fill — bo'sh joyli gap.
  Widget _prompt(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.3 : 0.05),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        children: [
          if (q.kind == QuestionKind.choose) ...[
            if (q.word.pos.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  q.word.pos,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.brandPurple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              q.word.en,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: dark ? AppColors.darkHeading : AppColors.lightHeading,
              ),
            ),
          ] else
            Text(
              q.sentence ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.5,
                color: dark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
          const SizedBox(height: 12),
          RoundPlay(text: q.word.en),
        ],
      ),
    );
  }

  /// Variant tugmasi — javobdan keyin to'g'ri yashil, tanlangan xato qizil.
  Widget _optionTile(String option) {
    Color border = Colors.black12;
    Color? text;
    if (_locked) {
      if (option == q.answer) {
        border = AppColors.success;
        text = AppColors.success;
      } else if (option == _chosen) {
        border = AppColors.danger;
        text = AppColors.danger;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: _locked ? null : () => _choose(option),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: border, width: 1.8),
            ),
            child: Text(
              option,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Harf plitkalaridan so'zni yig'ish. Ibora bo'lsa — bo'sh joy bo'yicha bo'linadi.
class _ConstructBody extends StatefulWidget {
  final Word word;
  final ValueChanged<bool> onDone;

  const _ConstructBody({required this.word, required this.onDone});

  @override
  State<_ConstructBody> createState() => _ConstructBodyState();
}

class _ConstructBodyState extends State<_ConstructBody> {
  final _rnd = Random();
  late List<String> _target;
  late List<String> _tiles;
  final List<int> _picked = [];
  bool? _result;

  @override
  void initState() {
    super.initState();
    final en = widget.word.en.trim();
    // Beginner kontentida ibora yo'q — deyarli har doim harf bo'yicha.
    _target = en.contains(' ') ? en.split(RegExp(r'\s+')) : en.split('');
    final scrambled = List.of(_target)..shuffle(_rnd);
    if (scrambled.join() == _target.join() && _target.length > 1) {
      scrambled.shuffle(_rnd);
    }
    _tiles = scrambled;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Tts.instance.speak(widget.word.en, id: 'hw'),
    );
  }

  void _tap(int i) {
    if (_result != null || _picked.contains(i)) return;
    setState(() => _picked.add(i));
    if (_picked.length == _target.length) _check();
  }

  void _undo() {
    if (_result != null || _picked.isEmpty) return;
    setState(() => _picked.removeLast());
  }

  /// BITTA urinish — Choose/Fill bilan bir xil qoida (spec §5: ball faqat
  /// birinchi urinishda). Xato bo'lsa to'g'ri yozilishi ko'rsatiladi va
  /// keyingi savolga o'tiladi; qayta urinish YO'Q (aks holda oqim qotib qoladi).
  void _check() {
    final sep = widget.word.en.trim().contains(' ') ? ' ' : '';
    final built = _picked.map((k) => _tiles[k]).join(sep);
    final ok = built.toLowerCase() == _target.join(sep).toLowerCase();
    setState(() => _result = ok);
    if (ok) showCorrectBurst(context);
    widget.onDone(ok); // ball + keyingiga o'tish (kechikish ota-widget'da)
  }

  @override
  Widget build(BuildContext context) {
    final sep = widget.word.en.trim().contains(' ') ? ' ' : '';
    final built = _picked.map((k) => _tiles[k]).join(sep);
    final long = _target.length > 12;
    final size = long ? 40.0 : 52.0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          '🧩 So\'zni yig\'ing',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            widget.word.uz,
            style: TextStyle(fontSize: 16, color: AppColors.muted(context)),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: RoundPlay(text: widget.word.en, size: 56)),
        const SizedBox(height: 20),
        Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _result == null
                  ? Colors.black26
                  : _result!
                      ? AppColors.success
                      : AppColors.danger,
              width: 2,
            ),
          ),
          child: Text(
            built.isEmpty ? '_ _ _' : built,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: _result == false
              // Xato — to'g'ri yozilishini ko'rsatamiz (o'rganish uchun).
              ? Center(
                  child: Text(
                    'To\'g\'risi: ${widget.word.en}',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : _picked.isNotEmpty
                  ? Center(
                      child: TextButton.icon(
                        onPressed: _undo,
                        icon: const Icon(Icons.backspace_outlined, size: 18),
                        label: const Text('Orqaga'),
                      ),
                    )
                  : const SizedBox(),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _tiles.length; i++)
              GestureDetector(
                onTap: () => _tap(i),
                child: AnimatedOpacity(
                  opacity: _picked.contains(i) ? 0.25 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: sep.isEmpty ? size : null,
                    height: size,
                    padding: sep.isEmpty
                        ? null
                        : const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.brandPurple.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _tiles[i],
                        style: TextStyle(
                          fontSize: long ? 18 : 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Moslash raundi: chapda inglizcha, o'ngda o'zbekcha. Har juft 1 ball.
/// Ball faqat BIRINCHI urinishda beriladi (xato bosilsa — juft "kuygan").
class _MatchRound extends StatefulWidget {
  final List<Word> words;
  final Future<void> Function(Word, bool) onPair;
  final VoidCallback onDone;

  const _MatchRound({
    required this.words,
    required this.onPair,
    required this.onDone,
  });

  @override
  State<_MatchRound> createState() => _MatchRoundState();
}

class _MatchRoundState extends State<_MatchRound> {
  final _rnd = Random();
  late List<Word> _left;
  late List<Word> _right;
  String? _selected; // tanlangan chap so'z id
  final Set<String> _matched = {};
  final Set<String> _failed = {}; // xato urinish bo'lgan so'zlar
  String? _wrongFlash;

  @override
  void initState() {
    super.initState();
    _left = List.of(widget.words)..shuffle(_rnd);
    _right = List.of(widget.words)..shuffle(_rnd);
  }

  Future<void> _tapRight(Word r) async {
    final sel = _selected;
    if (sel == null || _matched.contains(r.id)) return;

    if (sel == r.id) {
      setState(() {
        _matched.add(r.id);
        _selected = null;
      });
      await widget.onPair(r, !_failed.contains(r.id));
      Tts.instance.speak(r.en, id: r.id);
      if (_matched.length == widget.words.length) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) widget.onDone();
        });
      }
    } else {
      setState(() {
        _failed.add(sel); // tanlangan chap so'z uchun xato hisoblanadi
        _wrongFlash = r.id;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _wrongFlash = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '🔗 Moslash raundi',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (final x in _left)
                        _tile(
                          label: x.en,
                          done: _matched.contains(x.id),
                          selected: _selected == x.id,
                          onTap: () {
                            if (_matched.contains(x.id)) return;
                            setState(() => _selected = x.id);
                            Tts.instance.speak(x.en, id: x.id);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      for (final x in _right)
                        _tile(
                          label: x.uz,
                          done: _matched.contains(x.id),
                          wrong: _wrongFlash == x.id,
                          onTap: () => _tapRight(x),
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
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: done ? AppColors.success : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tuzatish raundi: xato qilingan so'zlar to'g'ri javob berilguncha so'raladi.
/// BALLGA TA'SIR QILMAYDI — maqsadi o'rgatish (spec §5.1).
class _CorrectionRound extends StatefulWidget {
  final List<Word> words;
  final List<Word> levelWords;
  final VoidCallback onDone;

  const _CorrectionRound({
    required this.words,
    required this.levelWords,
    required this.onDone,
  });

  @override
  State<_CorrectionRound> createState() => _CorrectionRoundState();
}

class _CorrectionRoundState extends State<_CorrectionRound> {
  final _rnd = Random();
  int _i = 0;
  late List<String> _options;
  String? _chosen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final target = widget.words[_i];
    final pool = [...widget.words, ...widget.levelWords];
    final d = pickDistractors(target, pool, 3, _rnd);
    _options = [target.uz, ...d.map((x) => x.uz)]..shuffle(_rnd);
    _chosen = null;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Tts.instance.speak(target.en, id: 'fix'),
    );
  }

  void _tap(String option) {
    final target = widget.words[_i];
    if (_chosen != null) return;
    setState(() => _chosen = option);

    if (option != target.uz) {
      // Xato — to'g'risini ko'rsatib, shu so'zni qayta so'raymiz.
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(_load);
      });
      return;
    }

    showCorrectBurst(context);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_i + 1 < widget.words.length) {
        setState(() {
          _i += 1;
          _load();
        });
      } else {
        widget.onDone();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.words[_i];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            const Text(
              '🔁 Xatolar ustida ishlash',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const Spacer(),
            Text(
              '${_i + 1} / ${widget.words.length}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.homework,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Bu raund bahoga ta\'sir qilmaydi',
          style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            target.en,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        Center(child: RoundPlay(text: target.en)),
        const SizedBox(height: 22),
        for (final o in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: _chosen == null ? () => _tap(o) : null,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: _chosen == null
                          ? Colors.black12
                          : o == target.uz
                              ? AppColors.success
                              : o == _chosen
                                  ? AppColors.danger
                                  : Colors.black12,
                      width: 1.8,
                    ),
                  ),
                  child: Text(
                    o,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Yakuniy natija: foiz, o'tdi/yiqildi, XP va tugmalar.
class _ResultView extends StatelessWidget {
  final HwResult result;
  final int xp;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  const _ResultView({
    required this.result,
    required this.xp,
    required this.onClose,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final passed = result.passed;
    final color = passed ? AppColors.success : AppColors.danger;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(
              passed ? Icons.check_rounded : Icons.refresh_rounded,
              color: Colors.white,
              size: 68,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '${result.percent}%',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        Center(
          child: Text(
            passed ? 'O\'tdingiz! 🎉' : 'O\'tish uchun $kPassMark% kerak',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '${result.earned} / ${result.total} to\'g\'ri',
            style: TextStyle(color: AppColors.muted(context)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.coin.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '+$xp XP',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.coin,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Pressable3D(
          color: AppColors.brandPurple,
          shadowColor: const Color(0xFF5B22B5),
          onPressed: onClose,
          child: const Center(
            child: Text(
              'Unitga qaytish',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Pressable3D(
          color: AppColors.homework,
          shadowColor: const Color(0xFFB8410C),
          onPressed: onRetry,
          child: const Center(
            child: Text(
              'Qayta topshirish',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
