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
class HelpSkipBar extends StatelessWidget {
  final VoidCallback? onHelp;
  final VoidCallback? onSkip;

  const HelpSkipBar({super.key, this.onHelp, this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: onHelp,
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 19),
              label: const Text("Bilmayman - ko'rsat",
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.homework,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: onSkip,
              icon: const Icon(Icons.skip_next_rounded, size: 19),
              label: const Text("O'tkazib yuborish",
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted(context),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
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
