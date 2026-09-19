import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/install.dart';
import '../theme.dart';

/// "TELEFONGA O'RNATING" — PWA kartasi. Bosh ekrandagi belgi = har
/// kuni ko'z oldida (retention). Faqat brauzerda ochilganda, kamida
/// bitta mashq qilingandan keyin; yopilsa qayta chiqmaydi.
class InstallCard extends StatefulWidget {
  const InstallCard({super.key});

  @override
  State<InstallCard> createState() => _InstallCardState();
}

class _InstallCardState extends State<InstallCard> {
  static const _key = 'install_card_dismissed';
  bool _hidden = true;
  bool _showIos = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _hidden = p.getBool(_key) ?? false);
    });
  }

  Future<void> _dismiss() async {
    setState(() => _hidden = true);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
  }

  Future<void> _install() async {
    if (Install.canPrompt) {
      final ok = await Install.prompt();
      if (ok) await _dismiss();
      if (!mounted) return;
      setState(() {});
      return;
    }
    setState(() => _showIos = !_showIos);
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden || Install.isStandalone) return const SizedBox.shrink();
    if (!Install.canPrompt && !Install.isIos) return const SizedBox.shrink();
    if (rewards.exercisesDone < 1) return const SizedBox.shrink();
    final muted = AppColors.muted(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_to_home_screen_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Telefonga o\'rnating',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                        'Bosh ekrandan bir bosishda - ilova kabi, to\'liq ekran.',
                        style: TextStyle(fontSize: 12.5, color: muted)),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _dismiss,
                icon: Icon(Icons.close_rounded, size: 20, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _install,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(
                Install.canPrompt ? 'O\'rnatish' : 'Qanday o\'rnatiladi?'),
          ),
          if (_showIos) ...[
            const SizedBox(height: 10),
            Text(
              'Safari: pastdagi "Ulashish" tugmasi -> "Add to Home Screen" -> "Add".',
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}
