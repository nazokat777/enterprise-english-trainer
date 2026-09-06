import 'package:flutter/material.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/geo_bg.dart';
import 'hard_words_screen.dart';
import 'level_reference_screens.dart';
import 'units_screen.dart';
import 'book/book_screens.dart';

/// Ilova qobig'i — chap sidebar + header (retention indikatorlari).
/// Keng ekranda doimiy sidebar, tor ekranda drawer.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _sel = 0;

  static const List<(IconData, String)> _items = [
    (Icons.school_rounded, 'Darslar'),
    (Icons.style_rounded, 'Lug\'at'),
    (Icons.priority_high_rounded, 'Qiyin so\'zlar'),
    (Icons.rule_rounded, 'Grammatika'),
    (Icons.account_tree_rounded, 'So\'z yasalishi'),
    (Icons.forum_rounded, 'Suhbatlar'),
    (Icons.settings_rounded, 'Sozlamalar'),
    (Icons.help_outline_rounded, 'Yordam'),
    (Icons.logout_rounded, 'Chiqish'),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          ?menu,
          const _LevelSwitcher(),
          // TELEFONDA: ilgari bu yerda `Spacer()` turardi va o'ng tomondagi
          // ko'rsatkichlar guruhi CHEKSIZ kenglik olardi — 375px ekranda
          // panel 47 piksel oshib ketib, sariq-qora "overflow" chizig'i
          // chiqardi. `Expanded` guruhga aniq kenglik beradi, `Wrap` esa
          // sig'masa ikkinchi qatorga o'tadi.
          Expanded(
            child: Wrap(
            alignment: WrapAlignment.end,
            runAlignment: WrapAlignment.center,
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StreakBadge(streak: progress.currentStreak),
              _DailyRing(progress: progress.dailyProgress, todayXp: progress.todayXp),
              _Stat(icon: Icons.bolt_rounded, color: AppColors.success, value: progress.xp),
              _Stat(icon: Icons.monetization_on_rounded, color: AppColors.coin, value: progress.coins),
              IconButton(
                tooltip: 'Rejimni almashtirish',
                onPressed: progress.toggleDark,
                icon: Icon(progress.darkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded),
              ),
            ],
          ),
          ),
        ],
      ),
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
      color: dark ? AppColors.darkSurface : AppColors.lightSurface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brandPurple,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Center(
                      child: Text('En',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text('Enterprise',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: dark
                                ? AppColors.darkHeading
                                : AppColors.lightHeading)),
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
              child: Text('Liga: ${progress.league}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.homework)),
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
        ? AppColors.brandPurple
        : (dark ? AppColors.darkMuted : AppColors.lightMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: active
            ? AppColors.brandPurple.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
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
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
                          color: fg)),
                ),
              ],
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
    final label = progress.currentLevel == 'beginner' ? 'Beginner' : 'Elementary';
    // Daraja KONTENTI bormi — shu yerda hal qilinadi. Ilgari ro'yxat
    // qat'iy edi: bo'sh darajani tanlash mumkin bo'lgani uchun yuqorida
    // "Elementary" yozilib turardi, kitob bo'limi esa baribir Beginner
    // kontentini ko'rsatardi.
    bool ready(String lvl) => repo.forLevel(lvl).units.isNotEmpty;
    return PopupMenuButton<String>(
      onSelected: progress.setLevel,
      itemBuilder: (_) => [
        for (final lvl in const [('beginner', 'Beginner'),
                                 ('elementary', 'Elementary')])
          PopupMenuItem(
            value: lvl.$1,
            enabled: ready(lvl.$1),
            child: Text(ready(lvl.$1) ? lvl.$2 : '${lvl.$2} — tayyor emas'),
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
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.brandPurple)),
            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.brandPurple),
          ],
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🔥', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 3),
        Text('$streak',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.homework)),
      ],
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
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              backgroundColor: AppColors.neutralShadow.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(
                  met ? AppColors.success : AppColors.coin),
            ),
          ),
          met
              ? const Icon(Icons.check_rounded, size: 18, color: AppColors.success)
              : Text('$todayXp',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 3),
        Text('$value',
            style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 15)),
      ],
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
          Icon(Icons.construction_rounded,
              size: 48, color: AppColors.brandPurple.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('$title — keyingi fazalarda', style: AppTheme.body(context)),
        ],
      ),
    );
  }
}

