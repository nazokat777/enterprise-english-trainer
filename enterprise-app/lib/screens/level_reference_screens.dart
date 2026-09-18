import 'package:flutter/material.dart';

import '../content.dart';
import '../main.dart';
import '../theme.dart';
import '../services/tts.dart';
import '../widgets/explain_text.dart';
import 'dart:math';

import '../book_content.dart';
import 'book/book_screens.dart';
import 'book/exercise_player.dart';

/// Daraja bo'yicha ma'lumotnoma: grammatika mavzulari va so'z oilalari.
///
/// Bu ikki ro'yxat asset'larda ANChADAN BERI bor edi (`grammar.json`,
/// `word_formation.json`) va ilova ularni yuklardi ham — lekin hech bir
/// ekran ko'rsatmasdi, ya'ni o'quvchi ularni umuman ko'rmasdi.
///
/// Kitob bo'limidagi `RuleScreen`/`WordFormationScreen` dan farqi: ular
/// BITTA unitga tegishli, bu yerda esa butun daraja bo'yicha umumiy
/// ro'yxat — takrorlash uchun qulay.

/// Ro'yxat bo'sh bo'lganda ko'rsatiladigan xabar.
Widget _empty(BuildContext context, IconData icon, String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.muted(context)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center, style: AppTheme.body(context)),
          ],
        ),
      ),
    );

// ═══════════════════ Grammatika mavzulari ═══════════════════
class LevelGrammarScreen extends StatefulWidget {
  const LevelGrammarScreen({super.key});

  @override
  State<LevelGrammarScreen> createState() => _LevelGrammarScreenState();
}

class _LevelGrammarScreenState extends State<LevelGrammarScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = repo.forLevel(progress.currentLevel).grammar;
    if (all.isEmpty) {
      return _empty(context, Icons.rule_rounded,
          'Bu daraja uchun grammatika mavzulari hali yo\'q.');
    }
    // Qidiruv: 300 ta qoida orasida "some any" deb yozib topiladi.
    final q = _q.trim().toLowerCase();
    final topics = q.isEmpty
        ? all
        : all
            .where((t) =>
                t.topic.toLowerCase().contains(q) ||
                t.ruleUz.toLowerCase().contains(q) ||
                t.examples.any((e) => e.toLowerCase().contains(q)))
            .toList();
    // Unit bo'yicha sarlavhalar — 200+ mavzu orasida yo'l topish uchun.
    final rows = <Widget>[];
    var lastUnit = -1;
    for (final t in topics) {
      if (t.unit != lastUnit) {
        lastUnit = t.unit;
        rows.add(_UnitDivider(unit: t.unit));
      }
      rows.add(_TopicCard(topic: t));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: rows.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _Header(
            title: 'Grammatika',
            subtitle: q.isEmpty
                ? "${all.length} ta qoida — uchala kitobdan, unit bo'yicha"
                : "${topics.length} ta topildi",
            icon: Icons.rule_rounded,
            color: AppColors.actionBlue,
          );
        }
        if (i == 1) {
          return Column(
            children: [
              const _GrammarQuizButton(),
              _SearchField(
                hint: 'Qidirish: some any, past simple, -er ...',
                onChanged: (v) => setState(() => _q = v),
              ),
            ],
          );
        }
        return rows[i - 2];
      },
    );
  }
}

class _TopicCard extends StatelessWidget {
  final GrammarTopic topic;
  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(topic.topic,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  color: AppColors.actionBlue)),
          if (topic.ruleUz.isNotEmpty) ...[
            const SizedBox(height: 7),
            ExplainText(topic.ruleUz,
                style: const TextStyle(fontSize: 13.5, height: 1.55)),
          ],
          if (topic.examples.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final e in topic.examples) _Example(text: e),
          ],
          if (topic.source.isNotEmpty || topic.unit > 0) ...[
            const SizedBox(height: 8),
            // Wrap: katta shriftda tugma ikkinchi qatorga tushadi,
            // chiqib ketmaydi.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                if (topic.source.isNotEmpty)
                  Text('📖 ${topic.source}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.brandPurple)),
                // Qoidadan to'g'ri mashqqa — o'qigan zahoti qo'llash
                // (retrieval practice).
                if (topic.unit > 0)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () async {
                      final u = await book.load(topic.unit);
                      if (u == null || !context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BookUnitScreen(unit: u)),
                      );
                    },
                    icon: const Icon(Icons.fitness_center_rounded, size: 15),
                    label: Text('${topic.unit}-unit mashqlari',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UnitDivider extends StatelessWidget {
  final int unit;
  const _UnitDivider({required this.unit});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.actionBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(unit > 0 ? '$unit-unit' : 'Umumiy',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: AppColors.actionBlue)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Divider(color: AppColors.actionBlue.withValues(alpha: 0.25))),
        ],
      ),
    );
  }
}

/// Misol gap — bosilganda ovoz chiqarib o'qiladi.
class _Example extends StatelessWidget {
  final String text;
  const _Example({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => Tts.instance.speak(text, id: text),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.volume_up_rounded,
                  size: 15, color: AppColors.actionBlue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13.5, fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════ So'z oilalari ═══════════════════
class LevelWordFormationScreen extends StatefulWidget {
  const LevelWordFormationScreen({super.key});

  @override
  State<LevelWordFormationScreen> createState() => _LevelWordFormationScreenState();
}

class _LevelWordFormationScreenState extends State<LevelWordFormationScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = repo.forLevel(progress.currentLevel).families;
    if (all.isEmpty) {
      return _empty(context, Icons.account_tree_rounded,
          'Bu daraja uchun so\'z oilalari hali yo\'q.');
    }
    final q = _q.trim().toLowerCase();
    final families = q.isEmpty
        ? all
        : all
            .where((f) =>
                f.base.toLowerCase().contains(q) ||
                f.uz.toLowerCase().contains(q) ||
                f.forms.any((x) => x.toLowerCase().contains(q)))
            .toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: families.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _Header(
            title: 'So\'z yasalishi',
            subtitle: q.isEmpty
                ? '${all.length} ta so\'z oilasi — '
                    'bitta o\'zakdan yasalgan shakllar'
                : '${families.length} ta topildi',
            icon: Icons.account_tree_rounded,
            color: AppColors.success,
          );
        }
        if (i == 1) {
          return Column(
            children: [
              _FamilyQuizButton(families: all),
              _SearchField(
                hint: 'Qidirish: happy, -ness, o\'qituvchi ...',
                onChanged: (v) => setState(() => _q = v),
              ),
            ],
          );
        }
        return _FamilyCard(family: families[i - 2]);
      },
    );
  }
}

class _FamilyCard extends StatelessWidget {
  final WordFamily family;
  const _FamilyCard({required this.family});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sarlavha qatori tor ekranda sig'masligi mumkin — `Wrap`.
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () =>
                    Tts.instance.speak(family.base, id: family.base),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(family.base,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.success)),
                    const SizedBox(width: 5),
                    const Icon(Icons.volume_up_rounded,
                        size: 14, color: AppColors.success),
                  ],
                ),
              ),
              if (family.uz.isNotEmpty)
                Text(family.uz,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.muted(context))),
            ],
          ),
          if (family.forms.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in family.forms) _FormChip(text: f),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FormChip extends StatelessWidget {
  final String text;
  const _FormChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: () => Tts.instance.speak(text, id: text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.success)),
      ),
    );
  }
}

// ═══════════════════ Umumiy sarlavha ═══════════════════
class _Header extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, Color.lerp(color, AppColors.brandIndigo, 0.5)!]),
              boxShadow: AppShadow.glow(color, alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: dark
                            ? AppColors.darkHeading
                            : AppColors.lightHeading)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.muted(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ro'yxat ustidagi qidiruv maydoni.
class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// "10 savollik test" — barcha unitlarning grammatika mashqlaridan
/// tasodifiy tanlov savollari. Har safar boshqa: qoidalarni o'qish
/// emas, ESLAB ChIQARISh (retrieval practice) — eng samarali usul.
class _GrammarQuizButton extends StatefulWidget {
  const _GrammarQuizButton();
  @override
  State<_GrammarQuizButton> createState() => _GrammarQuizButtonState();
}

class _GrammarQuizButtonState extends State<_GrammarQuizButton> {
  bool _loading = false;

  Future<void> _start() async {
    if (_loading) return;
    setState(() => _loading = true);
    final pool = <ExTask>[];
    for (final b in book.units) {
      if (b.isInfo) continue;
      final u = await book.load(b.unit);
      if (u == null) continue;
      for (final s in u.sections) {
        if (!s.kind.startsWith('grammar')) continue;
        for (final e in s.exercises) {
          if (e.kind != ExKind.choice) continue;
          for (final t in e.tasks) {
            if (t.options.length >= 2 && t.answer.isNotEmpty) pool.add(t);
          }
        }
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (pool.length < 4) return;
    pool.shuffle(Random());
    final ex = BookExercise(
      ref: '1',
      kind: ExKind.choice,
      tasks: pool.take(10).toList(),
      instructionEn: 'Grammar quiz: 10 random questions from all units.',
      instructionUz: '10 ta tasodifiy grammatika savoli - barcha unitlardan.',
      book: 'quiz',
      pageLabel: 'grammatika',
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExercisePlayer(
          exercise: ex,
          sectionTitle: 'Grammatika testi',
          unitLabel: 'Aralash',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.actionBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          onPressed: _loading ? null : _start,
          icon: _loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.quiz_rounded),
          label: Text(_loading ? "Savollar yig'ilmoqda..." : '10 savollik grammatika testi'),
        ),
      ),
    );
  }
}

/// So'z oilalari testi: "'happy' (baxtli) so'zining hosila shakli
/// qaysi?" — to'g'ri shakl + boshqa oilalardan 3 chalg'ituvchi.
class _FamilyQuizButton extends StatelessWidget {
  final List<WordFamily> families;
  const _FamilyQuizButton({required this.families});

  void _start(BuildContext context) {
    final rng = Random();
    final pool = families.where((f) => f.forms.isNotEmpty).toList()..shuffle(rng);
    if (pool.length < 4) return;
    final tasks = <ExTask>[];
    for (final f in pool.take(10)) {
      final answer = f.forms[rng.nextInt(f.forms.length)];
      final others = <String>{};
      while (others.length < 3) {
        final o = pool[rng.nextInt(pool.length)];
        if (o.base == f.base) continue;
        others.add(o.forms[rng.nextInt(o.forms.length)]);
      }
      tasks.add(ExTask(
        prompt: f.uz.isNotEmpty ? "'${f.base}' (${f.uz})" : "'${f.base}'",
        promptUz: "Shu so'zning hosila (yasama) shakli qaysi?",
        answer: answer,
        options: [answer, ...others],
        whyUz: "${f.base} → ${f.forms.join(', ')}",
        speakAnswer: answer,
      ));
    }
    final ex = BookExercise(
      ref: '1',
      kind: ExKind.choice,
      tasks: tasks,
      instructionEn: 'Word formation quiz: pick the word from the same family.',
      instructionUz: "Berilgan so'zning yasama shaklini toping.",
      book: 'quiz',
      pageLabel: 'soz-yasalishi',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExercisePlayer(
          exercise: ex,
          sectionTitle: "So'z yasalishi testi",
          unitLabel: 'Aralash',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          onPressed: () => _start(context),
          icon: const Icon(Icons.quiz_rounded),
          label: const Text("10 savollik so'z yasalishi testi"),
        ),
      ),
    );
  }
}
