import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets/pressable3d.dart';

/// QARMOQ USULI MAShQI — mnemonika ISHLASHINI o'z ko'zingiz bilan ko'rish.
///
/// Davronbek Turdiev amaliy darsi tartibi: 1) AVVAL TEST — 10 ta so'zni
/// 60 soniya ko'rib, tartib bilan eslash; 2) USUL — 1..10 raqamlarning
/// "qarmoqlari" (1=quyosh, 2=paypoq...) va har so'zni qarmoqqa sahna bilan
/// ilish; 3) QAYTA TEST — o'sish raqamda ko'rinadi. So'zlar o'quvchining
/// O'Z lug'atidan (inglizcha) olinadi.
class PegScreen extends StatefulWidget {
  const PegScreen({super.key});

  @override
  State<PegScreen> createState() => _PegScreenState();
}

/// Raqam qarmoqlari (shakli yoki ma'nosi raqamga o'xshash).
const List<(String, String, String)> kPegs = [
  ('1', 'quyosh', '☀️ yagona'),
  ('2', 'paypoq', '🧦 juft'),
  ('3', 'svetofor', '🚦 3 rang'),
  ('4', 'stol', '🪑 4 oyoq'),
  ('5', 'yulduz', '⭐ 5 qirra'),
  ('6', 'qulf', '🔓 shakli 6 ga o\'xshaydi'),
  ('7', 'bolta', '🪓 shakli 7 ga o\'xshaydi'),
  ('8', 'qumsoat', '⏳ shakli 8'),
  ('9', 'mushuk', '🐈 9 ta joni bor'),
  ('10', 'barmoqlar', '🖐️🖐️ 10 barmoq'),
];

enum _Phase { intro, memorize1, recall1, pegs, link, recall2, result }

class _PegScreenState extends State<PegScreen> {
  _Phase _phase = _Phase.intro;
  late final List<(String, String)> _words = _pick();
  int _seconds = 60;
  Timer? _timer;
  final List<TextEditingController> _in =
      List.generate(10, (_) => TextEditingController());
  int _score1 = 0;
  int _score2 = 0;
  int _link = 0;

  List<(String, String)> _pick() {
    // O'rganilgan so'zlar; kam bo'lsa - tayyor konkret so'zlar.
    final learned = mastery.learnedWords(limit: 60).map((e) => (e.$2, e.$3)).toList();
    const fallback = [
      ('apple', 'olma'), ('chair', 'stul'), ('river', 'daryo'), ('horse', 'ot'),
      ('window', 'deraza'), ('bread', 'non'), ('key', 'kalit'), ('rain', 'yomg\'ir'),
      ('shoe', 'tufli'), ('bird', 'qush'), ('clock', 'soat'), ('milk', 'sut'),
      ('bridge', 'ko\'prik'), ('moon', 'oy'), ('flower', 'gul'),
    ];
    final pool = [...learned, ...fallback];
    final seen = <String>{};
    final uniq = [for (final w in pool) if (seen.add(w.$1.toLowerCase())) w];
    uniq.shuffle(Random());
    return uniq.take(10).toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _in) {
      c.dispose();
    }
    super.dispose();
  }

  void _startTimer(_Phase next) {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _seconds--);
      if (_seconds <= 0) {
        t.cancel();
        _go(next);
      }
    });
  }

  void _go(_Phase p) {
    _timer?.cancel();
    if (p == _Phase.recall1 || p == _Phase.recall2) {
      for (final c in _in) {
        c.clear();
      }
    }
    setState(() => _phase = p);
  }

  int _score() {
    var s = 0;
    for (var i = 0; i < 10 && i < _words.length; i++) {
      if (_in[i].text.trim().toLowerCase() == _words[i].$1.toLowerCase()) s++;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qarmoq usuli mashqi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: _body(context),
      ),
    );
  }

  Widget _btn(String text, VoidCallback onTap, {Color? color}) => Pressable3D(
        color: color ?? AppColors.brandPurple,
        shadowColor: const Color(0xFF5B22B5),
        onPressed: onTap,
        child: Center(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ),
      );

  Widget _info(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t, style: const TextStyle(fontSize: 14, height: 1.5)),
      );

  List<Widget> _body(BuildContext context) {
    final muted = AppColors.muted(context);
    switch (_phase) {
      case _Phase.intro:
        return [
          const Text('🎯', style: TextStyle(fontSize: 44), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          _info('Bu mashqda mnemonika ishlashini O\'Z xotirangizda ko\'rasiz.'),
          _info('1) Avval 10 ta so\'zni 60 soniya ko\'rib, TARTIB bilan eslab '
              'qolishga harakat qilasiz - oddiy usulda.'),
          _info('2) Keyin qarmoq usulini o\'rganasiz: 1 dan 10 gacha raqamga '
              'bittadan "qarmoq" rasm, har so\'z qarmoqqa sahna bilan ilinadi.'),
          _info('3) Qayta test. Natijalarni solishtirasiz. Ko\'pchilikda 2-3 '
              'barobar o\'sadi.'),
          const SizedBox(height: 8),
          _btn('Boshlash - 1-test', () {
            _go(_Phase.memorize1);
            _startTimer(_Phase.recall1);
          }),
        ];

      case _Phase.memorize1:
        return [
          Text('Eslab qoling (tartib bilan) · $_seconds s',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 10),
          for (var i = 0; i < _words.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${i + 1}. ${_words[i].$1}  -  ${_words[i].$2}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 10),
          _btn('Tayyorman', () => _go(_Phase.recall1)),
        ];

      case _Phase.recall1:
      case _Phase.recall2:
        final second = _phase == _Phase.recall2;
        return [
          Text(
            second
                ? 'Qayta test: qarmoqlarni eslab, inglizchasini yozing'
                : 'Tartib bilan inglizchasini yozing (eslaganingizcha)',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _words.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: second ? 110 : 30,
                    child: Text(
                      second ? '${i + 1}. ${kPegs[i].$2}' : '${i + 1}.',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: second ? AppColors.brandPurple : null),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _in[i],
                      decoration: const InputDecoration(
                          isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          _btn('Tekshirish', () {
            if (second) {
              _score2 = _score();
              rewards.onExerciseDone(clean: _score2 == 10);
              progress.addXp(10);
              _go(_Phase.result);
            } else {
              _score1 = _score();
              _go(_Phase.pegs);
            }
          }),
        ];

      case _Phase.pegs:
        return [
          Text('1-test: $_score1 / 10',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 8),
          _info('Endi QARMOQLAR. Har raqamning bitta o\'zgarmas rasmi bor - '
              'shaklidan yoki ma\'nosidan. Ularni bir marta yodlaysiz, keyin '
              'har qanday ro\'yxat uchun ishlatasiz:'),
          for (final p in kPegs)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${p.$1} = ${p.$2}   (${p.$3})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 10),
          _btn('Qarmoqlarni bildim - so\'zlarni ilamiz', () {
            setState(() => _link = 0);
            _go(_Phase.link);
          }),
        ];

      case _Phase.link:
        final w = _words[_link];
        final p = kPegs[_link];
        return [
          Text('${_link + 1} / 10',
              style: TextStyle(fontSize: 13, color: muted)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                Text('${p.$1} = ${p.$2}',
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(w.$1,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900)),
                Text(w.$2,
                    style: const TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _info('Sahna: "${p.$2}" bilan "${w.$2}" ni BIR kadrga qo\'shing. '
              'Masalan: ulkan ${p.$2} ${w.$2}ni ... (nima qilyapti?). G\'alati va '
              'harakatli bo\'lsin, ichingizda "${w.$1}" deb ayting.'),
          _info('Ko\'zingizni yuming, sahnani 3 soniya ko\'ring.'),
          _btn(_link < 9 ? 'Ko\'rdim - keyingisi' : 'Tayyor - qayta test', () {
            if (_link < 9) {
              setState(() => _link++);
            } else {
              _go(_Phase.recall2);
            }
          }),
        ];

      case _Phase.result:
        final grow = _score1 == 0 ? _score2.toDouble() : _score2 / _score1;
        return [
          const Text('📈', style: TextStyle(fontSize: 44), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Row(
            children: [
              _ScoreBox(label: 'Oddiy usul', value: _score1, color: muted),
              const SizedBox(width: 10),
              _ScoreBox(
                  label: 'Qarmoq usuli',
                  value: _score2,
                  color: AppColors.success),
            ],
          ),
          const SizedBox(height: 14),
          _info(_score2 > _score1
              ? 'Natijangiz ${grow.toStringAsFixed(1)} barobar oshdi! Bu - '
                  'mnemonika. Xuddi shu usul so\'z darslaridagi "ilgak" bilan '
                  'ishlaydi.'
              : 'Birinchi urinishda usul hali odat emas - qarmoqlarni yana bir '
                  'marta takrorlang. 2-3 mashqdan keyin natija sezilarli o\'sadi.'),
          _btn('Mnemonika bo\'limiga qaytish', () => Navigator.pop(context),
              color: AppColors.success),
        ];
    }
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ScoreBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Text('$value / 10',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, color: color)),
              Text(label, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      );
}
