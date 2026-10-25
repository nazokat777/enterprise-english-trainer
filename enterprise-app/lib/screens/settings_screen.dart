import 'package:flutter/material.dart';

import '../main.dart';
import '../stats.dart';
import 'package:flutter/services.dart';

import '../services/backup.dart';
import '../services/ai_tutor_service.dart';
import '../services/tts.dart';
import 'ai_tutor_screen.dart' show KeySiteLink, ProviderPicker;
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
          // Bir xil ko'rinishdagi uzun ro'yxat guruhlarga bo'lindi:
          // qaysi karta nimaga tegishli ekani sarlavhadan ko'rinadi.
          const _Group("O'qish maqsadi"),
          _GoalCard(),
          const SizedBox(height: 10),
          _FreezeCard(),
          const _Group("Ko'rinish va ovoz"),
          _DarkCard(),
          const SizedBox(height: 10),
          const _SfxCard(),
          const SizedBox(height: 10),
          const _VoiceCard(),
          const _Group('Natijalaringiz'),
          const _AchievementsCard(),
          const SizedBox(height: 10),
          _StatsCard(),
          const SizedBox(height: 10),
          const _SkillsCard(),
          const _Group("AI o'qituvchi"),
          const _ApiKeyCard(),
          const _Group("Ma'lumotlar"),
          const _BackupCard(),
          const _Group('Xavfli joy'),
          _ResetCard(),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sozlamalar', style: AppTheme.heading(context)),
          const SizedBox(height: 2),
          Text('Ilova sozlamalari va natijalaringiz shu yerda.',
              style:
                  TextStyle(fontSize: 13, color: AppColors.muted(context))),
        ],
      );
}

/// Kartalar guruhi sarlavhasi.
class _Group extends StatelessWidget {
  final String title;
  const _Group(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8, left: 2),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: AppColors.muted(context))),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: AppShadow.card(context),
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
          Text(
              'Kuniga necha ball yig\'moqchisiz? Ball - to\'g\'ri javob va '
              'tugatilgan mashq uchun beriladi. Boshlovchiga 10 yoki 20 '
              'yetarli.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.4, color: AppColors.muted(context))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final g in goals)
                ChoiceChip(
                  label: Text('$g ball'),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tungi rejim',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Ekran qorong\'i bo\'ladi - kechqurun ko\'zni charchatmaydi.',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.muted(context))),
              ],
            ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ovoz effektlari',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(
                    "To'g'ri javob, ketma-ket to'g'ri javoblar va sovg'a qutisi "
                    "ochilganda chalinadigan qisqa tovushlar. Inglizcha "
                    "so'zlarni o'qishga ta'sir qilmaydi.",
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.muted(context))),
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
                  // "Daraja" kitob darajasi (Beginner/Elementary) bilan
                  // adashmasin: bu yerda AVATAR darajasi.
                  Text(
                      'Olingan medallar: $got / $all. Avatar darajasi: '
                      '${rewards.level} (${rewards.title}).',
                      style: const TextStyle(fontSize: 12)),
                  Text('Bosing - barcha medallarni ko\'rasiz.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.muted(context))),
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
                    child: Text('Inglizcha o\'qish ovozi',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Ilova inglizcha so\'z va gaplarni shu ovoz bilan o\'qib beradi.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.4, color: AppColors.muted(context)),
              ),
              const SizedBox(height: 4),
              Text(
                off
                    ? 'Bu brauzerda ovoz xizmati ishlamaydi - o\'qish '
                        'tugmalari jim qoladi. Boshqa brauzer (Chrome, Edge) '
                        'yoki telefon ilovasida urinib ko\'ring.'
                    : found
                    ? (voice != null
                        ? 'Hozirgi ovoz: $voice'
                        : 'Qurilmaning inglizcha ovozi ishlatiladi.')
                    : 'Qurilmada inglizcha ovoz yo\'q, so\'zlar noto\'g\'ri '
                        'o\'qilishi mumkin. Telefon sozlamalarida \'matnni '
                        'ovozga aylantirish\' (TTS) bo\'limidan inglizcha '
                        'ovozni yuklab oling.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.4, color: AppColors.muted(context)),
              ),
              if (Tts.instance.neuralCount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  "Lug'at so'zlari va namunaviy gaplar (${Tts.instance.neuralCount} ta) "
                  "uchun tayyor, aniq ovozli yozuv (Britan inglizchasi) bor - "
                  "ular har qurilmada bir xil eshitiladi. Qolgan matnlar "
                  "qurilmaning o'z ovozida o'qiladi.",
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w700,
                      color: AppColors.success),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Tts.instance.speak('Hello! How are you?'),
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                label: const Text('Ovozni eshitib ko\'rish'),
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
                child: Text('Ketma-ket kunlar himoyasi (muzlatgich)',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              const SizedBox(width: 8),
              Text('Sizda: ${progress.streakFreezeCount} ta',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Har kuni o\'qisangiz \'ketma-ket kunlar\' soni o\'sadi. Bir kun '
            'o\'qiy olmasangiz, muzlatgich shu hisobni saqlab qoladi (1 ta '
            'ishlatiladi). Narxi ${Progress.freezeCost} tanga 🪙. Tanga ball '
            'yig\'ganda (har 10 ball = 1 tanga) va sovg\'a qutilaridan '
            'olinadi.',
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
                            content: Text('Muzlatgich sotib olindi. Bir kun '
                                'o\'qimasangiz ham ketma-ket kunlaringiz '
                                'saqlanadi.')),
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.shopping_cart_rounded, size: 18),
            label: Text(enough
                ? 'Sotib olish (${Progress.freezeCost} tanga)'
                : 'Tanga yetmaydi: sizda ${progress.coins}, '
                    'kerak ${Progress.freezeCost}'),
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
      ('Jami ball', '${progress.xp}'),
      // "Liga" boshqalar bilan reyting EMAS: har 500 ballda yangi nom.
      ('Ball darajasi nomi (har 500 ballda yangisi)', progress.league),
      ('Tanga 🪙', '${progress.coins}'),
      ('Hozir ketma-ket kunlar', '${progress.currentStreak} kun'),
      ("Eng ko'p ketma-ket kunlar", '${progress.longestStreak} kun'),
      ("Qiyin so'zlar (tez-tez unutganlaringiz)", '${progress.hardCount()} ta'),
      ("Takrorlash kerak bo'lgan mashqlar", '${progress.needsReviewCount()} ta'),
      ("Unutishdan qaytarilgan so'zlar", '${rewards.wordsRescued} ta'),
      ("Mikrofonga to'g'ri aytilgan so'z va gaplar", '${rewards.spokenTotal} ta'),
      ("O'tilgan imtihonlar", '${rewards.examsPassed.length} ta'),
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Natijalar',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text('Hozirgacha qilgan ishlaringiz.',
              style:
                  TextStyle(fontSize: 12.5, color: AppColors.muted(context))),
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
                ? 'Til ko\'nikmalari bo\'yicha mashq darajangiz (0 dan 100% '
                    'gacha). Eng kam foizli ko\'nikmaga ko\'proq vaqt ajrating.'
                : 'Hali mashq qilinmagan. Dars boshlasangiz shu yerda '
                    'ko\'rinadi (har bir ko\'nikma 0 dan 100% gacha).',
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
          const Text('Hamma natijalarni o\'chirish',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            '$_whatIsDeleted Kitob darslarining o\'zi o\'chmaydi. Avval '
            '\'Zaxira nusxa\' oling.',
            style: TextStyle(
                fontSize: 12.5, height: 1.4, color: AppColors.muted(context)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => _confirmReset(context),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Hammasini o\'chirish'),
          ),
        ],
      ),
    );
  }

  /// Nima o'chishi aniq aytiladi: kod `SharedPreferences.clear()` chaqiradi,
  /// ya'ni brauzerdagi HAMMA saqlangan narsa ketadi.
  static const String _whatIsDeleted =
      'Ilovadagi BARCHA ma\'lumot shu qurilmadan o\'chadi va qaytarib '
      'bo\'lmaydi: ball, tanga, ketma-ket kunlar, medallar va daraja, '
      'tugatilgan mashqlar, so\'z takrorlash jadvali, xatolar daftari, '
      'Mr. Vaysaqi suhbatlari, AI kalitlari va barcha sozlamalar.';

  Future<void> _confirmReset(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hamma natijalar o\'chirilsinmi?'),
        content: SingleChildScrollView(
          child: Text(
              '$_whatIsDeleted\n\nKitob darslarining o\'zi o\'chmaydi. '
              'Zaxira nusxa olmagan bo\'lsangiz, avval uni oling.'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Yo\'q, qoldirish')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Ha, hammasini o\'chirish')),
        ],
      ),
    );
    if (yes == true) {
      await progress.resetAll();
      await rewards.resetAll();
      await mistakes.clear();
      // So'z o'zlashtirishi ham xotiradan tozalansin (diskdan ketgan edi).
      await mastery.load(level: progress.currentLevel);
    }
  }
}

/// ZAXIRA NUSXA: progressni matn qilib nusxalash / tiklash.
class _BackupCard extends StatefulWidget {
  const _BackupCard();
  @override
  State<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<_BackupCard> {
  String _msg = '';
  bool _err = false;

  Future<void> _copy() async {
    final text = await Backup.export();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      setState(() {
        _err = false;
        // Zaxira matniga AI kalitlari ham kiradi - oshkor bo'lmasin.
        _msg = 'Nusxalandi (${(text.length / 1024).toStringAsFixed(0)} KB). '
            "Uni Telegram'dagi 'Saqlangan xabarlar'ga qo'yib saqlang. "
            'Diqqat: matn ichida AI kalitingiz ham bor - uni boshqalarga '
            'yubormang.';
      });
    }
  }

  Future<void> _restore() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Zaxiradan tiklash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backup.import avval hamma narsani o'chiradi, keyin yozadi.
            const Text(
                'Diqqat: hozirgi natijalaringiz o\'chib, o\'rniga zaxiradagilari '
                'qo\'yiladi.',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.danger)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 6,
              decoration: const InputDecoration(
                  hintText: '\'Nusxalash\' bilan olingan matnning HAMMASINI '
                      'shu yerga qo\'ying',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Bekor')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tiklash')),
        ],
      ),
    );
    if (ok != true) return;
    final done = await Backup.import(ctrl.text);
    if (!done) {
      if (mounted) {
        setState(() {
          _err = true;
          _msg = 'Bu zaxira matni emas yoki to\'liq nusxalanmagan. '
              '\'Nusxalash\' bilan olingan matnni to\'liq qo\'ying.';
        });
      }
      return;
    }
    // Yangi holatni yuklash.
    await progress.load();
    await rewards.load();
    await mastery.load();
    await mistakes.load();
    if (mounted) {
      setState(() {
        _err = false;
        _msg = 'Tiklandi! Natijalaringiz qaytdi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.backup_rounded),
              SizedBox(width: 12),
              Expanded(
                child: Text('Zaxira nusxa',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Natijalaringiz faqat shu brauzerda saqlanadi. Brauzer tozalansa "
            "yoki boshqa telefonga o'tsangiz yo'qoladi.\n"
            "1) 'Nusxalash' ni bosing - natijalaringiz matn bo'lib nusxalanadi.\n"
            "2) Uni Telegram'dagi 'Saqlangan xabarlar'ga qo'yib saqlang.\n"
            "3) Yangi joyda 'Tiklash' ni bosib, shu matnni qo'ying.",
            style: TextStyle(
                fontSize: 12.5, height: 1.45, color: AppColors.muted(context)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Nusxalash (zaxira)'),
              ),
              OutlinedButton.icon(
                onPressed: _restore,
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Tiklash (zaxiradan)'),
              ),
            ],
          ),
          if (_msg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_msg,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _err ? AppColors.danger : AppColors.success)),
          ],
        ],
      ),
    );
  }
}

/// Mr. Vaysaqi (AI o'qituvchi) uchun Claude API kaliti.
/// Mr. Vaysaqi (AI o'qituvchi): provayder va API kaliti.
class _ApiKeyCard extends StatefulWidget {
  const _ApiKeyCard();
  @override
  State<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<_ApiKeyCard> {
  late final TextEditingController _c =
      TextEditingController(text: progress.activeAiKey);
  bool _hide = true;
  bool _saved = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _pick(String p) async {
    await progress.setAiProvider(p);
    if (!mounted) return;
    setState(() {
      _c.text = progress.activeAiKey;
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = progress.aiProvider;
    final info = AiTutorService.providers[prov]!;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.smart_toy_rounded),
              SizedBox(width: 12),
              Expanded(
                child: Text('Mr. Vaysaqi uchun AI kaliti',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mr. Vaysaqi (AI o\'qituvchi) ishlashi uchun AI xizmatining '
            '\'kaliti\' kerak - parol kabi maxfiy kod. Gemini va Groq '
            'kalitlari bepul. Bir nechta kalit kiritsangiz, birining kunlik '
            'limiti tugaganda o\'qituvchi o\'zi keyingisiga o\'tadi. Kalit '
            'faqat shu qurilmada saqlanadi. O\'chirish: katakni bo\'sh '
            'qoldirib \'Saqlash\' ni bosing.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted(context)),
          ),
          const SizedBox(height: 10),
          ProviderPicker(
            value: prov,
            onChanged: _pick,
            caption: 'Qaysi AI xizmati kalitini kiritasiz? Boshlovchilarga '
                'Gemini yetarli.',
          ),
          const SizedBox(height: 10),
          Text(
              'Kalit olish: 1) quyidagi saytni oching, 2) hisobingiz bilan '
              'kiring, 3) \'Create API key\' ni bosing, 4) kodni nusxalab '
              'pastdagi katakka qo\'ying.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.4, color: AppColors.muted(context))),
          const SizedBox(height: 6),
          KeySiteLink(domain: info.$2),
          const SizedBox(height: 10),
          TextField(
            controller: _c,
            obscureText: _hide,
            onChanged: (_) => setState(() => _saved = false),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Kalit (${AiTutorService.providerShort[prov] ?? prov})',
              hintText: info.$3,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              suffixIcon: IconButton(
                tooltip: _hide ? 'Kodni ko\'rsatish' : 'Kodni yashirish',
                onPressed: () => setState(() => _hide = !_hide),
                icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async {
                await progress.setAiKey(prov, _c.text);
                if (mounted) setState(() => _saved = true);
              },
              icon: Icon(_saved ? Icons.check_rounded : Icons.save_rounded),
              label: Text(_saved ? 'Saqlandi' : 'Saqlash'),
            ),
          ),
        ],
      ),
    );
  }
}
