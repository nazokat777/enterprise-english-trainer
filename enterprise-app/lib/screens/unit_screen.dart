import 'package:flutter/material.dart';
import '../main.dart';
import '../content.dart';
import '../theme.dart';
import '../widgets/entrance.dart';
import '../widgets/pressable3d.dart';
import 'pack/pack_flow.dart';

/// Unit sahifasi — Vocabulary (pack'lar) + Homework komponentlari.
class UnitScreen extends StatelessWidget {
  final Unit unit;
  const UnitScreen({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(unit.code)),
      body: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final c = repo.forLevel(progress.currentLevel);
          final packs = unit.vocabComponents.expand((cm) => cm.packs).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              EntranceFade(
                child: Text(unit.title, style: AppTheme.body(context)),
              ),
              const SizedBox(height: 20),
              _sectionTitle(context, '📖 Vocabulary', 'So\'zlarni pack bo\'yicha o\'rganing'),
              const SizedBox(height: 12),
              for (var i = 0; i < packs.length; i++)
                EntranceFade(
                  delay: Duration(milliseconds: 50 * i),
                  child: _PackCard(
                    pack: packs[i],
                    words: c.wordsOf(packs[i]),
                    done: progress.isDone(packs[i].id),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PackFlow(
                          unit: unit,
                          pack: packs[i],
                          words: c.wordsOf(packs[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              _sectionTitle(context, '📝 Homework', '4 interaktiv mashq turi'),
              const SizedBox(height: 12),
              EntranceFade(
                child: _HomeworkCard(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext c, String title, String sub) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: dark ? AppColors.darkHeading : AppColors.lightHeading)),
        Text(sub,
            style: TextStyle(
                fontSize: 12.5,
                color: dark ? AppColors.darkMuted : AppColors.lightMuted)),
      ],
    );
  }
}

class _PackCard extends StatelessWidget {
  final VocabPack pack;
  final List<Word> words;
  final bool done;
  final VoidCallback onTap;
  const _PackCard({
    required this.pack,
    required this.words,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PressableScale(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
                      blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (done ? AppColors.success : AppColors.brandPurple)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(done ? Icons.check_rounded : Icons.style_rounded,
                        color: done ? AppColors.success : AppColors.brandPurple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pack.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('${words.length} so\'z',
                            style: TextStyle(
                                fontSize: 12,
                                color: dark
                                    ? AppColors.darkMuted
                                    : AppColors.lightMuted)),
                      ],
                    ),
                  ),
                  Icon(done ? Icons.replay_rounded : Icons.play_arrow_rounded,
                      color: AppColors.brandPurple),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Pressable3D(
      color: AppColors.homework,
      shadowColor: const Color(0xFFB8410C),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: AppRadius.md,
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '4 mashq turi (Choose/Construct/Match/Fill) — keyingi fazada qo\'shiladi'),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.quiz_rounded, color: Colors.white),
          SizedBox(width: 10),
          Text('Mashqlarni boshlash',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}
