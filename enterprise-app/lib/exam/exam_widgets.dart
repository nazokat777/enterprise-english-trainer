import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets/pressable3d.dart';
import 'exam.dart';
import 'exam_screen.dart';

/// Eng oxirgi TUGATILGAN asosiy unit (mashqlari to'liq yoki lug'at
/// darslari tugagan). Imtihon shu unitgacha bo'ladi.
int highestCompletedUnit() {
  var best = 0;
  for (final b in book.units) {
    if (b.isInfo || b.unit < 1) continue;
    final done = rewards.unitsCompleted.contains(b.unit) ||
        (b.exercises > 0 && (progress.unitDone[b.unit] ?? 0) >= b.exercises);
    if (done && b.unit > best) best = b.unit;
  }
  return best;
}

/// BOSh EKRAN: "📝 Imtihon: 1-N unitlar" — N tugagach darhol.
///
/// Hech unit tugamagan bo'lsa ko'rinmaydi (bosh ekranni to'ldirmaslik
/// uchun). O'tilgan bo'lsa natija va "qayta topshirish".
class ExamCard extends StatefulWidget {
  const ExamCard({super.key});

  @override
  State<ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<ExamCard> {
  ExamResult? _last;
  int _n = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = highestCompletedUnit();
    final r = n > 0 ? await ExamStore.load(progress.currentLevel, n) : null;
    if (!mounted) return;
    setState(() {
      _n = n;
      _last = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_n == 0) return const SizedBox.shrink();
    final r = _last;
    final passed = r != null && r.passed;
    final color = passed ? AppColors.success : AppColors.brandPurple;
    final subtitle = r == null
        ? '$_n-unit tugadi - endi 1-$_n unitlarning hammasi bo\'yicha sinov. '
            'O\'zlashtirilmagan mavzu qolmasin.'
        : passed
            ? 'O\'tdingiz: ${r.score}%. Xohlasangiz qayta topshiring - '
                'mustahkamlash uchun.'
            : 'Oxirgi natija ${r.score}%, ${r.weakIds.length} ta zaif band. '
                'Qayta ishlab, 90%+ oling.';
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(passed ? '🏅' : '📝', style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Imtihon · 1-$_n unitlar',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: color)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.muted(context))),
                      ],
                    ),
                  ),
                ],
              ),
              if (r != null && !passed && r.weakIds.isNotEmpty) ...[
                const SizedBox(height: 10),
                Pressable3D(
                  color: AppColors.homework,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  onPressed: () => _open(context, onlyIds: r.weakIds.toSet()),
                  child: Center(
                    child: Text(
                        'Zaif ${r.weakIds.length} ta bandni qayta ishlash',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, {Set<String>? onlyIds}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ExamScreen(uptoUnit: _n, onlyIds: onlyIds)),
    );
    _load();
  }
}

/// UNIT EKRANI: "Imtihon 1-N" — istalgan vaqt.
class ExamButton extends StatelessWidget {
  final int unit;
  const ExamButton({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    if (unit < 1) return const SizedBox.shrink();
    return Pressable3D(
      color: AppColors.brandPurple,
      shadowColor: const Color(0xFF5B22B5),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ExamScreen(uptoUnit: unit)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_turned_in_rounded,
              color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              unit == 1
                  ? 'Imtihon · 1-unit'
                  : 'Imtihon · 1-$unit unitlar (yig\'ma)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
