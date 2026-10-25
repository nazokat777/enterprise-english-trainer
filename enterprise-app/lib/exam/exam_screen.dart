import 'package:flutter/material.dart';

import '../drill/drill_screen.dart';
import '../main.dart';
import '../mastery.dart';
import '../reward/confetti.dart';
import '../reward/sfx.dart';
import '../screens/book/type_stage.dart';
import '../theme.dart';
import '../widgets/help_skip.dart';
import '../widgets/pressable3d.dart';
import 'exam.dart';

/// 📝 IMTIHON EKRANI — 1..N unitlar.
///
/// Uch qism ketma-ket, xato band navbat oxiriga; yakunda baho (birinchi
/// urinish), zaif bandlar ro'yxati va "qayta ishlash".
class ExamScreen extends StatefulWidget {
  final int uptoUnit;

  /// Faqat [uptoUnit] ning o'zi - unit oxiridagi imtihon.
  final bool single;

  /// Faqat shu bandlar (qayta ishlash rejimi).
  final Set<String>? onlyIds;

  const ExamScreen(
      {super.key, required this.uptoUnit, this.onlyIds, this.single = false});

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
        .build(widget.uptoUnit, onlyIds: widget.onlyIds, single: widget.single);
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

  /// "Bilmayman": javob ko'rsatiladi, savol xato hisoblanib oxirga qaytadi.
  Future<void> _help() async {
    final it = _cur;
    if (it == null || _result != null) return;
    final q = it.q;
    await showAnswerHelp(context,
        question: q?.prompt ?? it.task?.prompt ?? '',
        answer: it.answer,
        translation: it.promptUz,
        speak: q != null ? englishOf(q) : it.answer);
    if (!mounted || _cur != it) return;
    await _answer(false);
  }

  /// "O'tkazish": xato hisoblanadi, lekin qaytmaydi - imtihon davom etadi.
  Future<void> _skip() async {
    final it = _cur;
    if (it == null || _result != null) return;
    _seen.add(it.id);
    _failed.add(it.id);
    _answered += 1;
    setState(() => _pos += 1);
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
    if (!_retake) {
      await ExamStore.save(progress.currentLevel, r, single: widget.single);
    }
    rewards.onExerciseDone(clean: _failed.isEmpty);
    if (score >= 90) {
      if (!widget.single) rewards.onExamPassed(widget.uptoUnit);
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
        ? 'Xato savollarni qayta ishlash'
        : widget.single
            ? '${widget.uptoUnit}-unit imtihoni'
            : 'Yig\'ma imtihon · 1-${widget.uptoUnit} unitlar';
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
              _retake
                  ? 'Qayta ishlash'
                  : widget.single
                      ? '${widget.uptoUnit}-unit imtihoni'
                      : 'Yig\'ma imtihon: 1-${widget.uptoUnit} unitlar',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 8),
        Text(
          _retake
              ? 'Avval xato qilgan ${p.items.length} ta savol. Xato qilsangiz, '
                  'savol oxirida yana keladi. Bu mashq imtihon natijasini '
                  'o\'zgartirmaydi.'
              : widget.single
                  ? 'Bu imtihon ${widget.uptoUnit}-unitda o\'tilgan narsalarni '
                      'tekshiradi.'
                  : 'Bu imtihon 1-${widget.uptoUnit} unitlarda o\'tilgan hamma '
                      'narsani tekshiradi.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13.5, height: 1.5, color: AppColors.muted(context)),
        ),
        if (widget.single && widget.uptoUnit > 1 && !_retake) ...[
          const SizedBox(height: 6),
          Text(
            'Yodda qolishi uchun 1-${widget.uptoUnit - 1} unitlardan ham ozgina '
            'takror savollar bor.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brandPurple),
          ),
        ],
        if (!_retake) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brandPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              'Baho: birinchi urinishda to\'g\'ri javoblar foizi.\n'
              '90% va undan yuqori - imtihondan o\'tdingiz.\n'
              'Xato qilgan savol oxirida yana so\'raladi.\n'
              'Tugagach xatolaringiz ro\'yxati chiqadi - ularni qayta ishlab '
              'olasiz.',
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: AppColors.muted(context)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _PartRow(
            icon: '📚',
            label: 'Lug\'at',
            hint: 'O\'zbekcha so\'zning inglizchasini tanlang yoki yozing',
            n: p.count(ExamPart.words)),
        _PartRow(
            icon: '📐',
            label: 'Grammatika',
            hint: 'To\'g\'ri variantni tanlang (grammatika mashqlaridan)',
            n: p.count(ExamPart.grammar)),
        _PartRow(
            icon: '⌨️',
            label: 'Gap tuzish va yozish',
            hint: 'So\'zlardan gap tuzing yoki eshitgan gapni yozing',
            n: p.count(ExamPart.sentences)),
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
      ExamPart.words => '📚 Lug\'at: so\'zning inglizchasi',
      ExamPart.grammar => '📐 Grammatika: ${it.topic}',
      ExamPart.sentences => '⌨️ Gap tuzish',
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
              Text('Savol ${_pos + 1} / $total',
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
                  onDone: (ok, {String given = ''}) => _answer(ok),
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
        HelpSkipBar(
          onHelp: _result == null ? _help : null,
          onSkip: _result == null ? _skip : null,
          helpHint: "javob ko'rsatiladi, savol xato hisoblanib oxirida qaytadi",
          skipHint: "savol xato hisoblanadi va qaytmaydi",
        ),
      ],
    );
  }

  Widget _done(BuildContext context) {
    final r = _saved;
    final plan = _plan;
    if (r == null || plan == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Bu unitlar uchun savol topilmadi. Orqaga qaytib, boshqa unitni '
            'tanlang.',
            textAlign: TextAlign.center,
          ),
        ),
      );
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
                  Text(
                      _retake
                          ? 'Qayta ishlash tugadi'
                          : passed
                              ? 'Imtihondan o\'tdingiz!'
                              : 'Hali o\'tmadingiz - o\'tish uchun 90% kerak edi',
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
                      '${r.total} ta savoldan ${_firstTryOk.length} tasiga '
                      'birinchi urinishda to\'g\'ri javob berdingiz · '
                      '${weak.length} ta savolda xato qildingiz',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _retake
                  ? 'Imtihon natijasi o\'zgarmadi.'
                  : 'Imtihon uchun ${passed ? 30 : 10} ball berildi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.muted(context)),
            ),
            const SizedBox(height: 14),
            if (weak.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Text(
                  '✅ Hamma savolga to\'g\'ri javob berdingiz - bu mavzularni yaxshi bilasiz.',
                  style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                ),
              )
            else ...[
              Text('Xato qilgan savollaringiz (${weak.length})',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Shularni hozir qayta ishlab oling, so\'ng imtihonni yana '
                'topshiring. So\'z va gaplar ertaga ham takrorlanadi.',
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
                              // Grammatikada javobning o'zi (masalan "am")
                              // ma'nosiz - savol matni ham ko'rsatiladi.
                              if (it.part == ExamPart.grammar &&
                                  (it.q?.prompt ?? '').isNotEmpty)
                                Text(it.q!.prompt,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.muted(context))),
                              Text('To\'g\'ri javob: ${it.answer}',
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
                  child: Text('Xato savollarni qayta ishlash',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
              ),
              const SizedBox(height: 6),
              Text('Natija o\'zgarmaydi - faqat mashq.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.muted(context))),
            ],
            const SizedBox(height: 10),
            Pressable3D(
              color: AppColors.brandPurple,
              onPressed: () => Navigator.pop(context, r),
              child: const Center(
                child: Text('Tugatish va qaytish',
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

/// Imtihon qismi: nomi, NIMA qilinishi va nechta savol ekani.
class _PartRow extends StatelessWidget {
  final String icon, label, hint;
  final int n;
  const _PartRow(
      {required this.icon,
      required this.label,
      required this.hint,
      required this.n});

  @override
  Widget build(BuildContext context) {
    // Savoli yo'q qism ko'rsatilmaydi ("0 ta savol" chalg'itadi).
    if (n == 0) return const SizedBox.shrink();
    return Padding(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(hint,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.muted(context))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('$n ta savol',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandPurple)),
          ],
        ),
      ),
    );
  }
}
