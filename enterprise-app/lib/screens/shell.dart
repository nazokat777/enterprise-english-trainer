import 'package:flutter/material.dart';
import '../book_content.dart';
import '../levels.dart';
import '../main.dart';
import '../theme.dart';
import '../reward/companion.dart';
import '../reward/reward_widgets.dart';
import '../widgets/geo_bg.dart';
import 'hard_words_screen.dart';
import 'level_reference_screens.dart';
import 'units_screen.dart';
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
        // Avval avatar nomlanadi, so'ng 3 sahifali xush kelibsiz turi.
        OnboardingSheet.showIfNeeded(context).then((_) {
          if (mounted && rewards.loaded && rewards.onboarded) {
            WelcomeTour.showIfNeeded(context);
          }
        });
      }
    });
  }

  static const List<(IconData, String)> _items = [
    (Icons.school_rounded, 'Darslar'),
    (Icons.style_rounded, 'Lug\'at'),
    (Icons.priority_high_rounded, 'Qiyin so\'zlar'),
    (Icons.rule_rounded, 'Grammatika'),
    (Icons.account_tree_rounded, 'So\'z yasalishi'),
    (Icons.forum_rounded, 'Suhbatlar'),
    (Icons.smart_toy_rounded, 'Mr. Vaysaqi'),
    (Icons.settings_rounded, 'Sozlamalar'),
    (Icons.help_outline_rounded, 'Yordam'),
    // "Chiqish" olib tashlandi: ilovada hisob (login) yo'q, hamma
    // narsa shu brauzerda saqlanadi — tugma hech nima qilmasdi.
    // Ma'lumotni o'chirish endi Sozlamalarda.
  ];

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
    final stats = <Widget>[
      StreakFlame(days: progress.currentStreak),
      const HappyHourBadge(),
      _DailyRing(progress: progress.dailyProgress, todayXp: progress.todayXp),
      _Stat(
        icon: Icons.bolt_rounded,
        color: AppColors.success,
        value: progress.xp,
      ),
      _Stat(
        icon: Icons.monetization_on_rounded,
        color: AppColors.coin,
        value: progress.coins,
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
        return const UnitsScreen(); // lug'at pack'lari (SRS)
      case 2:
        return const HardWordsScreen(); // qayta-qayta unutilgan so\'zlar
      case 3:
        return const LevelGrammarScreen(); // daraja grammatikasi
      case 4:
        return const LevelWordFormationScreen(); // so'z oilalari
      case 5:
        return const ConversationsScreen(); // kitobdagi barcha dialoglar
      case 6:
        return const TutorSetupScreen(); // AI o'qituvchi: fe'l, ovoz, so'ng suhbat
      case 7:
        return const SettingsScreen();
      case 8:
        return const HelpScreen();
      default:
        return _Placeholder(title: _items[_sel].$2);
    }
  }
}

// ───────────────────────── Sidebar ─────────────────────────
class _Sidebar extends StatelessWidget {
  final List<(IconData, String)> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool inDrawer;
  const _Sidebar({
    required this.items,
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
            for (var i = 0; i < items.length; i++)
              _NavItem(
                icon: items[i].$1,
                label: items[i].$2,
                active: i == selected,
                onTap: () => onSelect(i),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Liga: ${progress.league}',
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
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 12),
                  // Sidebar kengligi qat'iy (240px). Uzun yorliq
                  // ("So'z yasalishi") sig'may, chetidan chiqib ketardi.
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        color: fg,
                      ),
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
            child: Text(
              ready(lvl.id) ? lvl.label : '${lvl.label} — tayyor emas',
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
  const _Stat({required this.icon, required this.color, required this.value});
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
            '$value',
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
