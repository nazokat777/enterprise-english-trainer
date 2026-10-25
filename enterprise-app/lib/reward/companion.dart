import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'reward_engine.dart';
import 'reward_widgets.dart';

// ═══════════════════ HAMROH (maskot) ═══════════════════

/// Hamrohning bosqichi — daraja bilan evolyutsiya. O'quvchi "uni
/// o'stiryapman" deb his qiladi: g'amxo'rlik instinkti + endowment.
class MascotStage {
  final String emoji;
  final String name;
  final int minLevel;
  const MascotStage(this.emoji, this.name, this.minLevel);

  static const List<MascotStage> stages = [
    // AVATAR darajalari — xalqaro, brendga mos nomlar. Har daraja
    // avatarni yorqinroq qiladi ("bilim - yorug'lik").
    MascotStage('✨', 'Spark', 1),
    MascotStage('⭐', 'Star', 2),
    MascotStage('🌟', 'Nova', 4),
    MascotStage('💫', 'Comet', 7),
    MascotStage('🌠', 'Orbit', 10),
    MascotStage('🪐', 'Aurora', 15),
    MascotStage('☀️', 'Nebula', 22),
    MascotStage('🌌', 'Cosmos', 30),
  ];

  static MascotStage forLevel(int level) {
    var s = stages.first;
    for (final st in stages) {
      if (level >= st.minLevel) s = st;
    }
    return s;
  }

  static MascotStage? nextAfter(int level) {
    for (final st in stages) {
      if (st.minLevel > level) return st;
    }
    return null;
  }
}

enum Mood { sleepy, calm, happy, fired }

Mood mascotMood() {
  final r = rewards;
  if (r.combo >= 5) return Mood.fired;
  if (r.idleToday) return Mood.sleepy;
  if (r.todayCorrect >= 15) return Mood.happy;
  return Mood.calm;
}

/// Kontekstli gap — har ochilishda boshqa (kutilmaganlik).
String mascotLine(Random rng) {
  final r = rewards;
  final m = mascotMood();
  final h = DateTime.now().hour;
  final pool = <String>[];
  switch (m) {
    case Mood.sleepy:
      pool.addAll([
        'Bugun hali boshlamadik... bitta mashq? 🥺',
        r.petName.isNotEmpty
            ? '${r.petName} sizni kutyapti. 5 daqiqa yetadi!'
            : 'Sizni kutyapman. 5 daqiqa yetadi!',
        progress.currentStreak > 0
            ? '${progress.currentStreak} kun ketma-ket o\'qiyapsiz - uzilib qolmasin!'
            : 'Bugun boshlasangiz, ketma-ket kunlar hisobi boshlanadi!',
        h < 12 ? 'Xayrli tong! Ertalabki miya eng tez o\'rganadi.' : 'Kech bo\'lmasdan bitta dars qilaylik.',
      ]);
    case Mood.calm:
      pool.addAll([
        'Yaxshi ketyapmiz! Yana ${r.xpToNext} ball - va keyingi darajaga chiqamiz.',
        'Bugun ${r.todayCorrect} ta to\'g\'ri javob. Davom eting!',
        'Kunlik vazifalar sizni kutyapti 🎯',
        if (r.spinAvailable)
          "Omad g'ildiragi tayyor - aylantiring! 🎡"
        else if (!r.spinDoneToday)
          "Yana ${r.spinRemaining} ta to'g'ri javob bering - Omad g'ildiragi ochiladi."
        else
          "Omad g'ildiragi ertaga yana ochiladi. Bugun yana bitta mashq?",
      ]);
    case Mood.happy:
      final nextStage = MascotStage.nextAfter(r.level);
      pool.addAll([
        'Bugun zo\'r kun! ${r.todayXp} ball to\'pladingiz 🎉',
        'Men siz bilan faxrlanaman!',
        'Eng uzun ketma-ket to\'g\'ri javobingiz: ${r.bestCombo} ta. Yangilaymizmi?',
        nextStage != null
            ? 'Shu tezlikda ${nextStage.name} avatar darajasiga yetamiz!'
            : 'Biz avatarning eng oxirgi darajasidamiz!',
      ]);
    case Mood.fired:
      pool.addAll([
        'Ketma-ket ${r.combo} ta to\'g\'ri! To\'xtamang! 🔥',
        'Yonib ketdik! Yana bitta!',
        'Hozir eng yaxshi paytimiz - davom eting!',
      ]);
  }
  if (r.isHappyHour) pool.add('Hozir ikki hissa soat: har bir ball 2 barobar! ⚡⚡');
  return pool[rng.nextInt(pool.length)];
}

/// Hamroh kartasi — bosh ekranda.
class MascotCard extends StatefulWidget {
  final bool compact;
  const MascotCard({super.key, this.compact = false});
  @override
  State<MascotCard> createState() => _MascotCardState();
}

class _MascotCardState extends State<MascotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true, count: 8);
  final _rng = Random();
  String _line = '';
  Mood? _lastMood;

  @override
  void initState() {
    super.initState();
    _line = mascotLine(_rng);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _poke() {
    setState(() => _line = mascotLine(_rng));
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // progress ham: streak/tanga o'zgarsa gap yangilansin.
      listenable: Listenable.merge([rewards, progress]),
      builder: (context, _) {
        final st = MascotStage.forLevel(rewards.level);
        final next = MascotStage.nextAfter(rewards.level);
        final mood = mascotMood();
        // Kayfiyat o'zgarsa gap ham o'zgarsin (uyqudan uyg'ongach
        // "kutyapman" deb turmasin).
        if (_lastMood != null && _lastMood != mood) {
          _line = mascotLine(_rng);
        }
        _lastMood = mood;
        final sleepy = mood == Mood.sleepy;
        return GestureDetector(
          onTap: _poke,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: sleepy
                    ? [const Color(0xFF64748B), const Color(0xFF334155)]
                    : mood == Mood.fired
                        ? [const Color(0xFFF97316), const Color(0xFFDC2626)]
                        : [AppColors.brandPurple, AppColors.actionBlue],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                    color: (sleepy ? Colors.black : AppColors.brandPurple)
                        .withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, child) {
                    final v = Curves.easeInOut.transform(_c.value);
                    final bounce = sleepy ? 0.0 : -6.0 * v;
                    final tilt = sleepy ? 0.25 : (mood == Mood.fired ? (v - 0.5) * 0.3 : 0.0);
                    return Transform.translate(
                      offset: Offset(0, bounce),
                      child: Transform.rotate(angle: tilt, child: child),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(st.emoji, style: const TextStyle(fontSize: 52)),
                      if (sleepy)
                        const Positioned(
                            left: -10, top: -10,
                            child: Text('💤', style: TextStyle(fontSize: 18))),
                      if (mood == Mood.fired)
                        const Positioned(
                            right: -10, top: -8,
                            child: Text('🔥', style: TextStyle(fontSize: 20))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sizning avataringiz - o\'qigan sari rivojlanadi',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(rewards.petName.isNotEmpty ? rewards.petName : st.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15)),
                          if (rewards.petName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('· ${st.name}',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ],
                      ),
                      Text(
                          next != null
                              ? 'Avatar darajasi: ${st.name}. '
                                  'Keyingi: ${next.emoji} ${next.name} - '
                                  '${next.minLevel}-darajaga yetganda'
                              : 'Avatar darajasi: ${st.name} (eng oxirgisi)',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Text(_line,
                            style: const TextStyle(
                                color: Color(0xFF1F2430),
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                      const SizedBox(height: 4),
                      Text('Bosing - yangi maslahat',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════ KETMA-KET KUN XAVFI ═══════════════════

/// Bugun 0 ball bo'lsa: yo'qotish qo'rquvi — yarim tungacha hisoblagich.
class StreakDangerCard extends StatefulWidget {
  const StreakDangerCard({super.key});
  @override
  State<StreakDangerCard> createState() => _StreakDangerCardState();
}

class _StreakDangerCardState extends State<StreakDangerCard> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        if (!rewards.idleToday || progress.currentStreak == 0) {
          return const SizedBox.shrink();
        }
        final d = rewards.untilMidnight;
        final h = d.inHours;
        final m = d.inMinutes % 60;
        final urgent = h < 3;
        final color = urgent ? AppColors.danger : const Color(0xFFF97316);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Text(urgent ? '🚨' : '⏳', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${progress.currentStreak} kun ketma-ket o\'qiganingiz uzilishi mumkin',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14, color: color)),
                    Text(
                        'Bugun hali mashq qilmadingiz. Yarim tungacha '
                        '$h soat $m daqiqa - bitta mashq yetadi.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
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

// ═══════════════════ FAOLLIK XARITASI ═══════════════════

class ActivityHeatmap extends StatelessWidget {
  final int weeks;
  const ActivityHeatmap({super.key, this.weeks = 12});

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        // Oxirgi kun — bugun, ustun = hafta (Dushanbadan).
        final start = today.subtract(Duration(days: weeks * 7 - 1 + (today.weekday - 1)));
        final activeDays = rewards.dayXp.values.where((v) => v > 0).length;
        final totalXp = rewards.dayXp.values.fold<int>(0, (a, b) => a + b);
        // Haftalik o'sish — "o'tgan haftadan ko'proq" (o'z-o'zi bilan
        // raqobat: ijtimoiy taqqoslashsiz, lekin xuddi shunday kuchli).
        final (cur, prev) = rewards.weeklyXp();
        final delta = prev == 0 ? null : ((cur - prev) * 100 / prev).round();
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border(context)),
            boxShadow: AppShadow.card(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Kunlar taqvimi',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                  const GameInfoButton(
                    title: 'Kunlar taqvimi nima?',
                    lines: [
                      'Har bir katak - bitta kun. Yashil katak: o\'sha kuni o\'qigansiz. '
                          'Rang to\'qroq bo\'lsa, ko\'proq ball to\'plagansiz.',
                      'Binafsha ramka - bugun. Ustunlar - haftalar (dushanbadan yakshanbagacha).',
                    ],
                  ),
                ],
              ),
              Text('Qaysi kunlari o\'qiganingiz. To\'qroq rang - ko\'proq ball.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('$activeDays kun o\'qigansiz · jami $totalXp ball',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted(context))),
                  if (delta != null)
                    Tooltip(
                      message: 'Oxirgi 7 kundagi ballingiz, undan oldingi 7 kunga nisbatan',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (delta >= 0 ? AppColors.success : AppColors.homework)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                            'oldingi 7 kundan ${delta >= 0 ? '+' : ''}$delta%',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color:
                                    delta >= 0 ? AppColors.success : AppColors.homework)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, c) {
                  const labelW = 30.0;
                  final cell =
                      ((c.maxWidth - labelW - (weeks - 1) * 3) / weeks).clamp(6.0, 14.0);
                  const dayNames = ['Dush', '', 'Chor', '', 'Juma', '', ''];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hafta kunlari: qator qaysi kunga tegishli.
                      SizedBox(
                        width: labelW,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var d = 0; d < 7; d++)
                              SizedBox(
                                height: cell + 3,
                                child: Text(dayNames[d],
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                        fontSize: 9,
                                        height: 1,
                                        color: AppColors.muted(context))),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var w = 0; w < weeks; w++)
                              Column(
                                children: [
                                  for (var d = 0; d < 7; d++)
                                    Builder(builder: (_) {
                                      final day = start.add(Duration(days: w * 7 + d));
                                      final future = day.isAfter(today);
                                      final xp = rewards.dayXp[_key(day)] ?? 0;
                                      final isToday = day == today;
                                      final box = Container(
                                        width: cell,
                                        height: cell,
                                        margin: const EdgeInsets.only(bottom: 3),
                                        decoration: BoxDecoration(
                                          color: future
                                              ? Colors.transparent
                                              : _cellColor(_levelOf(xp)),
                                          borderRadius: BorderRadius.circular(3),
                                          border: isToday
                                              ? Border.all(
                                                  color: AppColors.brandPurple,
                                                  width: 1.5)
                                              : null,
                                        ),
                                      );
                                      if (future) return box;
                                      return Tooltip(
                                        message: '${day.day}-${_months[day.month - 1]}'
                                            ' · ${xp > 0 ? '$xp ball' : 'o\'qilmagan'}',
                                        child: box,
                                      );
                                    }),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 6),
              // Rang izohi: kam -> ko'p; binafsha ramka = bugun.
              Row(
                children: [
                  Text('kam ',
                      style: TextStyle(fontSize: 10.5, color: AppColors.muted(context))),
                  for (var l = 0; l <= 4; l++)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: _cellColor(l),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Text(' ko\'p',
                      style: TextStyle(fontSize: 10.5, color: AppColors.muted(context))),
                  const SizedBox(width: 10),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: AppColors.brandPurple, width: 1.5),
                    ),
                  ),
                  Flexible(
                    child: Text(' - bugun',
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 10.5, color: AppColors.muted(context))),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static const _months = [
    'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
    'iyul', 'avgust', 'sentyabr', 'oktyabr', 'noyabr', 'dekabr',
  ];

  static int _levelOf(int xp) =>
      xp == 0 ? 0 : (xp < 20 ? 1 : (xp < 50 ? 2 : (xp < 100 ? 3 : 4)));

  static Color _cellColor(int level) => level == 0
      ? AppColors.neutralShadow.withValues(alpha: 0.35)
      : AppColors.success.withValues(alpha: 0.25 + 0.19 * level);
}

// ═══════════════════ BAXTLI SOAT ═══════════════════

class HappyHourBadge extends StatefulWidget {
  const HappyHourBadge({super.key});
  @override
  State<HappyHourBadge> createState() => _HappyHourBadgeState();
}

class _HappyHourBadgeState extends State<HappyHourBadge> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '$h soat $m daqiqa' : '$m daqiqa';
  }

  @override
  Widget build(BuildContext context) {
    final r = rewards;
    final on = r.isHappyHour;
    final color = on ? const Color(0xFFDC2626) : AppColors.coin;
    return Tooltip(
      message: on
          ? 'Ikki hissa soat: hozir har bir ball 2 barobar - '
              '${_fmt(r.happyHourCountdown)} qoldi'
          : 'Soat ${r.happyHour}:00 da ikki hissa soat boshlanadi: shunda har bir '
              'ball 2 barobar (${_fmt(r.happyHourCountdown)}dan keyin)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: on ? 1 : 0.14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: on
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)]
              : null,
        ),
        // Tor ekranda (320px) sig'masa kichrayadi — hech qachon oshib
        // ketmaydi.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(on ? '⚡⚡' : '⏰', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                  on
                      ? '×2 ball ${r.happyHourCountdown.inMinutes} daqiqa'
                      : '×2 ball ${r.happyHour}:00',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: on ? Colors.white : color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════ KUNLIK G'ILDIRAK ═══════════════════

/// Bosh ekrandagi karta: ochilgan bo'lsa "Aylantir", bo'lmasa "yana N".
class SpinCard extends StatelessWidget {
  final VoidCallback onSpin;
  const SpinCard({super.key, required this.onSpin});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        final r = rewards;
        if (r.spinDoneToday) return const SizedBox.shrink();
        final ready = r.spinAvailable;
        final color = ready ? const Color(0xFFEC4899) : AppColors.muted(context);
        return GestureDetector(
          onTap: ready ? onSpin : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: ready ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: color.withValues(alpha: ready ? 0.6 : 0.25)),
            ),
            child: Row(
              children: [
                const Text('🎡', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ready ? 'Omad g\'ildiragi tayyor!' : 'Omad g\'ildiragi',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 14, color: color)),
                      Text(
                          ready
                              ? 'Kuniga bir marta aylantiriladi - tanga, ball yoki muzlatgich yutasiz'
                              : 'Yana ${r.spinRemaining} ta to\'g\'ri javob bering - g\'ildirak ochiladi',
                          style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
                    ],
                  ),
                ),
                if (ready)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Text('Aylantirish',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  )
                else
                  GameInfoButton(
                    title: 'Omad g\'ildiragi nima?',
                    lines: [
                      'Kuniga bir marta bepul aylantiriladi. Sovg\'a tasodifiy tushadi: tanga, ball yoki muzlatgich.',
                      'Ochilishi uchun bugun ${RewardEngine.spinUnlockCorrect} ta to\'g\'ri javob bering.',
                      '🧊 Muzlatgich - bir kun mashq qilmasangiz ham ketma-ket kunlaringiz uzilmaydi.',
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// G'ildirak — CustomPainter, 8 sektor; aylanib sektorda to'xtaydi.
class SpinWheelDialog extends StatefulWidget {
  const SpinWheelDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const SpinWheelDialog(),
      );

  @override
  State<SpinWheelDialog> createState() => _SpinWheelDialogState();
}

class _SpinWheelDialogState extends State<SpinWheelDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  int _target = -1;
  bool _spinning = false;
  bool _done = false;
  double _angle = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning || _done) return;
    final idx = rewards.spin();
    if (idx < 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _spinning = true;
      _target = idx;
    });
    final n = RewardEngine.spinSectors.length;
    final sector = 2 * pi / n;
    // Ko'rsatkich tepada (−π/2). Sektor markazi ko'rsatkichga kelsin.
    final finalAngle = -pi / 2 - (idx + 0.5) * sector;
    final turns = 6 * 2 * pi;
    final start = _angle;
    final end = finalAngle - turns - (start % (2 * pi));
    final anim = Tween<double>(begin: start, end: start + end).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeOutQuart));
    anim.addListener(() => setState(() => _angle = anim.value));
    await _c.forward(from: 0);
    final s = RewardEngine.spinSectors[idx];
    if (s.xp > 0) progress.addXp(s.xp);
    if (s.coins > 0) progress.addCoins(s.coins);
    if (s.freeze) progress.grantFreeze();
    if (mounted) {
      setState(() {
        _spinning = false;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectors = RewardEngine.spinSectors;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('OMAD G\'ILDIRAGI',
                style: TextStyle(
                    color: Color(0xFFEC4899),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 13)),
            const SizedBox(height: 6),
            Text(
                'Tugmani bosing - g\'ildirak aylanadi va sovg\'a tushadi. '
                'Kuniga bir marta.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.muted(context))),
            const SizedBox(height: 8),
            SizedBox(
              width: 260,
              height: 270,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 14,
                    child: Transform.rotate(
                      angle: _angle,
                      child: CustomPaint(
                        size: const Size(250, 250),
                        painter: _WheelPainter(sectors),
                      ),
                    ),
                  ),
                  // Ko'rsatkich
                  const Positioned(
                    top: 0,
                    child: Icon(Icons.arrow_drop_down_rounded,
                        size: 44, color: Color(0xFF1F2430)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_done && _target >= 0) ...[
              Text('Siz yutdingiz: ${sectors[_target].label}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              if (sectors[_target].freeze)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      'Bir kun mashq qilmasangiz ham ketma-ket kun uzilmaydi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted(context))),
                ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                onPressed: _done
                    ? () => Navigator.pop(context)
                    : (_spinning ? null : _spin),
                child: Text(_done ? 'Yopish' : (_spinning ? 'Aylanyapti...' : 'AYLANTIRISH')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<SpinSector> sectors;
  _WheelPainter(this.sectors);

  static const _colors = [
    Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFFF59E0B),
    Color(0xFFEC4899), Color(0xFF06B6D4), Color(0xFFF97316), Color(0xFFDC2626),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final n = sectors.length;
    final sweep = 2 * pi / n;
    final p = Paint();
    for (var i = 0; i < n; i++) {
      p.color = _colors[i % _colors.length];
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * sweep, sweep, true, p);
      // Matn — sektor o'rtasida, radial.
      final a = (i + 0.5) * sweep;
      final tp = TextPainter(
        text: TextSpan(
          text: sectors[i].label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 0.7);
      canvas.save();
      canvas.translate(c.dx + cos(a) * r * 0.62, c.dy + sin(a) * r * 0.62);
      canvas.rotate(a);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    p
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(c, r - 1.5, p);
    p
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(c, 16, p);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => false;
}

// ═══════════════════ TANIShUV (onboarding) ═══════════════════

/// Birinchi ochilishda: avatar "yonadi", o'quvchi unga ISM qo'yadi.
/// O'zi nomlagan narsa — o'ziniki (IKEA effekti). Ism keyin hamma
/// gaplarda ishlatiladi.
class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key});

  static Future<void> showIfNeeded(BuildContext context) async {
    if (!rewards.loaded || rewards.onboarded) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OnboardingSheet(),
    );
  }

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet>
    with SingleTickerProviderStateMixin {
  // Tayyor ism bilan boshlanadi: yangi odam ism o'ylab o'tirmasdan
  // "Boshlaymiz" ni bosa oladi (xohlasa o'zgartiradi).
  final _ctrl = TextEditingController(text: 'Nova');
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true, count: 12);
  static const _suggest = ['Nova', 'Leo', 'Aria', 'Max', 'Luna', 'Kai'];

  @override
  void dispose() {
    _ctrl.dispose();
    _c.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final n = _ctrl.text.trim();
    if (n.isEmpty) return;
    await rewards.setPetName(n);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) => Transform.rotate(
                  angle: (Curves.easeInOut.transform(_c.value) - 0.5) * 0.35,
                  child: child),
              child: const Text('✨', style: TextStyle(fontSize: 84)),
            ),
            const SizedBox(height: 10),
            const Text('Avataringiz tayyor!',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              'Avatar - o\'qishdagi yo\'ldoshingiz. Siz o\'rgangan sari u '
              'rivojlanadi: Spark - Star - Nova - Comet... Cosmos. '
              'Unga ism bering.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted(context), fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 14,
              onSubmitted: (_) => _done(),
              decoration: InputDecoration(
                hintText: 'Avatar ismi',
                counterText: '',
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final n in _suggest)
                  ActionChip(
                    label: Text(n),
                    onPressed: () => setState(() => _ctrl.text = n),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                onPressed: _ctrl.text.trim().isEmpty ? null : _done,
                child: const Text('Boshlaymiz!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════ SESSIYA YAKUNI (peak-end) ═══════════════════

/// Sessiya oxirida bir marta: raqamlar sanab chiqadi, hamroh reaksiya
/// beradi, ertangi vaqt so'raladi. Oxirgi taassurot — eng kuchlisi.
class SessionRecapDialog extends StatelessWidget {
  final SessionRecap r;
  const SessionRecapDialog({super.key, required this.r});

  static Future<void> showIfPending(BuildContext context) async {
    final r = rewards.takeRecap();
    if (r == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => SessionRecapDialog(r: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = rewards.petName.isNotEmpty ? rewards.petName : 'Avataringiz';
    final st = MascotStage.forLevel(rewards.level);
    final great = r.accuracy >= 85;
    final line = great
        ? '$name faxrlanyapti: javoblaringizning ${r.accuracy} % i to\'g\'ri!'
        : (r.accuracy >= 60
            ? '$name: "Yaxshi mehnat! Xatolar - o\'sish."'
            : '$name: "Qiyin edi, lekin tashlamadingiz. Ertaga osonroq bo\'ladi."');
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(great ? 'AJOYIB NATIJA' : 'MASHG\'ULOT TUGADI',
                style: const TextStyle(
                    color: AppColors.brandPurple,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 13)),
            const SizedBox(height: 10),
            Text(great ? '${st.emoji}🎉' : st.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text(line,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _RecapStat('⏱', '${r.minutes}', 'daqiqa o\'qidingiz')),
                Expanded(child: _RecapStat('⚡', '${r.xp}', 'ball')),
                Expanded(child: _RecapStat('🎯', '${r.accuracy}%', 'to\'g\'ri javoblar')),
                Expanded(
                    child: _RecapStat('🔥', '${r.bestCombo}', 'ketma-ket to\'g\'ri')),
              ],
            ),
            const SizedBox(height: 16),
            if (!rewards.commitAskedToday) ...[
              Text('Ertaga soat nechada o\'qiymiz?',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted(context))),
              const SizedBox(height: 2),
              Text(
                  'Ilovani shu soatdan keyin ochsangiz, bosh ekranda eslatma chiqadi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: rewards,
                builder: (context, _) => Wrap(
                  spacing: 8,
                  children: [
                    for (final h in [7, 9, 12, 18, 21])
                      ChoiceChip(
                        label: Text('$h:00'),
                        selected: rewards.commitHour == h,
                        onSelected: (_) => rewards.setCommitHour(h),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                onPressed: () {
                  if (!rewards.commitAskedToday) rewards.setCommitHour(rewards.commitHour);
                  Navigator.pop(context);
                },
                child: const Text('Tayyor'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapStat extends StatelessWidget {
  final String icon, value, label;
  const _RecapStat(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(value.replaceAll('%', ''));
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        n == null
            ? Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20))
            : CountUp(n,
                suffix: value.endsWith('%') ? '%' : '',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.muted(context))),
      ],
    );
  }
}

/// "Eslatma vaqti keldi" — bosh ekranda, vaqt o'tgan-u bugun ishlanmagan.
class CommitCard extends StatelessWidget {
  const CommitCard({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        if (!rewards.commitDue) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.actionBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.actionBlue.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Text('🤝', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Siz soat ${rewards.commitHour}:00 da o\'qishga kelishgandingiz - vaqti keldi',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppColors.actionBlue)),
                    Text(
                        'Bu soatni o\'zingiz tanlagan edingiz. '
                        'Yuqoridagi tavsiyadan boshlang - 3 daqiqa yetadi.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
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
