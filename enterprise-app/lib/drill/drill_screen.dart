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
import '../widgets/help_skip.dart';
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

  /// Yakuniy ekrandagi foiz nimaning foizi ekani ("Butun unit (bob)
  /// bo'yicha yodlanganlik"). Qiyin mavzu mashqida boshqacha yoziladi.
  final String progressLabel;

  const DrillScreen({
    super.key,
    required this.title,
    required this.lessonSources,
    this.earlierSources = const [],
    this.progressLabel = "Butun unit (bob) bo'yicha yodlanganlik",
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

  /// "Bilmayman": javob tarjimasi va ovozi bilan; band xato bo'lib qaytadi.
  /// "O'tkazish": ko'rsatmasdan o'tadi (band baribir keyin qaytadi).
  Future<void> _giveUp({required bool show}) async {
    final q = _s.current;
    if (q == null || _result != null) return;
    if (show) {
      await showAnswerHelp(context,
          question: q.prompt,
          answer: q.answer,
          translation: q.promptUz == q.prompt ? '' : q.promptUz,
          speak: englishOf(q));
    }
    if (!mounted || _s.current != q) return;
    await _s.answer(false);
    if (mounted) setState(() {});
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
        child: done
            ? _Finished(session: _s, progressLabel: widget.progressLabel)
            : _body(q),
      ),
    );
  }

  /// Ikki qism bor: avval shu mavzu, keyin oldingi mavzular aralash.
  /// Oldingi mavzu bo'lmasa faqat bitta qism - "1/2" yozilmaydi.
  String _phaseLabel() {
    final two = widget.earlierSources.isNotEmpty;
    return switch (_s.phase) {
      DrillPhase.lesson =>
        '${two ? '1/2 · ' : ''}Shu mavzuning savollari',
      DrillPhase.mixed => '2/2 · Oldingi mavzular aralash',
      DrillPhase.done => 'Tugadi',
    };
  }

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
        if (q.format != AskFormat.match)
          HelpSkipBar(
            onHelp: _result == null ? () => _giveUp(show: true) : null,
            onSkip: _result == null ? () => _giveUp(show: false) : null,
            skipHint: "savolni o'tkazadi, u keyinroq yana so'raladi",
          ),
      ],
    );
  }
}

/// Savoldagi INGLIZCHA matn (yordam ovozi uchun): tanishda savolning
/// o'zi, boshqa shakllarda javob.
String englishOf(DrillQuestion q) {
  if (q.speak.trim().isNotEmpty) return q.speak;
  return q.format == AskFormat.choice ? q.prompt : q.answer;
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
              // Bitta matn: tor ekranda ham o'raladi, sig'maslik bo'lmaydi.
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${(session.progress * 100).round()}% yodlandi',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.success),
                      ),
                      TextSpan(
                        text: ' · yana ${session.remaining} ta savol qoldi',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.muted(context)),
                      ),
                    ],
                  ),
                ),
              ),
              if (session.combo >= 2)
                Tooltip(
                  message: "Ketma-ket to'g'ri javoblar soni. "
                      "Xato qilsangiz, qaytadan boshlanadi.",
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.coin.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text("ketma-ket to'g'ri: ${session.combo}",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.homework)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          // Trening nima ekani - o'quvchi "qachon tugaydi?" deb o'ylamasin.
          Text(
            "Hamma savolga to'g'ri javob bergunicha davom etadi. "
            "Xato savol keyinroq qaytadi.",
            style: TextStyle(
                fontSize: 11.5, height: 1.3, color: AppColors.muted(context)),
          ),
        ],
      ),
    );
  }
}

/// SAVOL SHAKLIGA QARAB BIR QATORLI KO'RSATMA.
///
/// Ilgari yagona ko'rsatma ilova panelidagi mayda binafsha yozuv edi;
/// o'quvchi savol kartasiga qarab "tarjima qilamanmi, yozamanmi,
/// tanlaymanmi?" deb taxmin qilardi. Endi har savol kartasining O'ZIDA
/// qalin qator chiqadi (`InstructionLine`).
///
/// [bookQuestion] - kitob mashqidan olingan savol (tarjima jufti emas):
/// unda "ma'nosini tanlang" noto'g'ri bo'lardi.
String instructionFor(AskFormat format, {bool bookQuestion = false}) =>
    switch (format) {
      AskFormat.choice => bookQuestion
          ? "To'g'ri javobni tanlang"
          : "Quyidagi so'zning o'zbekcha ma'nosini tanlang",
      AskFormat.produce => "O'zbekchasiga mos inglizcha so'zni tanlang",
      AskFormat.cloze => "Gapdagi bo'sh joyga mos so'zni tanlang",
      AskFormat.build => "Harflarni to'g'ri tartibda bosib so'zni yig'ing",
      AskFormat.listen => "Eshiting va eshitganingizni yig'ing",
      AskFormat.match =>
        "Avval chapdan inglizcha so'zni, keyin o'ngdan uning o'zbekcha "
            "ma'nosini bosing",
      AskFormat.speak => "So'zni inglizcha ovoz chiqarib ayting",
    };

/// Gapdagi bo'shliq belgisi bormi (`kBlank` yoki `___`).
bool hasBlank(String s) => s.contains('___');

/// Aniq savol uchun ko'rsatma: shakldan tashqari savolning ichki
/// tuzilishiga ham qaraydi (bo'shliqli gap, so'z-so'z yig'ish...).
String instructionOf(DrillQuestion q) {
  final gap = hasBlank(q.prompt);
  // Javobda bo'shliq bo'lsa plitkalar - butun so'zlar (gap tuzish).
  final words = q.answer.trim().contains(' ');
  switch (q.format) {
    case AskFormat.choice:
      // Tarjima juftida savol bilan birga ovoz tugmasi ham bor.
      if (q.speak.isNotEmpty) return instructionFor(AskFormat.choice);
      return gap
          ? instructionFor(AskFormat.cloze)
          : instructionFor(AskFormat.choice, bookQuestion: true);
    case AskFormat.build:
      if (words) {
        return gap
            ? "Bo'sh joyga mos so'zlarni to'g'ri tartibda bosing"
            : "So'zlarni to'g'ri tartibda bosib gapni tuzing";
      }
      return gap
          ? "Bo'sh joyga mos so'zni harflardan yig'ing"
          : "Harflarni to'g'ri tartibda bosib inglizchasini yig'ing";
    case AskFormat.listen:
      return words
          ? "Eshiting va eshitganingizni so'zlardan yig'ing"
          : "Eshiting va eshitganingizni harflardan yig'ing";
    default:
      return instructionFor(q.format);
  }
}

/// Savol kartasining tepasidagi ko'rsatma qatori - qalin, katta,
/// fonli (mayda kulrang yozuv emas).
class InstructionLine extends StatelessWidget {
  final String text;
  const InstructionLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.brandPurple.withValues(alpha: dark ? 0.2 : 0.09),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.touch_app_rounded,
                size: 18,
                color: dark ? AppColors.darkHeading : AppColors.brandPurple),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color:
                        dark ? AppColors.darkHeading : AppColors.lightHeading)),
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
              // Nima qilish kerakligi - savolning O'ZIDA, aniq.
              InstructionLine(instructionOf(q)),
              const SizedBox(height: 14),
              Text(q.prompt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: q.prompt.length > 40 ? 17 : 24,
                      fontWeight: FontWeight.w800,
                      height: 1.35)),
              if (q.promptUz.isNotEmpty) ...[
                const SizedBox(height: 6),
                // Bu qator nima ekani yozilsin: bo'sh joydagi so'zning
                // ma'nosi yoki gapning tarjimasi - ikkalasi ham ishora.
                Text('Ishora: ${q.promptUz}',
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
        const SizedBox(height: 8),
        // Nima qilish kerakligi: avval chap, keyin o'ng.
        InstructionLine('${instructionFor(AskFormat.match)}. '
            "To'g'ri juft yashil bo'ladi."),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final t in const ['Inglizcha', 'O\'zbekcha']) ...[
              Expanded(
                child: Text(t,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted(context))),
              ),
              if (t == 'Inglizcha') const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 6),
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
              // Qanday javob beriladi - aniq va katta (mayda kulrang emas).
              InstructionLine(instructionOf(q)),
              const SizedBox(height: 14),
              // Eshitib yozishda katta matn - so'zning ma'nosi (javob
              // emas); shuni aytib qo'yamiz.
              if (q.format == AskFormat.listen && q.promptUz.isNotEmpty) ...[
                Text("Ma'nosi:",
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.muted(context))),
                const SizedBox(height: 2),
              ],
              // SAVOL O'ZBEKChA — javob inglizcha yoziladi.
              Text(q.format == AskFormat.listen ? q.promptUz : q.prompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800)),
              // Bo'shliqli gapda o'zbekcha qator - ishora.
              if (q.format == AskFormat.build &&
                  hasBlank(q.prompt) &&
                  q.promptUz.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Ishora: ${q.promptUz}',
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
        const SizedBox(height: 16),
        Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border, width: 2),
          ),
          child: _built.isEmpty
              // Bo'sh quti nima ekani aytiladi: javob shu yerda yig'iladi.
              ? Text("Javobingiz shu yerda yig'iladi",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted(context)))
              : Text(_built,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
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
                    label: const Text("Oxirgisini o'chirish"),
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

/// Trening tugadi — natija va keyingi qadam.
class _Finished extends StatelessWidget {
  final DrillSession session;
  final String progressLabel;
  const _Finished({required this.session, required this.progressLabel});

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
          child: Text('Mashq tugadi',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            "Bu mashqdagi hamma savolga to'g'ri javob berdingiz.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, height: 1.5, color: AppColors.muted(context)),
          ),
        ),
        const SizedBox(height: 18),
        // BUTUN dars qancha qolgani — o'quvchi yo'lni ko'rsin.
        // Mashq qisqa, lekin dars 100% gacha davom etadi.
        _LessonBar(value: session.lessonProgress, label: progressLabel),
        const SizedBox(height: 16),
        Center(
          child: Tooltip(
            message: "Xatosiz ketma-ket nechta savolga to'g'ri javob "
                'berganingiz',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.coin.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                  "Eng ko'p ketma-ket to'g'ri javob: ${session.bestCombo}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Pressable3D(
          color: AppColors.brandPurple,
          onPressed: () => Navigator.pop(context),
          child: const Center(
            child: Text('Orqaga qaytish',
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

/// Butun darsning o\'zlashtirilishi — mashq oxiridagi yo\'l xaritasi.
class _LessonBar extends StatelessWidget {
  final double value;
  final String label;
  const _LessonBar({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Column(
      children: [
        Text('$label: $pct%',
            textAlign: TextAlign.center,
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
              ? 'Hammasi yodlandi — ajoyib natija.'
              : "Qolgan savollar keyingi mashqda so'raladi. "
                  "Davom etish uchun mashqni yana boshlang.",
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
  Widget build(BuildContext context) => Tooltip(
        message: 'Eshitish',
        child: Container(
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
                child: Icon(Icons.volume_up_rounded,
                    color: Colors.white, size: 26),
              ),
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
