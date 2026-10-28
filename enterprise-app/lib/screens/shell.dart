import 'package:flutter/material.dart';
import '../book_content.dart';
import '../levels.dart';
import '../main.dart';
import '../stats.dart' show Progress;
import '../theme.dart';
import '../reward/companion.dart';
import '../reward/reward_widgets.dart';
import '../widgets/geo_bg.dart';
import 'hard_words_screen.dart';
import 'level_reference_screens.dart';
import 'units_screen.dart';
import '../plan/mnemonics_screen.dart';
import 'book/book_screens.dart';
import 'book/conversations_screen.dart';
import 'tutor_setup_screen.dart';
import '../widgets/hover_lift.dart';
import '../widgets/welcome_tour.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

/// Ilova qobig'i — chap sidebar + header (retention indikatorlari).
/// Keng ekranda doimiy sidebar, tor ekranda drawer.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _sel = 0;

  @override
  void initState() {
    super.initState();
    // Birinchi ochilishda hamrohga ism qo'yish (bir marta).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && book.units.isNotEmpty) {
        // AVVAL ilova nima ekani tushuntiriladi (xush kelibsiz turi),
        // KEYIN avatar nomlanadi: ilgari yangi odam hali nima ekanini
        // bilmay turib "avatar ismi" so'ralardi.
        WelcomeTour.showIfNeeded(context).then((_) {
          if (mounted) OnboardingSheet.showIfNeeded(context);
        });
      }
    });
  }

  static const List<(IconData, String)> _items = [
    (Icons.school_rounded, 'Darslar'),
    (Icons.menu_book_rounded, 'Kitob'),
    (Icons.psychology_alt_rounded, 'Mnemonika'),
    (Icons.style_rounded, 'Lug\'at'),
    (Icons.priority_high_rounded, 'Qiyin so\'zlar'),
    (Icons.rule_rounded, 'Grammatika'),
    (Icons.account_tree_rounded, 'So\'z yasalishi'),
    (Icons.forum_rounded, 'Suhbatlar'),
    (Icons.smart_toy_rounded, "AI o'qituvchi"),
    (Icons.settings_rounded, 'Sozlamalar'),
    (Icons.help_outline_rounded, 'Yordam'),
  ];

  /// Menyu bandining tagidagi qisqa izoh - yangi odam "Mnemonika" yoki
  /// "So'z yasalishi" nima ekanini bandni ochmay bilsin.
  static const List<String> _hints = [
    "Asosiy kurs",
    "Betma-bet, to'liq sahifalar",
    "Yodlash rejasi",
    "So'zlarni takrorlash",
    "Ko'p xato qilganlaringiz",
    "Qoidalar va misollar",
    "Qo'shimchali so'zlar",
    "Kitobdagi dialoglar",
    "Mr. Vaysaqi bilan suhbat",
    "Maqsad, ovoz, ma'lumot",
    "Ilova qanday ishlaydi",
  ];

  // "Chiqish" olib tashlandi: ilovada hisob (login) yo'q, hamma
  // narsa shu brauzerda saqlanadi - tugma hech nima qilmasdi.
  // Ma'lumotni o'chirish endi Sozlamalarda.

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        if (wide) {
          return Scaffold(
            body: GeoBackground(
              child: Row(
                children: [
                  _Sidebar(
                    items: _items,
                    hints: _hints,
                    selected: _sel,
                    onSelect: (i) => setState(() => _sel = i),
                    inDrawer: false,
                  ),
                  Expanded(
                    child: SafeArea(
                      child: Column(
                        children: [
                          _header(context),
                          Expanded(child: _body(context)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          drawer: Drawer(
            child: _Sidebar(
              items: _items,
              hints: _hints,
              selected: _sel,
              onSelect: (i) {
                setState(() => _sel = i);
                Navigator.pop(context);
              },
              inDrawer: true,
            ),
          ),
          body: GeoBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Builder(
                    builder: (ctx) => _header(
                      context,
                      menu: IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                  ),
                  Expanded(child: _body(context)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Header: level switcher + retention indikatorlari ---
  Widget _header(BuildContext context, {Widget? menu}) {
    // Panel `progress` ga O'ZI obuna bo'ladi — main.dart dagi
    // `AnimatedBuilder` ga tayanmaydi. Ilgari tayanardi va qobiq
    // `const` bo'lgani uchun rebuild umuman yetib kelmasdi: mashqdan
    // 9 XP olinsa ham panelda 0 turaverardi.
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) => _headerRow(context, menu: menu),
    );
  }

  Widget _headerRow(BuildContext context, {Widget? menu}) {
    final levelRing = GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AchievementsScreen())),
      child: const LevelRing(size: 38),
    );
    final darkBtn = IconButton(
      tooltip: 'Rejimni almashtirish',
      onPressed: progress.toggleDark,
      icon: Icon(
        progress.darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      ),
    );
    // Belgilar izohsiz edi - endi har biri bosilsa "Bu raqamlar nima?"
    // oynasi ochiladi; ball va tanga yorlig'i bilan.
    Widget tap(Widget w) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showStatsHelp(context),
          child: w,
        );
    final stats = <Widget>[
      tap(StreakFlame(days: progress.currentStreak)),
      tap(const HappyHourBadge()),
      tap(_DailyRing(
          progress: progress.dailyProgress, todayXp: progress.todayXp)),
      tap(_Stat(
        icon: Icons.bolt_rounded,
        color: AppColors.success,
        value: progress.xp,
        label: 'ball',
      )),
      tap(_Stat(
        icon: Icons.monetization_on_rounded,
        color: AppColors.coin,
        value: progress.coins,
        label: 'tanga',
      )),
      IconButton(
        tooltip: 'Bu raqamlar nima?',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.help_outline_rounded, size: 20),
        onPressed: () => showStatsHelp(context),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 640;
        if (!compact) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                ?menu,
                const _LevelSwitcher(),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    runAlignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [levelRing, ...stats, darkBtn],
                  ),
                ),
              ],
            ),
          );
        }
        // TELEFON: ikki qator — 1) menyu · daraja · halqa · tun;
        // 2) ko'rsatkichlar gorizontal aylanadi (hech qachon uch
        // qatorga yoyilmaydi, sarlavha joyi tejaladi).
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ?menu,
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _LevelSwitcher(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  levelRing,
                  darkBtn,
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                child: Row(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      stats[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    switch (_sel) {
      case 0:
        return const BookUnitsScreen(); // Enterprise kitobi — asosiy kurs
      case 1:
        return const BookReaderScreen(); // kitob betma-bet
      case 2:
        return const MnemonicsScreen(); // kitobni muddatda tugatish rejasi
      case 3:
        return const UnitsScreen(); // lug'at pack'lari (SRS)
      case 4:
        return const HardWordsScreen(); // qayta-qayta unutilgan so\'zlar
      case 5:
        return const LevelGrammarScreen(); // daraja grammatikasi
      case 6:
        return const LevelWordFormationScreen(); // so'z oilalari
      case 7:
        return const ConversationsScreen(); // kitobdagi barcha dialoglar
      case 8:
        return const TutorSetupScreen(); // AI o'qituvchi: fe'l, ovoz, so'ng suhbat
      case 9:
        return const SettingsScreen();
      case 10:
        return const HelpScreen();
      default:
        return _Placeholder(title: _items[_sel].$2);
    }
  }
}

// ───────────────────────── Sidebar ─────────────────────────
class _Sidebar extends StatelessWidget {
  final List<(IconData, String)> items;
  final List<String> hints;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool inDrawer;
  const _Sidebar({
    required this.items,
    required this.hints,
    required this.selected,
    required this.onSelect,
    required this.inDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        // Yarim shaffof "shisha" panel — aurora fon orqali ko'rinadi.
        color: (dark ? AppColors.darkSurface : AppColors.lightSurface)
            .withValues(alpha: dark ? 0.72 : 0.68),
        border: Border(right: BorderSide(color: AppColors.border(context))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Row(
                children: [
                  const GradientBadge(
                    size: 40,
                    child: Text(
                      'En',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Enterprise',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.3,
                        color: dark
                            ? AppColors.darkHeading
                            : AppColors.lightHeading,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Izohlar tufayli band balandroq - past ekranda aylantiriladi.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _NavItem(
                        icon: items[i].$1,
                        label: items[i].$2,
                        hint: i < hints.length ? hints[i] : '',
                        active: i == selected,
                        onTap: () => onSelect(i),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Reyting: ${progress.league}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.homework,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    this.hint = '',
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = active
        ? Colors.white
        : (dark ? AppColors.darkMuted : AppColors.lightMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          // Faol band — brend gradienti + nur; qolganlari shaffof.
          gradient: active ? AppColors.brandGradient : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: active ? AppShadow.glow(AppColors.brandPurple) : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            hoverColor: AppColors.brandPurple.withValues(alpha: 0.08),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 12),
                  // Sidebar kengligi qat'iy (240px). Uzun yorliq
                  // ("So'z yasalishi") sig'may, chetidan chiqib ketardi.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w600,
                            color: fg,
                          ),
                        ),
                        // Qisqa izoh: bu bo'lim nima ekanini ochmasdan biling.
                        if (hint.isNotEmpty)
                          Text(
                            hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              color: active
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : fg.withValues(alpha: 0.75),
                            ),
                          ),
                      ],
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

// ──────────────────── Header widgetlari ────────────────────
class _LevelSwitcher extends StatelessWidget {
  const _LevelSwitcher();
  @override
  Widget build(BuildContext context) {
    // `const _LevelSwitcher()` bo'lgani uchun ota qayta chizilganda bu
    // widget QAYTA ChIZILMAYDI - yorliq eski darajada qolardi
    // ("Beginner" turib, sarlavha "Elementary"). O'zi obuna bo'ladi.
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final label = levelLabel(progress.currentLevel);
    // Daraja KONTENTI bormi — shu yerda hal qilinadi. Ilgari ro'yxat
    // qat'iy edi: bo'sh darajani tanlash mumkin bo'lgani uchun yuqorida
    // "Elementary" yozilib turardi, kitob bo'limi esa baribir Beginner
    // kontentini ko'rsatardi.
    // Daraja tayyor: lug'ati YOKI kitobi bor.
    bool ready(String lvl) =>
        repo.forLevel(lvl).units.isNotEmpty || BookRepository.hasBook(lvl);
    return PopupMenuButton<String>(
      // Daraja almashsa KITOB ham almashishi kerak — ilgari faqat
      // lug'at almashardi.
      onSelected: (lvl) async {
        if (lvl == progress.currentLevel) return;
        // AVVAL kitob yuklansin, keyin xabar: aks holda ekranlar eski
        // ro'yxat bilan qayta chiziladi va Beginner ko'rinib qolardi.
        await book.setLevel(lvl);
        mastery.setLevel(lvl);
        mistakes.setLevel(lvl);
        await progress.setLevel(lvl);
      },
      itemBuilder: (_) => [
        for (final lvl in kLevels)
          PopupMenuItem(
            value: lvl.id,
            enabled: ready(lvl.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ready(lvl.id) ? lvl.label : '${lvl.label} — tayyor emas',
                ),
                Text(
                  lvl.bookTitle.split(' - ').first,
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.muted(context)),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.brandPurple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandPurple,
                ),
              ),
            ),
            // Qaysi kitob ekani: "Beginner" yolg'iz tushunarsiz edi.
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  levelBookTitle(progress.currentLevel).split(' - ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandPurple.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: AppColors.brandPurple,
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyRing extends StatelessWidget {
  final double progress;
  final int todayXp;
  const _DailyRing({required this.progress, required this.todayXp});
  @override
  Widget build(BuildContext context) {
    final met = progress >= 1.0;
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.neutralShadow.withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation(
                  met ? AppColors.success : AppColors.coin,
                ),
              ),
            ),
          ),
          met
              ? const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.success,
                )
              : Text(
                  '$todayXp',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    this.label = '',
  });
  @override
  Widget build(BuildContext context) {
    // Kichik "chip": rangli fon ustida raqam — panel bir tekis o'qiladi.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label.isEmpty ? '$value' : '$value $label',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Bu raqamlar nima?" - tepadagi belgilarning har biri nimani bildirishi.
void showStatsHelp(BuildContext context) {
  final r = rewards;
  Widget row(String icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.muted(context))),
                ],
              ),
            ),
          ],
        ),
      );
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu raqamlar nima?',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            row('🔥', 'Ketma-ket kunlar',
                "Necha kun ketma-ket o'qiganingiz. Har kuni kamida bir mashq "
                "qilsangiz o'sadi. 🌱 - hali boshlanmagan."),
            row('⏰', 'Ikki barobar ball soati',
                "Har kuni ${r.happyHour}:00 dan 1 soat davomida har to'g'ri "
                "javob uchun ball 2 barobar."),
            row('◯', 'Bugungi ball',
                "Aylana ichidagi raqam - bugun to'plagan ballingiz. Maqsad: "
                "${progress.dailyGoal} ball. Yetganda ✓ belgisi chiqadi."),
            row('⚡', 'Ball',
                "Har to'g'ri javob ball beradi. Ball ko'paygan sari "
                "darajangiz oshadi."),
            row('🪙', 'Tanga',
                "Kunlik vazifa, Omad g'ildiragi va sovg'a qutisidan "
                "olinadi. Uzilib qolgan kunlarni tiklashga yoki bir kunni "
                "o'tkazib yuborishdan himoyalashga (${Progress.freezeCost} "
                "tanga) sarflanadi."),
            row('1', 'Daraja',
                "Binafsha aylana - hozirgi darajangiz (${r.level}-daraja). "
                "Bosing: yutuqlaringiz ko'rinadi."),
            row('📘', 'Beginner / Elementary',
                "Kitob darajasi: Beginner - Enterprise 1, Elementary - "
                "Enterprise 2. Chap yuqoridagi tugmadan almashtirasiz."),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Tushundim',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ──────────────────── Body: placeholder ekranlar ────────────────────
class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.construction_rounded,
            size: 48,
            color: AppColors.brandPurple.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text('$title — keyingi fazalarda', style: AppTheme.body(context)),
        ],
      ),
    );
  }
}
