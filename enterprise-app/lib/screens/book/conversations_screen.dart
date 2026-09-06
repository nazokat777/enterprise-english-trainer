import 'package:flutter/material.dart';

import '../../book_content.dart';
import '../../main.dart';
import '../../theme.dart';
import 'exercise_player.dart';

/// SUHBATLAR — kitobdagi barcha dialoglar bir joyda.
///
/// Menyuda bu band bor edi, lekin bosilganda "keyingi fazalarda"
/// degan bo'sh ekran ochilardi. Kitobda esa 49 ta dialog mashqi
/// bor — ular unitlar bo'ylab tarqalgan va topish qiyin edi.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

/// Gapiruvchi belgisi: "A: ", "Ann: ", "Tom: ".
final RegExp _speaker = RegExp(r'^[A-Z][A-Za-z]{0,9}:\s');

/// Mashq dialogmi? Kamida ikkita gapiruvchili qator bo'lsa — ha.
bool isDialogue(BookExercise e) {
  if (e.kind != ExKind.study) return false;
  var lines = 0;
  for (final t in e.tasks) {
    if (_speaker.hasMatch(t.en.trim())) lines++;
    if (lines >= 2) return true;
  }
  return false;
}

class _Item {
  final BookUnit unit;
  final BookSection section;
  final BookExercise exercise;
  const _Item(this.unit, this.section, this.exercise);
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<_Item>? _items;

  @override
  void initState() {
    super.initState();
    _collect();
  }

  Future<void> _collect() async {
    // Barcha unitlar BIR VAQTDA yuklanadi — birin-ketin yuklash
    // takrorlash ekranida ~20 soniya kutishga olib kelgan edi.
    final loaded =
        await Future.wait(book.units.map((b) => book.load(b.unit)));
    final out = <_Item>[];
    for (final u in loaded) {
      if (u == null) continue;
      for (final s in u.sections) {
        for (final e in s.exercises) {
          if (isDialogue(e)) out.add(_Item(u, s, e));
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return _Header(count: items.length);
        return _Tile(item: items[i - 1]);
      },
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suhbatlar', style: AppTheme.heading(context)),
          const SizedBox(height: 2),
          Text(
            '$count ta dialog — kitobdagi barcha suhbatlar bir joyda. '
            'Har birini tinglang va ovoz chiqarib takrorlang.',
            style:
                TextStyle(fontSize: 12.5, color: AppColors.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final _Item item;
  const _Tile({required this.item});

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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExercisePlayer(
                exercise: e,
                sectionTitle: item.section.titleUz,
                unitLabel: item.unit.displayLabel,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.brandPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.forum_rounded,
                      color: AppColors.brandPurple, size: 20),
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
                    color: AppColors.brandPurple),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
