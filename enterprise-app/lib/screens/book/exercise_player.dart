import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../book_content.dart';
import '../../main.dart';
import '../../stats.dart';
import '../../theme.dart';
import '../../services/tts.dart';
import '../../widgets/correct_burst.dart';
import '../../widgets/pressable3d.dart';
import '../pack/pack_flow.dart' show RoundPlay;

/// Bitta mashqni o'ynatadi. 4 xil o'yin turi:
/// choice (tanlash) · text (yig'ish) · match (moslash) · study (o'qish).
class ExercisePlayer extends StatefulWidget {
  final BookExercise exercise;
  final String sectionTitle;

  const ExercisePlayer({
    super.key,
    required this.exercise,
    required this.sectionTitle,
  });

  @override
  State<ExercisePlayer> createState() => _ExercisePlayerState();
}

class _ExercisePlayerState extends State<ExercisePlayer> {
  int _index = 0;
  int _correct = 0;
  int _xp = 0;
  bool _done = false;

  BookExercise get ex => widget.exercise;

  @override
  void dispose() {
    Tts.instance.stop();
    super.dispose();
  }

  /// Band yakunlandi: XP va SRS (lug'at ko'nikmasi).
  Future<void> _answered(bool ok) async {
    if (ok) _correct++;
    final gain = ok ? 2 : 0;
    if (gain > 0) {
      _xp += gain;
      await progress.addXp(gain, skill: _skillOf(ex));
    }
    if (!mounted) return;
    setState(() {
      if (_index + 1 < ex.tasks.length) {
        _index++;
      } else {
        _done = true;
        _finish();
      }
    });
  }

  Skill _skillOf(BookExercise e) {
    if (e.audio) return Skill.listening;
    return switch (e.kind) {
      ExKind.match => Skill.vocab,
      ExKind.text => Skill.grammar,
      _ => Skill.vocab,
    };
  }

  void _finish() {
    final id = 'ex::${ex.book}::${ex.bookPage}::${ex.ref}';
    if (!progress.isDone(id)) {
      progress.addXp(3); // mashqni tugatgani uchun bonus
      progress.markDone(id);
      _xp += 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.sectionTitle} · ${ex.title}'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.coin.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('⚡ $_xp XP',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.coin,
                      fontSize: 13)),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (ex.tasks.isEmpty) {
      return const Center(child: Text('Bu mashqda band yo\'q'));
    }
    if (_done) return _result();

    return Column(
      children: [
        _header(),
        Expanded(child: _stage()),
      ],
    );
  }

  Widget _header() {
    final total = ex.kind == ExKind.study || ex.kind == ExKind.match
        ? 1
        : ex.tasks.length;
    final value = ex.kind == ExKind.study || ex.kind == ExKind.match
        ? 1.0
        : (_index + 1) / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: AppColors.actionBlue.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.actionBlue),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  ex.instructionUz,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              if (ex.kind != ExKind.study && ex.kind != ExKind.match)
                Text('${_index + 1} / ${ex.tasks.length}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.lightMuted)),
            ],
          ),
          if (ex.bookRef.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('📖 ${ex.bookRef}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.brandPurple)),
            ),
        ],
      ),
    );
  }

  Widget _stage() {
    switch (ex.kind) {
      case ExKind.choice:
        return _ChoiceStage(
          key: ValueKey('c$_index'),
          task: ex.tasks[_index],
          explanation: _index == 0 ? ex.explanationUz : '',
          onDone: _answered,
        );
      case ExKind.text:
        return _BuildStage(
          key: ValueKey('t$_index'),
          task: ex.tasks[_index],
          explanation: _index == 0 ? ex.explanationUz : '',
          onDone: _answered,
        );
      case ExKind.match:
        return _MatchStage(
          tasks: ex.tasks,
          explanation: ex.explanationUz,
          onDone: (right) {
            _correct = right;
            setState(() {
              _done = true;
              _finish();
            });
          },
        );
      case ExKind.study:
        return _StudyStage(
          exercise: ex,
          onDone: () => setState(() {
            _done = true;
            _finish();
          }),
        );
    }
  }

  Widget _result() {
    final total = ex.kind == ExKind.study ? ex.tasks.length : ex.tasks.length;
    final pct = total == 0 ? 100 : (_correct * 100 / total).round();
    final good = ex.kind == ExKind.study || pct >= 70;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: good ? AppColors.success : AppColors.homework,
            ),
            child: Icon(good ? Icons.check_rounded : Icons.replay_rounded,
                color: Colors.white, size: 58),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            ex.kind == ExKind.study ? 'O\'qib chiqdingiz' : '$_correct / $total',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: good ? AppColors.success : AppColors.homework),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.coin.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text('+$_xp XP',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.coin)),
          ),
        ),
        const SizedBox(height: 28),
        Pressable3D(
          color: AppColors.brandPurple,
          shadowColor: const Color(0xFF5B22B5),
          onPressed: () => Navigator.pop(context),
          child: const Center(
            child: Text('Bo\'limga qaytish',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
        ),
        if (ex.kind != ExKind.study) ...[
          const SizedBox(height: 12),
          Pressable3D(
            color: AppColors.actionBlue,
            onPressed: () => setState(() {
              _index = 0;
              _correct = 0;
              _done = false;
            }),
            child: const Center(
              child: Text('Qayta ishlash',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════ Izoh kartasi (barcha turlar uchun) ═══════════════
class ExplanationCard extends StatelessWidget {
  final String text;
  const ExplanationCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandPurple.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
            left: BorderSide(color: AppColors.brandPurple, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 18, color: AppColors.brandPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13.5, height: 1.55)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════ 1) Tanlash ═══════════════
class _ChoiceStage extends StatefulWidget {
  final ExTask task;
  final String explanation;
  final ValueChanged<bool> onDone;

  const _ChoiceStage({
    super.key,
    required this.task,
    required this.explanation,
    required this.onDone,
  });

  @override
  State<_ChoiceStage> createState() => _ChoiceStageState();
}

class _ChoiceStageState extends State<_ChoiceStage> {
  final _rnd = Random();
  late List<String> _options;
  String? _chosen;
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    _options = List.of(widget.task.options)..shuffle(_rnd);
    if (_options.isEmpty) _options = [widget.task.answer];
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  void _tap(String o) {
    if (_chosen != null) return;
    final ok = widget.task.isCorrect(o);
    setState(() => _chosen = o);
    if (ok) showCorrectBurst(context);
    Tts.instance.speak(widget.task.answer, id: 'ex');
    _advance = Timer(Duration(milliseconds: ok ? 900 : 1900), () {
      if (mounted) widget.onDone(ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        ExplanationCard(text: widget.explanation),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.3 : 0.05),
                  blurRadius: 14),
            ],
          ),
          child: Column(
            children: [
              Text(t.prompt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: t.prompt.length > 40 ? 17 : 24,
                      height: 1.4,
                      fontWeight: FontWeight.w800,
                      color:
                          dark ? AppColors.darkHeading : AppColors.lightHeading)),
              if (t.promptUz.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(t.promptUz,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.lightMuted)),
              ],
              const SizedBox(height: 12),
              RoundPlay(text: t.speakText),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final o in _options) _tile(o),
        if (_chosen != null && t.whyUz.isNotEmpty) ...[
          const SizedBox(height: 6),
          _WhyCard(text: t.whyUz, correct: t.isCorrect(_chosen!)),
        ],
      ],
    );
  }

  Widget _tile(String o) {
    Color border = Colors.black12;
    Color? text;
    if (_chosen != null) {
      if (widget.task.isCorrect(o)) {
        border = AppColors.success;
        text = AppColors.success;
      } else if (o == _chosen) {
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
          onTap: _chosen == null ? () => _tap(o) : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: border, width: 1.8),
            ),
            child: Text(o,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15, color: text)),
          ),
        ),
      ),
    );
  }
}

/// Javobdan keyingi "nega shunday" izohi.
class _WhyCard extends StatelessWidget {
  final String text;
  final bool correct;
  const _WhyCard({required this.text, required this.correct});

  @override
  Widget build(BuildContext context) {
    final c = correct ? AppColors.success : AppColors.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(left: BorderSide(color: c, width: 3)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
    );
  }
}

// ═══════════════ 2) Yig'ish ═══════════════
class _BuildStage extends StatefulWidget {
  final ExTask task;
  final String explanation;
  final ValueChanged<bool> onDone;

  const _BuildStage({
    super.key,
    required this.task,
    required this.explanation,
    required this.onDone,
  });

  @override
  State<_BuildStage> createState() => _BuildStageState();
}

class _BuildStageState extends State<_BuildStage> {
  final _rnd = Random();
  late List<String> _pieces;
  final List<int> _picked = [];
  bool? _result;
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    final target = widget.task.buildPieces;
    final s = List.of(target)..shuffle(_rnd);
    if (s.join() == target.join() && target.length > 1) s.shuffle(_rnd);
    _pieces = s;
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  void _tap(int i) {
    if (_result != null || _picked.contains(i)) return;
    setState(() => _picked.add(i));
    if (_picked.length == _pieces.length) _check();
  }

  void _undo() {
    if (_result != null || _picked.isEmpty) return;
    setState(() => _picked.removeLast());
  }

  void _check() {
    final built = _picked.map((k) => _pieces[k]).join(widget.task.buildSeparator);
    final ok = widget.task.isCorrect(built);
    setState(() => _result = ok);
    if (ok) showCorrectBurst(context);
    Tts.instance.speak(widget.task.answer, id: 'ex');
    _advance = Timer(Duration(milliseconds: ok ? 950 : 2100), () {
      if (mounted) widget.onDone(ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final built = _picked.map((k) => _pieces[k]).join(t.buildSeparator);
    final long = _pieces.length > 12;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        ExplanationCard(text: widget.explanation),
        Center(
          child: Text(t.prompt,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: t.prompt.length > 40 ? 16 : 22,
                  height: 1.4,
                  fontWeight: FontWeight.w800)),
        ),
        if (t.promptUz.isNotEmpty) ...[
          const SizedBox(height: 6),
          Center(
            child: Text(t.promptUz,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.lightMuted)),
          ),
        ],
        const SizedBox(height: 14),
        Center(child: RoundPlay(text: t.speakText, size: 48)),
        const SizedBox(height: 18),
        Container(
          constraints: const BoxConstraints(minHeight: 64),
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
              style: TextStyle(
                  fontSize: t.isPhrase ? 17 : 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: t.isPhrase ? 0 : 2)),
        ),
        SizedBox(
          height: 36,
          child: _result == false
              ? Center(
                  child: Text('To\'g\'risi: ${t.answer}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800)),
                )
              : _picked.isNotEmpty
                  ? Center(
                      child: TextButton.icon(
                          onPressed: _undo,
                          icon: const Icon(Icons.backspace_outlined, size: 18),
                          label: const Text('Orqaga')),
                    )
                  : const SizedBox(),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _pieces.length; i++)
              GestureDetector(
                onTap: () => _tap(i),
                child: AnimatedOpacity(
                  opacity: _picked.contains(i) ? 0.25 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: t.isPhrase ? 14 : 0, vertical: 10),
                    width: t.isPhrase ? null : (long ? 40 : 48),
                    height: long ? 40 : 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color:
                              AppColors.brandPurple.withValues(alpha: 0.35),
                          width: 1.5),
                    ),
                    child: Text(_pieces[i],
                        style: TextStyle(
                            fontSize: long ? 15 : 18,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
          ],
        ),
        if (_result != null && t.whyUz.isNotEmpty) ...[
          const SizedBox(height: 14),
          _WhyCard(text: t.whyUz, correct: _result!),
        ],
      ],
    );
  }
}

// ═══════════════ 3) Moslash ═══════════════
class _MatchStage extends StatefulWidget {
  final List<ExTask> tasks;
  final String explanation;
  final ValueChanged<int> onDone;

  const _MatchStage({
    required this.tasks,
    required this.explanation,
    required this.onDone,
  });

  @override
  State<_MatchStage> createState() => _MatchStageState();
}

class _MatchStageState extends State<_MatchStage> {
  final _rnd = Random();
  late List<ExTask> _left;
  late List<ExTask> _right;
  final Set<String> _matched = {};
  final Set<String> _failed = {};
  String? _sel;
  String? _wrongFlash;
  Timer? _advance;
  Timer? _flash;

  @override
  void initState() {
    super.initState();
    _left = List.of(widget.tasks)..shuffle(_rnd);
    _right = List.of(widget.tasks)..shuffle(_rnd);
  }

  @override
  void dispose() {
    _advance?.cancel();
    _flash?.cancel();
    super.dispose();
  }

  void _tapRight(ExTask r) {
    final sel = _sel;
    if (sel == null || _matched.contains(r.left)) return;
    if (sel == r.left) {
      setState(() {
        _matched.add(r.left);
        _sel = null;
      });
      Tts.instance.speak(r.right, id: r.left);
      if (_matched.length == widget.tasks.length) {
        _advance = Timer(const Duration(milliseconds: 650), () {
          if (mounted) {
            widget.onDone(widget.tasks.length - _failed.length);
          }
        });
      }
    } else {
      setState(() {
        _failed.add(sel);
        _wrongFlash = r.left;
      });
      _flash = Timer(const Duration(milliseconds: 420), () {
        if (mounted) setState(() => _wrongFlash = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        ExplanationCard(text: widget.explanation),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final t in _left)
                    _tile(
                      label: t.left,
                      done: _matched.contains(t.left),
                      selected: _sel == t.left,
                      onTap: () {
                        if (_matched.contains(t.left)) return;
                        setState(() => _sel = t.left);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  for (final t in _right)
                    _tile(
                      label: t.right,
                      done: _matched.contains(t.left),
                      wrong: _wrongFlash == t.left,
                      onTap: () => _tapRight(t),
                    ),
                ],
              ),
            ),
          ],
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
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: done ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: border, width: 1.8),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: done ? AppColors.success : null)),
          ),
        ),
      ),
    );
  }
}

// ═══════════════ 4) O'qish ═══════════════
class _StudyStage extends StatelessWidget {
  final BookExercise exercise;
  final VoidCallback onDone;

  const _StudyStage({required this.exercise, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        ExplanationCard(text: exercise.explanationUz),
        if (exercise.audioNoteUz.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.homework.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.headphones_rounded,
                    size: 18, color: AppColors.homework),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(exercise.audioNoteUz,
                      style: const TextStyle(fontSize: 12.5, height: 1.4)),
                ),
              ],
            ),
          ),
        for (final t in exercise.tasks) _line(context, t),
        const SizedBox(height: 22),
        Pressable3D(
          color: AppColors.success,
          shadowColor: const Color(0xFF0F7A37),
          onPressed: onDone,
          child: const Center(
            child: Text('O\'qib chiqdim',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _line(BuildContext context, ExTask t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Tts.instance.speak(t.speakText, id: 'study'),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.en,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.4)),
                      if (t.uz.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(t.uz,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.lightMuted,
                                height: 1.4)),
                      ],
                      if (t.note.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(t.note,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.brandPurple,
                                height: 1.4)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.volume_up_rounded,
                    size: 20, color: AppColors.actionBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
