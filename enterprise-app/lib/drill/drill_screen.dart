import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../mastery.dart';
import '../services/tts.dart';
import '../theme.dart';
import '../widgets/correct_burst.dart';
import '../widgets/pressable3d.dart';
import 'drill_item.dart';
import 'drill_session.dart';

/// DARS USTASI EKRANI — darsni o'zlashtirgunicha qo'ymaydigan seans.
///
/// Ikki bosqich: avval shu dars 100% gacha, so'ng oldingi darslar
/// aralashtirilib yana 100% gacha (`DrillSession`).
///
/// Zerikmaslik uchun (nevrologiya nuqtai nazaridan):
/// * savol KO'RINIShI almashib turadi — bir xillik dopaminni o'ldiradi;
/// * ketma-ket to'g'ri javoblar KOMBO hosil qiladi va ko'rinadi;
/// * halqa har javobda oldinga siljiydi — mehnat natijasi darhol
///   ko'rinsin;
/// * xato JAZO emas: "yana bir marta" deb qaytadi, ball olib
///   qo'yilmaydi.
class DrillScreen extends StatefulWidget {
  final String title;
  final List<DrillSource> lessonSources;
  final List<DrillSource> earlierSources;

  const DrillScreen({
    super.key,
    required this.title,
    required this.lessonSources,
    this.earlierSources = const [],
  });

  @override
  State<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends State<DrillScreen> {
  late final DrillSession _s;
  Timer? _next;

  /// Oxirgi javob to'g'ri edimi (null = hali javob berilmagan).
  bool? _result;

  @override
  void initState() {
    super.initState();
    _s = DrillSession(
      mastery: mastery,
      lessonSources: widget.lessonSources,
      earlierSources: widget.earlierSources,
    );
  }

  @override
  void dispose() {
    _next?.cancel();
    Tts.instance.stop();
    super.dispose();
  }

  Future<void> _answer(bool ok) async {
    if (_result != null) return; // ikki marta bosilmasin
    setState(() => _result = ok);
    if (ok) {
      showCorrectBurst(context);
      // Kombo o'sgan sari ko'proq ball — "yana bitta" hissi.
      final bonus = 2 + (_s.combo ~/ 5);
      await progress.addXp(bonus);
    }
    _next = Timer(Duration(milliseconds: ok ? 700 : 1400), () async {
      await _s.answer(ok);
      if (mounted) setState(() => _result = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _s.current;
    final done = _s.phase == DrillPhase.done || q == null;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16)),
            Text(_phaseLabel(),
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandPurple)),
          ],
        ),
      ),
      body: SafeArea(
        child: done ? _Finished(session: _s) : _body(q),
      ),
    );
  }

  String _phaseLabel() => switch (_s.phase) {
        DrillPhase.lesson => 'Shu dars — o\'zlashtirgunicha',
        DrillPhase.mixed => 'Aralash takror — oldingi darslar bilan',
        DrillPhase.done => 'Tugadi',
      };

  Widget _body(DrillQuestion q) {
    return Column(
      children: [
        _Header(session: _s),
        Expanded(
          child: switch (q.format) {
            AskFormat.build || AskFormat.listen => _BuildTask(
                key: ValueKey('b${q.itemId}${q.format}'),
                q: q,
                locked: _result != null,
                onDone: _answer,
              ),
            _ => _ChoiceTask(
                key: ValueKey('c${q.itemId}${q.format}'),
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

/// Yuqori panel: halqa, kombo, qolgan bandlar.
class _Header extends StatelessWidget {
  final DrillSession session;
  const _Header({required this.session});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: session.progress,
              minHeight: 8,
              backgroundColor: AppColors.success.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${(session.progress * 100).round()}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.success)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${session.remaining} ta band qoldi',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.muted(context))),
              ),
              if (session.combo >= 2)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.coin.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('${session.combo} ketma-ket',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.homework)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Variantdan tanlash (choice / produce / cloze).
class _ChoiceTask extends StatefulWidget {
  final DrillQuestion q;
  final bool locked;
  final ValueChanged<bool> onDone;

  const _ChoiceTask(
      {super.key,
      required this.q,
      required this.locked,
      required this.onDone});

  @override
  State<_ChoiceTask> createState() => _ChoiceTaskState();
}

class _ChoiceTaskState extends State<_ChoiceTask> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _Card(
          child: Column(
            children: [
              Text(q.prompt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: q.prompt.length > 40 ? 17 : 24,
                      fontWeight: FontWeight.w800,
                      height: 1.35)),
              if (q.promptUz.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(q.promptUz,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13.5, color: AppColors.muted(context))),
              ],
              if (q.speak.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Speak(text: q.speak),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final o in q.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Pressable3D(
              color: _color(o),
              onPressed: widget.locked
                  ? null
                  : () {
                      setState(() => _picked = o);
                      widget.onDone(_same(o, q.answer));
                    },
              child: Center(
                child: Text(o,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _picked == o ? Colors.white : null)),
              ),
            ),
          ),
      ],
    );
  }

  Color _color(String o) {
    if (_picked != o) return Theme.of(context).colorScheme.surface;
    return _same(o, widget.q.answer) ? AppColors.success : AppColors.danger;
  }
}

/// HARFLAB YOZISh — o'zbekcha savol, inglizchani harflardan yig'ish.
///
/// Egasining talabi: "lug'atni ko'proq o'zbekchada so'rasin, user o'zi
/// inglizcha harflab yozsin, shunda yodlanadi". Bu eng mustahkam
/// bosqich: tanish emas, ISHLAB ChIQARISh.
class _BuildTask extends StatefulWidget {
  final DrillQuestion q;
  final bool locked;
  final ValueChanged<bool> onDone;

  const _BuildTask(
      {super.key,
      required this.q,
      required this.locked,
      required this.onDone});

  @override
  State<_BuildTask> createState() => _BuildTaskState();
}

class _BuildTaskState extends State<_BuildTask> {
  final _rnd = Random();
  late List<String> _tiles;
  final List<int> _picked = [];
  bool? _ok;

  @override
  void initState() {
    super.initState();
    final target = widget.q.pieces;
    final t = List.of(target)..shuffle(_rnd);
    if (t.join() == target.join() && target.length > 1) t.shuffle(_rnd);
    _tiles = t;
    if (widget.q.format == AskFormat.listen) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => Tts.instance.speak(widget.q.speak, id: widget.q.itemId));
    }
  }

  String get _built => _picked.map((i) => _tiles[i]).join(
      widget.q.pieces.length > 1 && widget.q.answer.contains(' ') ? ' ' : '');

  void _tap(int i) {
    if (widget.locked || _ok != null || _picked.contains(i)) return;
    setState(() => _picked.add(i));
    if (_picked.length == _tiles.length) {
      final ok = _same(_built, widget.q.answer);
      setState(() => _ok = ok);
      widget.onDone(ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final border = _ok == null
        ? Colors.black26
        : (_ok! ? AppColors.success : AppColors.danger);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _Card(
          child: Column(
            children: [
              Text(
                  q.format == AskFormat.listen
                      ? 'Eshiting va yozing'
                      : 'Inglizchasini harflab yozing',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.muted(context))),
              const SizedBox(height: 8),
              // SAVOL O'ZBEKChA — javob inglizcha yoziladi.
              Text(q.format == AskFormat.listen ? q.promptUz : q.prompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800)),
              if (q.speak.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Speak(text: q.speak),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border, width: 2),
          ),
          child: Text(_built.isEmpty ? '. . .' : _built,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 2)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          child: _picked.isEmpty || _ok != null
              ? const SizedBox()
              : Center(
                  child: TextButton.icon(
                    onPressed: () => setState(_picked.removeLast),
                    icon: const Icon(Icons.backspace_outlined, size: 18),
                    label: const Text('Orqaga'),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _tiles.length; i++)
              GestureDetector(
                onTap: () => _tap(i),
                child: AnimatedOpacity(
                  opacity: _picked.contains(i) ? 0.25 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 48),
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color:
                              AppColors.brandPurple.withValues(alpha: 0.35),
                          width: 1.5),
                    ),
                    child: Center(
                      child: Text(_tiles[i],
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_ok == false) ...[
          const SizedBox(height: 14),
          Center(
            child: Text('To\'g\'risi: ${widget.q.answer}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger)),
          ),
        ],
      ],
    );
  }
}

/// Seans tugadi — natija va rag'bat.
class _Finished extends StatelessWidget {
  final DrillSession session;
  const _Finished({required this.session});

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
        const Center(
          child: Text('Dars o\'zlashtirildi',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Hamma band 100% to\'g\'ri javob berildi — shu dars ham, '
            'oldingi darslar bilan aralash takror ham.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, height: 1.5, color: AppColors.muted(context)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.coin.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text('Eng uzun ketma-ketlik: ${session.bestCombo}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 24),
        Pressable3D(
          color: AppColors.brandPurple,
          onPressed: () => Navigator.pop(context),
          child: const Center(
            child: Text('Yakunlash',
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

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: child,
      );
}

class _Speak extends StatelessWidget {
  final String text;
  const _Speak({required this.text});

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.actionBlue,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Tts.instance.speak(text, id: text),
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
          ),
        ),
      );
}

/// Javoblarni solishtirish — bosh harf va ortiqcha bo'shliq muhim emas.
bool _same(String a, String b) =>
    a.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ==
    b.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
