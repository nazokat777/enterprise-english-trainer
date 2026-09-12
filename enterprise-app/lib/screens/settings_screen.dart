import 'package:flutter/material.dart';

import '../main.dart';
import '../stats.dart';
import '../services/tts.dart';
import '../reward/reward_engine.dart';
import '../reward/reward_widgets.dart';
import '../theme.dart';

/// SOZLAMALAR — ilgari "keyingi fazalarda" degan bo'sh ekran edi.
///
/// Bu yerda kunlik maqsad, tungi rejim, seriya muzlatgichi va
/// jarayonni tozalash bor. Muzlatgich `Progress.buyStreakFreeze` da
/// yozilgan edi, lekin uni sotib oladigan tugma hech qayerda yo'q edi
/// — pulli imkoniyat erishib bo'lmas holda qolgan.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      // DIQQAT: bolalar `const` EMAS.
      //
      // `const` bo'lsa Dart har safar AYNAN BIR nusxani qaytaradi,
      // Flutter esa `identical(old, new)` ni ko'rib ularni qayta
      // QURMAYDI. Natijada tanga sotib olingandan keyin ham ekranda
      // eski "Tanga yetarli emas (0/200)" yozuvi turib qolardi.
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _Title(),
          const SizedBox(height: 14),
          _GoalCard(),
          const SizedBox(height: 10),
          _DarkCard(),
          const SizedBox(height: 10),
          const _SfxCard(),
          const SizedBox(height: 10),
          const _AchievementsCard(),
          const SizedBox(height: 10),
          const _VoiceCard(),
          const SizedBox(height: 10),
          _FreezeCard(),
          const SizedBox(height: 10),
          _StatsCard(),
          const SizedBox(height: 10),
          const _SkillsCard(),
          const SizedBox(height: 10),
          _ResetCard(),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();
  @override
  Widget build(BuildContext context) =>
      Text('Sozlamalar', style: AppTheme.heading(context));
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: child,
      );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard();

  @override
  Widget build(BuildContext context) {
    // Variantlar MODELDAN olinadi — ikki joyda ikki xil ro'yxat
    // bo'lib qolmasin.
    const goals = Progress.goalOptions;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kunlik maqsad',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text('Bir kunda nechta XP yig\'moqchisiz',
              style:
                  TextStyle(fontSize: 12.5, color: AppColors.muted(context))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final g in goals)
                ChoiceChip(
                  label: Text('$g XP'),
                  selected: progress.dailyGoal == g,
                  onSelected: (_) => progress.setDailyGoal(g),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkCard extends StatelessWidget {
  const _DarkCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Icon(progress.darkMode
              ? Icons.dark_mode_rounded
              : Icons.light_mode_rounded),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Tungi rejim',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          Switch(
            value: progress.darkMode,
            onChanged: (_) => progress.toggleDark(),
          ),
        ],
      ),
    );
  }
}

class _SfxCard extends StatelessWidget {
  const _SfxCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Icon(progress.sfx ? Icons.volume_up_rounded : Icons.volume_off_rounded),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ovoz effektlari',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text("To'g'ri javob, kombo, sandiq, daraja ovozlari",
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: progress.sfx,
            onChanged: (_) => progress.toggleSfx(),
          ),
        ],
      ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard();

  @override
  Widget build(BuildContext context) {
    final got = rewards.achievements.length;
    final all = RewardEngine.allAchievements.length;
    return _Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AchievementsScreen())),
        child: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Yutuqlar',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('$got / $all medal · ${rewards.level}-daraja · ${rewards.title}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// TALAFFUZ OVOZI — qaysi ovoz ishlatilyapti va u inglizchami.
///
/// `Tts.englishVoiceFound` allaqachon hisoblanardi ("topilmasa UI
/// ogohlantirishi mumkin" deb yozilgan edi), lekin uni HECH BIR ekran
/// ko'rsatmasdi. Qurilmada inglizcha ovoz bo'lmasa, talaffuz o'zbek
/// yoki rus talaffuzi bilan o'qilardi va o'quvchi sababini bilmasdi.
class _VoiceCard extends StatefulWidget {
  const _VoiceCard();

  @override
  State<_VoiceCard> createState() => _VoiceCardState();
}

class _VoiceCardState extends State<_VoiceCard> {
  @override
  void initState() {
    super.initState();
    // Ovoz ro'yxati faqat birinchi o'qishdan keyin to'ldiriladi —
    // ekran ochilishi bilan tayyorlab qo'yamiz.
    Tts.instance.warmUp().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Tts.instance.englishVoiceFound,
      builder: (context, found, _) {
        final voice = Tts.instance.selectedVoice;
        // Ba'zi brauzerlarda ovoz xizmati umuman yo'q — bunda har bir
        // ovoz tugmasi JIMGINA ishlamasdi va sababi noma'lum qolardi.
        final off = !Tts.instance.available;
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                      found && !off
                          ? Icons.record_voice_over_rounded
                          : Icons.warning_amber_rounded,
                      color: found && !off
                          ? AppColors.success
                          : AppColors.homework),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Talaffuz ovozi',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                off
                    ? 'Bu brauzerda ovoz xizmati ishlamaydi — talaffuz '
                        'tugmalari jim qoladi. Boshqa brauzer yoki '
                        'telefon ilovasida urinib ko\'ring.'
                    : found
                    ? (voice ?? 'Qurilmaning inglizcha ovozi ishlatiladi.')
                    : 'Qurilmada inglizcha ovoz topilmadi. So\'zlar '
                        'noto\'g\'ri talaffuz qilinishi mumkin — telefon '
                        'sozlamalaridan inglizcha ovozni yuklab oling.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.4, color: AppColors.muted(context)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Tts.instance.speak('Hello! How are you?'),
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                label: const Text('Sinab ko\'rish'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FreezeCard extends StatelessWidget {
  const _FreezeCard();

  @override
  Widget build(BuildContext context) {
    final enough = progress.coins >= Progress.freezeCost;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.ac_unit_rounded, color: AppColors.actionBlue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Seriya muzlatgichi',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Text('${progress.streakFreezeCount} ta',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Bir kun dars qilolmasangiz, muzlatgich seriyangizni saqlab '
            'qoladi. Narxi ${Progress.freezeCost} tanga.',
            style: TextStyle(
                fontSize: 12.5, height: 1.4, color: AppColors.muted(context)),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: enough
                ? () async {
                    final ok = await progress.buyStreakFreeze();
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Muzlatgich sotib olindi')),
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.shopping_cart_rounded, size: 18),
            label: Text(enough
                ? 'Sotib olish (${Progress.freezeCost} tanga)'
                : 'Tanga yetarli emas '
                    '(${progress.coins}/${Progress.freezeCost})'),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Jami XP', '${progress.xp}'),
      ('Liga', progress.league),
      ('Tanga', '${progress.coins}'),
      ('Joriy seriya', '${progress.currentStreak} kun'),
      ('Eng uzun seriya', '${progress.longestStreak} kun'),
      ('Qiyin so\'zlar', '${progress.hardCount()} ta'),
      ('Takrorlash kerak', '${progress.needsReviewCount()} ta mashq'),
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Natijalar',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                      child: Text(r.$1,
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.muted(context)))),
                  Text(r.$2,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// KO'NIKMALAR — qaysi ko'nikma zaif ekani.
///
/// `Progress.skills` har XP olinganda yozilardi va diskka ham
/// saqlanardi, lekin `skillPercent` ni HECH BIR ekran o'qimasdi —
/// ya'ni o'quvchi qaysi ko'nikmasi orqada qolayotganini bilolmasdi.
class _SkillsCard extends StatelessWidget {
  const _SkillsCard();

  static const Map<Skill, String> _uz = {
    Skill.listening: 'Tinglash',
    Skill.grammar: 'Grammatika',
    Skill.vocab: 'Lug\'at',
    Skill.reading: 'O\'qish',
    Skill.speaking: 'Gapirish',
  };

  @override
  Widget build(BuildContext context) {
    final any = Skill.values.any((s) => progress.skillPercent(s) > 0);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ko\'nikmalar',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(
            any
                ? 'Mashq qilgan sari o\'sadi — orqada qolgani ustida '
                    'ko\'proq ishlang.'
                : 'Hali mashq qilinmagan. Dars boshlasangiz shu yerda '
                    'ko\'rinadi.',
            style: TextStyle(
                fontSize: 12.5, height: 1.4, color: AppColors.muted(context)),
          ),
          const SizedBox(height: 10),
          for (final s in Skill.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_uz[s]!,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      Text('${progress.skillPercent(s)}%',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.muted(context))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.skillPercent(s) / 100,
                      minHeight: 5,
                      backgroundColor:
                          AppColors.brandPurple.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.brandPurple),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResetCard extends StatelessWidget {
  const _ResetCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Boshidan boshlash',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Barcha XP, seriya va o\'zlashtirilgan mashqlar o\'chadi. '
            'Buni qaytarib bo\'lmaydi.',
            style: TextStyle(
                fontSize: 12.5, height: 1.4, color: AppColors.muted(context)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => _confirmReset(context),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Jarayonni o\'chirish'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hammasini o\'chirasizmi?'),
        content: const Text(
            'XP, seriya, o\'zlashtirilgan mashqlar va so\'z takrorlash '
            'jadvali — hammasi yo\'qoladi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Bekor qilish')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('O\'chirish')),
        ],
      ),
    );
    if (yes == true) {
      await progress.resetAll();
      await rewards.resetAll();
    }
  }
}
