import 'dart:async';

import 'package:flutter/material.dart';

import '../drill/drill_item.dart';
import '../lessons/lesson_screen.dart';
import '../lessons/word_lesson.dart';
import '../main.dart';
import '../memory/memory.dart';
import '../memory/memory_widgets.dart';
import '../screens/book/exercise_player.dart';
import '../services/speech.dart';
import '../speak/pronunciation_screen.dart';
import '../theme.dart';
import '../widgets/hover_lift.dart';
import '../widgets/pressable3d.dart';
import 'hook_lesson_screen.dart';
import 'mnemonic_videos.dart';
import 'peg_screen.dart';
import 'recall_screen.dart';
import 'study_plan.dart';

const _months = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
];

String uzDate(DateTime d) => '${d.day}-${_months[d.month - 1]}';

String durationLabel(int days) => switch (days) {
      365 => '1 yil',
      _ when days % 30 == 0 => '${days ~/ 30} oy',
      _ => '$days kun',
    };

/// Raqamni guruhlab yozadi: 3328 -> "3 328".
String fmt(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// MNEMONIKA bo'limi — kitob hajmi, muddat xaritasi, bugungi cheklist.
class MnemonicsScreen extends StatefulWidget {
  const MnemonicsScreen({super.key});

  @override
  State<MnemonicsScreen> createState() => _MnemonicsScreenState();
}

class _MnemonicsScreenState extends State<MnemonicsScreen> {
  BookVolume? _v;
  StudyPlan? _plan;
  Set<String> _marks = {};
  List<String> _freshIds = const [];
  DateTime? _freshAt;
  bool _loading = true;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    plans.addListener(_load);
    book.addListener(_reset);
    // 10 daqiqalik qaytish vaqti kelganda qator o'zi ochilsin.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    plans.removeListener(_load);
    book.removeListener(_reset);
    super.dispose();
  }

  // Daraja almashsa - boshqa kitob.
  void _reset() => _load();

  Future<void> _load() async {
    final v = await plans.volume();
    final p = await plans.plan();
    final m = await plans.doneToday();
    final f = await plans.fresh();
    if (!mounted) return;
    setState(() {
      _v = v;
      _plan = p;
      _marks = m;
      _freshIds = f.$1;
      _freshAt = f.$2;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    if (_loading || v == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Text('Mnemonika xaritasi', style: AppTheme.heading(context)),
        const SizedBox(height: 2),
        Text(
          '${v.bookTitle} - kitobni belgilangan muddatda yodlab tugatish rejasi',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted(context)),
        ),
        const SizedBox(height: 14),
        _VolumeCard(v: v),
        const SizedBox(height: 14),
        // Rejasi yo'q (yangi) o'quvchiga avval darsliklar - tushunib boshlasin.
        if (_plan == null) ...[
          const MnemonicVideosCard(),
          const SizedBox(height: 14),
        ],
        if (_plan == null)
          _DurationPicker(v: v, onPick: _start)
        else ...[
          _TodayCard(
            v: v,
            plan: _plan!,
            marks: _marks,
            freshIds: _freshIds,
            freshAt: _freshAt,
            onChanged: _load,
          ),
          const SizedBox(height: 14),
          _GrammarCard(v: v, plan: _plan, onChanged: _load),
          const SizedBox(height: 14),
          _UnitMeasureCard(v: v, plan: _plan!),
          const SizedBox(height: 14),
          _Roadmap(v: v, plan: _plan!),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: _changeDuration,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Muddatni o\'zgartirish'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        const _PracticeCard(),
        const SizedBox(height: 10),
        const _MethodCard(),
        if (_plan != null) ...[
          const SizedBox(height: 14),
          const MnemonicVideosCard(),
        ],
      ],
    );
  }

  Future<void> _start(int days, int? hour) async {
    await plans.savePlan(days);
    if (hour != null) await rewards.setCommitHour(hour);
    await _load();
  }

  Future<void> _changeDuration() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Muddatni o\'zgartirasizmi?'),
        content: const Text(
            'O\'rganilgan so\'zlaringiz saqlanadi. Reja qolgan ish bo\'yicha '
            'yangi muddatga qayta taqsimlanadi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Yo\'q')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Ha, o\'zgartirish')),
        ],
      ),
    );
    if (ok == true) await plans.clearPlan();
  }
}

// ═════════════════ Hajm ═════════════════
class _VolumeCard extends StatelessWidget {
  final BookVolume v;
  const _VolumeCard({required this.v});

  @override
  Widget build(BuildContext context) {
    Widget metric(String value, String label, IconData icon, Color c) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                Icon(icon, color: c, size: 20),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900, color: c)),
                ),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.muted(context))),
              ],
            ),
          ),
        );
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kitob hajmi',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            children: [
              metric(fmt(v.uniqueWords), 'noyob so\'z', Icons.translate_rounded,
                  AppColors.brandPurple),
              const SizedBox(width: 8),
              metric(fmt(v.lessons), 'so\'z darsi', Icons.school_rounded,
                  AppColors.actionBlue),
              const SizedBox(width: 8),
              metric(fmt(v.rules), 'grammatika\nqoidasi', Icons.rule_rounded,
                  AppColors.success),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${v.units.length} ta unit · 1 darsda ${v.wordsPerLesson.round()} ta '
            'so\'z · ${fmt(v.grammarExercises)} ta grammatika mashqi. '
            'Unitlarda takrorlanadigan so\'zlar bilan jami ${fmt(v.words)} ta '
            'so\'z uchrashadi.',
            style: TextStyle(
                fontSize: 12.5, height: 1.45, color: AppColors.muted(context)),
          ),
        ],
      ),
    );
  }
}

// ═════════════════ Muddat tanlash ═════════════════
class _DurationPicker extends StatefulWidget {
  final BookVolume v;
  final Future<void> Function(int days, int? hour) onPick;
  const _DurationPicker({required this.v, required this.onPick});

  @override
  State<_DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<_DurationPicker> {
  late int _days = recommendedDays(widget.v);
  int? _hour = 20;

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final rec = recommendedDays(v);
    final now = DateTime.now();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kitobni necha kunda tugatasiz?',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Har muddat uchun kunlik yuk hisoblangan. Takror vaqti ham '
            'kiritilgan - aks holda 3-haftada charchab qolasiz.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted(context)),
          ),
          const SizedBox(height: 12),
          for (final d in kPlanDurations)
            _DurationRow(
              days: d,
              pace: paceFor(v, d),
              finish: now.add(Duration(days: d - 1)),
              selected: _days == d,
              recommended: d == rec,
              onTap: () => setState(() => _days = d),
            ),
          const SizedBox(height: 12),
          const Text('Har kuni qaysi soatda eslatay?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in const [7, 8, 12, 18, 20, 21])
                ChoiceChip(
                  label: Text('$h:00'),
                  selected: _hour == h,
                  onSelected: (_) => setState(() => _hour = h),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Pressable3D(
            color: AppColors.brandPurple,
            shadowColor: const Color(0xFF5B22B5),
            onPressed: () => widget.onPick(_days, _hour),
            child: Center(
              child: Text(
                'Rejani boshlash · ${durationLabel(_days)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationRow extends StatelessWidget {
  final int days;
  final Pace pace;
  final DateTime finish;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  const _DurationRow({
    required this.days,
    required this.pace,
    required this.finish,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  Color get _diffColor => switch (pace.difficulty) {
        'Yengil' => AppColors.success,
        'O\'rtacha' => AppColors.actionBlue,
        'Og\'ir' => AppColors.homework,
        _ => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final c = selected ? AppColors.brandPurple : AppColors.border(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandPurple.withValues(alpha: 0.07)
                : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(durationLabel(days),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kuniga ${pace.wordsPerDay.round()} so\'z · '
                      '${pace.lessonsPerDay.ceil()} dars'
                      '${pace.rulesPerDay >= 0.05 ? ' · ${_rules(pace.rulesPerDay)}' : ''}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '~${pace.minutesPerDay} daqiqa/kun · tugash: ${uzDate(finish)}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.muted(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _diffColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(pace.difficulty,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _diffColor)),
                  ),
                  if (recommended) ...[
                    const SizedBox(height: 4),
                    const Text('Tavsiya',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.brandPurple)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _rules(double perDay) {
    if (perDay >= 1) return '${perDay.round()} qoida';
    final every = (1 / perDay).round();
    return '$every kunda 1 qoida';
  }
}

// ═════════════════ Bugungi cheklist ═════════════════
class _TodayCard extends StatelessWidget {
  final BookVolume v;
  final StudyPlan plan;
  final Set<String> marks;
  final VoidCallback onChanged;

  /// 10 daqiqa oldin o'rganilgan so'zlar (bugun) va vaqti.
  final List<String> freshIds;
  final DateTime? freshAt;

  const _TodayCard({
    required this.v,
    required this.plan,
    required this.marks,
    required this.onChanged,
    this.freshIds = const [],
    this.freshAt,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = buildSchedule(v, plan.days);
    final now = DateTime.now();
    final day = plan.dayIndex(now);
    final status = planStatus(schedule, day, plans.isDone);
    final items = todayItems(schedule, day, plans.isDone);
    final lessons = items.where((e) => e.kind == PlanKind.lesson).toList();
    final lessonsDone = lessons.where(plans.isDone).length;
    final fading = mastery.fadingCount();
    final evening = MemoryRescue.isEvening(now) && MemoryRescue.tonight(mastery) != null;

    final rows = <_CheckRow>[
      _CheckRow(
        emoji: '🆕',
        title: 'Yangi so\'zlar',
        subtitle: lessons.isEmpty
            ? 'Bugungi darslar yo\'q'
            : '${lessons.length} ta dars · ~${fmt(lessons.length * v.wordsPerLesson)} so\'z '
                '($lessonsDone/${lessons.length} bajarildi). Ilgak darsi: har so\'zga '
                'o\'xshash o\'zbekcha so\'z + sahna, keyin yopib eslaysiz.',
        done: lessons.isNotEmpty && lessonsDone == lessons.length,
        action: lessons.every(plans.isDone)
            ? null
            : () => _openLesson(context,
                lessons.firstWhere((e) => !plans.isDone(e))),
      ),
      if (freshAt != null) _tenMinuteRow(context, now),
      _CheckRow(
        emoji: '🔁',
        title: 'Oraliqli takror',
        subtitle: fading == 0
            ? 'Bugun unutilayotgan so\'z yo\'q - xotira joyida.'
            : '$fading ta so\'z unutilish arafasida (1-3-7-14-30 kun jadvali).',
        done: fading == 0,
        action: fading == 0
            ? null
            : () => _track(context, 'review', MemoryRescueCard.startRescue),
      ),
      _CheckRow(
        emoji: '🧠',
        title: 'O\'zbekchasidan inglizchasini toping',
        subtitle: lessonsDone == 0
            ? 'Avval yangi so\'zlarni o\'ting - keyin yopib eslaysiz.'
            : 'Qaramasdan eslash: o\'zbekcha ko\'rinadi, inglizchasini o\'zingiz '
                'topasiz va yozasiz (eng kuchli usul).',
        done: marks.contains('recall'),
        action: lessonsDone == 0 || marks.contains('recall')
            ? null
            : () => _track(context, 'recall', (c) => _openRecall(c, lessons)),
      ),
      if (Speech.supported)
        _CheckRow(
          emoji: '🗣️',
          title: 'Ovoz chiqarib ayting',
          subtitle: 'Og\'iz xotirasi: aytilgan so\'z 2 barobar mustahkam qoladi.',
          done: marks.contains('speak'),
          action: marks.contains('speak')
              ? null
              : () => _track(context, 'speak', (c) => Navigator.push(
                  c,
                  MaterialPageRoute(
                      builder: (_) => const PronunciationScreen()))),
        ),
      _CheckRow(
        emoji: '🌙',
        title: 'Uxlashdan oldin 1 daqiqa',
        subtitle: evening
            ? 'Uyqu xotirani mustahkamlaydi - bugungi so\'zlarni bir ko\'rib oling.'
            : 'Kechqurun 20:00 dan keyin ochiladi.',
        done: marks.contains('night'),
        optional: !evening,
        action: !evening || marks.contains('night')
            ? null
            : () => _track(context, 'night', _openTonight),
      ),
    ];
    final counted = rows.where((r) => !r.optional).toList();
    // MINIMAL PLANKA: "eng yomon kunda ham" - 1 dars. Zanjir uzilmaydi.
    final minimalDone = lessonsDone > 0 || marks.isNotEmpty;
    final doneCount = counted.where((r) => r.done).length;

    final behind = status.behind;
    final statusText = behind > 0
        ? '$behind ta band ortda - bugun ular ham qo\'shildi, jazo yo\'q.'
        : behind < 0
            ? 'Rejadan ${-behind} ta band OLDINDASIZ!'
            : 'Reja bo\'yicha ketyapsiz.';

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${day + 1}-kun / ${plan.days}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(
                      'Tugash: ${uzDate(plan.finishDate)} · '
                      '${status.done} / ${status.total} band bajarildi',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.muted(context)),
                    ),
                  ],
                ),
              ),
              _Ring(done: doneCount, total: counted.length),
            ],
          ),
          const SizedBox(height: 6),
          Text(statusText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: behind > 0 ? AppColors.homework : AppColors.success,
              )),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: (minimalDone ? AppColors.success : AppColors.coin)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              minimalDone
                  ? 'Minimal planka bajarildi - bugun zanjir uzilmadi.'
                  : "Vaqt yo'qmi? Eng kamida 1 ta dars (~5 daqiqa) - zanjirni "
                      "uzmang. Har kuni oz - haftada bir ko'pdan kuchli.",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: minimalDone ? AppColors.success : AppColors.homework,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Bugungi cheklist',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 6),
          for (final r in rows) r,
        ],
      ),
    );
  }

  /// 10 DAQIQADAN KEYIN ESLASH - yangi so'zlarni birinchi marta qaytarish.
  _CheckRow _tenMinuteRow(BuildContext context, DateTime now) {
    final at = freshAt!;
    final id = 'tenmin::${at.millisecondsSinceEpoch}';
    final left = at.add(const Duration(minutes: 10)).difference(now);
    final ready = left.isNegative || left.inSeconds == 0;
    final done = marks.contains(id);
    return _CheckRow(
      emoji: '⏱️',
      title: '10 daqiqadan keyin eslash',
      subtitle: done
          ? 'Bajarildi - endi 1 kundan keyin qaytadi.'
          : ready
              ? "Hozirgina o'rgangan ${freshIds.length} ta so'zni yopib eslang. "
                  'Birinchi qaytish - eng muhimi.'
              : '${left.inMinutes + 1} daqiqadan keyin ochiladi (unutish egri '
                  "chizig'i eng tik joyida).",
      done: done,
      optional: !ready && !done,
      action: done || !ready
          ? null
          : () => _track(context, id, (c) => _openFresh(c)),
    );
  }

  Future<void> _openFresh(BuildContext context) async {
    final src = <DrillSource>[];
    final ids = freshIds.toSet();
    final schedule = buildSchedule(v, plan.days);
    for (final day in schedule) {
      for (final it in day) {
        if (it.kind != PlanKind.lesson || !it.itemIds.any(ids.contains)) continue;
        final l = plans.lessonOf(it);
        if (l != null) src.addAll(l.sources.where((s) => ids.contains(s.itemId)));
      }
    }
    if (src.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecallScreen(
          title: '10 daqiqadan keyin eslash',
          words: src,
        ),
      ),
    );
  }

  /// Faoliyat tugadimi - `rewards.exercisesDone` o'sganidan bilinadi.
  Future<void> _track(BuildContext context, String id,
      Future<void> Function(BuildContext) open) async {
    final before = rewards.exercisesDone;
    await open(context);
    if (rewards.exercisesDone > before) await plans.markToday(id);
    onChanged();
  }

  /// Yangi so'zlar: AVVAL ilgak darsi (mnemonika amalda: ilgak, sahna,
  /// tasavvur, yopib eslash), keyin mustahkamlash darsi (4 shakl).
  Future<void> _openLesson(BuildContext context, PlanItem it) async {
    final l = plans.lessonOf(it);
    final u = plans.unitOf(it.unit);
    if (l == null || u == null) return;
    var goOn = false;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HookLessonScreen(
          lesson: l,
          unitLabel: u.displayLabel,
          onFinished: () => goOn = true,
        ),
      ),
    );
    // Ilgak darsi o'tildi - 10 daqiqadan keyin qaytarish uchun eslab qolamiz.
    if (goOn) await plans.rememberFresh(l.itemIds);
    if (goOn && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LessonScreen(
            lesson: l,
            unitLabel: u.displayLabel,
            pool: sourcesFromUnit(u),
          ),
        ),
      );
    }
    onChanged();
  }

  Future<void> _openRecall(BuildContext context, List<PlanItem> lessons) async {
    final src = <DrillSource>[];
    for (final it in lessons.where(plans.isDone)) {
      final l = plans.lessonOf(it);
      if (l != null) src.addAll(l.sources);
    }
    if (src.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecallScreen(
          title: 'O\'zbekchasidan inglizchasini toping',
          words: src,
        ),
      ),
    );
  }

  static Future<void> _openTonight(BuildContext context) async {
    final l = MemoryRescue.tonight(mastery);
    if (l == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          lesson: l,
          unitLabel: '🌙 Uxlashdan oldin',
          rescue: true,
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final int done;
  final int total;
  const _Ring({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final r = total == 0 ? 0.0 : done / total;
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: r,
            strokeWidth: 5,
            strokeCap: StrokeCap.round,
            backgroundColor: AppColors.success.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(AppColors.success),
          ),
          Text('$done/$total',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool done;
  final bool optional;
  final VoidCallback? action;

  const _CheckRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.done,
    this.optional = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
          decoration: BoxDecoration(
            color: done
                ? AppColors.success.withValues(alpha: 0.08)
                : AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: done
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.border(context)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: done ? AppColors.success : muted,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: optional ? muted : null,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, height: 1.4, color: muted)),
                  ],
                ),
              ),
              if (action != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 2),
                  child: Icon(Icons.play_circle_fill_rounded,
                      color: AppColors.brandPurple, size: 26),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Qoida bo'limini ochadi (o'qish + mashq).
Future<void> openRule(BuildContext context, PlanItem it) async {
  final s = plans.ruleSection(it);
  final u = plans.unitOf(it.unit);
  if (s == null || s.exercises.isEmpty) return;
  final first = s.exercises.firstWhere(
      (e) => !progress.isDone(e.progressId),
      orElse: () => s.exercises.first);
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ExercisePlayer(
        exercise: first,
        sectionTitle: s.titleUz.isNotEmpty ? s.titleUz : s.title,
        unitLabel: u?.displayLabel ?? '',
        siblings: s.exercises,
      ),
    ),
  );
}

// ═════════════════ GRAMMATIKA - alohida yo'l ═════════════════
/// Grammatika so'zlardan ALOHIDA: o'z hajmi va foizi, bugungi qoida(lar),
/// barcha qoidalar unitlar bo'yicha (bajarilgani belgilangan). Reja
/// kunlariga teng taqsimlangan; ortda qolgani bugunga qo'shiladi.
class _GrammarCard extends StatefulWidget {
  final BookVolume v;
  final StudyPlan? plan;
  final VoidCallback onChanged;
  const _GrammarCard(
      {required this.v, required this.plan, required this.onChanged});

  @override
  State<_GrammarCard> createState() => _GrammarCardState();
}

class _GrammarCardState extends State<_GrammarCard> {
  bool _all = false;

  Future<void> _open(PlanItem it) async {
    await openRule(context, it);
    widget.onChanged();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final muted = AppColors.muted(context);
    final rules = planItems(v).where((e) => e.kind == PlanKind.rule).toList();
    final done = rules.where(plans.isDone).length;
    final p = widget.plan;
    final today = <PlanItem>[];
    if (p != null) {
      final s = buildSchedule(v, p.days);
      today.addAll(todayItems(s, p.dayIndex(DateTime.now()), plans.isDone)
          .where((e) => e.kind == PlanKind.rule));
    }
    final perDay = p == null ? null : paceFor(v, p.days).rulesPerDay;

    Widget ruleRow(PlanItem r, {bool showUnit = false}) {
      final ok = plans.isDone(r);
      return InkWell(
        onTap: () => _open(r),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 20, color: ok ? AppColors.success : muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  showUnit ? '${r.unit}-unit · ${r.title}' : r.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    decoration: ok ? TextDecoration.lineThrough : null,
                    color: ok ? muted : null,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: muted),
            ],
          ),
        ),
      );
    }

    final byUnit = <int, List<PlanItem>>{};
    for (final r in rules) {
      (byUnit[r.unit] ??= []).add(r);
    }

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📐', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Grammatika',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              Text('$done / ${rules.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "${rules.length} ta qoida · ${fmt(v.grammarExercises)} ta mashq"
            "${perDay == null ? '' : ' · ${_rulePace(perDay)}'}. So'zlardan "
            "alohida: qoidani o'qing, misolni ovoz chiqarib ayting, o'z "
            "gapingizni tuzing, mashqni bajaring.",
            style: TextStyle(fontSize: 12.5, height: 1.45, color: muted),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: rules.isEmpty ? 0 : done / rules.length,
              minHeight: 6,
              backgroundColor: AppColors.success.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          if (p != null) ...[
            const SizedBox(height: 12),
            const Text('Bugungi qoida',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(height: 2),
            if (today.isEmpty)
              Text("Bugun yangi qoida yo'q - so'zlarga e'tibor bering.",
                  style: TextStyle(fontSize: 12.5, color: muted))
            else
              for (final r in today) ruleRow(r, showUnit: true),
          ],
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _all = !_all),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                        _all
                            ? 'Yopish'
                            : "Barcha qoidalar (unitlar bo'yicha)",
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandPurple)),
                  ),
                  Icon(
                      _all
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.brandPurple),
                ],
              ),
            ),
          ),
          if (_all)
            for (final e in byUnit.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Text(
                    '${e.key}-unit · ${e.value.where(plans.isDone).length}/${e.value.length}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: muted)),
              ),
              for (final r in e.value) ruleRow(r),
            ],
        ],
      ),
    );
  }

  static String _rulePace(double perDay) {
    if (perDay >= 1) return 'kuniga ${perDay.round()} ta';
    return '${(1 / perDay).round()} kunda 1 ta';
  }
}

// ═════════════════ Unit oldi / keyingi o'lchov ═════════════════
/// "Avval test -> usul -> qayta test": o'quvchi o'sishni RAQAMDA ko'radi.
/// Har unitdan 10 ta so'z (darslar bo'ylab teng tanlangan - har safar bir
/// xil), unit boshida va tugagach yopib eslanadi.
class _UnitMeasureCard extends StatefulWidget {
  final BookVolume v;
  final StudyPlan plan;
  const _UnitMeasureCard({required this.v, required this.plan});

  @override
  State<_UnitMeasureCard> createState() => _UnitMeasureCardState();
}

class _UnitMeasureCardState extends State<_UnitMeasureCard> {
  String? _pre, _post;
  int? _unit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? _currentUnit() {
    final s = buildSchedule(widget.v, widget.plan.days);
    final today = widget.plan.dayIndex(DateTime.now());
    for (var d = today; d < s.length; d++) {
      for (final it in s[d]) {
        if (!plans.isDone(it)) return it.unit;
      }
    }
    return s.isNotEmpty && s[today].isNotEmpty ? s[today].first.unit : null;
  }

  Future<void> _load() async {
    final u = _currentUnit();
    if (u == null) return;
    final r = await plans.unitTests(u);
    if (!mounted) return;
    setState(() {
      _unit = u;
      _pre = r.$1;
      _post = r.$2;
    });
  }

  List<DrillSource> _sample(int unit) {
    final bu = plans.unitOf(unit);
    if (bu == null) return const [];
    final all = [for (final l in lessonsOf(bu)) ...l.sources];
    if (all.length <= 10) return all;
    final step = all.length / 10;
    return [for (var i = 0; i < 10; i++) all[(i * step).floor()]];
  }

  Future<void> _run(bool post) async {
    final u = _unit;
    if (u == null) return;
    final words = _sample(u);
    if (words.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecallScreen(
          title: post ? 'Unit yakuni o\'lchovi' : 'Unit oldi o\'lchovi',
          words: words,
          measure: true,
          onScore: (c, t) => plans.saveUnitTest(u, post, c, t),
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final u = _unit;
    if (u == null) return const SizedBox.shrink();
    final uv = widget.v.units.where((e) => e.unit == u).firstOrNull;
    if (uv == null) return const SizedBox.shrink();
    final unitDone = uv.lessons.every((l) => l.isNotEmpty && mastery.allStrong(l));
    final muted = AppColors.muted(context);

    String text;
    String? button;
    VoidCallback? onTap;
    if (_pre == null) {
      text = '${uv.label}ni boshlashdan OLDIN: shu unitdagi 10 ta so\'zdan '
          'nechtasini bilasiz? Tugagach qayta o\'lchaymiz - o\'sishni ko\'rasiz.';
      button = 'Oldingi o\'lchov (1 daqiqa)';
      onTap = () => _run(false);
    } else if (_post == null && unitDone) {
      text = '${uv.label} tugadi! Boshida $_pre edi. Endi o\'sha so\'zlarni '
          'qayta tekshiramiz.';
      button = 'Yakuniy o\'lchov';
      onTap = () => _run(true);
    } else if (_post == null) {
      text = '${uv.label}: boshida $_pre. Unit tugagach yakuniy o\'lchov ochiladi.';
    } else {
      int n(String s) => int.tryParse(s.split('/').first) ?? 0;
      final grow = n(_post!) - n(_pre!);
      text = '${uv.label}: oldin $_pre  ->  keyin $_post'
          '${grow > 0 ? '  (+$grow so\'z!)' : ''}';
    }
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📏', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Unit o\'lchovi',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(fontSize: 13, height: 1.45, color: muted)),
          if (button != null) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.timer_outlined, size: 18),
              label: Text(button),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════ Xarita (unitlar bo'yicha) ═════════════════
class _Roadmap extends StatelessWidget {
  final BookVolume v;
  final StudyPlan plan;
  const _Roadmap({required this.v, required this.plan});

  @override
  Widget build(BuildContext context) {
    final schedule = buildSchedule(v, plan.days);
    final today = plan.dayIndex(DateTime.now());
    // Har unit qaysi kunlarga tushadi.
    final first = <int, int>{}, last = <int, int>{};
    for (var d = 0; d < schedule.length; d++) {
      for (final it in schedule[d]) {
        first.putIfAbsent(it.unit, () => d);
        last[it.unit] = d;
      }
    }
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Xarita',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 2),
          Text('Qaysi unit qaysi kunlarda o\'tiladi',
              style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
          const SizedBox(height: 10),
          for (final u in v.units)
            _RoadRow(
              u: u,
              fromDay: first[u.unit],
              toDay: last[u.unit],
              today: today,
              start: plan.startDate,
            ),
        ],
      ),
    );
  }
}

class _RoadRow extends StatelessWidget {
  final UnitVolume u;
  final int? fromDay;
  final int? toDay;
  final int today;
  final DateTime start;

  const _RoadRow({
    required this.u,
    required this.fromDay,
    required this.toDay,
    required this.today,
    required this.start,
  });

  @override
  Widget build(BuildContext context) {
    final done = u.lessons.where((l) => l.isNotEmpty && mastery.allStrong(l)).length;
    final ratio = u.lessons.isEmpty ? 0.0 : done / u.lessons.length;
    final current = fromDay != null &&
        toDay != null &&
        today >= fromDay! &&
        today <= toDay!;
    final c = ratio >= 1
        ? AppColors.success
        : current
            ? AppColors.brandPurple
            : AppColors.muted(context);
    final range = fromDay == null
        ? ''
        : fromDay == toDay
            ? '${fromDay! + 1}-kun'
            : '${fromDay! + 1}-${toDay! + 1}-kun';
    final dates = fromDay == null
        ? ''
        : ' (${uzDate(start.add(Duration(days: fromDay!)))} - '
            '${uzDate(start.add(Duration(days: toDay!)))})';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: current ? Border.all(color: c, width: 2) : null,
            ),
            child: ratio >= 1
                ? Icon(Icons.check_rounded, color: c, size: 18)
                : Text('${u.unit}',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: c, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${u.label} · ${u.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                ),
                Text(
                  '$range$dates · ${u.words} so\'z · ${u.lessons.length} dars · '
                  '${u.rules.length} qoida',
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.muted(context)),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: c.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(c),
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

// ═════════════════ Amaliy mashq ═════════════════
class _PracticeCard extends StatelessWidget {
  const _PracticeCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const PegScreen())),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mnemonikani sinab ko\'ring (10 daqiqa)',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(
                  'Qarmoq usuli: avval oddiy usulda 10 so\'z, keyin usul bilan '
                  '- natija necha barobar oshganini o\'zingiz ko\'rasiz.',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.muted(context)),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

// ═════════════════ Usul (nega ishlaydi) ═════════════════
class _MethodCard extends StatefulWidget {
  const _MethodCard();

  @override
  State<_MethodCard> createState() => _MethodCardState();
}

class _MethodCardState extends State<_MethodCard> {
  bool _open = false;

  static const _steps = [
    ('1. Hajm', 'Kitobda nechta so\'z va qoida borligini bilasiz - "ko\'p" emas, aniq raqam. Reja shu raqamdan tuziladi.'),
    ('2. Ilgak', 'Yangi so\'zni tovushi o\'xshash o\'zbekcha so\'zga ilang: book -> buqa, kettle -> katta, bucket -> buket. Birinchi bo\'g\'in yetadi.'),
    ('3. Obraz', 'Bitta sahnada tovush ham, ma\'no ham bo\'lsin: "buqa ko\'zoynak taqib kitob o\'qiyapti". G\'alati, harakatli, katta - miya zerikarlisini saqlamaydi.'),
    ('4. Yopib eslash', 'O\'qib takrorlash emas - yopib, o\'zingiz eslash. Xato - signal: shu so\'z qaytadi.'),
    ('5. Ikki tomon', 'Inglizchadan tanish - tushunish; o\'zbekchadan inglizchasini topish - gapirish. Ikkalasi ham mashq qilinadi.'),
    ('6. Oraliqli takror', '1 -> 3 -> 7 -> 14 -> 30 kun. So\'z unutilish arafasida qaytadi - takror soni kam, natija uzoq.'),
    ('7. Qo\'llash', 'Gap ichida, ovoz chiqarib, suhbatda. So\'z ishlatilgandagina "sizniki" bo\'ladi.'),
  ];

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Nega bu usul ishlaydi? (7 qadam)',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 14)),
                ),
                Icon(_open
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 10),
            for (final (t, d) in _steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(d,
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: AppColors.muted(context))),
                  ],
                ),
              ),
            Text(
              'Manba: xotira bo\'yicha tadqiqotlar (Ebbinghaus 1885, Atkinson 1975, '
              'Roediger & Karpicke 2006). Kuniga yuzlab so\'z va\'da qilinmaydi - '
              'barqaror sur\'at muhimroq.',
              style: TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: AppColors.muted(context)),
            ),
          ],
        ],
      ),
    );
  }
}
