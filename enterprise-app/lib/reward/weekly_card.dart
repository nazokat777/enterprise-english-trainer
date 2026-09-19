import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../theme.dart';

/// HAFTALIK HISOBOT — dushanba (yoki haftaning birinchi ochilishi)da
/// o'tgan 7 kun: XP, faol kunlar, eng yaxshi kun, o'tgan haftaga
/// nisbatan o'sish. 7 ustunli mini-grafik.
///
/// Psixologiya: o'z-o'zi bilan taqqoslash (self-referential progress)
/// liderjadvalsiz ham motivatsiya beradi; "o'tgan haftadan +40%" —
/// aniq, ko'rinadigan o'sish. Bir hafta bir marta ko'rsatiladi,
/// yopilsa qayta chiqmaydi.
class WeeklyCard extends StatefulWidget {
  const WeeklyCard({super.key});

  static String weekKey(DateTime d) {
    // ISO hafta boshi (dushanba) sanasi — kalit.
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// O'tgan hafta (dushanba..yakshanba) XP lari, 7 ta.
  static List<int> lastWeek(Map<String, int> dayXp, DateTime now) {
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1 + 7));
    return [
      for (var i = 0; i < 7; i++)
        dayXp[_fmt(monday.add(Duration(days: i)))] ?? 0,
    ];
  }

  static List<int> weekBefore(Map<String, int> dayXp, DateTime now) {
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1 + 14));
    return [
      for (var i = 0; i < 7; i++)
        dayXp[_fmt(monday.add(Duration(days: i)))] ?? 0,
    ];
  }

  @override
  State<WeeklyCard> createState() => _WeeklyCardState();
}

class _WeeklyCardState extends State<WeeklyCard> {
  bool _dismissed = true;

  String get _key => 'weekly_seen::${WeeklyCard.weekKey(DateTime.now())}';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _dismissed = p.getBool(_key) ?? false);
    });
  }

  Future<void> _close() async {
    setState(() => _dismissed = true);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
  }

  static const _days = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final now = DateTime.now();
    final week = WeeklyCard.lastWeek(rewards.dayXp, now);
    final prev = WeeklyCard.weekBefore(rewards.dayXp, now);
    final total = week.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    final prevTotal = prev.fold(0, (a, b) => a + b);
    final active = week.where((v) => v > 0).length;
    final best = week.indexOf(week.reduce((a, b) => a > b ? a : b));
    final maxV = week.reduce((a, b) => a > b ? a : b);
    final delta = prevTotal == 0 ? null : ((total - prevTotal) * 100 / prevTotal).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4C1D95)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.glow(AppColors.brandIndigo, alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📈', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('O\'tgan hafta hisoboti',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _close,
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Num(label: 'XP', value: '$total'),
              _Num(label: 'faol kun', value: '$active/7'),
              _Num(label: 'eng yaxshi', value: _days[best]),
              if (delta != null)
                _Num(
                  label: 'o\'tgan haftaga',
                  value: '${delta >= 0 ? '+' : ''}$delta%',
                  color: delta >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 62,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: maxV == 0 ? 0 : week[i] / maxV),
                            duration: Duration(milliseconds: 500 + 80 * i),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => Container(
                              height: 4 + 36 * v,
                              decoration: BoxDecoration(
                                color: i == best
                                    ? AppColors.coin
                                    : Colors.white.withValues(alpha: week[i] > 0 ? 0.85 : 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_days[i],
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.8))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Num extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Num({required this.label, required this.value, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75), fontSize: 10.5)),
          ],
        ),
      );
}
