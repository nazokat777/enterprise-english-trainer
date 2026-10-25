import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../book_content.dart';
import '../../levels.dart';
import '../../drill/drill_item.dart';
import '../../drill/drill_screen.dart';
import '../../lessons/lesson_screen.dart';
import '../../lessons/lessons_screen.dart';
import '../../lessons/word_lesson.dart';
import '../../main.dart';
import '../../exam/exam_widgets.dart';
import '../../memory/advice.dart';
import '../../plan/plan_home_card.dart';
import '../../memory/memory_widgets.dart';
import '../../reward/streak_repair_card.dart';
import '../../reward/weekly_card.dart';
import '../../widgets/hover_lift.dart';
import '../../widgets/install_card.dart';
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
    // book ham tinglanadi: daraja almashsa ro'yxat DARHOL yangilanadi.
    return ListenableBuilder(
      listenable: book,
      builder: (context, _) => _list(context),
    );
  }

  Widget _list(BuildContext context) {
    final units = book.units;
    final main = units.where((u) => !u.isInfo).toList();
    final info = units.where((u) => u.isInfo).toList();
    if (units.isEmpty) {
      return const _Empty(
        icon: Icons.menu_book_rounded,
        title: 'Darslar yuklanmadi',
        subtitle: 'Sahifani yangilab ko\'ring. Muammo qolsa - Yordam bo\'limiga qarang.',
      );
    }
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // (a) SARLAVHA + BITTA ODDIY SATR + HERO. Kitobi yo'q odam ham
          // 5 soniyada tushunsin: bu nima, nima qilish kerak.
          EntranceFade(
            child: Text(
              _levelHeading(progress.currentLevel),
              style: AppTheme.heading(context),
            ),
          ),
          const SizedBox(height: 4),
          EntranceFade(
            child: Text(
              "Ingliz tilini 0 dan o'rganing: unitlar ketma-ket - har birida "
              "so'zlar, grammatika, mashqlar va imtihon. Kitob shart emas.",
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.muted(context),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // HERO: keyingi qadam aytiladi. Boshlash ishqalanishi
          // (friction) eng katta to'siq: qaysi unit, qaysi dars deb
          // o'ylamasdan "Davom eting: ..." satrini o'qish yetarli.
          const EntranceFade(child: _HomeHero()),
          const SizedBox(height: 10),
          // (b) DIQQAT KARTALARI - faqat kerak bo'lganda ko'rinadi, shuning
          // uchun hero'dan keyin, kursdan OLDIN turadi.
          // Uzilgan ketma-ket kunlarni tiklash - vaqt chegarali.
          const EntranceFade(child: StreakRepairCard()),
          const EntranceFade(child: StreakDangerCard()),
          if (rewards.idleToday && progress.currentStreak > 0)
            const SizedBox(height: 10),
          // "Va'da vaqti keldi" - vaqtga bog'liq eslatma (mukofot emas),
          // pastda hech kim ko'rmasdi.
          const EntranceFade(child: CommitCard()),
          // O'CHIB KETAYOTGAN SO'ZLAR - faqat so'z unutilayotgan bo'lsa shu
          // yerda; aks holda xotira bog'i pastda ("Qo'shimcha").
          const EntranceFade(child: _RescueSlot(urgent: true)),
          // Oxirgi mashqqa qaytish va xato bilan tugatilgan mashqlar:
          // aks holda "takrorlash kerak" belgisini 1545 mashq orasidan
          // qidirish kerak bo'lardi.
          if (progress.lastExerciseId.isNotEmpty) ...[
            const EntranceFade(child: _ContinueBanner()),
            const SizedBox(height: 10),
          ],
          if (progress.needsReviewCount() > 0) ...[
            EntranceFade(
              child: _ReviewBanner(count: progress.needsReviewCount()),
            ),
            const SizedBox(height: 10),
          ],
          // (c) ASOSIY YO'L - kurs. Muqova, mundarija, modul muqovalari
          // dars EMAS: ular pastda, yig'ilgan holda. O'quvchi kitob
          // haqidagi ma'lumotda uzoq qolib ketmasin - 1-unitdan boshlasin.
          const _SectionHeader(
            title: 'Kurs - unitlar',
            helper:
                "Unit (bob) - kursning bir qismi. 1-unitdan boshlab ketma-ket "
                "o'ting. Doiradagi raqam - unit raqami, uning atrofidagi "
                "halqa - bajarilgan mashqlar ulushi.",
            sheetTitle: 'Kurs qanday ishlaydi?',
            sheetLines: [
              "1. Unitni oching.",
              "2. So'z darslarini o'rganing.",
              "3. Grammatika va mashqlarni bajaring.",
              "4. Oxirida unit imtihonini topshiring.",
              "Dars - 7 ta yangi so'z. Mashq - kitobdagi bitta topshiriq. "
                  "Kitobingiz bo'lmasa ham bo'ladi: hammasi ilovaning o'zida bor.",
            ],
          ),
          for (var i = 0; i < main.length; i++)
            EntranceFade(
              delay: Duration(milliseconds: 60 * (i < 10 ? i : 10)),
              child: _UnitCard(brief: main[i]),
            ),
          // (d) QO'SHIMCHA - majburiy emas: vazifalar, takror, mukofotlar.
          // Kartalarning o'z manbasiga tegilmaydi, faqat tartibi shu yerda.
          const SizedBox(height: 8),
          const _SectionHeader(
            title: "Qo'shimcha: vazifalar, takror va mukofotlar",
            helper:
                "Majburiy emas, lekin o'qishni osonlashtiradi: Mnemonika "
                "(kitobni belgilangan muddatda yodlash rejasi), kunlik "
                "vazifalar, tezlik o'yini, sovg'a qutisi va natijalar.",
            sheetTitle: "Bu bo'limda nima bor?",
            sheetLines: [
              "Mnemonika - kitobni belgilangan muddatda yodlash rejasi.",
              "Imtihon - tugatgan unitlaringiz bo'yicha sinov.",
              "Kunlik vazifalar - bugun bajariladigan 3 ta kichik topshiriq; "
                  "uchalasini bajarsangiz sovg'a qutisi ochiladi.",
              "Tezlik o'yini, omad g'ildiragi, haftalik natija va kunlar "
                  "taqvimi - qiziqarli qo'shimchalar. O'qish uchun shart emas.",
            ],
          ),
          // MNEMONIKA XARITASI - kitobni muddatda tugatish rejasi.
          const EntranceFade(child: PlanHomeCard()),
          // YIG'MA IMTIHON - unit tugagach 1..N.
          const EntranceFade(child: ExamCard()),
          if (highestCompletedUnit() > 0) const SizedBox(height: 10),
          // Xotira bog'i (so'z o'chmayotgan paytda) shu yerda turadi.
          const EntranceFade(child: _RescueSlot(urgent: false)),
          const EntranceFade(child: DailyQuestsCard()),
          const SizedBox(height: 10),
          const EntranceFade(child: BlitzCard()),
          if (mastery.learnedWords(limit: 8).length >= 8)
            const SizedBox(height: 10),
          // Avatar - hissiy bog'lanish.
          const EntranceFade(child: MascotCard()),
          const SizedBox(height: 10),
          EntranceFade(
            child: SpinCard(onSpin: () => SpinWheelDialog.show(context)),
          ),
          if (!rewards.spinDoneToday) const SizedBox(height: 10),
          // Haftalik hisobot - haftada bir marta, yopiladi.
          const EntranceFade(child: WeeklyCard()),
          const SizedBox(height: 10),
          const EntranceFade(child: ActivityHeatmap()),
          const SizedBox(height: 14),
          // Telefonga o'rnatish (PWA) - brauzerda, birinchi mashqdan keyin.
          const EntranceFade(child: InstallCard()),
          // (e) Kitob haqida - dars emas, ma'lumot.
          if (info.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoGroup(units: info),
          ],
        ],
      ),
    );
  }

  /// Sarlavha: "Beginner · Enterprise 1" - daraja nomi kitob bilan birga.
  static String _levelHeading(String level) =>
      '${levelLabel(level)} · ${levelBookTitle(level).split(' - ').first}';
}

/// "O'CHIB KETAYOTGAN SO'ZLAR" kartasi uchun joy: [urgent] bo'lsa faqat
/// so'z unutilayotganda kursdan oldin; aks holda (xotira bog'i) pastdagi
/// "Qo'shimcha" bo'limida. Kartaning o'zi o'zgarmaydi.
class _RescueSlot extends StatelessWidget {
  final bool urgent;
  const _RescueSlot({required this.urgent});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mastery,
      builder: (context, _) {
        if ((mastery.fadingCount() > 0) != urgent) {
          return const SizedBox.shrink();
        }
        return const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: MemoryRescueCard(),
        );
      },
    );
  }
}

/// Bo'lim sarlavhasi: nom + bir qator izoh + "?" (qisqa tushuntirish oynasi).
class _SectionHeader extends StatelessWidget {
  final String title;
  final String helper;
  final String sheetTitle;
  final List<String> sheetLines;
  const _SectionHeader({
    required this.title,
    required this.helper,
    required this.sheetTitle,
    required this.sheetLines,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: dark ? AppColors.darkHeading : AppColors.lightHeading,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Bu nima?',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.actionBlue,
                ),
                onPressed: () => _showInfoSheet(context, sheetTitle, sheetLines),
              ),
            ],
          ),
          Text(
            helper,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Qisqa tushuntirish oynasi ("?" tugmasi): sarlavha + 2-5 qisqa satr.
Future<void> _showInfoSheet(
  BuildContext context,
  String title,
  List<String> lines,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: AppColors.muted(ctx),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tushunarli'),
            ),
          ],
        ),
      ),
    ),
  );
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
            "Dars emas, ma'lumot: muqova, mundarija, noto'g'ri fe'llar jadvali, "
            "so'zlar ro'yxati, rasmli kartalar, video loyihalar · "
            "${units.length} ta qism",
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: AppColors.muted(context)),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          children: [
            for (final b in units) _infoTile(context, b),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(BuildContext context, UnitBrief b) {
    final info = _infoName(b);
    return ListTile(
      dense: true,
      leading: Icon(info.icon, color: AppColors.actionBlue),
      title: Text(
        info.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        info.hint,
        maxLines: 2,
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
    );
  }

  /// Kitob qismlarining tushunarli nomi. Ilgari "VP", "WL", "PF" kabi
  /// belgilar va inglizcha bo'lim nomlari ko'rinardi - kitobi yo'q odam
  /// ularning nima ekanini bilmasdi.
  static ({String title, String hint, IconData icon}) _infoName(UnitBrief b) {
    if (b.label.contains('-modul:')) {
      return (
        title: b.displayLabel,
        hint: "Modul muqovasi: shu modulda qaysi unitlar borligi",
        icon: Icons.collections_bookmark_outlined,
      );
    }
    if (b.unit >= 980 && b.unit <= 989) {
      return (
        title: b.displayLabel,
        hint: "Video loyiha: film bo'yicha topshiriq",
        icon: Icons.play_circle_outline_rounded,
      );
    }
    return switch (b.unit) {
      800 => (
        title: 'Kirish qismi',
        hint: 'Muqova, titul varag\'i, mundarija',
        icon: Icons.book_outlined,
      ),
      960 => (
        title: 'Nazorat testlari (muqova)',
        hint: "Progress Tests bo'limining birinchi sahifasi",
        icon: Icons.assignment_outlined,
      ),
      969 => (
        title: 'Video loyihalar',
        hint: "Kitob tavsiya qilgan filmlar ro'yxati",
        icon: Icons.movie_outlined,
      ),
      970 => (
        title: "Grammatika ma'lumotnomasi",
        hint: 'Grammar Reference: qoidalar bir joyda',
        icon: Icons.rule_rounded,
      ),
      971 => (
        title: "Noto'g'ri fe'llar",
        hint: "go - went - gone kabi fe'llar jadvali",
        icon: Icons.table_rows_outlined,
      ),
      972 => (
        title: "So'zlar ro'yxati",
        hint: "Word List: har bir unitning so'zlari",
        icon: Icons.list_alt_rounded,
      ),
      973 => (
        title: 'Rasmli kartalar',
        hint: "Photo File: so'zlarni rasm orqali yodlash",
        icon: Icons.photo_library_outlined,
      ),
      974 => (
        title: 'Madaniyat lavhalari',
        hint: 'Culture Clips: madaniyat haqida qisqa lavhalar',
        icon: Icons.public_rounded,
      ),
      975 => (
        title: 'Amerika va Britaniya inglizchasi',
        hint: "Ikki xil imlo va so'zlar farqi",
        icon: Icons.translate_rounded,
      ),
      990 => (
        title: 'Orqa muqova',
        hint: 'Kitobning oxirgi sahifasi',
        icon: Icons.book_outlined,
      ),
      _ => (
        title: b.displayLabel,
        hint: b.title,
        icon: Icons.description_outlined,
      ),
    };
  }
}

/// DAVOM ETISH — oxirgi ochilgan mashqqa bir bosishda qaytish.
///
/// 51 unit va 1545 mashq ichida o'quvchi qayerda qolganini O'ZI
/// eslab qolishi kerak edi: qaysi unit, qaysi bo'lim, nechanchi
/// mashq. Xotirasi yomon odam uchun bu eng katta to'siq edi.
class _ContinueBanner extends StatelessWidget {
  const _ContinueBanner();

  /// "3-unit · Grammatika · 5-mashq": qaysi unit va qaysi mashq ekani
  /// aniq yoziladi ("Ex. 5" kitob qisqartmasi o'rniga "5-mashq").
  String _where() {
    final label = progress.lastLabel.replaceAllMapped(
      RegExp(r'Ex\. (.+)$'),
      (m) => _exerciseName(m[1]!),
    );
    var unit = '';
    for (final b in book.units) {
      if (b.unit == progress.lastUnitNo) {
        unit = b.displayLabel;
        break;
      }
    }
    return unit.isEmpty ? label : '$unit · $label';
  }

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
                      "Oxirgi mashqni davom ettirish",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.brandPurple,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _where(),
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
      subtitle:
          "$words ta yangi so'z · ${lessons.length} ta dars (har biri "
          "~$kLessonSize so'z). Avval ko'rsatiladi, keyin so'raladi.",
      progress: lessons.isEmpty ? 0 : done / lessons.length,
      progressLabel: '$done/${lessons.length}',
      progressHint: 'Tugagan darslar: $done / ${lessons.length}',
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
          title: '${unit.displayLabel} — mashq',
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
      title: pct >= 100 ? 'Mashq - yana takrorlash' : 'Unit savollari bilan mashq',
      subtitle:
          "${ids.length} ta savol · hammasini bilguningizcha takrorlanadi · "
          "$pct% o'zlashtirilgan",
      progress: ratio,
      progressLabel: '$pct%',
      progressHint: "O'zlashtirilgan savollar: $pct%",
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

  /// Halqa nimani ko'rsatishi ("Tugagan darslar: 3 / 28") - sichqoncha
  /// ustida yoki uzoq bosganda chiqadi, ekran o'qigichga ham aytiladi.
  final String progressHint;
  final VoidCallback onTap;
  const BentoTile({
    super.key,
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.progressLabel,
    this.progressHint = '',
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
                      Tooltip(
                        message: progressHint,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: progress.clamp(0, 1),
                                ),
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
                    maxLines: 4,
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
              appBar: AppBar(title: const Text('Xatolarni qayta ishlash')),
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
                      'Xatolarni qayta ishlash',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.homework,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$count ta mashqda xato qildingiz - bosing va qayta bajaring",
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

  /// Qator ichida nima borligi so'z bilan: "192 ta so'z · 28 ta dars · 57
  /// ta mashq". Hikoya va testlarda avval turi yoziladi - ular unit emas.
  String _subtitle() {
    final parts = <String>[];
    if (brief.isExtra) {
      if (brief.badge.startsWith('E')) {
        parts.add("Hikoya (o'qish va savollar)");
      } else if (brief.label.contains('modul testi')) {
        parts.add('Modul testi');
      } else if (brief.badge.startsWith('PT')) {
        parts.add('Nazorat testi');
      }
      final m = RegExp(r'\(Units?\s+(\d+(?:-\d+)?)').firstMatch(brief.title);
      if (m != null) {
        final r = m[1]!;
        parts.add(r.contains('-') ? "$r unitlar bo'yicha" : "$r-unit bo'yicha");
      }
    }
    if (brief.words > 0) {
      parts.add(
        "${brief.words} ta so'z · ${(brief.words / kLessonSize).ceil()} ta dars"
        ' · ${brief.exercises} ta mashq',
      );
    } else {
      parts.add('${brief.exercises} ta mashq · ${brief.tasks} ta savol');
    }
    return parts.join(' · ');
  }

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
            // Raqam/belgi nimani bildirishi tooltip va ekran o'qigichda.
            Tooltip(
              message: complete
                  ? '${brief.displayLabel}: hammasi tugatilgan'
                  : done > 0
                  ? '${brief.displayLabel}: $done / ${brief.exercises} mashq tugatilgan'
                  : '${brief.displayLabel}: hali boshlanmagan',
              child: SizedBox(
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
                              colors: [
                                AppColors.actionBlue,
                                AppColors.brandCyan,
                              ],
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
                    _subtitle(),
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
                          ? '$done / ${brief.exercises} mashq — hammasi tugatildi'
                          : (brief.exercises - done <= 5
                                ? 'Yana ${brief.exercises - done} ta mashq qoldi — oz qoldi!'
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
            // Qayerdan boshlash kerak - kitobsiz o'quvchi uchun tartib.
            if (unit.unit >= 1 && unit.unit < 800) ...[
              const SizedBox(height: 10),
              const _OrderHint(),
            ],
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
            // 4) UNIT IMTIHONI (lug'at + grammatika + gap tuzish, oldingi
            //    unitlardan takror) va YIG'MA IMTIHON (1..N hammasi).
            if (unit.unit >= 1 && unit.unit < 800) ...[
              const SizedBox(height: 12),
              const _Label('Imtihon (bilimni tekshirish)'),
              const SizedBox(height: 4),
              Text(
                unit.unit > 1
                    ? "Unit imtihoni - faqat shu unit (+ oldingi unitlardan "
                          "takror). Yig'ma imtihon - 1-unitdan shu unitgacha "
                          "hammasi bo'yicha."
                    : "Unit imtihoni: shu unitning so'zlari, grammatikasi va "
                          "gap tuzish.",
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(height: 10),
              UnitExamCard(unit: unit.unit),
              const SizedBox(height: 10),
              // 1-unitda yig'ma imtihon unit imtihonining aynan o'zi -
              // ikkita bir xil tugma chalkashtirardi.
              if (unit.unit > 1) ...[
                ExamButton(unit: unit.unit),
                const SizedBox(height: 10),
              ],
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
                      "Kitob sahifalari bo'yicha (${unit.pages().length} bet)",
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
              "Mashqlar kitobdagi sahifa tartibida: Coursebook (asosiy "
              "darslik), Grammar (grammatika kitobi), Workbook (mashq "
              "daftari). Kitobingiz bo'lmasa ham bo'ladi - mashqlar "
              "ilovaning o'zida bor.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.muted(context),
              ),
            ),
            const SizedBox(height: 22),
            const _Label("Mavzu bo'yicha (kitob bo'limlari)"),
            const SizedBox(height: 4),
            Text(
              "Lug'at, O'qish, Grammatika, Tinglash... Birini bossangiz, shu "
              "mavzudagi mashqlar ochiladi.",
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.muted(context),
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < groups.length; i++)
              EntranceFade(
                delay: Duration(milliseconds: 40 * i),
                child: _GroupCard(group: groups[i]),
              ),
            const SizedBox(height: 24),
            const _Label("Ma'lumotnoma (qo'shimcha, o'qish shart emas)"),
            const SizedBox(height: 10),
            _refTile(
              context,
              icon: Icons.account_tree_rounded,
              color: AppColors.success,
              title: 'So\'z yasalishi',
              subtitle:
                  "${unit.wordFormation.fold(0, (s, g) => s + g.items.length)} ta juft so'z · teach -> teacher kabi",
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
              subtitle:
                  "${unit.sentencePatterns.length} ta tayyor qolip · masalan: I'm a + kasb",
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
              subtitle:
                  "Barcha ${unit.vocabulary.length} ta so'z ro'yxati (bossangiz ovozi chiqadi) va yodlash mashqi",
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
              subtitle:
                  "Ilovadagi rasmlar qayerdan olingan (Wikimedia Commons, erkin litsenziya)",
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bu unitda:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted(context),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _stat(context, '${unit.sections.length}', 'bo\'lim'),
              _stat(context, '${unit.exerciseCount}', 'mashq'),
              _stat(context, '${unit.answerableCount}', 'savol'),
              _stat(context, '${unit.vocabulary.length}', 'so\'z'),
            ],
          ),
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

/// "Tavsiya etilgan tartib" - unit sahifasida nimadan boshlashni aytadi.
/// Sahifada 10 dan ortiq tugma bor; tartib bo'lmasa hammasi bir xil
/// ko'rinadi va yangi o'quvchi nimani birinchi bosishni bilmaydi.
class _OrderHint extends StatelessWidget {
  const _OrderHint();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.actionBlue.withValues(alpha: dark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tavsiya etilgan tartib',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _OrderStep(1, "So'z darslari"),
              _OrderStep(2, 'Grammatika'),
              _OrderStep(3, 'Mashqlar'),
              _OrderStep(4, 'Unit imtihoni'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Hammasi shart emas, lekin shu tartibda osonroq. Grammatika - "
            "pastdagi mavzular ichida.",
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStep extends StatelessWidget {
  final int n;
  final String text;
  const _OrderStep(this.n, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.actionBlue,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$n',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }
}

/// Bo'lim turlarining tushunarli nomi. `book_content.dart` dagi ro'yxatda
/// bu turlar yo'q, shuning uchun karta tasodifiy birinchi bo'limning nomini
/// olardi (masalan "Savollar - 1-mashq" ichida 6 bo'lim bor edi).
const Map<String, String> _kGroupTitleUz = {
  'practice': "Qo'shimcha mashqlar",
  'revision': 'Takrorlash',
  'test': 'Testlar',
  'quiz': 'Viktorina',
  'culture': 'Madaniyat',
  'wisdom': "Hikmatli so'zlar",
  'words_of_wisdom': "Hikmatli so'zlar",
  'language_development': "Til rivojlantirish (lug'at va iboralar)",
  'reference': "Ma'lumot sahifalari",
  'story': 'Hikoya (epizodlar)',
  'video': 'Video loyiha',
  'module_cover': 'Modul muqovasi',
};

/// Guruh nomi: bizning ro'yxat -> kitobdagi nomi.
/// "culture" turidagi bo'limlarning ko'pi kitobdagi "Words of Wisdom" -
/// ular boshqa unitlardagi "Hikmatli so'zlar" bilan BIR XIL nom oladi.
String _groupTitle(SectionGroup g) {
  if (g.kind == 'culture' &&
      g.sections.any((s) => s.title.toLowerCase().contains('wisdom'))) {
    return "Hikmatli so'zlar";
  }
  return _kGroupTitleUz[g.kind] ?? g.titleUz;
}

/// Mashq nomi: "5-mashq", "4b-mashq". Kitobdagi "Ex. 5" qisqartmasi
/// kitobsiz o'quvchiga hech narsa demaydi. So'zli belgilar ("muqova",
/// "qoida", "Writing") o'z nomi bilan, bosh harfda.
String _exerciseName(String ref) {
  final r = ref.trim();
  if (r.isEmpty) return 'Mashq';
  if (RegExp(r'^\d+[a-z]?$', caseSensitive: false).hasMatch(r)) {
    return '$r-mashq';
  }
  const english = {
    'writing': 'Yozish',
    'speaking': 'Gapirish',
    'project': 'Loyiha',
    'words of wisdom': "Hikmatli so'zlar",
  };
  return english[r.toLowerCase()] ?? '${r[0].toUpperCase()}${r.substring(1)}';
}

/// Kitob manzilidagi "Ex. 5" ni "5-mashq" ga almashtiradi:
/// "1-unit · Enterprise 1 · Coursebook · 7-bet · Ex. 5" ->
/// "... · 7-bet · 5-mashq". Boshqa qismlarga tegmaydi.
String _uzRef(String s) => s.replaceAllMapped(
  RegExp(r'Ex\.\s*([^·]*?)\s*(?=·|$)'),
  (m) => _exerciseName(m[1] ?? ''),
);

/// Kitob nomi izoh bilan: "Coursebook (asosiy darslik)".
String _bookGloss(String name) => switch (name) {
  'Coursebook' => 'Coursebook (asosiy darslik)',
  'Workbook' => 'Workbook (mashq daftari)',
  'Grammar' => 'Grammar (grammatika kitobi)',
  _ => name,
};

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
                        _groupTitle(group),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (group.exerciseCount > 0)
                            '${group.exerciseCount} ta mashq',
                          if (group.hasRule) "qoida bor (o'qish mumkin)",
                          if (group.exerciseCount == 0 && !group.hasRule)
                            "faqat o'qish uchun",
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Qaysi kitobdan olingani — aniq nom bilan.
                      Text(
                        'Kitobda: ${group.sourceSummary}',
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
      appBar: AppBar(title: Text('${unit.displayLabel} — kitob sahifalari')),
      body: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              "Unit mashqlari kitobdagi sahifa tartibida. Kitobingiz bo'lsa - "
              "shu betni oching va birga ishlang; bo'lmasa - ilovaning o'zi "
              "yetarli.",
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
                        _bookGloss(entry.key),
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
                // Bet raqami: tagida "bet" yozuvi; tugagan bo'lsa raqam
                // o'rnida emas, burchakdagi yashil belgi.
                Tooltip(
                  message: done
                      ? "Bet tugatilgan (xatosiz)"
                      : (p.bookPage > 0 ? '${p.bookPage}-bet' : 'Raqamsiz bet'),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (done ? AppColors.success : AppColors.actionBlue)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (p.bookPage > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${p.bookPage}',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                    color: done
                                        ? AppColors.success
                                        : AppColors.actionBlue,
                                  ),
                                ),
                                Text(
                                  'bet',
                                  style: TextStyle(
                                    fontSize: 9,
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.muted(context),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Icon(
                            Icons.description_outlined,
                            color: AppColors.actionBlue,
                          ),
                        if (done)
                          const Positioned(
                            top: -5,
                            right: -5,
                            child: CircleAvatar(
                              radius: 8,
                              backgroundColor: AppColors.success,
                              child: Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '${p.exerciseCount} ta mashq',
                          if (p.hasRule) 'qoida bor',
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
      appBar: AppBar(title: Text('${BookExercise.bookName} · ${page.bookLabel} · ${page.bookPage}-bet')),
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
                          '${page.exerciseCount} ta mashq · ${page.answerableCount} ta savol',
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
            // O'zbekcha nom birinchi (katta), kitobdagi inglizcha sarlavha
            // ikkinchi qatorda kichik - kitobsiz o'quvchi uchun.
            Expanded(
              child: _SectionTitle(section: s, color: st.color, big: 15.5),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rule_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 9),
                // Katta shrift rejimida matn tugmadan chiqib ketardi.
                Flexible(
                  child: Text(
                    s.exercises.isEmpty
                        ? "Qoidani o'qish"
                        : "Avval qoidani o'qing",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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

/// Bo'lim sarlavhasi: o'zbekcha nom BIRINCHI (katta), kitobdagi inglizcha
/// sarlavha ostida kichik. Ilgari inglizcha kitob sarlavhasi asosiy matn
/// bo'lib, o'zbekchasi deyarli ko'rinmasdi.
class _SectionTitle extends StatelessWidget {
  final BookSection section;
  final Color? color;
  final double big;
  const _SectionTitle({required this.section, this.color, required this.big});

  @override
  Widget build(BuildContext context) {
    final uz = section.titleUz.trim();
    final en = section.title.trim();
    final main = uz.isNotEmpty ? uz : en;
    final sub = (uz.isNotEmpty && en.isNotEmpty && en != uz) ? en : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          main,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: big,
            color: color,
          ),
        ),
        if (sub.isNotEmpty)
          Text(
            sub,
            style: TextStyle(fontSize: 11.5, color: AppColors.muted(context)),
          ),
      ],
    );
  }
}

// ═══════════════════ Bo'lim guruhi ═══════════════════
class BookGroupScreen extends StatelessWidget {
  final SectionGroup group;
  const BookGroupScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_groupTitle(group))),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(section: s, big: 15),
            const SizedBox(height: 5),
            // Manba chipi pastda: telefonda va katta shriftda sig'adi.
            Wrap(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandPurple.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Kitobda: ${s.sourceLabel}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandPurple,
                    ),
                  ),
                ),
              ],
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rule_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 9),
                // Katta shrift rejimida matn tugmadan chiqib ketardi.
                Flexible(
                  child: Text(
                    s.exercises.isEmpty
                        ? "Qoidani o'qish"
                        : "Avval qoidani o'qing",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
          label: 'Variantdan tanlash',
        ),
        ExKind.text => (
          icon: Icons.extension_rounded,
          color: AppColors.actionBlue,
          label: 'So\'z va harflardan yig\'ish',
        ),
        ExKind.match => (
          icon: Icons.compare_arrows_rounded,
          color: AppColors.success,
          label: 'Juftlarni moslash',
        ),
        ExKind.study => (
          icon: Icons.auto_stories_rounded,
          color: AppColors.coin,
          label: 'Faqat o\'qish (savolsiz)',
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
                            _exerciseName(exercise.ref),
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
                            Tooltip(
                              message: 'Bu mashqda ovoz bor',
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.homework.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.headphones_rounded,
                                      size: 12,
                                      color: AppColors.homework,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'ovozli',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.homework,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                                'xato bor - qayta ishlang',
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
                            ? '${exercise.tasks.length} ta savol'
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
                        'Kitobda: ${_uzRef(unitLabel.isNotEmpty ? exercise.locationLabel(unitLabel) : exercise.sourceLabel)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted(context),
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

/// BOSh EKRAN "HERO" — brend gradientli katta karta: kun salomi, bugungi
/// maqsad halqasi, ketma-ket kunlar va KEYINGI QADAM ("Davom eting: ...").
///
/// UX: kitobi yo'q odam ham 5 soniyada bilsin: bu nima, nima qilish kerak.
/// Shuning uchun sarlavha - keyingi dars (aniq unit va dars raqami bilan),
/// raqamlar so'z bilan yozilgan ("Bugun: 12 / 20 ball"), "Bu nima?" tugmasi
/// ball, kunlik maqsad va ketma-ket kunni tushuntiradi.
/// Oq tugma — unitning savollari bilan tezkor mashq (so'z darsi emas).
class _HomeHero extends StatefulWidget {
  const _HomeHero();

  @override
  State<_HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<_HomeHero> {
  /// Keyingi dars: "1-unit, 1-dars - 7 ta yangi so'z" (yuklanguncha null).
  String? _nextLesson;
  Timer? _debounce;

  /// Kuzatiladigan obyektlar (initState dagi nusxa - dispose'da aynan
  /// shularidan chiqamiz).
  List<Listenable> _watched = const [];

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Xayrli tun';
    if (h < 12) return 'Xayrli tong';
    if (h < 17) return 'Xayrli kun';
    return 'Xayrli kech';
  }

  @override
  void initState() {
    super.initState();
    _watched = [progress, book];
    for (final w in _watched) {
      w.addListener(_onProgress);
    }
    _findNextLesson();
  }

  @override
  void dispose() {
    for (final w in _watched) {
      w.removeListener(_onProgress);
    }
    _debounce?.cancel();
    super.dispose();
  }

  /// Mashq tugagach "keyingi dars" yangilansin (ilgari bir marta hisoblanib
  /// qolardi). Hisob og'ir bo'lgani uchun mashqlar orasida emas, kichik
  /// to'xtashdan keyin bajariladi.
  void _onProgress() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _findNextLesson();
    });
  }

  /// Sarlavhada nomlangan darsning o'zi - oq tugma shuni boshlaydi
  /// (ilgari tugma boshqa narsani - unit savollarini - ochardi).
  WordLesson? _nextWl;
  BookUnit? _nextUnit;

  Future<void> _findNextLesson() async {
    String? next;
    WordLesson? nextWl;
    BookUnit? nextUnit;
    final main = book.units.where((u) => !u.isInfo && u.unit >= 1).toList();
    if (main.isNotEmpty) {
      final target = progress.lastUnitNo > 0
          ? progress.lastUnitNo
          : main.first.unit;
      final u = await book.load(target);
      if (u != null) {
        for (final l in lessonsOf(u)) {
          if (!mastery.allStrong(l.itemIds)) {
            // displayLabel: hikoya/test uchun ham to'g'ri nom ("1-epizod"),
            // aks holda ichki raqam chiqardi ("901-unit").
            next =
                "${u.displayLabel}, ${l.index}-dars - ${l.words.length} ta yangi so'z";
            nextWl = l;
            nextUnit = u;
            break;
          }
        }
      }
    }
    if (!mounted) return;
    // Daraja almashganda eski darajaning "keyingi darsi" qolib ketmasin.
    if (next != _nextLesson) {
      setState(() {
        _nextLesson = next;
        _nextWl = nextWl;
        _nextUnit = nextUnit;
      });
    }
  }

  /// Sarlavhadagi darsni darhol boshlaydi (so'zlar ro'yxati -> savollar).
  Future<void> _startNextLesson(BuildContext context) async {
    final l = _nextWl;
    final u = _nextUnit;
    if (l == null || u == null) return;
    final pool = [for (final x in lessonsOf(u)) ...x.sources];
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          lesson: l,
          unitLabel: u.displayLabel,
          pool: pool,
        ),
      ),
    );
    if (mounted) _findNextLesson();
  }

  /// Oq tugma ochadigan unitning nomi ("1-unit") - `_start` bilan bir xil tanlov.
  String _drillUnitLabel() {
    final main = book.units.where((u) => !u.isInfo).toList();
    if (main.isEmpty) return '';
    final target = progress.lastUnitNo > 0
        ? progress.lastUnitNo
        : main.first.unit;
    for (final b in book.units) {
      if (b.unit == target) return b.displayLabel;
    }
    return main.first.displayLabel;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([progress, mastery, rewards]),
      builder: (context, _) => _card(context),
    );
  }

  Widget _card(BuildContext context) {
    final goal = progress.dailyGoal;
    final today = progress.todayXp;
    final left = (goal - today).clamp(0, goal);
    final met = progress.dailyGoalMet;
    final streak = progress.currentStreak;
    final next = _nextLesson;
    final fading = mastery.fadingCount();
    final examUnit = highestCompletedUnit();
    final examDue = examUnit > 0 && !rewards.examsPassed.contains(examUnit);
    final advice = HomeAdvice.compute(
      fading: fading,
      examUnit: examUnit,
      examPassed: rewards.examsPassed.contains(examUnit),
      nextLesson: next,
      goalMet: met,
    );
    // Keyingi dars sarlavhada turgani uchun tavsiya qatori faqat shoshilinch
    // bo'lsa (so'z o'chyapti / imtihon tayyor) yoki keyingi dars yo'q bo'lsa.
    final showAdvice = next == null || fading >= 3 || examDue;
    // Hali hech narsa qilmagan o'quvchiga "Davom eting" noto'g'ri - "Boshlang".
    final fresh = progress.xp == 0 && progress.lastExerciseId.isEmpty;
    final headline = next != null
        ? '${fresh ? 'Boshlang' : 'Davom eting'}: $next'
        : met
        ? "Kunlik maqsad bajarildi - barakalla!"
        : today == 0
        ? "Bugun kamida $goal ball yig'ing."
        : 'Kunlik maqsadga yana $left ball qoldi.';
    final drillUnit = _drillUnitLabel();
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
                                '${_greeting()} 👋',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _HeroChip(
                                    icon: Icons.local_fire_department_rounded,
                                    text: streak > 0
                                        ? "$streak kun ketma-ket o'qiyapsiz"
                                        : "Bugun boshlang: kunma-kun o'qing",
                                  ),
                                  _HeroChip(
                                    icon: Icons.bolt_rounded,
                                    text: 'Bugun: $today / $goal ball',
                                  ),
                                  _HeroChip(
                                    icon: Icons.help_outline_rounded,
                                    text: 'Bu raqamlar nima?',
                                    onTap: () => _showInfoSheet(
                                      context,
                                      'Bu raqamlar nima?',
                                      [
                                        "Ball - har to'g'ri javob uchun beriladi.",
                                        "Kunlik maqsad - kuniga $goal ball yig'ish "
                                            "(Sozlamalarda o'zgartirasiz). Halqa "
                                            "shu maqsadning necha foizi bajarilganini "
                                            "ko'rsatadi.",
                                        "Ketma-ket kun - har kuni kamida bitta "
                                            "mashq qilsangiz ortadi; bir kunni "
                                            "o'tkazib yuborsangiz 0 dan boshlanadi.",
                                      ],
                                    ),
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
                    // KEYINGI QADAM — bitta aniq, tushunarli jumla.
                    Text(
                      headline,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontSize: 21,
                            height: 1.2,
                          ),
                    ),
                    if (next != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        "Pastdagi tugma shu darsni darhol boshlaydi: "
                        "avval so'zlar ro'yxati, keyin savollar.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                    // Shoshilinch tavsiya (so'z o'chyapti / imtihon tayyor).
                    if (showAdvice) ...[
                      const SizedBox(height: 8),
                      _AdviceLine(advice: advice),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          onTap: () => _nextWl != null
                              ? _startNextLesson(context)
                              : _start(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppColors.brandIndigo,
                                  size: 24,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _nextWl != null
                                        ? "${fresh ? 'Boshlash' : 'Davom etish'}: "
                                            "${_nextWl!.index}-dars "
                                            "(${_nextWl!.words.length} ta so'z)"
                                        : drillUnit.isEmpty
                                        ? 'Tez mashq'
                                        : 'Tez mashq: $drillUnit savollari',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.brandIndigo,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_nextWl != null && drillUnit.isNotEmpty)
                      Center(
                        child: TextButton(
                          onPressed: () => _start(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                          ),
                          child: Text(
                            'Tez mashq: $drillUnit savollari',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: Text(
                        "Mashqda savollar to'g'ri javob berguncha takrorlanadi",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5,
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

/// Hero ichida bitta shoshilinch tavsiya qatori (so'z o'chyapti, imtihon
/// tayyor yoki keyingi dars yo'q bo'lsa). Matn `HomeAdvice` dan keladi.
class _AdviceLine extends StatelessWidget {
  final HomeAdvice advice;
  const _AdviceLine({required this.advice});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(advice.emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            advice.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Hero ichidagi kichik yorliq (ikonka + matn). [onTap] berilsa bosiladi.
/// Matn `Flexible`: tor ekranda va katta shriftda chip ichida qatorga o'tadi.
class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _HeroChip({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
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
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: chip),
    );
  }
}

/// Kunlik maqsad halqasi — katta, oq, animatsiyali to'lish.
/// Tagida nima ekani yoziladi: foiz nimaning foizi ekani ko'rinib tursin.
class _GoalRing extends StatelessWidget {
  final double progress;
  final bool met;
  const _GoalRing({required this.progress, required this.met});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return Semantics(
      label: met
          ? 'Kunlik maqsad bajarildi'
          : 'Kunlik maqsad: $pct foiz bajarildi',
      child: SizedBox(
        width: 84,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
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
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 34,
                        )
                      : Text(
                          '$pct%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              met ? 'maqsad bajarildi' : 'kunlik maqsad',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                  "Diktant: eshiting va gapni yig'ing",
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
          "${tasks.length} ta gap. Ovoz chiqadi, ekranda faqat o'zbekcha "
          "tarjima - gapni so'zlardan tartib bilan teramiz.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
        ),
      ],
    );
  }
}
