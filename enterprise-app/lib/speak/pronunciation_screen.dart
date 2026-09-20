import 'dart:math';

import 'package:flutter/material.dart';

import '../blitz/blitz_screen.dart' show blitzSourcesFromMastery;
import '../drill/drill_item.dart';
import '../main.dart';
import '../mastery.dart';
import '../stats.dart';
import '../reward/confetti.dart';
import '../theme.dart';
import '../widgets/correct_burst.dart';
import '../widgets/pressable3d.dart';
import 'speak_task.dart';

/// TALAFFUZ TRENINGI — o'rganilgan so'zlardan 10 tasi ketma-ket ovoz
/// chiqarib aytiladi. Tez, 2 daqiqalik "og'iz mashqi": so'z ko'z
/// bilan tanish bo'lsa ham, AYTA OLISH alohida ko'nikma.
class PronunciationScreen extends StatefulWidget {
  final int count;
  const PronunciationScreen({super.key, this.count = 10});

  @override
  State<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends State<PronunciationScreen> {
  late final List<DrillQuestion> _qs = _build();
  int _i = 0;
  int _ok = 0;
  int _skipped = 0;
  bool _locked = false;

  List<DrillQuestion> _build() {
    final rnd = Random();
    final src = blitzSourcesFromMastery(mastery, limit: 80)..shuffle(rnd);
    final out = <DrillQuestion>[];
    for (final s in src) {
      final q = buildQuestion(s, AskFormat.speak, const [], rnd);
      if (q != null) out.add(q);
      if (out.length >= widget.count) break;
    }
    return out;
  }

  Future<void> _answer(bool ok) async {
    if (_locked) return;
    _locked = true;
    if (ok) {
      _ok++;
      showCorrectBurst(context);
      final bonus = rewards.onAnswer(true, baseXp: 2);
      await progress.addXp(2 + bonus, skill: Skill.speaking);
      await mastery.record(_qs[_i].itemId, AskFormat.speak,
          ok: true, en: _qs[_i].answer, uz: _qs[_i].promptUz);
    }
    await Future<void>.delayed(const Duration(milliseconds: 650));
    _next();
  }

  void _skip() {
    if (_locked) return;
    _skipped++;
    _next();
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      _i++;
      _locked = false;
    });
    if (_i >= _qs.length) {
      progress.addXp(5, skill: Skill.speaking);
      rewards.onExerciseDone(clean: _skipped == 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _i >= _qs.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(done
            ? 'Talaffuz treningi'
            : 'Talaffuz · ${_i + 1}/${_qs.length}'),
      ),
      body: _qs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Hali o\'rganilgan so\'z yo\'q. Avval bitta so\'z darsini o\'ting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted(context)),
                ),
              ),
            )
          : done
              ? _finished(context)
              : Column(
                  children: [
                    LinearProgressIndicator(
                      value: _i / _qs.length,
                      minHeight: 6,
                      backgroundColor:
                          AppColors.brandPurple.withValues(alpha: 0.12),
                    ),
                    Expanded(
                      child: SpeakTask(
                        key: ValueKey('p$_i'),
                        q: _qs[_i],
                        locked: _locked,
                        onDone: _answer,
                        onSkip: _skip,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _finished(BuildContext context) {
    final perfect = _ok == _qs.length;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: perfect
                    ? AppColors.successGradient
                    : AppColors.brandGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadow.glow(
                    perfect ? AppColors.success : AppColors.brandPurple),
              ),
              child: Column(
                children: [
                  Text(perfect ? '🎤' : '🗣️',
                      style: const TextStyle(fontSize: 52)),
                  const SizedBox(height: 8),
                  Text(perfect ? 'Mukammal talaffuz!' : 'Trening tugadi',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('$_ok / ${_qs.length} so\'z to\'g\'ri aytildi',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Pressable3D(
              color: AppColors.brandPurple,
              shadowColor: const Color(0xFF5B22B5),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => PronunciationScreen(count: widget.count)),
              ),
              child: const Center(
                child: Text('Yana 10 ta',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
            Pressable3D(
              color: AppColors.success,
              shadowColor: const Color(0xFF0F7A37),
              onPressed: () => Navigator.pop(context),
              child: const Center(
                child: Text('Tayyor',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
        if (perfect) const IgnorePointer(child: ConfettiBurst(count: 100)),
      ],
    );
  }
}
