import 'dart:math';
import 'package:flutter/material.dart';

import '../../book_content.dart';
import '../../drill/drill_item.dart';
import '../../drill/drill_screen.dart';
import '../../lessons/lessons_screen.dart';
import '../../lessons/word_lesson.dart';
import '../../main.dart';
import '../../exam/exam_widgets.dart';
import '../../memory/memory_widgets.dart';
import '../../reward/weekly_card.dart';
import '../../widgets/hover_lift.dart';
import '../../reward/companion.dart';
import '../../reward/reward_widgets.dart';
import '../../theme.dart';
import '../../widgets/entrance.dart';
import '../../widgets/pressable3d.dart';
import 'book_page_viewer.dart';
import 'exercise_player.dart';
import 'reference_screens.dart';
import 'review_screen.dart';

/// Bo'lim turiga mos rang va belgi.
///
/// DIQQAT: eksportda 24 xil bo'lim turi bor. Ilgari bu ro'yxatda faqat
/// 13 tasi sanalgan edi va qolgan 160 ta bo'lim ma'nosiz kulrang doira
/// belgisini olardi (eng ko'pi — `reference` 73 ta, `test` 35 ta).
({IconData icon, Color color}) sectionStyle(
  BuildContext context,
  String kind,
) => switch (kind) {
  'lead_in' => (icon: Icons.flag_rounded, color: AppColors.brandPurple),
  'vocabulary' => (icon: Icons.menu_book_rounded, color: AppColors.brandPurple),
  'reading' => (icon: Icons.article_rounded, color: AppColors.actionBlue),
  'grammar_theory' => (icon: Icons.rule_rounded, color: AppColors.actionBlue),
  'grammar' => (icon: Icons.edit_note_rounded, color: AppColors.actionBlue),
  'grammar_exercise' => (
    icon: Icons.fact_check_rounded,
    color: AppColors.actionBlue,
  ),
  'language_development' => (
    icon: Icons.translate_rounded,
    color: AppColors.actionBlue,
  ),
  'practice' => (
    icon: Icons.model_training_rounded,
    color: AppColors.actionBlue,
  ),
  'pronunciation' => (
    icon: Icons.record_voice_over_rounded,
    color: AppColors.homework,
  ),
  'listening' => (icon: Icons.headphones_rounded, color: AppColors.homework),
  'video' => (icon: Icons.play_circle_rounded, color: AppColors.homework),
  'speaking' => (icon: Icons.mic_rounded, color: AppColors.success),
  'communication' => (icon: Icons.forum_rounded, color: AppColors.coin),
  'game' => (icon: Icons.sports_esports_rounded, color: AppColors.success),
  'quiz' => (icon: Icons.quiz_rounded, color: AppColors.success),
  'culture' => (icon: Icons.public_rounded, color: AppColors.success),
  'writing' => (icon: Icons.draw_rounded, color: AppColors.brandPurple),
  'story' => (icon: Icons.auto_stories_rounded, color: AppColors.brandPurple),
  'reference' => (icon: Icons.bookmark_rounded, color: AppColors.brandPurple),
  'module_cover' => (
    icon: Icons.collections_bookmark_rounded,
    color: AppColors.brandPurple,
  ),
  'revision' => (icon: Icons.replay_rounded, color: AppColors.brandPurple),
  'test' => (
    icon: Icons.assignment_turned_in_rounded,
    color: AppColors.homework,
  ),
  'words_of_wisdom' ||
  'wisdom' => (icon: Icons.auto_awesome_rounded, color: AppColors.coin),
  _ => (icon: Icons.circle_outlined, color: AppColors.muted(context)),
};

// ═══════════════════ Unit'lar ro'yxati ═══════════════════
class BookUnitsScreen extends StatefulWidget {
  const BookUnitsScreen({super.key});

  @override
  State<BookUnitsScreen> createState() => _BookUnitsScreenState();
}

class _BookUnitsScreenState extends State<BookUnitsScreen> {
  @override
  void initState() {
    super.initState();
    // Sessiya yakuni — bosh ekranga qaytilganda bir marta (peak-end).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SessionRecapDialog.showIfPending(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final units = book.units;
    final main = units.where((u) => !u.isInfo).toList();
    final info = units.where((u) => u.isInfo).toList();
    if (units.isEmpty) {
      return const _Empty(
        icon: Icons.menu_book_rounded,
        title: 'Kitob kontenti hali yuklanmagan',
        subtitle: 'Sahifalar qayta ishlangach shu yerda paydo bo\'ladi.',
      );
    }
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          EntranceFade(
            child: Text(
              'Enterprise 1 — Beginner',
              style: AppTheme.heading(context),
            ),
          ),
          const SizedBox(height: 4),
          EntranceFade(
            child: Text(
              '${units.length} ta dars tayyor · har biri uchala kitobdan yig\'ilgan',
              style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
            ),
          ),
          const SizedBox(height: 16),
          // HERO birinchi — bitta qaror: "boshlash". Boshlash
          // ishqalanishi (friction) eng katta to'siq: qaysi unit, qaysi
          // mashq deb o'ylamasdan 3 daqiqalik trening.
          const EntranceFade(child: _HomeHero()),
          const SizedBox(height: 10),
          const EntranceFade(child: CommitCard()),
          // Avatar — hissiy bog'lanish, hero'dan keyin.
          const EntranceFade(child: MascotCard()),
          const SizedBox(height: 10),
          // Haftalik hisobot — haftada bir marta, yopiladi.
          const EntranceFade(child: WeeklyCard()),
          const EntranceFade(child: BlitzCard()),
          if (mastery.learnedWords(limit: 8).length >= 8)
            const SizedBox(height: 10),
          // O'ChIB KETAYoTGAN SO'ZLAR — kunlik topshiriqdan ham oldin:
          // unutish egri chizig'i kutmaydi.
          const EntranceFade(child: MemoryRescueCard()),
          const SizedBox(height: 10),
          // YIG'MA IMTIHON — unit tugagach 1..N.
          const EntranceFade(child: ExamCard()),
          if (highestCompletedUnit() > 0) const SizedBox(height: 10),
          const EntranceFade(child: StreakDangerCard()),
          if (rewards.idleToday && progress.currentStreak > 0)
            const SizedBox(height: 10),
          const EntranceFade(child: DailyQuestsCard()),
          const SizedBox(height: 10),
          EntranceFade(
            child: SpinCard(onSpin: () => SpinWheelDialog.show(context)),
          ),
          if (!rewards.spinDoneToday) const SizedBox(height: 10),
          const EntranceFade(child: ActivityHeatmap()),
          const SizedBox(height: 14),
          // Xato bilan tugatilgan mashqlar bir joyda — aks holda
          // "takrorlash kerak" belgisini 1545 mashq orasidan qidirish
          // kerak bo'lardi va u amalda hech kimga ko'rinmasdi.
          if (progress.lastExerciseId.isNotEmpty) ...[
            const EntranceFade(child: _ContinueBanner()),
            const SizedBox(height: 10),
          ],
          if (progress.needsReviewCount() > 0) ...[
            EntranceFade(
              child: _ReviewBanner(count: progress.needsReviewCount()),
            ),
            const SizedBox(height: 16),
          ],
          // ASOSIY YO'L — darslar. Muqova, mundarija, modul muqovalari
          // dars EMAS: ular pastda, yig'ilgan holda. O'quvchi kitob
          // haqidagi ma'lumotda uzoq qolib ketmasin — 1-unitdan boshlasin.
          for (var i = 0; i < main.length; i++)
            EntranceFade(
              delay: Duration(milliseconds: 60 * (i < 10 ? i : 10)),
              child: _UnitCard(brief: main[i]),
            ),
          if (info.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoGroup(units: info),
          ],
        ],
      ),
    );
  }
}

/// Kitob haqidagi bo'limlar — bitta yig'ma karta.
class _InfoGroup extends StatelessWidget {
  final List<UnitBrief> units;
  const _InfoGroup({required this.units});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(
            Icons.info_outline_rounded,
            color: AppColors.actionBlue,
          ),
          title: const Text(
            'Kitob haqida',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          subtitle: Text(
            'Muqova, mundarija, modul muqovalari va ilovalar · ${units.length} bo\'lim',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted(context)),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          children: [
            for (final b in units)
              ListTile(
                dense: true,
                leading: Text(
                  b.displayBadge,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.actionBlue,
                  ),
                ),
                title: Text(
                  b.displayLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  b.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final u = await book.load(b.unit);
                  if (u == null || !context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BookUnitScreen(unit: u)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// DAVOM ETISH — oxirgi ochilgan mashqqa bir bosishda qaytish.
///
/// 51 unit va 1545 mashq ichida o'quvchi qayerda qolganini O'ZI
/// eslab qolishi kerak edi: qaysi unit, qaysi bo'lim, nechanchi
/// mashq. Xotirasi yomon odam uchun bu eng katta to'siq edi.
class _ContinueBanner extends StatelessWidget {
  const _ContinueBanner();

  /// Mashqni topib ochadi. Faqat BITTA unit yuklanadi — tez.
  Future<void> _open(BuildContext context) async {
    final u = await book.load(progress.lastUnitNo);
    if (u == null) return;
    for (final s in u.sections) {
      for (final e in s.exercises) {
        if (e.progressId != progress.lastExerciseId) continue;
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExercisePlayer(
              exercise: e,
              sectionTitle: s.titleUz,
              unitLabel: u.displayLabel,
              siblings: s.exercises,
            ),
          ),
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandPurple.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.brandPurple,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Davom etish',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.brandPurple,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress.lastLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.brandPurple,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "So'zlarni o'rganish" — unit lug'atini kichik darslarda yodlatish.
class _WordsButton extends StatelessWidget {
  final BookUnit unit;
  const _WordsButton({required this.unit});

  @override
  Widget build(BuildContext context) {
    final lessons = lessonsOf(unit);
    if (lessons.isEmpty) return const SizedBox.shrink();
    final done = lessons.where((l) => mastery.allStrong(l.itemIds)).length;
    final words = lessons.fold(0, (s, l) => s + l.words.length);
    return BentoTile(
      gradient: AppColors.brandGradient,
      icon: Icons.school_rounded,
      title: done >= lessons.length
          ? 'So\'zlar o\'rganildi'
          : 'So\'zlarni o\'rganish',
      subtitle: '$words ta so\'z · ${lessons.length} dars',
      progress: lessons.isEmpty ? 0 : done / lessons.length,
      progressLabel: '$done/${lessons.length}',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LessonsScreen(unit: unit)),
      ),
    );
  }
}

/// "Trening" tugmasi — o'zlashtirish seansini boshlaydi.
class _MasterButton extends StatelessWidget {
  final BookUnit unit;
  const _MasterButton({required this.unit});

  Future<void> _start(BuildContext context) async {
    final lessonSrc = sourcesFromUnit(unit);
    if (lessonSrc.isEmpty) return;

    // ARALASh bosqich uchun shu darsGAChA bo'lgan darslar.
    final earlier = <DrillSource>[];
    for (final b in book.units) {
      if (b.unit >= unit.unit) continue;
      final u = await book.load(b.unit);
      if (u != null) earlier.addAll(sourcesFromUnit(u));
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillScreen(
          title: '${unit.displayLabel} — trening',
          lessonSources: lessonSrc,
          earlierSources: earlier,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = sourcesFromUnit(unit).map((e) => e.itemId).toList();
    final ratio = mastery.ratio(ids);
    final pct = (ratio * 100).round();
    return BentoTile(
      gradient: AppColors.successGradient,
      icon: Icons.psychology_rounded,
      title: pct >= 100 ? 'Trening - takrorlash' : 'Mashqlar treningi',
      subtitle: '${ids.length} band · 100% gacha qaytadi',
      progress: ratio,
      progressLabel: '$pct%',
      onTap: () => _start(context),
    );
  }
}

/// BENTO PLITKA — gradient fon, katta ikonka, sarlavha, progress halqa.
/// Ikki asosiy yo'l ("So'zlar" va "Trening") yonma-yon turadi.
class BentoTile extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final double progress;
  final String progressLabel;
  final VoidCallback onTap;
  const BentoTile({
    super.key,
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.progressLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final first = gradient.colors.first;
    return HoverLift(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadow.glow(first, alpha: 0.4),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progress.clamp(0, 1)),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => CircularProgressIndicator(
                                value: v,
                                strokeWidth: 4,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.25,
                                ),
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              progressLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Takrorlash kerak bo'lgan mashqlarga tez o'tish.
class _ReviewBanner extends StatelessWidget {
  final int count;
  const _ReviewBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.homework.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Takrorlash kerak')),
              body: const ReviewScreen(),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              const Icon(
                Icons.replay_rounded,
                color: AppColors.homework,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Takrorlash kerak',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.homework,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ta mashq xato bilan tugatilgan',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.homework,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final UnitBrief brief;
  const _UnitCard({required this.brief});

  @override
  Widget build(BuildContext context) {
    final done = progress.doneInUnit(brief.unit);
    final ratio = brief.exercises == 0
        ? 0.0
        : (done / brief.exercises).clamp(0.0, 1.0);
    final complete = brief.exercises > 0 && done >= brief.exercises;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.all(16),
        onTap: () async {
          final u = await book.load(brief.unit);
          if (u == null || !context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BookUnitScreen(unit: u)),
          );
        },
        child: Row(
          children: [
            // Nishon: tugallangan unit — yashil gradient + belgi;
            // boshlangan — halqa progress; yangi — brend gradient.
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (done > 0 && !complete)
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        backgroundColor: AppColors.brandPurple.withValues(
                          alpha: 0.12,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.brandPurple,
                        ),
                      ),
                    ),
                  GradientBadge(
                    size: done > 0 && !complete ? 42 : 50,
                    gradient: complete
                        ? AppColors.successGradient
                        : brief.isExtra
                        ? const LinearGradient(
                            colors: [AppColors.actionBlue, AppColors.brandCyan],
                          )
                        : AppColors.brandGradient,
                    child: complete
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 26,
                          )
                        : Text(
                            brief.displayBadge,
                            style: TextStyle(
                              fontSize: brief.isExtra ? 15 : 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${brief.displayLabel} — ${brief.title}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    brief.words > 0
                        ? '${brief.words} so\'z · ${(brief.words / kLessonSize).ceil()} dars · ${brief.exercises} mashq'
                        : '${brief.exercises} mashq · ${brief.tasks} band',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted(context),
                    ),
                  ),
                  // Nechta mashq tugatilgani — ilgari o\'quvchi
                  // unitni ochmasdan buni bilolmasdi.
                  if (done > 0) ...[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: AppColors.brandPurple.withValues(
                          alpha: 0.15,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.brandPurple,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // "Yana N ta qoldi" — maqsadga yaqinlashgan
                    // sari intilish kuchayadi (goal gradient).
                    Text(
                      done >= brief.exercises
                          ? '$done / ${brief.exercises} — unit tugatildi'
                          : (brief.exercises - done <= 5
                                ? 'Yana ${brief.exercises - done} ta qoldi — oz qoldi!'
                                : '$done / ${brief.exercises} mashq tugatildi'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color:
                            brief.exercises - done <= 5 &&
                                done < brief.exercises
                            ? AppColors.homework
                            : AppColors.brandPurple,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.brandPurple,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════ Bitta unit ═══════════════════
class BookUnitScreen extends StatelessWidget {
  final BookUnit unit;
  const BookUnitScreen({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    final groups = unit.groupedSections();
    return Scaffold(
      appBar: AppBar(title: Text('${unit.displayLabel} — ${unit.title}')),
      body: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _summary(context),
            const SizedBox(height: 16),
            // ENG ASOSIY tugma — trening seansi.
            //
            // Betma-bet ko'rish "o'qish", bu esa "o'rganish": dars
            // 100% o'zlashtirilgunicha savollar takrorlanadi, so'ng
            // oldingi darslar bilan aralash takror.
            // 1) SO'ZLAR — Duolingo uslubidagi kichik darslar. Avval
            //    ko'rsatiladi, keyin so'raladi. Bu asosiy yo'l.
            // BENTO: ikki asosiy yo'l yonma-yon (keng ekranda), telefonda
            // ustma-ust — "nima qilay?" degan savolga bitta qarashda javob.
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 560;
                final a = _WordsButton(unit: unit);
                final b = _MasterButton(unit: unit);
                if (!wide) {
                  return Column(children: [a, const SizedBox(height: 10), b]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 12),
                    Expanded(child: b),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            // 3) Diktant — tinglab gap yig'ish (tinglash + imlo).
            _DictationButton(unit: unit),
            const SizedBox(height: 10),
            // 4) YIG'MA IMTIHON — 1-unitdan shu unitgacha hammasi.
            if (unit.unit >= 1 && unit.unit < 800) ...[
              ExamButton(unit: unit.unit),
              const SizedBox(height: 10),
            ],
            // Kitobni betma-bet ko'rish.
            Pressable3D(
              color: AppColors.actionBlue,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BookPagesScreen(unit: unit)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  // TELEFONDA: matn 375px ekranga sig'masdi va tugma
                  // sariq-qora "overflow" chizig'i bilan chizilardi.
                  // `Flexible` matnga keyingi qatorga o'tishga ruxsat beradi.
                  Flexible(
                    child: Text(
                      'Betma-bet ko\'rish (${unit.pages().length} bet)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kitobingizni oching — ilova aynan shu betlarni ko\'rsatadi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
            ),
            const SizedBox(height: 22),
            const _Label('Yoki mavzu bo\'yicha'),
            const SizedBox(height: 10),
            for (var i = 0; i < groups.length; i++)
              EntranceFade(
                delay: Duration(milliseconds: 40 * i),
                child: _GroupCard(group: groups[i]),
              ),
            const SizedBox(height: 24),
            const _Label('Ma\'lumotnoma'),
            const SizedBox(height: 10),
            _refTile(
              context,
              icon: Icons.account_tree_rounded,
              color: AppColors.success,
              title: 'So\'z yasalishi',
              subtitle:
                  '${unit.wordFormation.fold(0, (s, g) => s + g.items.length)} ta qoida',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WordFormationScreen(unit: unit),
                ),
              ),
            ),
            _refTile(
              context,
              icon: Icons.short_text_rounded,
              color: AppColors.actionBlue,
              title: 'Gap qoliplari',
              subtitle: '${unit.sentencePatterns.length} ta qolip',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SentencePatternsScreen(unit: unit),
                ),
              ),
            ),
            _refTile(
              context,
              icon: Icons.style_rounded,
              color: AppColors.brandPurple,
              title: 'Unit lug\'ati',
              subtitle: '${unit.vocabulary.length} ta so\'z — yodlash mashqi',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UnitVocabularyScreen(unit: unit),
                ),
              ),
            ),
            _refTile(
              context,
              icon: Icons.photo_library_rounded,
              color: AppColors.muted(context),
              title: 'Rasmlar manbasi',
              subtitle: 'Wikimedia Commons — erkin litsenziya',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImageCreditsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandPurple.withValues(alpha: dark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          _stat(context, '${unit.sections.length}', 'bo\'lim'),
          _stat(context, '${unit.exerciseCount}', 'mashq'),
          _stat(context, '${unit.answerableCount}', 'band'),
          _stat(context, '${unit.vocabulary.length}', 'so\'z'),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String v, String label) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.brandPurple,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: AppColors.muted(context)),
        ),
      ],
    ),
  );

  Widget _refTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface(context),
        surfaceTintColor: Colors.transparent,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.border(context)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final SectionGroup group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final st = sectionStyle(context, group.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface(context),
        surfaceTintColor: Colors.transparent,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.border(context)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BookGroupScreen(group: group)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: st.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(st.icon, color: st.color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.titleUz,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (group.exerciseCount > 0)
                            '${group.exerciseCount} mashq',
                          if (group.hasRule) 'qoida',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Qaysi kitobdan olingani — aniq nom bilan.
                      Text(
                        group.sourceSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════ Betlar ro'yxati ═══════════════════
/// Unitdagi barcha betlar — kitob bo'yicha guruhlangan.
class BookPagesScreen extends StatelessWidget {
  final BookUnit unit;
  const BookPagesScreen({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    final pages = unit.pages();
    final byBook = <String, List<BookPage>>{};
    for (final p in pages) {
      byBook.putIfAbsent(p.bookLabel, () => []).add(p);
    }
    return Scaffold(
      appBar: AppBar(title: Text('${unit.displayLabel} — betlar')),
      body: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              'Kitobingizni oching va shu betlarni ilova bilan birga ishlang.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            for (final entry in byBook.entries) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 18,
                      color: AppColors.brandPurple,
                    ),
                    const SizedBox(width: 8),
                    // Katta shrift rejimida (1.5x) bu qator ekrandan
                    // chiqib ketardi — `Flexible` sarlavhaga qisqarishga
                    // ruxsat beradi.
                    Flexible(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.brandPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.value.length} bet',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              for (final p in entry.value) _pageTile(context, p),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pageTile(BuildContext context, BookPage p) {
    // Bet faqat hamma mashq XATOSIZ o'zlashtirilganda tugagan
    // hisoblanadi — aks holda takrorlash kerakligi ko'rinmay qolardi.
    final done = p.exercises.every((e) {
      final id = e.progressId;
      return progress.isDone(id) && !progress.needsRepeat(id);
    });
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: AppColors.surface(context),
        surfaceTintColor: Colors.transparent,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.border(context)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BookPageScreen(page: p)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (done ? AppColors.success : AppColors.actionBlue)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: done
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.success,
                          )
                        : Text(
                            '${p.bookPage}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.actionBlue,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p.bookLabel} · ${p.bookPage}-bet',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '${p.exerciseCount} mashq',
                          if (p.hasRule) 'qoida',
                          ...p.sections.map((s) => s.titleUz).toSet().take(2),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════ Bitta bet — to'liq ═══════════════════
/// Kitobning bitta betidagi HAMMA NARSA bir joyda: bo'limlar, qoida,
/// barcha mashqlar. O'quvchi kitobdagi betni ochib, shu ekran bilan ishlaydi.
class BookPageScreen extends StatelessWidget {
  final BookPage page;
  const BookPageScreen({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${page.bookLabel} · ${page.bookPage}-bet')),
      body: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            // Betning to'liq manzili — o'quvchi qayerdaligini bilib turadi.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandPurple.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.place_rounded,
                    size: 19,
                    color: AppColors.brandPurple,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          page.fullLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: AppColors.brandPurple,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${page.exerciseCount} mashq · ${page.answerableCount} band',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Bet surati mavjud bo'lsagina ko'rinadi (assets/book_pages/).
            BookPageButton(
              level: book.level,
              book: page.book,
              bookLabel: page.bookLabel,
              page: page.bookPage,
            ),
            const SizedBox(height: 4),
            for (final s in page.sections) ..._section(context, s),
          ],
        ),
      ),
    );
  }

  List<Widget> _section(BuildContext context, BookSection s) {
    final st = sectionStyle(context, s.kind);
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Row(
          children: [
            Icon(st.icon, size: 18, color: st.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.title.isEmpty ? s.titleUz : s.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  color: st.color,
                ),
              ),
            ),
            Flexible(
              child: Text(
                s.titleUz,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.muted(context),
                ),
              ),
            ),
          ],
        ),
      ),
      if (s.hasRule)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Pressable3D(
            color: AppColors.actionBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RuleScreen(section: s)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.rule_rounded, color: Colors.white, size: 20),
                SizedBox(width: 9),
                // Katta shrift rejimida matn tugmadan chiqib ketardi.
                Flexible(
                  child: Text(
                    'Qoidani o\'qish',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      for (final e in s.exercises)
        _ExerciseTile(exercise: e, section: s, unitLabel: page.unitLabel),
      const SizedBox(height: 12),
    ];
  }
}

// ═══════════════════ Bo'lim guruhi ═══════════════════
class BookGroupScreen extends StatelessWidget {
  final SectionGroup group;
  const BookGroupScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(group.titleUz)),
      body: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [for (final s in group.sections) ..._section(context, s)],
        ),
      ),
    );
  }

  List<Widget> _section(BuildContext context, BookSection s) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                s.title.isEmpty ? s.titleUz : s.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.brandPurple.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                s.sourceLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPurple,
                ),
              ),
            ),
          ],
        ),
      ),
      if (s.hasRule)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Pressable3D(
            color: AppColors.actionBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RuleScreen(section: s)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.rule_rounded, color: Colors.white, size: 20),
                SizedBox(width: 9),
                // Katta shrift rejimida matn tugmadan chiqib ketardi.
                Flexible(
                  child: Text(
                    'Qoidani o\'qish',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      for (final e in s.exercises) _ExerciseTile(exercise: e, section: s),
      const SizedBox(height: 14),
    ];
  }
}

class _ExerciseTile extends StatelessWidget {
  final BookExercise exercise;
  final BookSection section;

  /// Unit yorlig'i — to'liq manzil uchun ("1-unit · Coursebook · 7-bet").
  /// Hikoya betlarida "1-epizod" bo'ladi.
  final String unitLabel;

  const _ExerciseTile({
    required this.exercise,
    required this.section,
    this.unitLabel = '',
  });

  ({IconData icon, Color color, String label}) get _kindInfo =>
      switch (exercise.kind) {
        ExKind.choice => (
          icon: Icons.checklist_rounded,
          color: AppColors.brandPurple,
          label: 'Tanlash',
        ),
        ExKind.text => (
          icon: Icons.extension_rounded,
          color: AppColors.actionBlue,
          label: 'Yig\'ish',
        ),
        ExKind.match => (
          icon: Icons.compare_arrows_rounded,
          color: AppColors.success,
          label: 'Moslash',
        ),
        ExKind.study => (
          icon: Icons.auto_stories_rounded,
          color: AppColors.coin,
          label: 'O\'qish',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final info = _kindInfo;
    final id = exercise.progressId;
    final done = progress.isDone(id);
    // Tugatilgan, lekin XATO bilan — o'zlashtirilmagan. Yashil belgi
    // qo'yish o'quvchini adashtiradi.
    final repeat = done && progress.needsRepeat(id);
    // Unitdagi jami mashq — "unit tugadi" nishonlashi uchun.
    int? unitTotal;
    var label = unitLabel;
    for (final b in book.units) {
      if (b.unit == exercise.unitNo) {
        unitTotal = b.exercises;
        if (label.isEmpty) label = b.displayLabel;
        break;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: AppColors.surface(context),
        surfaceTintColor: Colors.transparent,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.border(context)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExercisePlayer(
                exercise: exercise,
                sectionTitle: section.titleUz,
                unitLabel: label,
                siblings: section.exercises,
                unitTotal: unitTotal,
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
                    color:
                        (repeat
                                ? AppColors.homework
                                : (done ? AppColors.success : info.color))
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    repeat
                        ? Icons.replay_rounded
                        : (done ? Icons.check_rounded : info.icon),
                    color: repeat
                        ? AppColors.homework
                        : (done ? AppColors.success : info.color),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Katta shrift rejimida (1.5x) bu qator ekrandan
                      // chiqib ketardi. `Wrap` sig'magan qismini pastga
                      // tushiradi, ellipsis esa sarlavhani qisqartiradi.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            exercise.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: info.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              info.label,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: info.color,
                              ),
                            ),
                          ),
                          if (exercise.audio)
                            const Icon(
                              Icons.headphones_rounded,
                              size: 14,
                              color: AppColors.homework,
                            ),
                          // Xato bilan tugatilgan mashq — qayta ishlash
                          // kerakligi ochiq aytiladi.
                          if (repeat)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.homework.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: const Text(
                                'takrorlash kerak',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.homework,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        exercise.instructionUz.isEmpty
                            ? '${exercise.tasks.length} band'
                            : exercise.instructionUz,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted(context),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // To'liq manzil — qaysi kitob, qaysi bet, qaysi mashq.
                      Text(
                        unitLabel.isNotEmpty
                            ? exercise.locationLabel(unitLabel)
                            : exercise.sourceLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.play_arrow_rounded, color: AppColors.muted(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════ Umumiy ═══════════════════
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: dark ? AppColors.darkHeading : AppColors.lightHeading,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.muted(context)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "3 daqiqalik tez mashq" — oxirgi ochilgan (yoki birinchi) unitning
/// zaif so'zlari bilan trening. O'ylash shart emas: bitta tugma.
/// BOSh EKRAN "HERO" — brend gradientli katta karta: kun salomi, bugungi
/// maqsad halqasi, olov (streak) va BITTA katta harakat ("Tez mashq").
///
/// UX: birinchi ko'z tushadigan joyda faqat bitta qaror — "boshlash".
/// Salomlashish hamroh ismi bilan (shaxsiylik), halqa "oz qoldi"
/// hissini beradi (goal gradient), gradient va nur — "wow" birinchi
/// soniyada.
class _HomeHero extends StatelessWidget {
  const _HomeHero();

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Xayrli tun';
    if (h < 12) return 'Xayrli tong';
    if (h < 17) return 'Xayrli kun';
    return 'Xayrli kech';
  }

  @override
  Widget build(BuildContext context) {
    final name = rewards.petName;
    final goal = progress.dailyGoal;
    final today = progress.todayXp;
    final left = (goal - today).clamp(0, goal);
    final met = progress.dailyGoalMet;
    final streak = progress.currentStreak;
    return HoverLift(
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadow.glow(AppColors.brandIndigo, alpha: 0.45),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              // Dekorativ shar va halqa — chuqurlik.
              Positioned(
                right: -40,
                top: -50,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -60,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 18,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_greeting()}${name.isNotEmpty ? ', $name bilan' : ''} 👋',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                met
                                    ? 'Bugungi maqsad bajarildi!'
                                    : today == 0
                                    ? 'Bugun 3 daqiqa yetadi.'
                                    : 'Yana $left XP - maqsadga oz qoldi.',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontSize: 22,
                                      height: 1.15,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _HeroChip(
                                    icon: Icons.local_fire_department_rounded,
                                    text: streak > 0
                                        ? '$streak kun ketma-ket'
                                        : 'Seriyani boshlang',
                                  ),
                                  _HeroChip(
                                    icon: Icons.bolt_rounded,
                                    text: '$today / $goal XP bugun',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _GoalRing(progress: progress.dailyProgress, met: met),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        onTap: () => _start(context),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.brandIndigo,
                                size: 24,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '3 daqiqalik tez mashq',
                                style: TextStyle(
                                  color: AppColors.brandIndigo,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    final main = book.units.where((u) => !u.isInfo).toList();
    if (main.isEmpty) return;
    final target = progress.lastUnitNo > 0
        ? progress.lastUnitNo
        : main.first.unit;
    var u = await book.load(target);
    u ??= await book.load(main.first.unit);
    if (u == null) return;
    final src = sourcesFromUnit(u);
    if (src.isEmpty) return;
    final earlier = <DrillSource>[];
    for (final b in main) {
      if (b.unit >= u.unit) continue;
      final e = await book.load(b.unit);
      if (e != null) earlier.addAll(sourcesFromUnit(e));
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillScreen(
          title: '${u!.displayLabel} — tez mashq',
          lessonSources: src,
          earlierSources: earlier,
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

/// Kunlik maqsad halqasi — katta, oq, animatsiyali to'lish.
class _GoalRing extends StatelessWidget {
  final double progress;
  final bool met;
  const _GoalRing({required this.progress, required this.met});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    height: 84,
    child: Stack(
      alignment: Alignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => SizedBox(
            width: 84,
            height: 84,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
        met
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 34)
            : Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
      ],
    ),
  );
}

/// DIKTANT — unitning namunaviy gaplarini TINGLAB, so'zlardan yig'ish.
/// Kitob mashqlari o'qishga tayanadi; bu yerda quloq ishlaydi: gap
/// faqat ovozda, ekranda tarjimasi. Tinglash + imlo + so'z tartibi.
class _DictationButton extends StatelessWidget {
  final BookUnit unit;
  const _DictationButton({required this.unit});

  static const int _size = 8;

  List<ExTask> _tasks() {
    final rng = Random();
    final seen = <String>{};
    final pool = <ExTask>[];
    for (final sp in unit.sentencePatterns) {
      // Birinchi gap, 3..9 so'z — juda uzun gap yig'ish charchatadi.
      final first = sp.exampleEn.split(RegExp(r'(?<=[.!?])\s+')).first.trim();
      final words = first.split(RegExp(r'\s+'));
      if (words.length < 3 || words.length > 9) continue;
      if (!seen.add(first.toLowerCase())) continue;
      final uz = sp.exampleUz.split(RegExp(r'(?<=[.!?])\s+')).first.trim();
      pool.add(
        ExTask(
          prompt: "🔊 Tinglang va so'zlardan gap tuzing",
          promptUz: uz,
          answer: first,
          speak: first,
          speakAnswer: first,
          whyUz: sp.formula.isNotEmpty ? 'Qolip: ${sp.formula}' : '',
        ),
      );
    }
    pool.shuffle(rng);
    return pool.take(_size).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks();
    if (tasks.length < 3) return const SizedBox.shrink();
    return Column(
      children: [
        Pressable3D(
          color: const Color(0xFF0D9488),
          shadowColor: const Color(0xFF115E59),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          onPressed: () {
            final ex = BookExercise(
              ref: '1',
              kind: ExKind.text,
              tasks: _tasks(),
              instructionEn: 'Listen and build the sentence from the words.',
              instructionUz:
                  "Gapni tinglang (ovoz tugmasi), so'ng so'zlardan yig'ing.",
              book: 'quiz',
              pageLabel: 'diktant ${unit.unit}',
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExercisePlayer(
                  exercise: ex,
                  sectionTitle: 'Diktant',
                  unitLabel: unit.displayLabel,
                ),
              ),
            );
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.headphones_rounded, color: Colors.white, size: 20),
              SizedBox(width: 9),
              Flexible(
                child: Text(
                  'Diktant — tinglab gap tuzish',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Unitning ${tasks.length} ta namunaviy gapi: faqat ovoz va tarjima — quloq ishlaydi.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
        ),
      ],
    );
  }
}
