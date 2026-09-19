import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// XUSH KELIBSIZ TURI — birinchi ochilishda 3 ta sahifa (bir marta).
///
/// UX: yangi foydalanuvchi bosh ekrandagi 8 ta kartani ko'rib "qayerdan
/// boshlay?" deb qotib qolmasin. Uch qisqa sahifa: nima bu, qanday
/// o'rgatadi, nima bilan boshlash. Har sahifa gradient nishon + 1-2
/// gap. Oxirida bitta katta tugma.
class WelcomeTour extends StatefulWidget {
  const WelcomeTour({super.key});

  static const _key = 'welcome_tour_done';

  static Future<bool> isDone() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key) ?? false;
  }

  static Future<void> markDone() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
  }

  /// Avatar nomlangandan KEYIN ko'rsatiladi (ikki oyna birga chiqmasin).
  static Future<void> showIfNeeded(BuildContext context) async {
    if (await isDone()) return;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WelcomeTour(),
    );
    await markDone();
  }

  @override
  State<WelcomeTour> createState() => _WelcomeTourState();
}

class _WelcomeTourState extends State<WelcomeTour> {
  final _page = PageController();
  int _i = 0;

  static const _pages = [
    (
      Icons.auto_stories_rounded,
      AppColors.brandGradient,
      'Enterprise kitobi - o\'yin ko\'rinishida',
      'Coursebook, Workbook va Grammar kitoblarining har bir beti '
          'interaktiv mashqqa aylantirilgan. Kitob qo\'lingizda bo\'lsa ham, '
          'bo\'lmasa ham - ilova betma-bet olib boradi.',
    ),
    (
      Icons.psychology_rounded,
      AppColors.successGradient,
      'Xotira ilmi bilan yodlanadi',
      'Har so\'z avval ko\'rsatiladi, so\'ng 3-4 shaklda so\'raladi va '
          '1-3-7-14-30 kun oralig\'ida qayta keladi. Xato - jazo emas: '
          'band qaytadi, siz o\'zlashtirmaguningizcha.',
    ),
    (
      Icons.rocket_launch_rounded,
      AppColors.goldGradient,
      'Har kuni 3 daqiqa',
      'Bosh ekrandagi "Tez mashq" - bir bosishda. Seriya, XP, missiyalar, '
          'Blitz va imtihonlar sizni har kuni qaytarib turadi. Boshlaymizmi?',
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(
              height: 340,
              child: PageView.builder(
                controller: _page,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (context, i) {
                  final (icon, grad, title, body) = _pages[i];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            gradient: grad,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: AppShadow.glow(
                              grad.colors.first,
                              alpha: 0.4,
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 44),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _i
                          ? AppColors.brandPurple
                          : AppColors.brandPurple.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  if (last) {
                    Navigator.pop(context);
                  } else {
                    _page.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                child: Text(last ? 'Boshlash' : 'Keyingisi'),
              ),
            ),
            if (!last)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('O\'tkazib yuborish'),
              ),
          ],
        ),
      ),
    );
  }
}
