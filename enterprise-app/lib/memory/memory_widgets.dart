import 'dart:math';

import 'package:flutter/material.dart';

import '../blitz/blitz_screen.dart';
import '../lessons/lesson_screen.dart';
import '../lessons/word_lesson.dart';
import '../main.dart';
import '../mastery.dart';
import '../theme.dart';
import '../widgets/pressable3d.dart';
import 'memory.dart';

/// XOTIRA VIDJETLARI — o'sish ko'rinsin, unutish sezilsin.
///
/// Psixologiya: odam o'z xotirasini KO'RA olmaydi, shuning uchun
/// "yodladimmi?" degan savolga javob yo'q va motivatsiya so'nadi.
/// Bu vidjetlar xotirani ko'rinadigan narsaga aylantiradi: urug'dan
/// kristallgacha o'sadigan so'z, so'nayotgan so'zni qutqarish, o'z
/// eslatmasi.

/// So'zning xotira bosqichi — kichik chip (🌿 Nihol · 3 kun).
class MemoryStageChip extends StatelessWidget {
  final String itemId;
  const MemoryStageChip({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final m = mastery.of(itemId);
    final s = m.stage;
    final color = stageColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '${ItemMastery.stageEmoji[s]} ${ItemMastery.stageName[s]}'
        '${m.interval > 0 ? ' · ${m.interval} kun' : ''}',
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

Color stageColor(int stage) => switch (stage) {
      0 => const Color(0xFF9CA3AF),
      1 => AppColors.success,
      2 => const Color(0xFF15803D),
      3 => AppColors.actionBlue,
      _ => AppColors.coin,
    };

/// O'quvchining o'z eslatmasi (💡).
class HookBubble extends StatelessWidget {
  final String text;
  const HookBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.coin.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💡', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      );
}

/// Qiyin so'zlar uchun ESLATMA yozish (generation effect).
///
/// Tayyor mnemonika berilmaydi — o'zi o'ylab topgani yodda qoladi.
/// Ixtiyoriy: yozmasa ham o'tib ketaveradi.
class HookEditor extends StatefulWidget {
  /// (itemId, en, uz)
  final List<(String, String, String)> words;
  const HookEditor({super.key, required this.words});

  @override
  State<HookEditor> createState() => _HookEditorState();
}

class _HookEditorState extends State<HookEditor> {
  final Map<String, TextEditingController> _c = {};
  final Set<String> _saved = {};

  @override
  void initState() {
    super.initState();
    for (final w in widget.words) {
      _c[w.$1] = TextEditingController(text: mastery.of(w.$1).hook);
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(String id) async {
    await mastery.setHook(id, _c[id]!.text);
    if (!mounted) return;
    setState(() => _saved.add(id));
    rewards.onAnswer(true, baseXp: 3);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.coin.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.coin.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡 Qiyin so\'zga o\'z eslatmangizni yozing',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'O\'zingiz topgan bog\'lanish (o\'xshash so\'z, rasm, hazil) '
            'tayyor qoidadan 3 barobar mustahkam yodda qoladi. +3 XP.',
            style: TextStyle(
                fontSize: 12, height: 1.4, color: AppColors.muted(context)),
          ),
          for (final w in widget.words) ...[
            const SizedBox(height: 12),
            Text('${w.$2} — ${w.$3}',
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c[w.$1],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(w.$1),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'masalan: "${w.$2}" — ...ga o\'xshaydi',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _save(w.$1),
                  icon: Icon(_saved.contains(w.$1)
                      ? Icons.check_rounded
                      : Icons.save_rounded),
                  style: IconButton.styleFrom(
                      backgroundColor: _saved.contains(w.$1)
                          ? AppColors.success
                          : AppColors.coin),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Bitta so'zning o'sishi: bosqich oldin -> keyin.
class MemoryGrowth {
  final String en, uz;
  final int before, after, interval;
  const MemoryGrowth({
    required this.en,
    required this.uz,
    required this.before,
    required this.after,
    required this.interval,
  });

  bool get grew => after > before;
}

/// Dars yakunida: har so'z uchun 🌱 -> 🌿 animatsiyasi.
class MemoryGrowthList extends StatelessWidget {
  final List<MemoryGrowth> items;
  const MemoryGrowthList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final grown = items.where((e) => e.grew).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (grown > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '🌱 $grown ta so\'z xotirangizda o\'sdi',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: AppColors.success),
            ),
          ),
        for (var i = 0; i < items.length; i++)
          _GrowthRow(item: items[i], delay: 120 * i),
      ],
    );
  }
}

class _GrowthRow extends StatefulWidget {
  final MemoryGrowth item;
  final int delay;
  const _GrowthRow({required this.item, required this.delay});

  @override
  State<_GrowthRow> createState() => _GrowthRowState();
}

class _GrowthRowState extends State<_GrowthRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 250 + widget.delay), () {
      if (mounted) _a.forward();
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final t = Curves.easeOutBack.transform(_a.value.clamp(0, 1));
        final showAfter = _a.value > 0.45;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text('${it.en} — ${it.uz}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(ItemMastery.stageEmoji[it.before],
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.black.withValues(
                          alpha: it.grew ? 1 - 0.6 * t : 1))),
              if (it.grew) ...[
                Icon(Icons.arrow_forward_rounded,
                    size: 16, color: AppColors.muted(context)),
                Transform.scale(
                  scale: showAfter ? 0.6 + 0.4 * t : 0.0,
                  child: Text(ItemMastery.stageEmoji[it.after],
                      style: const TextStyle(fontSize: 22)),
                ),
              ],
              const SizedBox(width: 6),
              Text('${it.interval} kun',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: stageColor(it.after))),
            ],
          ),
        );
      },
    );
  }
}

/// BOSh EKRAN: "N ta so'z o'chib ketmoqda — qutqar!" yoki xotira bog'i.
class MemoryRescueCard extends StatelessWidget {
  const MemoryRescueCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mastery,
      builder: (context, _) {
        final n = mastery.fadingCount();
        if (n == 0) {
          if (MemoryRescue.isEvening(DateTime.now()) &&
              MemoryRescue.tonight(mastery) != null) {
            return const _TonightCard();
          }
          return const MemoryGardenCard();
        }
        final ids = mastery.fadingIds(limit: 4);
        return Material(
          color: AppColors.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => startRescue(context),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _FadingIcon(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$n ta so\'z o\'chib ketmoqda',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.danger)),
                            const SizedBox(height: 2),
                            Text(
                              'Takrorlash muddati o\'tdi — hozir eslasangiz, '
                              'ular mustahkamlanadi',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: AppColors.muted(context)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final id in ids)
                        _FadingWord(text: mastery.of(id).en.isEmpty
                            ? id.substring(3)
                            : mastery.of(id).en),
                      if (n > ids.length)
                        Text('+${n - ids.length}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted(context))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Pressable3D(
                    color: AppColors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () => startRescue(context),
                    child: Center(
                      child: Text(
                          '🛟 Qutqarish · ${min(n, MemoryRescue.size)} ta so\'z',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> startRescue(BuildContext context) async {
    final l = MemoryRescue.lesson(mastery);
    if (l == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          lesson: l,
          unitLabel: '🛟 Xotira qutqaruvi',
          rescue: true,
        ),
      ),
    );
  }
}

/// So'nayotgan so'z — xira, titrab turadi (yo'qotish hissi).
class _FadingWord extends StatefulWidget {
  final String text;
  const _FadingWord({required this.text});

  @override
  State<_FadingWord> createState() => _FadingWordState();
}

class _FadingWordState extends State<_FadingWord>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true, count: 6);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.95, end: 0.45).animate(_a),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.4)),
          ),
          child: Text(widget.text,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      );
}

class _FadingIcon extends StatelessWidget {
  const _FadingIcon();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Center(
            child: Text('🧠', style: TextStyle(fontSize: 24))),
      );
}

/// XOTIRA BOG'I — bosqichlar bo'yicha so'zlar soni (o'sishni ko'rish).
class MemoryGardenCard extends StatelessWidget {
  const MemoryGardenCard({super.key});

  @override
  Widget build(BuildContext context) {
    final g = mastery.garden();
    final total = g.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌳', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Xotira bog\'i · $total ta so\'z',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Text('hammasi o\'z vaqtida',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success.withValues(alpha: 0.9))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var s = 0; s < g.length; s++)
                Expanded(
                  child: Column(
                    children: [
                      Text(ItemMastery.stageEmoji[s],
                          style: TextStyle(
                              fontSize: g[s] > 0 ? 22 : 16,
                              color: g[s] > 0
                                  ? null
                                  : Colors.black.withValues(alpha: 0.3))),
                      const SizedBox(height: 2),
                      Text('${g[s]}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: g[s] > 0
                                  ? stageColor(s)
                                  : AppColors.muted(context))),
                      Text(ItemMastery.stageName[s],
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.muted(context))),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 🌙 UXLAShDAN OLDIN — bugungi zaif so'zlarni bir eslab qo'yish.
class _TonightCard extends StatelessWidget {
  const _TonightCard();

  @override
  Widget build(BuildContext context) {
    final l = MemoryRescue.tonight(mastery);
    if (l == null) return const MemoryGardenCard();
    return Material(
      color: const Color(0xFF312E81).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _start(context, l),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              const Text('🌙', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Uxlashdan oldin ${l.words.length} ta so\'z',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF4338CA))),
                    const SizedBox(height: 2),
                    Text(
                      'Uyqu xotirani mustahkamlaydi: oxirgi eslagan '
                      'so\'zlaringiz ertalab yodda qoladi. 1 daqiqa.',
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.muted(context)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF4338CA)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, WordLesson l) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LessonScreen(
            lesson: l,
            unitLabel: '🌙 Kechki takror',
            rescue: true,
          ),
        ),
      );
}

/// BOSh EKRAN: ⚡ Blitz — o'rganilgan so'zlar bilan (8+ bo'lsa).
class BlitzCard extends StatefulWidget {
  const BlitzCard({super.key});

  @override
  State<BlitzCard> createState() => _BlitzCardState();
}

class _BlitzCardState extends State<BlitzCard> {
  int _best = 0;
  String get _key => '${book.level}::all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await BlitzScreen.bestOf(_key);
    if (mounted) setState(() => _best = b);
  }

  @override
  Widget build(BuildContext context) {
    final src = blitzSourcesFromMastery(mastery);
    if (src.length < 8) return const SizedBox.shrink();
    return Material(
      color: AppColors.homework.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlitzScreen(
                sources: src,
                label: 'barcha so\'zlar',
                recordKey: _key,
              ),
            ),
          );
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Blitz · 60 soniya',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.homework)),
                    const SizedBox(height: 2),
                    Text(
                      _best > 0
                          ? 'Rekord: $_best · ${src.length} ta o\'rganilgan so\'z'
                          : '${src.length} ta o\'rganilgan so\'z bilan tezlik sinovi',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.muted(context)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.homework),
            ],
          ),
        ),
      ),
    );
  }
}
