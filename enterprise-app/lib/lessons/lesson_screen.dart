import 'dart:async';

import 'package:flutter/material.dart';

import '../drill/drill_item.dart';
import '../drill/drill_screen.dart';
import '../main.dart';
import '../mastery.dart';
import '../services/tts.dart';
import '../theme.dart';
import '../widgets/correct_burst.dart';
import '../widgets/pressable3d.dart';
import 'lesson_session.dart';
import 'word_lesson.dart';

/// SO'Z DARSI EKRANI — Duolingo uslubi.
///
/// Uch bosqich:
///   1) TANIShUV — har so'z kartada: inglizcha, ovoz, o'zbekcha, misol.
///      Avval so'raladigan narsa KO'RSATILADI. Ilgari shu bosqich yo'q
///      edi va o'quvchi hech ko'rmagan so'zni topishga majbur edi.
///   2) SAVOLLAR — tanish -> tanlash -> harflab yozish; xato qaytadi.
///   3) YaKUN — natija va keyingi darsga yo'l.
class LessonScreen extends StatefulWidget {
  final WordLesson lesson;
  final String unitLabel;
  final List<DrillSource> pool;

  const LessonScreen({
    super.key,
    required this.lesson,
    required this.unitLabel,
    this.pool = const [],
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

enum _Stage { intro, quiz, done }

class _LessonScreenState extends State<LessonScreen> {
  _Stage _stage = _Stage.intro;
  int _card = 0;
  late final LessonSession _s;
  Timer? _next;
  bool? _result;

  @override
  void initState() {
    super.initState();
    _s = LessonSession(
      lesson: widget.lesson,
      mastery: mastery,
      pool: widget.pool,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCard());
  }

  @override
  void dispose() {
    _next?.cancel();
    Tts.instance.stop();
    super.dispose();
  }

  void _speakCard() {
    if (_stage != _Stage.intro) return;
    final w = widget.lesson.words[_card];
    Tts.instance.speak(w.en, id: w.itemId);
  }

  void _nextCard() {
    if (_card + 1 < widget.lesson.words.length) {
      setState(() => _card += 1);
      _speakCard();
    } else {
      Tts.instance.stop();
      setState(() => _stage = _s.isDone ? _Stage.done : _Stage.quiz);
    }
  }

  Future<void> _answer(bool ok) async {
    if (_result != null) return;
    setState(() => _result = ok);
    final bonus = rewards.onAnswer(ok, baseXp: 2);
    if (ok) {
      showCorrectBurst(context);
      await progress.addXp(2 + bonus);
    }
    _next = Timer(Duration(milliseconds: ok ? 650 : 1400), () async {
      await _s.answer(ok);
      if (!mounted) return;
      setState(() {
        _result = null;
        if (_s.isDone) _stage = _Stage.done;
      });
      if (_s.isDone) {
        await progress.addXp(5);
        rewards.onExerciseDone(clean: true);
        // Dars tugadi = darsdagi so'zlar o'rganildi (kunlik topshiriq).
        rewards.onWordLearned(_s.lesson.sources.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.unitLabel} · ${l.index}-dars',
                style: const TextStyle(fontSize: 16)),
            Text(_stageLabel(),
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandPurple)),
          ],
        ),
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.intro => _intro(context),
          _Stage.quiz => _quiz(context),
          _Stage.done => _Finished(
              lesson: l,
              mistakes: _s.mistakes,
              onClose: () => Navigator.pop(context, true),
            ),
        },
      ),
    );
  }

  String _stageLabel() => switch (_stage) {
        _Stage.intro =>
          'Tanishuv · ${_card + 1}/${widget.lesson.words.length}',
        _Stage.quiz => switch (_s.round) {
            1 => '1-bosqich · ma\'nosini tanlang',
            2 => '2-bosqich · inglizchasini tanlang',
            _ => '3-bosqich · harflab yozing',
          },
        _Stage.done => 'Yakunlandi',
      };

  // ───────────── 1) Tanishuv ─────────────
  Widget _intro(BuildContext context) {
    final words = widget.lesson.words;
    final w = words[_card];
    return Column(
      children: [
        _Bar(value: (_card + 1) / words.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: AppColors.brandPurple.withValues(alpha: 0.25),
                      width: 1.5),
                ),
                child: Column(
                  children: [
                    Text('YANGI SO\'Z',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.muted(context))),
                    const SizedBox(height: 12),
                    Text(w.en,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.2)),
                    const SizedBox(height: 14),
                    SpeakButton(text: w.en),
                    const SizedBox(height: 18),
                    Text(w.uz,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandPurple,
                            height: 1.3)),
                    if (w.exampleEn.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Divider(color: AppColors.muted(context).withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(w.exampleEn,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.4)),
                      if (w.exampleUz.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(w.exampleUz,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: AppColors.muted(context))),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Darsdagi hamma so'z bir qarashda — "yana nechta qoldi".
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < words.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: i <= _card
                            ? AppColors.brandPurple.withValues(alpha: 0.14)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(words[i].en,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: i <= _card
                                  ? AppColors.brandPurple
                                  : AppColors.muted(context))),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Pressable3D(
            color: AppColors.success,
            onPressed: _nextCard,
            child: Center(
              child: Text(
                  _card + 1 < words.length ? 'Keyingi so\'z' : 'Mashqni boshlash',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────── 2) Savollar ─────────────
  Widget _quiz(BuildContext context) {
    final q = _s.current!;
    return Column(
      children: [
        _Bar(value: _s.progress),
        Expanded(
          child: switch (q.format) {
            AskFormat.build || AskFormat.listen => BuildTask(
                key: ValueKey('b${q.itemId}${q.format}${_s.remaining}'),
                q: q,
                locked: _result != null,
                onDone: _answer,
              ),
            _ => ChoiceTask(
                key: ValueKey('c${q.itemId}${q.format}${_s.remaining}'),
                q: q,
                locked: _result != null,
                onDone: _answer,
              ),
          },
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  const _Bar({required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: AppColors.brandPurple.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
          ),
        ),
      );
}

/// Dars tugadi.
class _Finished extends StatelessWidget {
  final WordLesson lesson;
  final int mistakes;
  final VoidCallback onClose;
  const _Finished(
      {required this.lesson, required this.mistakes, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 20),
        const Center(
          child: Icon(Icons.workspace_premium_rounded,
              size: 96, color: AppColors.success),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('${lesson.index}-dars tugadi',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            mistakes == 0
                ? '${lesson.words.length} ta so\'z — birorta xatosiz!'
                : '${lesson.words.length} ta so\'z o\'rganildi. $mistakes ta xato — ular qayta so\'raldi.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13.5, height: 1.5, color: AppColors.muted(context)),
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final w in lesson.words)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text('${w.en} — ${w.uz}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        const SizedBox(height: 26),
        Pressable3D(
          color: AppColors.brandPurple,
          onPressed: onClose,
          child: const Center(
            child: Text('Davom etish',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
