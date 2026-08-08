import 'package:flutter/material.dart';
import 'theme.dart';
import 'stats.dart';
import 'content.dart';
import 'screens/shell.dart';

/// Global foydalanuvchi holati (bitta foydalanuvchi — egasi).
late Progress progress;

/// Global kontent repozitoriysi (asset'lardan yuklanadi).
late ContentRepository repo;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  progress = Progress();
  repo = ContentRepository();
  await Future.wait([progress.load(), repo.load()]);
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
        home: const AppShell(),
      ),
    );
  }
}
