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

// ═══════════════════ Grammatika qoidasi ═══════════════════
/// Grammatika kitobidagi nazariya sahifasini ko'rsatadi.
/// Qoida tuzilishi erkin (asset'dan qanday kelsa) — shuning uchun
/// ma'lum kalitlar tanib olinadi, qolganlari umumiy ko'rinishda beriladi.
class RuleScreen extends StatelessWidget {
  final BookSection section;
  const RuleScreen({super.key, required this.section});

  Map<String, dynamic> get r => section.rule?.raw ?? const {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(section.titleUz)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _source(),
          if (section.rule?.titleUz.isNotEmpty ?? false) ...[
            Text(section.rule!.titleUz,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
          ],
          if (section.rule?.explanationUz.isNotEmpty ?? false)
            _block(context, section.rule!.explanationUz),
          ..._usage(context),
          ..._table(context),
          ..._rulesList(context),
          ..._shortAnswers(context),
          ..._keyRules(context),
          if (section.rule?.warningUz.isNotEmpty ?? false)
            _warn(section.rule!.warningUz, AppColors.danger,
                Icons.warning_amber_rounded),
          if (section.rule?.noteUz.isNotEmpty ?? false)
            _warn(section.rule!.noteUz, AppColors.actionBlue,
                Icons.info_outline_rounded),
          if ((r['pluralNoteUz'] as String?)?.isNotEmpty ?? false)
            _warn(r['pluralNoteUz'] as String, AppColors.homework,
                Icons.info_outline_rounded),
          if ((r['extraUz'] as String?)?.isNotEmpty ?? false)
            _warn(r['extraUz'] as String, AppColors.brandPurple,
                Icons.lightbulb_outline_rounded),
        ],
      ),
    );
  }

  Widget _source() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandPurple.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text('📖 ${section.sourceLabel}',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPurple)),
          ),
        ),
      );

  Widget _block(BuildContext context, String text) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14, height: 1.6)),
      );

  Widget _warn(String text, Color c, IconData icon) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border(left: BorderSide(color: c, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: c),
            const SizedBox(width: 10),
            Expanded(
              child:
                  Text(text, style: const TextStyle(fontSize: 13, height: 1.55)),
            ),
          ],
        ),
      );

  List<Widget> _usage(BuildContext context) {
    final list = r['usage'] as List?;
    if (list == null || list.isEmpty) return [];
    return [
      const _H('Qo\'llanishi'),
      for (final u in list.cast<Map>())
        _row(context, u['pronoun']?.toString() ?? '',
            u['uzRule']?.toString() ?? '', u['enRule']?.toString() ?? ''),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _table(BuildContext context) {
    final rows = (r['table'] ?? r['affirmative']) as List?;
    if (rows == null || rows.isEmpty) return [];
    final neg = r['negative'] as List?;
    return [
      const _H('Jadval'),
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              _tableRow(context, (rows[i] as Map).cast<String, dynamic>(),
                  neg != null && i < neg.length
                      ? (neg[i] as Map).cast<String, dynamic>()
                      : null,
                  last: i == rows.length - 1),
          ],
        ),
      ),
    ];
  }

  Widget _tableRow(
      BuildContext context, Map<String, dynamic> a, Map<String, dynamic>? n,
      {bool last = false}) {
    final subject = a['subject']?.toString() ?? '';
    final aff = a['short']?.toString() ?? a['affShort']?.toString() ?? '';
    final affLong = a['full']?.toString() ?? a['affLong']?.toString() ?? '';
    final negShort = n?['short']?.toString() ?? a['negShort']?.toString() ?? '';
    final q = a['interrogative']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(subject,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppColors.brandPurple)),
          ),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                if (affLong.isNotEmpty) _chip(affLong, AppColors.success),
                if (aff.isNotEmpty && aff != affLong)
                  _chip(aff, AppColors.success),
                if (negShort.isNotEmpty) _chip(negShort, AppColors.danger),
                if (q.isNotEmpty) _chip(q, AppColors.actionBlue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(t,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
      );

  List<Widget> _rulesList(BuildContext context) {
    final list = r['rules'] as List?;
    if (list == null || list.isEmpty) return [];
    return [
      const _H('Qoidalar'),
      for (final x in list.cast<Map>())
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(x['uzRule']?.toString() ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5)),
              if ((x['enRule']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(x['enRule'].toString(),
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.lightMuted,
                        fontStyle: FontStyle.italic)),
              ],
              if (x['examples'] is List) ...[
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final e in (x['examples'] as List))
                      _chip(e.toString(), AppColors.brandPurple),
                  ],
                ),
              ],
            ],
          ),
        ),
    ];
  }

  List<Widget> _shortAnswers(BuildContext context) {
    final list = (r['examples'] ?? r['interrogative']) as List?;
    if (list == null || list.isEmpty) return [];
    final first = list.first;
    if (first is! Map || !(first.containsKey('q'))) return [];
    return [
      const _H('Qisqa javoblar'),
      for (final x in list.cast<Map>())
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(x['q']?.toString() ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              if ((x['qUz']?.toString() ?? '').isNotEmpty)
                Text(x['qUz'].toString(),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.lightMuted)),
              const SizedBox(height: 7),
              Row(
                children: [
                  _chip(x['yes']?.toString() ?? '', AppColors.success),
                  const SizedBox(width: 8),
                  _chip(x['no']?.toString() ?? '', AppColors.danger),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _keyRules(BuildContext context) {
    final list = r['keyRules'] as List?;
    if (list == null || list.isEmpty) return [];
    return [
      const _H('Muhim qoidalar'),
      for (final x in list.cast<Map>())
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.coin.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(x['uzRule']?.toString() ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(height: 8),
              _pair(Icons.check_circle_rounded, AppColors.success,
                  x['correct']?.toString() ?? ''),
              const SizedBox(height: 4),
              _pair(Icons.cancel_rounded, AppColors.danger,
                  x['wrong']?.toString() ?? ''),
              if ((x['whyUz']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(x['whyUz'].toString(),
                    style: const TextStyle(fontSize: 12.5, height: 1.5)),
              ],
            ],
          ),
        ),
    ];
  }

  Widget _pair(IconData i, Color c, String t) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 16, color: c),
          const SizedBox(width: 7),
          Expanded(
              child: Text(t, style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      );

  Widget _row(BuildContext context, String left, String main, String sub) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (left.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(left,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.brandPurple)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(main,
                      style: const TextStyle(fontSize: 13.5, height: 1.45)),
                  if (sub.isNotEmpty)
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.lightMuted,
                            fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.brandPurple)),
      );
}

// ═══════════════════ So'z yasalishi ═══════════════════
class WordFormationScreen extends StatelessWidget {
  final BookUnit unit;
  const WordFormationScreen({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _Bar(title: 'So\'z yasalishi'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          for (final g in unit.wordFormation) _group(context, g),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, WfGroup g) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.ruleUz,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.success)),
            if (g.explanationUz.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(g.explanationUz,
                  style: const TextStyle(fontSize: 13, height: 1.55)),
            ],
            const SizedBox(height: 12),
            for (final it in g.items) _item(context, it),
          ],
        ),
      );

  Widget _item(BuildContext context, WfItem it) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: InkWell(
          onTap: () => Tts.instance.speak(it.derived, id: it.derived),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.base,
                        style: const TextStyle(
                            fontSize: 13.5, color: AppColors.lightMuted)),
                    if (it.baseUz.isNotEmpty)
                      Text(it.baseUz,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.lightMuted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  size: 16, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.derived,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800)),
                    if (it.derivedUz.isNotEmpty)
                      Text(it.derivedUz,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.lightMuted)),
                  ],
                ),
              ),
              if (it.note.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxWidth: 110),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.coin.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(it.note,
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8A5A00))),
                ),
            ],
          ),
        ),
      );
}

// ═══════════════════ Gap qoliplari ═══════════════════
class SentencePatternsScreen extends StatelessWidget {
  final BookUnit unit;
  const SentencePatternsScreen({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _Bar(title: 'Gap qoliplari'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          for (final p in unit.sentencePatterns) _card(context, p),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, SentencePattern p) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.actionBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(p.formula,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.actionBlue,
                      height: 1.4)),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => Tts.instance.speak(p.exampleEn, id: p.formula),
              child: Row(
                children: [
                  const Icon(Icons.volume_up_rounded,
                      size: 17, color: AppColors.actionBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.exampleEn,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
            if (p.exampleUz.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 25, top: 2),
                child: Text(p.exampleUz,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.lightMuted)),
              ),
            if (p.explanationUz.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(p.explanationUz,
                  style: const TextStyle(fontSize: 13, height: 1.55)),
            ],
          ],
        ),
      );
}

// ═══════════════════ Unit lug'ati (yodlash) ═══════════════════
class UnitVocabularyScreen extends StatefulWidget {
  final BookUnit unit;
  const UnitVocabularyScreen({super.key, required this.unit});

  @override
  State<UnitVocabularyScreen> createState() => _UnitVocabularyScreenState();
}

class _UnitVocabularyScreenState extends State<UnitVocabularyScreen> {
  bool _drill = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.unit.vocabulary;
    if (_drill) {
      return _VocabDrill(
        entries: v,
        onExit: () => setState(() => _drill = false),
      );
    }
    return Scaffold(
      appBar: const _Bar(title: 'Unit lug\'ati'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Pressable3D(
            color: AppColors.brandPurple,
            shadowColor: const Color(0xFF5B22B5),
            onPressed: v.length < 4
                ? () {}
                : () => setState(() => _drill = true),
            enabled: v.length >= 4,
            child: Center(
              child: Text(
                  v.length < 4
                      ? 'Yodlash uchun kamida 4 so\'z kerak'
                      : 'Yodlashni boshlash (${v.length} so\'z)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(height: 18),
          for (final e in v)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => Tts.instance.speak(e.en, id: e.en),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(e.en,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          child: Text(e.uz,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.lightMuted)),
                        ),
                        const Icon(Icons.volume_up_rounded,
                            size: 18, color: AppColors.actionBlue),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sahifa lug'atini interaktiv yodlash: inglizcha so'z → 4 ta o'zbekcha variant.
class _VocabDrill extends StatefulWidget {
  final List<VocabEntry> entries;
  final VoidCallback onExit;
  const _VocabDrill({required this.entries, required this.onExit});

  @override
  State<_VocabDrill> createState() => _VocabDrillState();
}

class _VocabDrillState extends State<_VocabDrill> {
  final _rnd = Random();
  late List<VocabEntry> _queue;
  int _i = 0;
  int _correct = 0;
  int _xp = 0;
  String? _chosen;
  late List<String> _options;

  @override
  void initState() {
    super.initState();
    _queue = List.of(widget.entries)..shuffle(_rnd);
    _load();
  }

  void _load() {
    final target = _queue[_i];
    final pool = widget.entries
        .where((e) => e.uz != target.uz)
        .map((e) => e.uz)
        .toList()
      ..shuffle(_rnd);
    _options = [target.uz, ...pool.take(3)]..shuffle(_rnd);
    _chosen = null;
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => Tts.instance.speak(target.en, id: 'voc'));
  }

  Future<void> _tap(String o) async {
    if (_chosen != null) return;
    final target = _queue[_i];
    final ok = o == target.uz;
    setState(() => _chosen = o);
    if (ok) {
      _correct++;
      _xp += 2;
      showCorrectBurst(context);
      await progress.addXp(2, skill: Skill.vocab);
    }
    Future.delayed(Duration(milliseconds: ok ? 850 : 1500), () {
      if (!mounted) return;
      if (_i + 1 < _queue.length) {
        setState(() {
          _i++;
          _load();
        });
      } else {
        setState(() => _i = -1); // yakun
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_i == -1) {
      return Scaffold(
        appBar: const _Bar(title: 'Lug\'at yodlash'),
        body: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.success),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 58),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text('$_correct / ${_queue.length}',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              onPressed: widget.onExit,
              child: const Center(
                child: Text('Lug\'atga qaytish',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
      );
    }

    final target = _queue[_i];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lug\'at yodlash'),
        leading: IconButton(
            onPressed: widget.onExit,
            icon: const Icon(Icons.arrow_back_rounded)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${_i + 1} / ${_queue.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.brandPurple)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                Text(target.en,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                RoundPlay(text: target.en),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
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
                          width: 1.8),
                    ),
                    child: Text(o,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const _Bar({required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(title: Text(title));
}
