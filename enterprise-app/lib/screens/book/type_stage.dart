import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../book_content.dart';
import '../../reward/reward_widgets.dart';
import '../../services/tts.dart';
import '../../teach/clarify.dart';
import '../../teach/explain_card.dart';
import '../../teach/question_card.dart';
import '../../teach/vocab_lookup.dart';
import '../../theme.dart';
import '../../widgets/correct_burst.dart';
import 'exercise_player.dart' show ExplanationCard, AudioNoteCard;
import '../../widgets/pressable3d.dart';
import '../pack/pack_flow.dart' show RoundPlay;

// ═══════════════ Yozish (diktant, harfma-harf) ═══════════════
/// Gapni KLAVIATURADA yozish. Bo'laklardan yig'ishda so'zlar tayyor
/// turadi — o'quvchi faqat tartibni topadi; bu yerda esa har harfni
/// o'zi eslaydi (to'liq eslab chiqarish = eng kuchli yodlash).
/// Xato bo'lsa, qaysi belgi noto'g'riligi rang bilan ko'rsatiladi.
class TypeStage extends StatefulWidget {
  final ExTask task;
  final String explanation;
  final String audioNote;
  final void Function(bool ok, {String given}) onDone;

  /// Kitob ko'rsatmasi va manzili - "nima qilinadi" qatori uchun.
  final String instructionUz;
  final String source;
  final VoidCallback? onNearMiss;
  final bool golden;

  const TypeStage({
    super.key,
    required this.task,
    required this.explanation,
    this.audioNote = '',
    required this.onDone,
    this.instructionUz = '',
    this.source = '',
    this.onNearMiss,
    this.golden = false,
  });

  @override
  State<TypeStage> createState() => _TypeStageState();
}

class _TypeStageState extends State<TypeStage> {
  final _c = TextEditingController();
  final _focus = FocusNode();
  final _rnd = Random();
  bool? _result;
  bool _near = false;
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    // Avval eshitiladi, keyin yoziladi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.task.canSpeak) {
        Tts.instance.speak(widget.task.speakText, id: 'ex');
      }
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _advance?.cancel();
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  static int editDistance(String a, String b) {
    if (a == b) return 0;
    final m = a.length, n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;
    var prev = List<int>.generate(n + 1, (j) => j);
    for (var i = 1; i <= m; i++) {
      final cur = List<int>.filled(n + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      prev = cur;
    }
    return prev[n];
  }

  void _check() {
    if (_result != null) return;
    final given = _c.text.trim();
    if (given.isEmpty) return;
    final ok = widget.task.isCorrect(given);
    final near = !ok &&
        widget.onNearMiss != null &&
        editDistance(given.toLowerCase(), widget.task.answer.toLowerCase()) <= 1;
    setState(() {
      _result = ok;
      _near = near;
    });
    if (ok) showCorrectBurst(context, text: cheer(_rnd));
    Tts.instance.speak(widget.task.speakAnswer, id: 'ex');
    _advance = Timer(Duration(milliseconds: ok ? 950 : 2600), () {
      if (!mounted) return;
      if (near) {
        widget.onNearMiss!();
      } else {
        widget.onDone(ok, given: given);
      }
    });
  }

  /// Xato bo'lganda: to'g'ri javob, mos kelmagan belgilar qizil.
  Widget _diff(BuildContext context) {
    final a = widget.task.answer;
    final g = _c.text.trim();
    final spans = <TextSpan>[];
    for (var i = 0; i < a.length; i++) {
      final same = i < g.length && g[i].toLowerCase() == a[i].toLowerCase();
      spans.add(TextSpan(
        text: a[i],
        style: TextStyle(
          color: same ? AppColors.success : AppColors.danger,
          fontWeight: FontWeight.w800,
          decoration: same ? null : TextDecoration.underline,
        ),
      ));
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 17, height: 1.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final border = _result == null
        ? Colors.black26
        : _result!
            ? AppColors.success
            : AppColors.danger;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        QuestionCard(
          question: clarify(widget.task,
                  kind: ExKind.text, instructionUz: widget.instructionUz)
              .question,
          source: widget.source,
        ),
        ExplanationCard(text: widget.explanation),
        AudioNoteCard(text: widget.audioNote),
        if (widget.golden) const GoldenBanner(),
        if (_near) const NearMissNote(),
        Center(
          child: Text(
            t.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, height: 1.4, fontWeight: FontWeight.w800),
          ),
        ),
        if (t.promptUz.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              t.promptUz,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, height: 1.35, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        if (t.canSpeak) ...[
          const SizedBox(height: 14),
          Center(child: RoundPlay(text: t.speakText, size: 48)),
        ],
        const SizedBox(height: 18),
        TextField(
          controller: _c,
          focusNode: _focus,
          enabled: _result == null,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _check(),
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Inglizcha yozing...',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: border, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: Colors.black26, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: border, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
                  const BorderSide(color: AppColors.brandPurple, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_result == false) ...[
          Text('To\'g\'risi:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
          const SizedBox(height: 4),
          _diff(context),
          // NEGA xato bo'lgani - qoida bilan (artikl, -s, tartib...).
          ExplainCard.forAnswer(
            correct: widget.task.answer,
            given: _c.text.trim(),
            whyUz: widget.task.whyUz,
            ruleUz: widget.explanation,
            uz: widget.task.uz.isNotEmpty
                ? widget.task.uz
                : widget.task.promptUz,
            lookup: meaningOf,
            isCorrect: false,
          ),
        ] else if (_result == null)
          Pressable3D(
            color: AppColors.actionBlue,
            onPressed: _c.text.trim().isEmpty ? null : _check,
            enabled: _c.text.trim().isNotEmpty,
            child: const Center(
              child: Text('Tekshirish',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          ),
        if (_result == null && t.whyUz.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(t.whyUz,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.muted(context))),
        ],
      ],
    );
  }
}

/// O'qish mashqidan YODLASh mashqini yasaydi: har satr avval so'zlardan
/// yig'iladi (tartib), so'ng klaviaturada harfma-harf yoziladi
/// (imlo + to'liq eslash). Ikkala bosqichda ham ovoz va o'zbekchasi bor.
BookExercise memorizeExerciseFrom(BookExercise study) {
  final lines = [
    for (final t in study.tasks)
      if (t.en.trim().isNotEmpty) t,
  ];
  final tasks = <ExTask>[
    for (final t in lines)
      ExTask(
        prompt: '🔊 Tinglang va so\'zlardan gap tuzing',
        promptUz: t.uz,
        answer: t.en.trim(),
        speak: t.en.trim(),
        speakAnswer: t.en.trim(),
      ),
    for (final t in lines)
      ExTask(
        prompt: '⌨️ Tinglang va o\'zingiz yozing',
        promptUz: t.uz,
        answer: t.en.trim(),
        speak: t.en.trim(),
        speakAnswer: t.en.trim(),
        typed: true,
      ),
  ];
  return BookExercise(
    ref: study.ref,
    kind: ExKind.text,
    tasks: tasks,
    instructionEn: 'Listen, build, then type each sentence.',
    instructionUz: 'Avval so\'zlardan yig\'ing, so\'ng o\'zingiz yozing. '
        'Xato bo\'lsa qaytadi - hammasi to\'g\'ri bo\'lguncha.',
    book: study.book,
    bookPage: study.bookPage,
    pageLabel: study.pageLabel,
  );
}
