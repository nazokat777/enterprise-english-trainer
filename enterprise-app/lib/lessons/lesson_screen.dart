import 'dart:async';

import 'package:flutter/material.dart';

import '../drill/drill_item.dart';
import '../drill/drill_screen.dart';
import '../main.dart';
import '../plan/hook_suggest.dart' show approxSound;
import '../stats.dart';
import '../mastery.dart';
import '../memory/memory.dart';
import '../memory/memory_widgets.dart';
import '../reward/confetti.dart';
import '../services/speech.dart';
import '../services/tts.dart';
import '../speak/speak_task.dart';
import '../theme.dart';
import '../widgets/correct_burst.dart';
import '../widgets/hover_lift.dart';
import '../widgets/pressable3d.dart';
import 'lesson_session.dart';
import 'word_lesson.dart';

/// SO'Z DARSI EKRANI — Duolingo uslubi.
///
/// Uch bosqich:
///   1) TANIShUV — har so'z kartada: inglizcha, ovoz, o'zbekcha, misol.
///      Avval so'raladigan narsa KO'RSATILADI. Ilgari shu bosqich yo'q
///      edi va o'quvchi hech ko'rmagan so'zni topishga majbur edi.
///   2) SAVOLLAR — tanish -> tanlash -> harflab yozish; xato qaytadi.
///   3) YaKUN — natija va keyingi darsga yo'l.
class LessonScreen extends StatefulWidget {
  final WordLesson lesson;
  final String unitLabel;
  final List<DrillSource> pool;

  /// XOTIRA QUTQARUVI rejimi: tanishuv YO'Q — so'z avval eslab
  /// aytiladi (retrieval), ko'rsatib qo'yilmaydi.
  final bool rescue;

  const LessonScreen({
    super.key,
    required this.lesson,
    required this.unitLabel,
    this.pool = const [],
    this.rescue = false,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

enum _Stage { list, intro, quiz, done }

class _LessonScreenState extends State<LessonScreen> {
  _Stage _stage = _Stage.list;
  int _card = 0;
  late final LessonSession _s;
  Timer? _next;
  bool? _result;

  /// Dars boshidagi xotira bosqichlari — yakunda "o'sish" ko'rsatiladi.
  /// `late final` bo'lsa birinchi murojaat YAKUNDA bo'lib, "oldin" =
  /// "keyin" chiqardi — shuning uchun initState da darhol olinadi.
  final Map<String, int> _stageBefore = {};

  @override
  void initState() {
    super.initState();
    for (final w in widget.lesson.words) {
      _stageBefore[w.itemId] = mastery.of(w.itemId).stage;
    }
    _s = LessonSession(
      lesson: widget.lesson,
      mastery: mastery,
      pool: widget.pool,
      extras: widget.rescue
          ? const []
          : MemoryRescue.extras(mastery, widget.lesson),
      formats: widget.rescue
          ? const [AskFormat.produce, AskFormat.build]
          : LessonSession.rounds,
      // Talaffuz raundi faqat oddiy darsda va brauzer nutq tanishni
      // qo'llasa (Chrome/Edge/Safari).
      canSpeak: !widget.rescue && Speech.supported,
    );
    if (widget.rescue) {
      _stage = _s.isDone ? _Stage.done : _Stage.quiz;
    }
  }

  /// Ro'yxatdan kartalarga o'tish: avval hammasi ko'rsatiladi, keyin
  /// har so'z alohida kartada, keyin savollar.
  void _startCards() {
    setState(() => _stage = _Stage.intro);
    _speakCard();
  }

  @override
  void dispose() {
    _next?.cancel();
    Tts.instance.stop();
    super.dispose();
  }

  void _speakCard() {
    if (_stage != _Stage.intro) return;
    final w = widget.lesson.words[_card];
    Tts.instance.speak(w.en, id: w.itemId);
  }

  void _nextCard() {
    if (_card + 1 < widget.lesson.words.length) {
      setState(() => _card += 1);
      _speakCard();
    } else {
      Tts.instance.stop();
      setState(() => _stage = _s.isDone ? _Stage.done : _Stage.quiz);
    }
  }

  Future<void> _answer(bool ok) async {
    if (_result != null) return;
    setState(() => _result = ok);
    final bonus = rewards.onAnswer(ok, baseXp: 2);
    if (ok) {
      showCorrectBurst(context);
      await progress.addXp(2 + bonus,
          skill: _s.current?.format == AskFormat.speak ? Skill.speaking : null);
    }
    _next = Timer(Duration(milliseconds: ok ? 650 : 1400), () async {
      await _s.answer(ok);
      if (!mounted) return;
      setState(() {
        _result = null;
        if (_s.isDone) _stage = _Stage.done;
      });
      if (_s.isDone) {
        await progress.addXp(5);
        rewards.onExerciseDone(clean: true);
        if (widget.rescue) {
          rewards.onRescue(_s.lesson.sources.length);
        } else {
          // Dars tugadi = darsdagi so'zlar o'rganildi (kunlik topshiriq).
          rewards.onWordLearned(_s.lesson.sources.length);
        }
      }
    });
  }

  /// Talaffuzni o'tkazib yuborish — xato emas, mastery'ga yozilmaydi.
  void _skip() {
    if (_result != null) return;
    _s.skip();
    setState(() {
      if (_s.isDone) _stage = _Stage.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.rescue
                  ? widget.unitLabel
                  : '${widget.unitLabel} · ${l.index}-dars',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              _stageLabel(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.brandPurple,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.list => _WordList(words: l.words, onStart: _startCards),
          _Stage.intro => _intro(context),
          _Stage.quiz => _quiz(context),
          _Stage.done => _Finished(
            lesson: l,
            mistakes: _s.mistakes,
            rescue: widget.rescue,
            stageBefore: _stageBefore,
            mistaken: _s.mistakenIds,
            onClose: () => Navigator.pop(context, true),
          ),
        },
      ),
    );
  }

  String _stageLabel() => switch (_stage) {
    _Stage.list => 'So\'zlar ro\'yxati',
    _Stage.intro => 'Tanishuv · ${_card + 1}/${widget.lesson.words.length}',
    _Stage.quiz =>
      '${_s.round}-bosqich · ${switch (_s.current?.format) {
        AskFormat.choice => 'ma\'nosini tanlang',
        AskFormat.produce => 'inglizchasini tanlang',
        AskFormat.listen => 'eshitib yozing',
        AskFormat.cloze => 'gapdagi bo\'shliqni to\'ldiring',
        AskFormat.speak => 'ovoz chiqarib ayting',
        _ => 'harflab yozing',
      }}',
    _Stage.done => 'Yakunlandi',
  };

  // ───────────── 1) Tanishuv ─────────────
  Widget _intro(BuildContext context) {
    final words = widget.lesson.words;
    final w = words[_card];
    return Column(
      children: [
        _Bar(value: (_card + 1) / words.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              // SO'Z KARTASI — gradient chegara (2px), yuqori chapda
              // yumshoq nur; so'z Manrope bilan katta, gradient rangda.
              // Har yangi kartada 260 ms "kirish" (fade + slide).
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Container(
                  key: ValueKey(w.itemId),
                  width: double.infinity,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: AppShadow.glow(
                      AppColors.brandPurple,
                      alpha: 0.25,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(AppRadius.xl - 2),
                    ),
                    child: Column(
                      children: [
                        // Ilgari ko'rilgan so'z "yangi" deb chiqmasin —
                        // uning xotira bosqichi ko'rinsin (o'sish hissi).
                        if (mastery.of(w.itemId).isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: const Text(
                              'YANGI SO\'Z',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          MemoryStageChip(itemId: w.itemId),
                        const SizedBox(height: 14),
                        GradientText(
                          w.en,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(fontSize: 38, height: 1.15),
                        ),
                        const SizedBox(height: 14),
                        SpeakButton(text: w.en),
                        const SizedBox(height: 18),
                        Text(
                          w.uz,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandPurple,
                            height: 1.3,
                          ),
                        ),
                        if (mastery.of(w.itemId).hook.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          HookBubble(text: mastery.of(w.itemId).hook),
                        ],
                        if (w.exampleEn.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          Divider(
                            color: AppColors.muted(
                              context,
                            ).withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            w.exampleEn,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          if (w.exampleUz.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              w.exampleUz,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: AppColors.muted(context),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Darsdagi hamma so'z bir qarashda — "yana nechta qoldi".
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < words.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: i <= _card
                            ? AppColors.brandPurple.withValues(alpha: 0.14)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        words[i].en,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: i <= _card
                              ? AppColors.brandPurple
                              : AppColors.muted(context),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Pressable3D(
            color: AppColors.success,
            onPressed: _nextCard,
            child: Center(
              child: Text(
                _card + 1 < words.length ? 'Keyingi so\'z' : 'Mashqni boshlash',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────── 2) Savollar ─────────────
  Widget _quiz(BuildContext context) {
    final q = _s.current!;
    final hook = mastery.of(q.itemId).hook;
    return Column(
      children: [
        _Bar(value: _s.progress),
        // Xato bo'lganda o'quvchining O'Z eslatmasi chiqadi — javob
        // shunchaki ko'rsatilmaydi, o'zi tuzgan bog'lanish eslatiladi.
        if (_result == false && hook.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: HookBubble(text: hook),
          ),
        Expanded(
          child: switch (q.format) {
            AskFormat.build || AskFormat.listen => BuildTask(
              key: ValueKey('b${q.itemId}${q.format}${_s.remaining}'),
              q: q,
              locked: _result != null,
              onDone: _answer,
            ),
            AskFormat.speak => SpeakTask(
              key: ValueKey('s${q.itemId}${_s.remaining}'),
              q: q,
              locked: _result != null,
              onDone: _answer,
              onSkip: _skip,
            ),
            _ => ChoiceTask(
              key: ValueKey('c${q.itemId}${q.format}${_s.remaining}'),
              q: q,
              locked: _result != null,
              onDone: _answer,
            ),
          },
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  const _Bar({required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 10,
        backgroundColor: AppColors.brandPurple.withValues(alpha: 0.15),
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
      ),
    ),
  );
}

/// Dars tugadi.
class _Finished extends StatelessWidget {
  final WordLesson lesson;
  final int mistakes;
  final bool rescue;
  final Map<String, int> stageBefore;
  final Set<String> mistaken;
  final VoidCallback onClose;
  const _Finished({
    required this.lesson,
    required this.mistakes,
    required this.onClose,
    this.rescue = false,
    this.stageBefore = const {},
    this.mistaken = const {},
  });

  @override
  Widget build(BuildContext context) {
    // Qiyin so'zlar — shu seansda xato qilingan yoki tarixda 2+ marta
    // unutilgan, hali eslatmasi yo'q — o'z eslatmasini yozish taklif
    // qilinadi. (`isWeak` bo'lmaydi: dars oxirida hamma so'z
    // "mustahkam" bo'ladi, shuning uchun taklif hech chiqmasdi.)
    final weak = [
      for (final w in lesson.words)
        if (mastery.of(w.itemId).hook.isEmpty &&
            (mistaken.contains(w.itemId) || mastery.of(w.itemId).lapses >= 2))
          w,
    ];
    final perfect = mistakes == 0;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // YAKUN KARTASI — "peak-end": oxirgi taassurot eng kuchli qoladi.
            // Gradient karta, katta nishon "sakrab" chiqadi, ostida raqamlar.
            Container(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              decoration: BoxDecoration(
                gradient: perfect
                    ? AppColors.goldGradient
                    : AppColors.successGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadow.glow(
                  perfect ? AppColors.coin : AppColors.success,
                  alpha: 0.45,
                ),
              ),
              child: Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        rescue
                            ? Icons.health_and_safety_rounded
                            : perfect
                            ? Icons.emoji_events_rounded
                            : Icons.workspace_premium_rounded,
                        size: 52,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    rescue
                        ? '${lesson.words.length} ta so\'z qutqarildi!'
                        : perfect
                        ? 'Benuqson!'
                        : '${lesson.index}-dars tugadi',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mistakes == 0
                        ? '${lesson.words.length} ta so\'z - birorta xatosiz'
                        : '${lesson.words.length} ta so\'z ${rescue ? 'qutqarildi' : 'o\'rganildi'} · $mistakes ta xato qayta so\'raldi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // XOTIRA O'SIShI — har so'z qaysi bosqichdan qaysiga o'tdi.
            // Ko'rinadigan o'sish = harakat-natija bog'i (dofamin).
            MemoryGrowthList(
              items: [
                for (final w in lesson.words)
                  MemoryGrowth(
                    en: w.en,
                    uz: w.uz,
                    before: stageBefore[w.itemId] ?? 0,
                    after: mastery.of(w.itemId).stage,
                    interval: mastery.of(w.itemId).interval,
                  ),
              ],
            ),
            const SizedBox(height: 22),
            _WordResults(lesson: lesson, mistaken: mistaken),
            if (weak.isNotEmpty) ...[
              const SizedBox(height: 22),
              HookEditor(words: [for (final w in weak) (w.itemId, w.en, w.uz)]),
            ],
            const SizedBox(height: 26),
            Pressable3D(
              color: AppColors.brandPurple,
              onPressed: onClose,
              child: const Center(
                child: Text(
                  'Davom etish',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (perfect) const IgnorePointer(child: ConfettiBurst(count: 110)),
      ],
    );
  }
}

/// Bitta so\'z qatori: inglizcha, taxminiy o\'qilishi, o\'zbekcha, ovoz.
class _WordRow extends StatelessWidget {
  final LessonWord w;
  final Color? tint;
  const _WordRow({required this.w, this.tint});

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(context);
    final snd = [
      for (final p in w.en.split(RegExp(r'\s+')))
        if (approxSound(p).isNotEmpty) approxSound(p)
    ].join(' ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: (tint ?? AppColors.brandPurple).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.en,
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w900)),
                if (snd.isNotEmpty)
                  Text('o\'qilishi: $snd',
                      style: TextStyle(fontSize: 12.5, color: muted)),
                const SizedBox(height: 2),
                Text(w.uz,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tinglash',
            icon: const Icon(Icons.volume_up_rounded),
            color: AppColors.brandPurple,
            onPressed: () => Tts.instance.speak(w.en, id: w.itemId),
          ),
        ],
      ),
    );
  }
}

/// DARS BOSHI: yodlashdan OLDIN barcha so\'zlar - tarjima + talaffuz.
class _WordList extends StatelessWidget {
  final List<LessonWord> words;
  final VoidCallback onStart;
  const _WordList({required this.words, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Bu darsda ${words.length} ta yangi so\'z',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(
          'Avval hammasini ko\'zdan kechiring va tinglang (ovozli tugma). '
          '"O\'qilishi" - taxminiy; aniq talaffuz uchun tinglang. '
          'Keyin yodlashni boshlaymiz.',
          style: TextStyle(
              fontSize: 13, height: 1.4, color: AppColors.muted(context)),
        ),
        const SizedBox(height: 12),
        for (final w in words) _WordRow(w: w),
        const SizedBox(height: 12),
        Pressable3D(
          color: AppColors.brandPurple,
          onPressed: onStart,
          child: const Center(
            child: Text('Yodlashni boshlash',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

/// DARS OXIRI: qaysi so\'zlar yaxshi yodlandi, qaysilari yo\'q.
class _WordResults extends StatelessWidget {
  final WordLesson lesson;
  final Set<String> mistaken;
  const _WordResults({required this.lesson, required this.mistaken});

  @override
  Widget build(BuildContext context) {
    final good = [for (final w in lesson.words) if (!mistaken.contains(w.itemId)) w];
    final bad = [for (final w in lesson.words) if (mistaken.contains(w.itemId)) w];
    Widget head(String t, int n, Color c) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text('$t ($n)',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: c)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head('Yaxshi yodlangan so\'zlar', good.length, AppColors.success),
        if (good.isEmpty)
          Text('Hozircha yo\'q - bu normal, takror hammasini mustahkamlaydi.',
              style: TextStyle(color: AppColors.muted(context)))
        else
          for (final w in good) _WordRow(w: w, tint: AppColors.success),
        const SizedBox(height: 10),
        head('Yaxshi yodlanmagan so\'zlar', bad.length, AppColors.danger),
        if (bad.isEmpty)
          Text('Hammasi birinchi urinishda yodlandi!',
              style: TextStyle(color: AppColors.muted(context)))
        else ...[
          Text('Bular xato qilindi - tez-tez takrorlanadi. Ilgak yozing.',
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.muted(context))),
          const SizedBox(height: 8),
          for (final w in bad) _WordRow(w: w, tint: AppColors.danger),
        ],
      ],
    );
  }
}
