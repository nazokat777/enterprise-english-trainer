import 'package:flutter/material.dart';
import '../main.dart';
import '../content.dart';
import '../theme.dart';
import '../widgets/entrance.dart';
import 'unit_screen.dart';

/// Darslar — joriy darajaning unit'lari (game-map uslubidagi ro'yxat).
class UnitsScreen extends StatelessWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LevelContent c = repo.forLevel(progress.currentLevel);
    if (c.units.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty_rounded,
                size: 48, color: AppColors.homework),
            const SizedBox(height: 12),
            Text('Bu daraja uchun kontent hali yo\'q (OCR kerak).',
                style: AppTheme.body(context)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: c.units.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Darslar', style: AppTheme.heading(context)),
          );
        }
        final unit = c.units[i - 1];
        return EntranceFade(
          delay: Duration(milliseconds: 40 * (i.clamp(0, 8))),
          child: _UnitNode(unit: unit, isFirst: i == 1),
        );
      },
    );
  }
}

class _UnitNode extends StatelessWidget {
  final Unit unit;
  final bool isFirst;
  const _UnitNode({required this.unit, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final packs = unit.vocabComponents.expand((c) => c.packs).toList();
    final done = packs.where((p) => progress.isDone(p.id)).length;
    final pct = packs.isEmpty ? 0.0 : done / packs.length;
    final complete = packs.isNotEmpty && done == packs.length;

    return PressableScale(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => UnitScreen(unit: unit))),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.3 : 0.05),
                      blurRadius: 10),
                ],
              ),
              child: Row(
                children: [
                  // Progress-ring tugun (game-map node).
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 54,
                          height: 54,
                          child: CircularProgressIndicator(
                            value: pct,
                            strokeWidth: 5,
                            backgroundColor:
                                AppColors.neutralShadow.withValues(alpha: 0.4),
                            valueColor: AlwaysStoppedAnimation(
                                complete ? AppColors.success : AppColors.brandPurple),
                          ),
                        ),
                        complete
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.success, size: 26)
                            : Text('${unit.order}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 18)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(unit.code,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: dark
                                        ? AppColors.darkHeading
                                        : AppColors.lightHeading)),
                            if (unit.isRevision) ...[
                              const SizedBox(width: 8),
                              _tag('Revision', AppColors.homework),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('${unit.wordCount} so\'z · $done/${packs.length} pack',
                            style: TextStyle(
                                fontSize: 13,
                                color: dark
                                    ? AppColors.darkMuted
                                    : AppColors.muted(context))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(t,
            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11)),
      );
}
