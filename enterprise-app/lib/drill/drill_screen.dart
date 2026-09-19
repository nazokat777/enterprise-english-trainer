import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../mastery.dart';
import '../services/tts.dart';
import '../theme.dart';
import '../widgets/correct_burst.dart';
import '../widgets/hover_lift.dart';
import '../widgets/pressable3d.dart';
import 'drill_item.dart';
import 'drill_session.dart';

/// TRENING EKRANI — dars 100% bo'lgunicha qo'ymaydigan seans.
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

  /// Moslash o'yinlari uchun hisoblagich — har o'yinda yangi holat.
  int _matchSeq = 0;

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

  /// Moslash o'yini yakunlandi.
  Future<void> _answerMatch(Set<String> clean, int total) async {
    if (clean.length == total) showCorrectBurst(context);
    // Har bir TOPILGAN juft uchun ball — o'yin ham mehnat.
    await progress.addXp(clean.length * 2);
    await _s.answerMatch(clean);
    if (mounted) setState(() => _matchSeq++);
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
        DrillPhase.lesson => 'Fokus · shu dars',
        DrillPhase.mixed => 'Miks · oldingi darslar bilan',
        DrillPhase.done => 'Yakunlandi',
      };

  Widget _body(DrillQuestion q) {
    return Column(
      children: [
        _Header(session: _s),
        Expanded(
          child: switch (q.format) {
            // MOSLASh — o'yin: bir necha juftni birga so'raydi.
            AskFormat.match => _MatchTask(
                key: ValueKey('m${_s.hashCode}$_matchSeq'),
                q: q,
                onDone: _answerMatch,
              ),
            AskFormat.build || AskFormat.listen => BuildTask(
                key: ValueKey('b${q.itemId}${q.format}'),
                q: q,
                locked: _result != null,
                onDone: _answer,
              ),
            _ => ChoiceTask(
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
                child: Text('${session.remaining} ta savol qoldi',
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
                  child: Text('x${session.combo} kombo',
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
class ChoiceTask extends StatefulWidget {
  final DrillQuestion q;
  final bool locked;
  final ValueChanged<bool> onDone;

  const ChoiceTask(
      {super.key,
      required this.q,
      required this.locked,
      required this.onDone});

  @override
  State<ChoiceTask> createState() => _ChoiceTaskState();
}

class _ChoiceTaskState extends State<ChoiceTask> {
  String? _picked;

  void _pick(int i) {
    final q = widget.q;
    if (widget.locked || _picked != null || i >= q.options.length) return;
    setState(() => _picked = q.options[i]);
    widget.onDone(sameAnswer(q.options[i], q.answer));
  }

  /// KLAVIATURA: plitkadagi raqam (1-4) bosilsa o'sha variant.
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final n = int.tryParse(e.character ?? '');
    if (n == null || n < 1 || n > widget.q.options.length) {
      return KeyEventResult.ignored;
    }
    _pick(n - 1);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        DrillCard(
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
                SpeakButton(text: q.speak),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OptionTile(
              index: i,
              text: q.options[i],
              state: _picked == null
                  ? OptionState.idle
                  : sameAnswer(q.options[i], q.answer)
                      ? OptionState.right
                      : q.options[i] == _picked
                          ? OptionState.wrong
                          : OptionState.dim,
              onTap: widget.locked ? null : () => _pick(i),
            ),
          ),
      ],
      ),
    );
  }
}

/// MOSLASh O'YINI — bir necha juftni bir ekranda.
///
/// Nega o'yin kerak: bir xil ko'rinishdagi savollar ketma-ket kelsa
/// diqqat so'nadi. Moslash tez va oson — nafas rostlash, lekin baribir
/// ESLAB AYTISh (chapdagi so'zning ma'nosini topish).
class _MatchTask extends StatefulWidget {
  final DrillQuestion q;

  /// [clean] — birinchi urinishda topilgan juftlar, [total] — jami.
  final void Function(Set<String> clean, int total) onDone;

  const _MatchTask({super.key, required this.q, required this.onDone});

  @override
  State<_MatchTask> createState() => _MatchTaskState();
}

class _MatchTaskState extends State<_MatchTask> {
  final _rnd = Random();
  late List<DrillPair> _left;
  late List<DrillPair> _right;
  final Set<String> _matched = {};
  final Set<String> _failed = {};
  String? _sel;
  String? _wrongFlash;
  Timer? _end;

  @override
  void initState() {
    super.initState();
    _left = List.of(widget.q.pairs)..shuffle(_rnd);
    _right = List.of(widget.q.pairs)..shuffle(_rnd);
  }

  @override
  void dispose() {
    _end?.cancel();
    super.dispose();
  }

  void _tapRight(DrillPair r) {
    final sel = _sel;
    if (sel == null || _matched.contains(r.itemId)) return;
    if (sel == r.itemId) {
      setState(() {
        _matched.add(r.itemId);
        _sel = null;
      });
      Tts.instance.speak(r.en, id: r.itemId);
      if (_matched.length == widget.q.pairs.length) {
        _end = Timer(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          final clean = _matched.difference(_failed);
          widget.onDone(clean, widget.q.pairs.length);
        });
      }
    } else {
      // Xato TANLANGAN so'zga yoziladi — o'quvchi aynan uning
      // ma'nosini bilmayapti.
      setState(() {
        _failed.add(sel);
        _wrongFlash = r.itemId;
      });
      Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _wrongFlash = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Row(
          children: [
            const Icon(Icons.extension_rounded,
                size: 18, color: AppColors.brandPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.q.prompt,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final p in _left)
                    _tile(
                      label: p.en,
                      done: _matched.contains(p.itemId),
                      selected: _sel == p.itemId,
                      onTap: () {
                        if (_matched.contains(p.itemId)) return;
                        setState(() => _sel = p.itemId);
                        Tts.instance.speak(p.en, id: p.itemId);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  for (final p in _right)
                    _tile(
                      label: p.uz,
                      done: _matched.contains(p.itemId),
                      wrong: _wrongFlash == p.itemId,
                      onTap: () => _tapRight(p),
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
    required bool done,
    bool selected = false,
    bool wrong = false,
    VoidCallback? onTap,
  }) {
    final color = done
        ? AppColors.success.withValues(alpha: 0.14)
        : wrong
            ? AppColors.danger.withValues(alpha: 0.16)
            : selected
                ? AppColors.brandPurple.withValues(alpha: 0.16)
                : Theme.of(context).colorScheme.surface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: done ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: done ? AppColors.success : null)),
          ),
        ),
      ),
    );
  }
}

/// HARFLAB YOZISh — o'zbekcha savol, inglizchani harflardan yig'ish.
///
/// Egasining talabi: "lug'atni ko'proq o'zbekchada so'rasin, user o'zi
/// inglizcha harflab yozsin, shunda yodlanadi". Bu eng mustahkam
/// bosqich: tanish emas, ISHLAB ChIQARISh.
class BuildTask extends StatefulWidget {
  final DrillQuestion q;
  final bool locked;
  final ValueChanged<bool> onDone;

  const BuildTask(
      {super.key,
      required this.q,
      required this.locked,
      required this.onDone});

  @override
  State<BuildTask> createState() => _BuildTaskState();
}

class _BuildTaskState extends State<BuildTask> {
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
      final ok = sameAnswer(_built, widget.q.answer);
      setState(() => _ok = ok);
      widget.onDone(ok);
    }
  }

  /// KLAVIATURA: kompyuterda harf bosilsa mos (hali olinmagan) plitka
  /// tanlanadi; Backspace - orqaga. So'zlardan yig'ishda (bo'shliqli
  /// javob) plitka so'z bo'ladi - birinchi harfi bilan tanlanadi.
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent || widget.locked || _ok != null) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      if (_picked.isNotEmpty) setState(_picked.removeLast);
      return KeyEventResult.handled;
    }
    final ch = e.character?.toLowerCase();
    if (ch == null || ch.isEmpty) return KeyEventResult.ignored;
    for (var i = 0; i < _tiles.length; i++) {
      if (_picked.contains(i)) continue;
      final t = _tiles[i].toLowerCase();
      if (t == ch || (t.length > 1 && t.startsWith(ch))) {
        _tap(i);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final border = _ok == null
        ? Colors.black26
        : (_ok! ? AppColors.success : AppColors.danger);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        DrillCard(
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
                SpeakButton(text: q.speak),
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
                    // widthFactor: Center Wrap ichida butun kenglikni
                    // egallab olmasin - plitka matn kengligida.
                    child: Center(
                      widthFactor: 1,
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
      ),
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
          child: Text('Trening yakunlandi',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Shu seansdagi savollar 100% to\'g\'ri javob berildi.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, height: 1.5, color: AppColors.muted(context)),
          ),
        ),
        const SizedBox(height: 18),
        // BUTUN dars qancha qolgani — o'quvchi yo'lni ko'rsin.
        // Seans qisqa, lekin dars 100% gacha davom etadi.
        _LessonBar(value: session.lessonProgress),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.coin.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text('Eng uzun kombo: x${session.bestCombo}',
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

/// Butun darsning o\'zlashtirilishi — seans oxiridagi yo\'l xaritasi.
class _LessonBar extends StatelessWidget {
  final double value;
  const _LessonBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Column(
      children: [
        Text('Dars progressi: $pct%',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            backgroundColor: AppColors.brandPurple.withValues(alpha: 0.15),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.brandPurple),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          pct >= 100
              ? 'Bu dars 100% — ajoyib natija.'
              : 'Keyingi seansda qolgan savollar keladi.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppColors.muted(context)),
        ),
      ],
    );
  }
}

class DrillCard extends StatelessWidget {
  final Widget child;
  const DrillCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: AppShadow.card(context),
        ),
        child: child,
      );
}

class SpeakButton extends StatelessWidget {
  final String text;
  const SpeakButton({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          shape: BoxShape.circle,
          boxShadow: AppShadow.glow(AppColors.brandIndigo, alpha: 0.4),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Tts.instance.speak(text, id: text),
            child: const SizedBox(
              width: 56,
              height: 56,
              child: Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
      );
}

/// Javoblarni solishtirish — bosh harf va ortiqcha bo'shliq muhim emas.
bool sameAnswer(String a, String b) =>
    a.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ==
    b.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');


enum OptionState { idle, right, wrong, dim }

/// JAVOB PLITKASI — raqamli belgi (1-4), katta matn, hover'da ko'tariladi;
/// to'g'ri — yashil gradient + belgi, xato — qizil, qolganlari xiralashadi.
class OptionTile extends StatelessWidget {
  final int index;
  final String text;
  final OptionState state;
  final VoidCallback? onTap;
  const OptionTile({
    super.key,
    required this.index,
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surface(context);
    final (Color bg, Color fg, Color border) = switch (state) {
      OptionState.idle => (surface, Theme.of(context).textTheme.bodyLarge!.color!, AppColors.border(context)),
      OptionState.right => (AppColors.success, Colors.white, AppColors.success),
      OptionState.wrong => (AppColors.danger, Colors.white, AppColors.danger),
      OptionState.dim => (surface, AppColors.muted(context), AppColors.border(context)),
    };
    final badgeBg = switch (state) {
      OptionState.idle => AppColors.brandPurple.withValues(alpha: 0.12),
      OptionState.dim => AppColors.border(context),
      _ => Colors.white.withValues(alpha: 0.25),
    };
    final badgeFg = switch (state) {
      OptionState.idle => AppColors.brandPurple,
      OptionState.dim => AppColors.muted(context),
      _ => Colors.white,
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: state == OptionState.dim ? 0.55 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        scale: state == OptionState.right ? 1.02 : (state == OptionState.wrong ? 0.98 : 1),
        child: HoverLift(
          enabled: onTap != null,
          hoverScale: 1.01,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: border, width: 1.5),
              boxShadow: state == OptionState.idle
                  ? AppShadow.card(context)
                  : state == OptionState.right
                      ? AppShadow.glow(AppColors.success, alpha: 0.45)
                      : const [],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: state == OptionState.right
                              ? Icon(Icons.check_rounded, size: 18, color: badgeFg)
                              : state == OptionState.wrong
                                  ? Icon(Icons.close_rounded, size: 18, color: badgeFg)
                                  : Text('${index + 1}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: badgeFg)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(text,
                            style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                                color: fg)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
