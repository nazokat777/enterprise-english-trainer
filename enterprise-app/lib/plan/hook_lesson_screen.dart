import 'dart:async';

import 'package:flutter/material.dart';

import '../lessons/word_lesson.dart';
import '../main.dart';
import '../services/tts.dart';
import '../theme.dart';
import '../widgets/pressable3d.dart';
import 'hook_suggest.dart';

/// ILGAK DARSI — mnemonikani AMALDA qilish.
///
/// Har so'z uchun 7 qadamli algoritmning 1-4 qadami ekranda bajariladi:
///  1) Ma'no — so'z, tarjima, ovoz.
///  2) Ilgak — tovushi o'xshash o'zbekcha so'z (ilova taklif qiladi, o'quvchi
///     o'zgartira oladi).
///  3) Obraz — ilgak va ma'no BIR sahnada; o'quvchi o'zi yozadi, 4 belgini
///     belgilaydi (g'alati · harakatli · katta · o'zim ichida).
///  4) Tasavvur — 5 soniya ko'z yumib sahnani ko'rish.
/// Oxirida YOPIB ESLASH: o'zbekchasi ko'rinadi, inglizchasini yozadi;
/// xato bo'lsa o'z sahnasi eslatiladi. Ilgak `mastery.setHook` ga saqlanadi
/// va keyingi darslarda xato qilinganda chiqadi.
class HookLessonScreen extends StatefulWidget {
  final WordLesson lesson;
  final String unitLabel;

  /// Dars tugagach (mustahkamlash darsiga o'tish uchun).
  final VoidCallback? onFinished;

  const HookLessonScreen({
    super.key,
    required this.lesson,
    required this.unitLabel,
    this.onFinished,
  });

  @override
  State<HookLessonScreen> createState() => _HookLessonScreenState();
}

enum _Step { meaning, hook, scene, imagine }

class _HookLessonScreenState extends State<HookLessonScreen> {
  late final List<LessonWord> _words = widget.lesson.words;
  int _i = 0;
  _Step _step = _Step.meaning;
  final _hook = TextEditingController();
  final _scene = TextEditingController();
  final Set<int> _qualities = {};
  int _countdown = 0;
  Timer? _timer;

  // Yopib eslash bosqichi.
  bool _recall = false;
  int _r = 0;
  final _answer = TextEditingController();
  bool? _ok;
  int _correct = 0;
  final List<int> _order = [];

  static const _qualityLabels = [
    'G\'alati / bo\'lishi mumkin emas',
    'Harakatli',
    'Katta, rangli',
    'Men o\'zim sahnada',
  ];

  LessonWord get _w => _words[_i];

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hook.dispose();
    _scene.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _prepare() {
    final saved = mastery.of(_w.itemId).hook;
    // Saqlangan ilgak "ilgak — sahna" ko'rinishida bo'ladi.
    final parts = saved.split(' — ');
    _hook.text = saved.isNotEmpty
        ? parts.first
        : suggestHook(_w.en, meaningUz: _w.uz);
    _scene.text = parts.length > 1 ? parts.sublist(1).join(' — ') : '';
    _qualities.clear();
    _step = _Step.meaning;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Tts.instance.speak(_w.en, id: _w.itemId));
  }

  Future<void> _next() async {
    switch (_step) {
      case _Step.meaning:
        setState(() => _step = _Step.hook);
      case _Step.hook:
        setState(() => _step = _Step.scene);
      case _Step.scene:
        final h = _hook.text.trim();
        final sc = _scene.text.trim();
        if (h.isNotEmpty || sc.isNotEmpty) {
          await mastery.setHook(
              _w.itemId, sc.isEmpty ? h : '${h.isEmpty ? '?' : h} — $sc');
        }
        setState(() {
          _step = _Step.imagine;
          _countdown = 5;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) return t.cancel();
          setState(() => _countdown--);
          if (_countdown <= 0) t.cancel();
        });
      case _Step.imagine:
        if (_i + 1 < _words.length) {
          setState(() {
            _i++;
            _prepare();
          });
        } else {
          _startRecall();
        }
    }
  }

  void _startRecall() {
    _order
      ..clear()
      ..addAll(List.generate(_words.length, (k) => k)..shuffle());
    setState(() {
      _recall = true;
      _r = 0;
      _ok = null;
      _answer.clear();
    });
  }

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r"[^a-z' ]"), '').trim();

  void _check() {
    if (_ok != null) return;
    final w = _words[_order[_r]];
    final ok = _norm(_answer.text) == _norm(w.en);
    setState(() => _ok = ok);
    if (ok) {
      _correct++;
      rewards.onAnswer(true, baseXp: 2);
      progress.addXp(2);
    } else {
      rewards.onAnswer(false);
    }
    Tts.instance.speak(w.en, id: w.itemId);
  }

  void _nextRecall() {
    if (_r + 1 < _order.length) {
      setState(() {
        _r++;
        _ok = null;
        _answer.clear();
      });
    } else {
      rewards.onExerciseDone(clean: _correct == _words.length);
      setState(() => _r = _order.length); // tugadi
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_recall
            ? 'Yopib eslash'
            : 'Ilgak darsi · ${_i + 1}/${_words.length}'),
      ),
      body: _recall ? _recallView(context) : _learnView(context),
    );
  }

  // ═══════════ 1-4 qadam ═══════════
  Widget _learnView(BuildContext context) {
    final muted = AppColors.muted(context);
    final w = _w;
    final stepIndex = _Step.values.indexOf(_step);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        // Qadamlar chizig'i.
        Row(
          children: [
            for (var k = 0; k < 4; k++) ...[
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: k <= stepIndex
                        ? AppColors.brandPurple
                        : AppColors.brandPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              if (k < 3) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          const ['1. Ma\'no', '2. Ilgak', '3. Obraz', '4. Tasavvur'][stepIndex],
          style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: AppColors.brandPurple),
        ),
        const SizedBox(height: 12),
        // So'z kartasi - har qadamda ko'rinib turadi.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: [
              Text(w.en,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(w.uz,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16)),
              const SizedBox(height: 8),
              IconButton.filledTonal(
                onPressed: () => Tts.instance.speak(w.en, id: w.itemId),
                icon: const Icon(Icons.volume_up_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._stepBody(context, w, muted),
        const SizedBox(height: 18),
        Pressable3D(
          color: AppColors.brandPurple,
          shadowColor: const Color(0xFF5B22B5),
          enabled: _step != _Step.imagine || _countdown <= 0,
          onPressed: _step == _Step.imagine && _countdown > 0 ? null : _next,
          child: Center(
            child: Text(
              switch (_step) {
                _Step.meaning => 'Tushundim - ilgak topamiz',
                _Step.hook => 'Ilgak tayyor - sahna quramiz',
                _Step.scene => 'Saqlash va tasavvur qilish',
                _Step.imagine => _countdown > 0
                    ? 'Ko\'zingizni yuming... $_countdown'
                    : (_i + 1 < _words.length
                        ? 'Keyingi so\'z'
                        : 'Endi yopib eslaymiz'),
              },
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _stepBody(BuildContext context, LessonWord w, Color muted) {
    switch (_step) {
      case _Step.meaning:
        return [
          if (w.exampleEn.isNotEmpty) ...[
            Text(w.exampleEn,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            if (w.exampleUz.isNotEmpty)
              Text(w.exampleUz, style: TextStyle(fontSize: 13, color: muted)),
            const SizedBox(height: 10),
          ],
          _Tip(
            'So\'zni ovoz chiqarib 2 marta ayting. Ma\'nosini tasavvur qiling - '
            'mavhum emas, KONKRET narsa sifatida.',
          ),
        ];
      case _Step.hook:
        return [
          const Text('Tovushi o\'xshash o\'zbekcha so\'z',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            controller: _hook,
            decoration: InputDecoration(
              hintText: 'masalan: buqa, ketmon, pilov...',
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: 10),
          _Tip(
            '"${w.en}" - qaysi o\'zbekcha so\'zga o\'xshab eshitiladi? Mukammal '
            'qofiya shart emas, BIRINChI BO\'G\'IN yetadi. Ilova taklif qildi - '
            'o\'zingiz yaxshiroq topsangiz, almashtiring: o\'zingiz topgani '
            'yaxshiroq yodda qoladi.',
          ),
        ];
      case _Step.scene:
        final h = _hook.text.trim().isEmpty ? '...' : _hook.text.trim();
        return [
          Text('Sahna: "$h" + "${w.uz}" bir kadrda',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            controller: _scene,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: sceneTemplate(h, w.uz),
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: 10),
          Text('Sahnangiz kuchlimi? Belgilang:',
              style: TextStyle(fontSize: 12.5, color: muted)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var k = 0; k < _qualityLabels.length; k++)
                FilterChip(
                  label: Text(_qualityLabels[k],
                      style: const TextStyle(fontSize: 12)),
                  selected: _qualities.contains(k),
                  onSelected: (v) => setState(
                      () => v ? _qualities.add(k) : _qualities.remove(k)),
                ),
            ],
          ),
          if (_qualities.length < 2) ...[
            const SizedBox(height: 8),
            _Tip('Kamida 2 ta belgi bo\'lsin - miya zerikarli kadrni saqlamaydi.'),
          ],
        ];
      case _Step.imagine:
        final h = _hook.text.trim();
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.brandPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                const Text('🎬', style: TextStyle(fontSize: 34)),
                const SizedBox(height: 6),
                Text(
                  _scene.text.trim().isNotEmpty
                      ? _scene.text.trim()
                      : (h.isNotEmpty ? '$h  →  ${w.uz}' : w.uz),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ko\'zingizni yuming va sahnani RANGLI, HARAKATDA ko\'ring. '
                  'Ichida "${w.en}" deb ovoz chiqarib ayting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
              ],
            ),
          ),
        ];
    }
  }

  // ═══════════ Yopib eslash ═══════════
  Widget _recallView(BuildContext context) {
    final muted = AppColors.muted(context);
    if (_r >= _order.length) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 20),
          Text(
            '$_correct / ${_words.length}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
          ),
          Text('so\'z yopib eslandi',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: muted)),
          const SizedBox(height: 14),
          _Tip(
            'Ilgaklaringiz saqlandi. Bu so\'zlar 1, 3, 7, 14, 30 kundan keyin '
            'qaytadi - xato qilsangiz sahnangiz eslatiladi. Endi mustahkamlash '
            'darsida 4 xil shaklda mashq qilamiz.',
          ),
          const SizedBox(height: 18),
          Pressable3D(
            color: AppColors.success,
            shadowColor: const Color(0xFF0F7A37),
            onPressed: () {
              Navigator.pop(context);
              widget.onFinished?.call();
            },
            child: const Center(
              child: Text('Mustahkamlash darsiga o\'tish',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          ),
        ],
      );
    }
    final w = _words[_order[_r]];
    final hook = mastery.of(w.itemId).hook;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        LinearProgressIndicator(
          value: _r / _order.length,
          minHeight: 6,
          backgroundColor: AppColors.brandPurple.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 16),
        Text('Inglizchasini yozing (qaramasdan):',
            style: TextStyle(fontSize: 13, color: muted)),
        const SizedBox(height: 6),
        Text(w.uz,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        TextField(
          controller: _answer,
          autofocus: true,
          enabled: _ok == null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _check(),
          decoration: InputDecoration(
            hintText: 'inglizcha...',
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
        const SizedBox(height: 12),
        if (_ok == null)
          FilledButton(onPressed: _check, child: const Text('Tekshirish'))
        else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_ok! ? AppColors.success : AppColors.danger)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ok! ? 'To\'g\'ri! ${w.en}' : 'To\'g\'risi: ${w.en}',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _ok! ? AppColors.success : AppColors.danger),
                ),
                if (!_ok! && hook.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Sahnangizni eslang: $hook',
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: _nextRecall, child: const Text('Keyingisi')),
        ],
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.coin.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💡', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12.5, height: 1.45)),
            ),
          ],
        ),
      );
}
