import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'sfx.dart';

/// KETMA-KET KUNLARNI QAYTARISH kartasi — uzilgan kunlarni 2 kun ichida tanga evaziga
/// qaytarish. Yo'qotish og'rig'i (loss aversion) o'quvchini
/// ilovadan uzoqlashtiradi; "qaytarish mumkin" degan xabar uni qaytaradi.
class StreakRepairCard extends StatelessWidget {
  const StreakRepairCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        if (!progress.canRepairStreak) return const SizedBox.shrink();
        final cost = progress.repairCost;
        final canPay = progress.coins >= cost;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7C2D12), Color(0xFFB45309), Color(0xFFD97706)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadow.glow(const Color(0xFFD97706), alpha: 0.35),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ketma-ket ${progress.lostStreak} kunlik o\'qishingiz uzildi',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      canPay
                          ? 'Tanga evaziga qaytarishingiz mumkin: $cost tanga (2 kun ichida).'
                          : 'Qaytarish uchun $cost tanga kerak, sizda ${progress.coins} ta. '
                              'Mashq qilib tanga yig\'ing.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF9A3412),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.sm)),
                          ),
                          onPressed: canPay
                              ? () async {
                                  final ok = await progress.repairStreak();
                                  if (ok) {
                                    Sfx.instance.chest();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                          content: Text(
                                              '🔥 Ketma-ket kunlar qaytdi: ${progress.currentStreak} kun!')));
                                    }
                                  }
                                }
                              : null,
                          child: Text('Qaytarish · $cost tanga'),
                        ),
                        Tooltip(
                          message: 'Yopsangiz, uzilgan kunlarni keyin qaytarib bo\'lmaydi',
                          child: TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                visualDensity: VisualDensity.compact),
                            onPressed: progress.dismissRepair,
                            child: const Text('Kerak emas, yopish'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
