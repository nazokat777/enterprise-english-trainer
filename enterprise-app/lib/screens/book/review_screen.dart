import 'package:flutter/material.dart';

import '../../book_content.dart';
import '../../main.dart';
import '../../theme.dart';
import 'exercise_player.dart';

/// TAKRORLASh KERAK — xato bilan tugatilgan mashqlar bir joyda.
///
/// Mashq kartochkasida "takrorlash kerak" belgisi bor edi, lekin
/// o'quvchi uni 1545 mashq orasidan QIDIRIB topishi kerak edi. Amalda
/// bu belgi hech kimga ko'rinmasdi.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

/// Bitta takrorlanadigan mashq — unit yorlig'i bilan birga.
class _Item {
  final BookUnit unit;
  final BookSection section;
  final BookExercise exercise;
  const _Item(this.unit, this.section, this.exercise);
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<_Item>? _items;

  @override
  void initState() {
    super.initState();
    _collect();
  }

  /// Barcha unitlarni yuklab, takrorlash kerak bo'lganlarini yig'adi.
  ///
  /// Unitlar odatda KERAK BO'LGANDA yuklanadi; bu yerda hammasi bir
  /// marta o'qiladi va keshda qoladi.
  ///
  /// TEZLIK: ilgari `for` ichida `await` turardi — 51 ta JSON fayl
  /// BIRIN-KETIN so'ralardi va ekran ~20 soniya "aylanib" turardi.
  /// Endi hammasi bir vaqtda so'raladi.
  Future<void> _collect() async {
    // Faqat KERAKLI unitlar yuklanadi. Ilgari 51 unitning hammasi
    // o'qilardi va ekran ~7 soniya aylanardi. `reviewUnits` bo'sh
    // bo'lsa (eski yozuvlar) hammasini o'qiymiz.
    final units = progress.reviewUnits.isEmpty
        ? book.units.map((b) => b.unit).toList()
        : book.units
            .map((b) => b.unit)
            .where(progress.reviewUnits.contains)
            .toList();
    final loaded = await Future.wait(units.map(book.load));
    final out = <_Item>[];
    for (final u in loaded) {
      if (u == null) continue;
      for (final s in u.sections) {
        for (final e in s.exercises) {
          final id = e.progressId;
          if (progress.needsRepeat(id)) out.add(_Item(u, s, e));
        }
      }
    }
    if (mounted) setState(() => _items = out);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) return const _Empty();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return _Header(count: items.length);
        return _Tile(item: items[i - 1], onDone: _collect);
      },
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
            const Icon(Icons.verified_rounded,
                size: 52, color: AppColors.success),
            const SizedBox(height: 14),
            Text('Takrorlash kerak bo\'lgan mashq yo\'q',
                textAlign: TextAlign.center,
                style: AppTheme.body(context)
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              'Mashqni xato bilan tugatsangiz, u shu yerda paydo bo\'ladi '
              'va xatosiz o\'tguningizcha turadi.',
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
  const _Header({required this.count});

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
              color: AppColors.homework.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.replay_rounded,
                color: AppColors.homework, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Takrorlash kerak',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: dark
                            ? AppColors.darkHeading
                            : AppColors.lightHeading)),
                const SizedBox(height: 2),
                Text('$count ta mashq xato bilan tugatilgan',
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

class _Tile extends StatelessWidget {
  final _Item item;
  final VoidCallback onDone;
  const _Tile({required this.item, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final e = item.exercise;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExercisePlayer(
                  exercise: e,
                  sectionTitle: item.section.titleUz,
                  unitLabel: item.unit.displayLabel,
                ),
              ),
            );
            // Qaytganda ro'yxat yangilanadi — xatosiz o'tilgan mashq
            // shu yerda qolmasligi kerak.
            onDone();
          },
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.homework.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.replay_rounded,
                      color: AppColors.homework, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      if (e.instructionUz.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(e.instructionUz,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.muted(context))),
                      ],
                      const SizedBox(height: 4),
                      Text(e.locationLabel(item.unit.displayLabel),
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandPurple)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.homework),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
