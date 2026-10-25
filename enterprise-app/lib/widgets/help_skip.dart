import 'package:flutter/material.dart';

import '../services/tts.dart';
import '../theme.dart';

/// BILMAYMAN / O'TKAZISh — har savol ostida.
///
/// O'quvchi so'zni bilmasa, taxmin qilib "xato" yig'ishi shart emas:
///   * "Bilmayman - ko'rsat": to'g'ri javob tarjimasi va ovozi bilan
///     ochiladi; savol keyinroq yana so'raladi (ko'rgandan keyin eslash
///     - eng kuchli yodlash usuli).
///   * "O'tkazib yuborish": savol hozircha chetga suriladi.
///
/// Ikkala tugma ham CHEGARALI (outlined) - ochiq-oydin bosiladigan
/// tugma ko'rinishida; ilgari tekis matn edi va "o'chirilgan" deb
/// o'ylanardi. Tagida bir qator izoh: chapdagi tugma nima qiladi,
/// o'ngdagisi nima qiladi (jarima yo'qligi shundan bilinadi).
class HelpSkipBar extends StatelessWidget {
  final VoidCallback? onHelp;
  final VoidCallback? onSkip;

  /// Chapdagi tugma nima qilishi (izoh va tooltip uchun).
  final String helpHint;

  /// O'ngdagi tugma nima qilishi. Ekranga qarab farq qiladi (masalan,
  /// darsda o'tkazilgan savol qaytmaydi, trening'da qaytadi) - shuning
  /// uchun chaqiruvchi aniqlashtirishi mumkin.
  final String skipHint;

  /// Tagidagi izoh qatorini ko'rsatish.
  final bool showHint;

  const HelpSkipBar({
    super.key,
    this.onHelp,
    this.onSkip,
    this.helpHint = "javobni ko'rsatadi, savol keyin yana so'raladi",
    this.skipHint = "savolni o'tkazib yuboradi",
    this.showHint = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Och fonda to'q sariq matn kontrasti past (3.6:1) - to'qroq tus.
    final helpColor = dark ? const Color(0xFFFB923C) : const Color(0xFFC2410C);
    final skipColor = Theme.of(context).textTheme.bodyLarge?.color ??
        (dark ? AppColors.darkInk : AppColors.lightInk);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Tooltip(
                    message: 'Bilmayman: $helpHint',
                    child: _bar(
                      onPressed: onHelp,
                      icon: Icons.lightbulb_outline_rounded,
                      label: "Bilmayman - ko'rsat",
                      color: helpColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: "O'tkazib yuborish: $skipHint",
                    child: _bar(
                      onPressed: onSkip,
                      icon: Icons.skip_next_rounded,
                      label: "O'tkazib yuborish",
                      color: skipColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showHint) ...[
            const SizedBox(height: 4),
            Text(
              "Chapdagi tugma - $helpHint. O'ngdagisi - $skipHint.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5, height: 1.3, color: AppColors.muted(context)),
            ),
          ],
        ],
      ),
    );
  }

  /// Bitta chegarali tugma: kamida 44 px balandlik, 1.5 px chegara,
  /// engil fon. O'chirilgan (null) holatda Flutter o'zi xiralashtiradi.
  Widget _bar({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final on = onPressed != null;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      // Tor ekranda matn kesilmasin - 2 qatorga o'raladi.
      label: Text(label, textAlign: TextAlign.center, maxLines: 2),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: on ? 0.07 : 0.03),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.padded,
        side: BorderSide(
            color: color.withValues(alpha: on ? 0.6 : 0.2), width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
      ),
    );
  }
}

/// To'g'ri javobni tushuntirib ko'rsatadi. [speak] - inglizcha matn
/// (bo'lsa ovoz tugmasi chiqadi va darhol bir marta o'qiladi).
Future<void> showAnswerHelp(
  BuildContext context, {
  String question = '',
  required String answer,
  String translation = '',
  String speak = '',
  String note = "Bu savol keyinroq yana so'raladi - shunda o'zingiz toping.",
}) async {
  if (speak.trim().isNotEmpty) Tts.instance.speak(speak);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final muted = AppColors.muted(ctx);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💡 Yordam',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              if (question.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Savol:', style: TextStyle(fontSize: 12.5, color: muted)),
                Text(question,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 12),
              Text("To'g'ri javob:",
                  style: TextStyle(fontSize: 12.5, color: muted)),
              Row(
                children: [
                  Expanded(
                    child: Text(answer,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.success)),
                  ),
                  if (speak.trim().isNotEmpty)
                    IconButton(
                      tooltip: 'Tinglash',
                      icon: const Icon(Icons.volume_up_rounded),
                      color: AppColors.brandPurple,
                      onPressed: () => Tts.instance.speak(speak),
                    ),
                ],
              ),
              if (translation.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Tarjimasi:',
                    style: TextStyle(fontSize: 12.5, color: muted)),
                Text(translation,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 12),
              Text(note,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: muted)),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Tushundim, davom etamiz',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    },
  );
}
