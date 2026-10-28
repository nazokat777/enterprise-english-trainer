import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../book_content.dart';
import '../../services/tts.dart';
import '../../teach/vocab_lookup.dart';
import '../../theme.dart';

/// TO'LIQ DARSNI KO'RISH (matn + lug'at): unitdagi o'qish matnlari va
/// dialoglar bir joyda. Har SO'Z ustiga bosilsa - ovozda o'qiladi va
/// tarjimasi yozuv bilan chiqadi; har qatorning o'zbekcha tarjimasi
/// avval YASHIRIN (ko'z belgisi bilan ochiladi) - avval o'zingiz
/// tushunishga urinasiz.
///
/// Matnlar ilovaning o'z ma'lumotidan olinadi (study turidagi mashqlar).
class UnitReaderScreen extends StatefulWidget {
  final BookUnit unit;
  const UnitReaderScreen({super.key, required this.unit});

  @override
  State<UnitReaderScreen> createState() => _UnitReaderScreenState();
}

class _Line {
  final String speaker;
  final String en;
  final String uz;
  const _Line(this.speaker, this.en, this.uz);
}

class _Block {
  final String title;
  final String page;
  final List<_Line> lines;
  const _Block(this.title, this.page, this.lines);
}

class _UnitReaderScreenState extends State<UnitReaderScreen> {
  static final _wordRe = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");
  static final _speakerRe = RegExp(r'^([A-Z][\w .\-]{0,24}?):\s+(.+)$');

  late final List<_Block> _blocks = _collect();
  late final Map<String, String> _unitVocab = _vocabMap();
  final Set<int> _shown = {};
  bool _showAll = false;
  bool _playing = false;

  String _word = '';
  String _meaning = '';
  String _lineUz = '';

  List<_Block> _collect() {
    final out = <_Block>[];
    for (final s in widget.unit.sections) {
      for (final e in s.exercises) {
        if (e.kind != ExKind.study) continue;
        final lines = <_Line>[];
        for (final t in e.tasks) {
          final en = t.en.trim();
          if (en.isEmpty || !RegExp(r'[A-Za-z]').hasMatch(en)) continue;
          final m = _speakerRe.firstMatch(en);
          var uz = t.uz.trim();
          if (m != null) {
            final mu = RegExp(r'^[^:]{1,26}:\s+(.+)$').firstMatch(uz);
            if (mu != null) uz = mu.group(1)!;
            lines.add(_Line(m.group(1)!.trim(), m.group(2)!.trim(), uz));
          } else {
            lines.add(_Line('', en, uz));
          }
        }
        if (lines.isEmpty) continue;
        final title = s.titleUz.isNotEmpty ? s.titleUz : s.title;
        final page = s.pageLabel.isNotEmpty ? s.pageLabel : '${s.bookPage}-bet';
        out.add(_Block(title, page, lines));
      }
    }
    return out;
  }

  Map<String, String> _vocabMap() {
    final m = <String, String>{};
    for (final v in widget.unit.vocabulary) {
      final en = v.en.trim().toLowerCase();
      if (en.isNotEmpty && v.uz.trim().isNotEmpty) m[en] = v.uz.trim();
    }
    return m;
  }

  /// So'z ma'nosi: avval shu unit lug'ati, keyin umumiy lug'at.
  String _lookup(String w) {
    final k = w.toLowerCase();
    final direct = _unitVocab[k];
    if (direct != null) return direct;
    // "a farmer" kabi iboralar ichidagi so'z.
    for (final e in _unitVocab.entries) {
      final parts = e.key.split(RegExp(r'\s+'));
      if (parts.length > 1 && parts.contains(k) && parts.length <= 3) {
        return '${e.value} (${e.key})';
      }
    }
    return meaningOf(k);
  }

  void _tapWord(String w, _Line l) {
    Tts.instance.speak(w, id: 'w::${w.toLowerCase()}');
    setState(() {
      _word = w;
      _meaning = _lookup(w);
      _lineUz = l.uz;
    });
  }

  Future<void> _playAll() async {
    if (_playing) {
      setState(() => _playing = false);
      Tts.instance.stop();
      return;
    }
    setState(() => _playing = true);
    for (final b in _blocks) {
      for (final l in b.lines) {
        if (!mounted || !_playing) return;
        await Tts.instance.speak(l.en, id: 'l::${l.en}');
        // Ovoz tugaguncha kutamiz (eng ko'pi 20 soniya).
        for (var i = 0; i < 100 && mounted && _playing; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          if (Tts.instance.speakingId.value == null) break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    if (mounted) setState(() => _playing = false);
  }

  @override
  void dispose() {
    _playing = false;
    Tts.instance.stop();
    super.dispose();
  }

  Widget _lineView(BuildContext context, int key, _Line l) {
    final muted = AppColors.muted(context);
    final base = TextStyle(
        fontSize: 17,
        height: 1.55,
        color: Theme.of(context).colorScheme.onSurface);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _wordRe.allMatches(l.en)) {
      if (m.start > last) {
        spans.add(TextSpan(text: l.en.substring(last, m.start)));
      }
      final w = m.group(0)!;
      final sel = w == _word;
      spans.add(TextSpan(
        text: w,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: sel ? AppColors.brandPurple : null,
          backgroundColor:
              sel ? AppColors.brandPurple.withValues(alpha: 0.12) : null,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _tapWord(w, l),
      ));
      last = m.end;
    }
    if (last < l.en.length) spans.add(TextSpan(text: l.en.substring(last)));
    final open = _showAll || _shown.contains(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              tooltip: "Qatorni tinglash",
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.volume_up_rounded),
              color: AppColors.brandPurple,
              onPressed: () => Tts.instance.speak(l.en, id: 'l::${l.en}'),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (l.speaker.isNotEmpty)
                    Text(l.speaker,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: muted)),
                  Text.rich(TextSpan(style: base, children: spans)),
                  if (open && l.uz.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(l.uz,
                          style: TextStyle(
                              fontSize: 14, height: 1.4, color: muted)),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: open ? "Tarjimani yashirish" : "Tarjimani ko'rsatish",
              visualDensity: VisualDensity.compact,
              icon: Icon(open
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded),
              color: muted,
              onPressed: l.uz.isEmpty
                  ? null
                  : () => setState(() {
                        if (open) {
                          _showAll = false;
                          _shown.remove(key);
                        } else {
                          _shown.add(key);
                        }
                      }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wordPanel(BuildContext context) {
    final muted = AppColors.muted(context);
    return Material(
      elevation: 8,
      color: AppColors.surface(context),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: _word.isEmpty
              ? Text("Istalgan so'z ustiga bosing: o'qiladi va tarjimasi chiqadi.",
                  style: TextStyle(fontSize: 13.5, color: muted))
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_word,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(
                            _meaning.isNotEmpty
                                ? _meaning
                                : "Bu so'zning alohida tarjimasi lug'atda yo'q"
                                    "${_lineUz.isNotEmpty ? ' - qator tarjimasi: $_lineUz' : ''}",
                            style: TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: _meaning.isNotEmpty
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _meaning.isNotEmpty
                                    ? AppColors.success
                                    : muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: "So'zni tinglash",
                      icon: const Icon(Icons.volume_up_rounded),
                      color: AppColors.brandPurple,
                      onPressed: () => Tts.instance
                          .speak(_word, id: 'w::${_word.toLowerCase()}'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(context);
    var key = 0;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.unit.displayLabel} - matn + lug\'at')),
      body: Column(
        children: [
          Expanded(
            child: _blocks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          "Bu unitda alohida o'qish matni yoki dialog yo'q. "
                          "Lug'at va mashqlarni unit sahifasidan oching.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted)),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _playAll,
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.brandPurple,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12)),
                              icon: Icon(_playing
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded),
                              label: Text(_playing
                                  ? "To'xtatish"
                                  : "Butun matnni tinglash"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _showAll = !_showAll),
                            icon: Icon(_showAll
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded),
                            label: Text(_showAll ? "Yashirish" : "Tarjima"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "So'z ustiga bosing: o'qiladi va tarjimasi pastda "
                        "chiqadi. Qator tarjimasi yashirin - ko'z belgisi bilan "
                        "ochiladi.",
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                      for (final b in _blocks) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 8),
                          child: Text('${b.title} · ${b.page}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: AppColors.brandPurple)),
                        ),
                        for (final l in b.lines) _lineView(context, key++, l),
                      ],
                    ],
                  ),
          ),
          _wordPanel(context),
        ],
      ),
    );
  }
}
