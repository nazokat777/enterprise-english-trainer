import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/tts.dart';
import '../teach/question_card.dart' show PageIntro;
import '../theme.dart';

/// GRAMMATIKA MAKTABI: har unitdagi grammatika qoidalari alohida-alohida,
/// har biri batafsil o'zbekcha tushuntirish, misollar (bossangiz o'qiladi),
/// tipik xatolar va mini-test bilan. Ma'lumot: assets/content/DARAJA/
/// grammar_school.json (shartnoma: assets/content/grammar_school_SPEC.md).

class GsExample {
  final String en, uz;
  const GsExample(this.en, this.uz);
}

class GsMistake {
  final String wrong, right, why;
  const GsMistake(this.wrong, this.right, this.why);
}

class GsQuiz {
  final String q, why;
  final List<String> options;
  final int answer;
  const GsQuiz(this.q, this.options, this.answer, this.why);
}

class GsRule {
  final String id, title, summary, tip;
  final List<(String, String)> sections;
  final List<GsExample> examples;
  final List<GsMistake> mistakes;
  final List<GsQuiz> quiz;
  const GsRule({
    required this.id,
    required this.title,
    required this.summary,
    required this.tip,
    required this.sections,
    required this.examples,
    required this.mistakes,
    required this.quiz,
  });

  factory GsRule.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String k) =>
        ((j[k] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
    String s(Object? v) => (v ?? '').toString();
    return GsRule(
      id: s(j['id']),
      title: s(j['title']),
      summary: s(j['summary']),
      tip: s(j['tip']),
      sections: [for (final x in list('sections')) (s(x['h']), s(x['body']))],
      examples: [for (final x in list('examples')) GsExample(s(x['en']), s(x['uz']))],
      mistakes: [
        for (final x in list('mistakes'))
          GsMistake(s(x['wrong']), s(x['right']), s(x['why']))
      ],
      quiz: [
        for (final x in list('quiz'))
          GsQuiz(
            s(x['q']),
            [for (final o in (x['options'] as List? ?? const [])) s(o)],
            (x['answer'] as num?)?.toInt() ?? 0,
            s(x['why']),
          )
      ],
    );
  }

  /// Qidiruv uchun bitta matn.
  String get haystack => [
        title,
        summary,
        for (final s in sections) '${s.$1} ${s.$2}',
        for (final e in examples) '${e.en} ${e.uz}',
      ].join(' ').toLowerCase();
}

class GsUnit {
  final int unit;
  final List<GsRule> rules;
  const GsUnit(this.unit, this.rules);
}

class GrammarSchool {
  GrammarSchool._();
  static final Map<String, List<GsUnit>> _cache = {};

  static Future<List<GsUnit>> load(String level) async {
    final hit = _cache[level];
    if (hit != null) return hit;
    var out = <GsUnit>[];
    try {
      final raw = await rootBundle
          .loadString('assets/content/$level/grammar_school.json');
      final j = json.decode(raw) as Map<String, dynamic>;
      for (final u in (j['units'] as List? ?? const [])) {
        if (u is! Map<String, dynamic>) continue;
        final rules = [
          for (final r in (u['rules'] as List? ?? const []))
            if (r is Map<String, dynamic>) GsRule.fromJson(r)
        ];
        if (rules.isNotEmpty) {
          out.add(GsUnit((u['unit'] as num?)?.toInt() ?? 0, rules));
        }
      }
      out.sort((a, b) => a.unit.compareTo(b.unit));
    } catch (_) {
      out = <GsUnit>[];
    }
    _cache[level] = out;
    return out;
  }
}

/// O'rganilgan qoidalar (shu qurilmada saqlanadi).
class GsDone {
  GsDone._();
  static const _key = 'gs_done';
  static final Set<String> ids = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final p = await SharedPreferences.getInstance();
      ids.addAll(p.getStringList(_key) ?? const []);
    } catch (_) {}
    _loaded = true;
  }

  static Future<void> mark(String id) async {
    ids.add(id);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_key, ids.toList());
    } catch (_) {}
  }
}

String _unitTitle(int unit) {
  for (final b in book.units) {
    if (b.unit == unit && !b.isExtra) return b.title;
  }
  return '';
}

// ═══════════════════ Ro'yxat: unitlar va qoidalar ═══════════════════
class GrammarSchoolScreen extends StatefulWidget {
  const GrammarSchoolScreen({super.key});

  @override
  State<GrammarSchoolScreen> createState() => _GrammarSchoolScreenState();
}

class _GrammarSchoolScreenState extends State<GrammarSchoolScreen> {
  String _q = '';
  late Future<List<GsUnit>> _f;
  String _level = '';

  @override
  void initState() {
    super.initState();
    _level = progress.currentLevel;
    _f = _open();
  }

  Future<List<GsUnit>> _open() async {
    await GsDone.load();
    return GrammarSchool.load(_level);
  }

  @override
  Widget build(BuildContext context) {
    if (_level != progress.currentLevel) {
      _level = progress.currentLevel;
      _f = _open();
    }
    final muted = AppColors.muted(context);
    return FutureBuilder<List<GsUnit>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final units = snap.data ?? const <GsUnit>[];
        if (units.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "Bu daraja uchun grammatika darslari hali tayyor emas.",
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
            ),
          );
        }
        final total = units.fold<int>(0, (a, u) => a + u.rules.length);
        final done = units.fold<int>(
            0, (a, u) => a + u.rules.where((r) => GsDone.ids.contains(r.id)).length);
        final q = _q.trim().toLowerCase();
        final shown = <Widget>[];
        for (final u in units) {
          final rules = q.isEmpty
              ? u.rules
              : u.rules.where((r) => r.haystack.contains(q)).toList();
          if (rules.isEmpty) continue;
          shown.add(_UnitBlock(unit: u, rules: rules, onBack: () => setState(() {})));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text("Grammatika maktabi", style: AppTheme.heading(context)),
            const SizedBox(height: 4),
            Text(
              "${units.length} ta unit, $total ta qoida · o'rganilgan: $done",
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: muted),
            ),
            const SizedBox(height: 10),
            const PageIntro(
                "Bu yerda har unitdagi grammatika qoidalari alohida-alohida, "
                "oddiy o'zbek tilida tushuntirilgan: qachon ishlatiladi, "
                "qanday tuziladi, odatiy xatolar va mini-test. Misolni "
                "bossangiz ovozda o'qiladi. Qoidani ochib oxirigacha "
                "o'qisangiz, u \"o'rganildi\" deb belgilanadi."),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: "Qidirish: some, any, located, there is ...",
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (shown.isEmpty)
              Text("Hech narsa topilmadi.", style: TextStyle(color: muted)),
            ...shown,
          ],
        );
      },
    );
  }
}

class _UnitBlock extends StatelessWidget {
  final GsUnit unit;
  final List<GsRule> rules;
  final VoidCallback onBack;
  const _UnitBlock(
      {required this.unit, required this.rules, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(context);
    final t = _unitTitle(unit.unit);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.brandPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text("${unit.unit}",
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.brandPurple)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.isEmpty ? "${unit.unit}-unit" : t,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        Text("${unit.rules.length} ta grammatika qoidasi",
                            style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final r in rules)
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GsRuleScreen(rule: r)),
                  );
                  onBack();
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                  child: Row(
                    children: [
                      Icon(
                        GsDone.ids.contains(r.id)
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: GsDone.ids.contains(r.id)
                            ? AppColors.success
                            : muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14.5)),
                            if (r.summary.isNotEmpty)
                              Text(r.summary,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5, height: 1.35, color: muted)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: muted),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════ Bitta qoida: batafsil dars ═══════════════════
class GsRuleScreen extends StatefulWidget {
  final GsRule rule;
  const GsRuleScreen({super.key, required this.rule});

  @override
  State<GsRuleScreen> createState() => _GsRuleScreenState();
}

class _GsRuleScreenState extends State<GsRuleScreen> {
  late final List<int?> _picked =
      List<int?>.filled(widget.rule.quiz.length, null);

  void _check() {
    for (var i = 0; i < _picked.length; i++) {
      if (_picked[i] != widget.rule.quiz[i].answer) return;
    }
    GsDone.mark(widget.rule.id);
  }

  Widget _card(BuildContext context,
      {required String title, required Widget child, Color? accent}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: accent ?? AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: accent ?? AppColors.brandPurple)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rule;
    final muted = AppColors.muted(context);
    final body = TextStyle(
        fontSize: 15,
        height: 1.55,
        color: Theme.of(context).colorScheme.onSurface);
    return Scaffold(
      appBar: AppBar(title: Text(r.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          if (r.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(r.summary,
                  style: body.copyWith(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          for (final s in r.sections)
            _card(context,
                title: s.$1,
                child: SelectableText(s.$2, style: body)),
          if (r.examples.isNotEmpty)
            _card(
              context,
              title: "Misollar (bossangiz o'qiladi)",
              child: Column(
                children: [
                  for (final e in r.examples)
                    InkWell(
                      onTap: () =>
                          Tts.instance.speak(e.en, id: 'gs::${e.en}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.volume_up_rounded,
                                size: 20, color: AppColors.brandPurple),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.en,
                                      style: body.copyWith(
                                          fontWeight: FontWeight.w700)),
                                  Text(e.uz,
                                      style: TextStyle(
                                          fontSize: 13.5, color: muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (r.mistakes.isNotEmpty)
            _card(
              context,
              title: "Odatiy xatolar",
              accent: AppColors.danger,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final m in r.mistakes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("✗ ${m.wrong}",
                              style: body.copyWith(
                                  color: AppColors.danger,
                                  decoration: TextDecoration.lineThrough)),
                          Text("✓ ${m.right}",
                              style: body.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700)),
                          if (m.why.isNotEmpty)
                            Text(m.why,
                                style: TextStyle(
                                    fontSize: 13.5, height: 1.4, color: muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (r.tip.isNotEmpty)
            _card(context,
                title: "Eslab qoling",
                accent: AppColors.coin,
                child: Text(r.tip, style: body)),
          if (r.quiz.isNotEmpty)
            _card(
              context,
              title: "Mini-test",
              accent: AppColors.actionBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < r.quiz.length; i++) ...[
                    Text("${i + 1}. ${r.quiz[i].q}",
                        style: body.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (var o = 0; o < r.quiz[i].options.length; o++)
                          ChoiceChip(
                            label: Text(r.quiz[i].options[o]),
                            selected: _picked[i] == o,
                            selectedColor: o == r.quiz[i].answer
                                ? AppColors.success.withValues(alpha: 0.25)
                                : AppColors.danger.withValues(alpha: 0.25),
                            onSelected: _picked[i] != null &&
                                    _picked[i] == r.quiz[i].answer
                                ? null
                                : (_) {
                                    setState(() => _picked[i] = o);
                                    if (o == r.quiz[i].answer) _check();
                                  },
                          ),
                      ],
                    ),
                    if (_picked[i] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _picked[i] == r.quiz[i].answer
                              ? "To'g'ri! ${r.quiz[i].why}"
                              : "Yana urinib ko'ring. ${r.quiz[i].why}",
                          style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: _picked[i] == r.quiz[i].answer
                                  ? AppColors.success
                                  : AppColors.danger),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
