import 'package:flutter/material.dart';
import 'theme.dart';
import 'stats.dart';
import 'content.dart';
import 'book_content.dart';
import 'mastery.dart';
import 'reward/reward_engine.dart';
import 'reward/reward_overlay.dart';
import 'reward/sfx.dart';
import 'screens/shell.dart';

/// Global foydalanuvchi holati (bitta foydalanuvchi — egasi).
late Progress progress;

/// Dofamin dvigateli — `reward/reward_engine.dart`.
RewardEngine rewards = RewardEngine();

/// Band darajasidagi o'zlashtirish — `mastery.dart`.
late MasteryStore mastery;

/// Global lug'at repozitoriysi (asset'lardan yuklanadi).
late ContentRepository repo;

/// Enterprise kitobi kontenti (unit'lar, mashqlar, qoidalar).
late BookRepository book;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  progress = Progress();
  mastery = MasteryStore();
  repo = ContentRepository();
  book = BookRepository();
  await Future.wait([
    progress.load(),
    rewards.load(),
    mastery.load(),
    repo.load(),
    book.loadIndex(),
    // Qaysi darajalarda KITOB borligi — daraja tanlagichi shunga
    // qarab ochiladi.
    BookRepository.probeLevels(),
  ]);
  // Saqlangan daraja Beginner bo'lmasa, kitob ham o'shanga o'tsin.
  await book.setLevel(progress.currentLevel);
  mastery.setLevel(progress.currentLevel);
  runApp(const EnterpriseApp());
}

class EnterpriseApp extends StatelessWidget {
  const EnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    // progress o'zgarganda (dark mode, XP...) butun ilova qayta quriladi.
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => MaterialApp(
        title: 'Enterprise English Trainer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: progress.darkMode ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) {
          Sfx.instance.enabled = progress.sfx;
          return RewardOverlay(child: child ?? const SizedBox());
        },
        home: const AppShell(),
      ),
    );
  }
}
