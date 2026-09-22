import 'package:flutter/material.dart';

import '../content.dart';
import '../main.dart';
import '../mistakes.dart';
import '../teach/explain.dart';
import '../teach/explain_card.dart';
import '../teach/vocab_lookup.dart';
import '../book_content.dart';
import 'book/exercise_player.dart';
import '../srs.dart';
import '../theme.dart';
import '../services/tts.dart';
import '../widgets/pressable3d.dart';
import '../drill/weak_topics_section.dart';
import 'pack/pack_flow.dart';

/// QIYIN SO'ZLAR — o'quvchi qayta-qayta unutayotgan so'zlar.
///
/// Ilgari ilova "qaysi so'z yodlanmayapti" degan savolga javob
/// bermasdi: SM-2 holati saqlanardi, lekin uni ko'rish yoki aynan shu
/// so'zlar ustida ishlash imkoni yo'q edi. Endi:
///   * har bir so'z necha marta unutilgani ko'rinadi
///   * FAQAT shu so'zlar bilan mashq qilish mumkin
class HardWordsScreen extends StatelessWidget {
  const HardWordsScreen({super.key});

  /// Mashq uchun bir vaqtda olinadigan so'zlar soni.
  /// Kichik to'da — takrorlash tez-tez bo'lsin va charchatmasin.
  static const int _drillSize = 6;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final c = repo.forLevel(progress.currentLevel);
        final ids = progress.hardWordIds();
        final words = [
          for (final id in ids)
            if (c.wordsById[id] != null) c.wordsById[id]!,
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            // ZAIF MAVZULAR — "qaysi joyini o'zlashtirolmayapti".
            // Bu so'zlardan kengroq: grammatika, o'qish, gapirish
            // bandlari ham hisobga olinadi.
            const WeakTopicsSection(),
            // XATOLAR DAFTARI — xato qilingan bandlar, qayta ishlash.
            const _MistakesSection(),
            if (words.isEmpty)
              const _Empty()
            else ...[
              _Header(count: words.length, words: words),
              for (final w in words)
                _HardWordCard(word: w, srs: progress.srsFor(w.id)),
            ],
          ],
        );
      },
    );
  }

  /// Faqat qiyin so'zlar bilan mashq — mavjud pack oqimi ishlatiladi.
  /// Moslash bosqichi tanlov bo'lishi uchun eng kam so'z soni.
  ///
  /// XATO: bitta qiyin so'z bo'lsa mashqda chapda ham, o'ngda ham
  /// BITTA yozuv turardi — o'quvchi o'ylamasdan bosardi va so'z
  /// "o'zlashtirildi" bo'lib qiyinlar ro'yxatidan chiqib ketardi.
  static const int _minDrill = 4;

  static void drill(BuildContext context, List<Word> words) {
    final chunk = words.take(_drillSize).toList();
    if (chunk.length < _minDrill) {
      // Chalg'ituvchi variantlar — o'sha darajaning boshqa so'zlaridan.
      final have = chunk.map((w) => w.id).toSet();
      final pool = repo.forLevel(progress.currentLevel).wordsById.values
          .where((w) => !have.contains(w.id))
          .toList()
        ..shuffle();
      chunk.addAll(pool.take(_minDrill - chunk.length));
    }

    final pack = VocabPack(
      id: 'hard',
      name: 'Qiyin so\'zlar',
      wordIds: chunk.map((w) => w.id).toList(),
    );
    final unit = Unit(
      id: 'hard',
      code: 'Qiyin so\'zlar',
      title: 'Qayta ishlash',
      module: '',
      order: 0,
      isRevision: true,
      components: [
        Component(id: 'hard-v', type: 'VOCABULARY', order: 0, packs: [pack]),
      ],
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PackFlow(unit: unit, pack: pack, words: chunk),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded,
                size: 52, color: AppColors.success),
            const SizedBox(height: 14),
            Text('Hozircha qiyin so\'z yo\'q',
                textAlign: TextAlign.center,
                style: AppTheme.body(context)
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              'Lug\'at mashqlarini bajaring — ikki marta unutilgan so\'z '
              'shu yerda paydo bo\'ladi va uni alohida mashq qilish '
              'mumkin bo\'ladi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, height: 1.5, color: AppColors.muted(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  final List<Word> words;
  const _Header({required this.count, required this.words});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.homework.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.priority_high_rounded,
                    color: AppColors.homework, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qiyin so\'zlar',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: dark
                                ? AppColors.darkHeading
                                : AppColors.lightHeading)),
                    const SizedBox(height: 2),
                    Text('$count ta so\'z qayta-qayta unutilyapti',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.muted(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Pressable3D(
              color: AppColors.homework,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              onPressed: () => HardWordsScreen.drill(context, words),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.replay_rounded, color: Colors.white, size: 21),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text('Shu so\'zlar ustida ishlash',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HardWordCard extends StatelessWidget {
  final Word word;
  final WordSrs srs;
  const _HardWordCard({required this.word, required this.srs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () => Tts.instance.speak(word.en, id: word.id),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(word.en,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.homework)),
                    const SizedBox(width: 5),
                    const Icon(Icons.volume_up_rounded,
                        size: 14, color: AppColors.homework),
                  ],
                ),
              ),
              Text(word.uz,
                  style: TextStyle(
                      fontSize: 13.5, color: AppColors.muted(context))),
            ],
          ),
          if (word.hasExample) ...[
            const SizedBox(height: 6),
            boldExample(
                word.example,
                word.en,
                TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.muted(context))),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _Chip(
                icon: Icons.close_rounded,
                text: '${srs.lapses} marta unutilgan',
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              if (srs.isKnown)
                const _Chip(
                  icon: Icons.check_rounded,
                  text: 'endi yodda',
                  color: AppColors.success,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Chip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Xatolar daftari bo'limi: oxirgi xatolar + "ustida ishlash" tugmasi.
class _MistakesSection extends StatelessWidget {
  const _MistakesSection();

  void _quiz(BuildContext context) {
    final tasks = mistakes.quizTasks();
    if (tasks.isEmpty) return;
    final ex = BookExercise(
      ref: '1',
      kind: ExKind.choice,
      tasks: tasks,
      instructionEn: 'Work on your own mistakes.',
      instructionUz: "O'z xatolaringiz ustida ishlang — to'g'ri topilgani daftardan o'chadi.",
      book: 'quiz',
      pageLabel: 'xatolar',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExercisePlayer(
          exercise: ex,
          sectionTitle: 'Xatolar daftari',
          unitLabel: 'Takror',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mistakes,
      builder: (context, _) {
        final items = mistakes.items;
        if (items.isEmpty) return const SizedBox.shrink();
        final quizable = items.where((m) => m.options.length >= 2).length;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('📓', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Xatolar daftari — ${items.length} ta band',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                  TextButton(
                    onPressed: mistakes.clear,
                    child: const Text('Tozalash', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              Text(
                "Xato qilingan bandlar. To'g'ri topilgani daftardan o'chadi — "
                "o'z xatolari ustida ishlash eng samarali usul.",
                style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
              ),
              const SizedBox(height: 8),
              for (final m in items.take(5)) _MistakeRow(m),
              if (items.length > 5)
                Text('... yana ${items.length - 5} ta',
                    style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
              const SizedBox(height: 10),
              if (quizable >= 2)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900)),
                    onPressed: () => _quiz(context),
                    icon: const Icon(Icons.replay_rounded),
                    label: Text('Xatolar ustida ishlash ($quizable)'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
class _MistakeRow extends StatefulWidget {
  final Mistake m;
  const _MistakeRow(this.m);

  @override
  State<_MistakeRow> createState() => _MistakeRowState();
}

class _MistakeRowState extends State<_MistakeRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    // Daftardagi har band TUShUNTIRILADI: kitob izohi bo'lmasa,
    // yozilgan javob bilan to'g'ri variant farqidan qoida chiqariladi.
    final items = explainAnswer(
      correct: m.answer,
      given: m.given,
      whyUz: m.whyUz,
      uz: m.promptUz,
      lookup: meaningOf,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: AppColors.danger, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).textTheme.bodyMedium?.color),
                    children: [
                      TextSpan(
                          text: m.prompt,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(
                          text: '   =  ${m.answer}',
                          style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800)),
                      if (m.times > 1)
                        TextSpan(
                            text: '  x${m.times}',
                            style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              if (items.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _open = !_open),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_open ? 'Yopish' : 'Nega?',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandPurple)),
                        Icon(
                            _open
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 16,
                            color: AppColors.brandPurple),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (_open) ExplainCard(items: items, correct: false),
        ],
      ),
    );
  }
}
