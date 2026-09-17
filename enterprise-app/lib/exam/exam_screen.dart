import 'package:flutter/material.dart';

import '../drill/drill_screen.dart';
import '../main.dart';
import '../mastery.dart';
import '../reward/confetti.dart';
import '../reward/sfx.dart';
import '../screens/book/type_stage.dart';
import '../theme.dart';
import '../widgets/pressable3d.dart';
import 'exam.dart';

/// 📝 IMTIHON EKRANI — 1..N unitlar.
///
/// Uch qism ketma-ket, xato band navbat oxiriga; yakunda baho (birinchi
/// urinish), zaif bandlar ro'yxati va "qayta ishlash".
class ExamScreen extends StatefulWidget {
  final int uptoUnit;

  /// Faqat shu bandlar (qayta ishlash rejimi).
  final Set<String>? onlyIds;

  const ExamScreen({super.key, required this.uptoUnit, this.onlyIds});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

enum _Phase { loading, intro, play, done }

class _ExamScreenState extends State<ExamScreen> {
  _Phase _phase = _Phase.loading;
  ExamPlan? _plan;
  final List<ExamItem> _queue = [];
  int _pos = 0;
  int _answered = 0;
  final Set<String> _firstTryOk = {};
  final Set<String> _failed = {};
  final Set<String> _seen = {};
  bool? _result;
  ExamResult? _saved;

  bool get _retake => widget.onlyIds != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await ExamBuilder(book: book, mastery: mastery)
        .build(widget.uptoUnit, onlyIds: widget.onlyIds);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _queue
        ..clear()
        ..addAll(plan.items);
      _phase = plan.items.isEmpty ? _Phase.done : _Phase.intro;
    });
  }

  ExamItem? get _cur => _pos < _queue.length ? _queue[_pos] : null;

  Future<void> _answer(bool ok) async {
    final it = _cur;
    if (it == null || _result != null) return;
    setState(() => _result = ok);
    final first = _seen.add(it.id);
    if (ok && first) _firstTryOk.add(it.id);
    if (!ok) _failed.add(it.id);
    // Lug'at va gaplar xotira jadvaliga yoziladi.
    if (it.part != ExamPart.grammar) {
      final q = it.q;
      await mastery.record(
        it.id,
        q?.format ?? AskFormat.listen,
        ok: ok,
        en: it.answer,
        uz: it.promptUz,
      );
    }
    rewards.onAnswer(ok, baseXp: 2);
    if (ok) await progress.addXp(2);
    _answered += 1;
    // Yozish bosqichi o'zi kutib beradi; tanlov uchun qisqa pauza.
    await Future.delayed(Duration(milliseconds: it.task != null ? 0 : (ok ? 500 : 1300)));
    if (!mounted) return;
    setState(() {
      if (!ok) _queue.add(it); // navbat oxiriga
      _pos += 1;
      _result = null;
    });
    if (_cur == null) await _finish();
  }

  Future<void> _finish() async {
    final plan = _plan!;
    final total = plan.items.length;
    final score = total == 0 ? 100 : (_firstTryOk.length * 100 / total).round();
    final topics = <String>{
      for (final it in plan.items)
        if (_failed.contains(it.id)) it.topic,
    };
    final r = ExamResult(
      uptoUnit: widget.uptoUnit,
      score: score,
      total: total,
      dateMs: DateTime.now().millisecondsSinceEpoch,
      weakIds: _failed.toList(),
      weakTopics: topics.toList(),
    );
    if (!_retake) await ExamStore.save(progress.currentLevel, r);
    rewards.onExerciseDone(clean: _failed.isEmpty);
    if (score >= 90) {
      rewards.onExamPassed(widget.uptoUnit);
      Sfx.instance.levelUp();
    }
    await progress.addXp(score >= 90 ? 30 : 10);
    if (!mounted) return;
    setState(() {
      _saved = r;
      _phase = _Phase.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _retake
        ? 'Zaif bandlarni qayta ishlash'
        : 'Imtihon · 1-${widget.uptoUnit} unitlar';
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 16))),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.intro => _intro(context),
          _Phase.play => _play(context),
          _Phase.done => _done(context),
        },
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final p = _plan!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        const Center(child: Text('📝', style: TextStyle(fontSize: 64))),
        const SizedBox(height: 10),
        Center(
          child: Text(
              _retake ? 'Qayta ishlash' : '1-${widget.uptoUnit} unitlar imtihoni',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 8),
        Text(
          'Xato band navbat oxiriga qaytadi - imtihon hammasi to\'g\'ri '
          'bo\'lguncha tugamaydi. Baho birinchi urinish bo\'yicha. '
          '90% va undan yuqori - o\'tdi.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13.5, height: 1.5, color: AppColors.muted(context)),
        ),
        const SizedBox(height: 20),
        _PartRow(icon: '📚', label: 'Lug\'at', n: p.count(ExamPart.words)),
        _PartRow(icon: '📐', label: 'Grammatika', n: p.count(ExamPart.grammar)),
        _PartRow(icon: '⌨️', label: 'Gaplar (yozish)', n: p.count(ExamPart.sentences)),
        const SizedBox(height: 24),
        Pressable3D(
          color: AppColors.brandPurple,
          onPressed: () => setState(() => _phase = _Phase.play),
          child: Center(
            child: Text('Boshlash · ${p.items.length} savol',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _play(BuildContext context) {
    final it = _cur!;
    final total = _queue.length;
    final partLabel = switch (it.part) {
      ExamPart.words => '📚 Lug\'at',
      ExamPart.grammar => '📐 Grammatika · ${it.topic}',
      ExamPart.sentences => '⌨️ Gap · ${it.topic}',
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(partLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandPurple)),
              ),
              Text('${_pos + 1}/$total',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted(context))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : _answered / (total + (_queue.length - _plan!.items.length)),
              minHeight: 8,
              backgroundColor: AppColors.brandPurple.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
        ),
        Expanded(
          child: it.task != null
              ? TypeStage(
                  key: ValueKey('y$_pos'),
                  task: it.task!,
                  explanation: '',
                  onDone: _answer,
                )
              : switch (it.q!.format) {
                  AskFormat.build || AskFormat.listen => BuildTask(
                      key: ValueKey('b$_pos'),
                      q: it.q!,
                      locked: _result != null,
                      onDone: _answer,
                    ),
                  _ => ChoiceTask(
                      key: ValueKey('c$_pos'),
                      q: it.q!,
                      locked: _result != null,
                      onDone: _answer,
                    ),
                },
        ),
      ],
    );
  }

  Widget _done(BuildContext context) {
    final r = _saved;
    final plan = _plan;
    if (r == null || plan == null) {
      return const Center(child: Text('Bu unitlar uchun savol topilmadi.'));
    }
    final passed = r.score >= 90;
    final weak = [
      for (final it in plan.items)
        if (_failed.contains(it.id)) it,
    ];
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // NATIJA KARTASI — o'tgan: oltin gradient; o'tmagan: olov.
            Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                gradient: passed
                    ? AppColors.goldGradient
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF97316), Color(0xFFEA580C), Color(0xFFDB2777)]),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadow.glow(
                    passed ? AppColors.coin : AppColors.homework, alpha: 0.45),
              ),
              child: Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) => Transform.scale(scale: v, child: child),
                    child: Text(passed ? '🏅' : '💪',
                        style: const TextStyle(fontSize: 60)),
                  ),
                  const SizedBox(height: 6),
                  Text(passed ? 'Imtihondan o\'tdingiz!' : 'Hali mustahkam emas',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: Colors.white)),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: r.score),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, v, _) => Text('$v%',
                        style: const TextStyle(
                            fontSize: 60,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                  Text(
                      '${_firstTryOk.length}/${r.total} birinchi urinishda · '
                      '${weak.length} ta band qayta so\'raldi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (weak.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Text(
                  '✅ O\'zlashtirilmagan mavzu qolmadi - 1-unitdan shu unitgacha hammasi mustahkam.',
                  style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                ),
              )
            else ...[
              Text('O\'zlashtirilmagan bandlar (${weak.length})',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Bular xotira jadvalida "1 kun"ga qaytdi va zaif ro\'yxatga tushdi. '
                'Hozir qayta ishlang - keyin yana imtihon topshiring.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.4, color: AppColors.muted(context)),
              ),
              const SizedBox(height: 10),
              for (final it in weak)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(
                            switch (it.part) {
                              ExamPart.words => '📚',
                              ExamPart.grammar => '📐',
                              ExamPart.sentences => '⌨️',
                            },
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.answer,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                              Text(
                                  it.part == ExamPart.grammar
                                      ? '${it.unit}-unit · ${it.topic}'
                                      : '${it.unit}-unit · ${it.promptUz}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted(context))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Pressable3D(
                color: AppColors.homework,
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExamScreen(
                        uptoUnit: widget.uptoUnit,
                        onlyIds: weak.map((e) => e.id).toSet()),
                  ),
                ),
                child: const Center(
                  child: Text('Zaif bandlarni qayta ishlash',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Pressable3D(
              color: AppColors.brandPurple,
              onPressed: () => Navigator.pop(context, r),
              child: const Center(
                child: Text('Yakunlash',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
        if (passed && !_retake)
          const IgnorePointer(child: ConfettiBurst(count: 160)),
      ],
    );
  }
}

class _PartRow extends StatelessWidget {
  final String icon, label;
  final int n;
  const _PartRow({required this.icon, required this.label, required this.n});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15))),
              Text('$n ta',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandPurple)),
            ],
          ),
        ),
      );
}
