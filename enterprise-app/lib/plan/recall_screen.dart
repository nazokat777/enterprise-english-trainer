import 'package:flutter/material.dart';

import '../drill/drill_item.dart';
import '../main.dart';
import '../mastery.dart';
import '../services/tts.dart';
import '../theme.dart';
import '../widgets/correct_burst.dart';
import '../widgets/pressable3d.dart';

/// YOPIB ESLASH — o'zbekchasi ko'rinadi, inglizchasini o'zi yozadi.
///
/// Ilgari bu band "trening" dvigatelini ochardi: u faqat HALI
/// o'zlashtirilmagan so'zlarni so'raydi, darsdan keyin esa so'zlar
/// o'zlashtirilgan bo'ladi - ekran bo'sh ochilardi. Bu ekran
/// berilgan so'zlarni HAR DOIM so'raydi; xato so'z oxirida qaytadi,
/// hammasi to'g'ri bo'lguncha tugamaydi. Xato bo'lsa o'quvchining
/// o'z ilgagi (sahnasi) eslatiladi.
class RecallScreen extends StatefulWidget {
  final String title;
  final List<DrillSource> words;
  const RecallScreen({super.key, required this.title, required this.words});

  @override
  State<RecallScreen> createState() => _RecallScreenState();
}

class _RecallScreenState extends State<RecallScreen> {
  late final List<DrillSource> _queue = List.of(widget.words)..shuffle();
  int _pos = 0;
  int _firstTry = 0;
  final Set<String> _missed = {};
  final _c = TextEditingController();
  bool? _ok;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z' ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _check() async {
    if (_ok != null || _c.text.trim().isEmpty) return;
    final w = _queue[_pos];
    final ok = _norm(_c.text) == _norm(w.en);
    setState(() => _ok = ok);
    Tts.instance.speak(w.en, id: w.itemId);
    await mastery.record(w.itemId, AskFormat.produce,
        ok: ok, en: w.en, uz: w.uz);
    if (ok) {
      if (!_missed.contains(w.itemId)) _firstTry++;
      if (mounted) showCorrectBurst(context);
      final bonus = rewards.onAnswer(true, baseXp: 2);
      await progress.addXp(2 + bonus);
    } else {
      rewards.onAnswer(false);
      _missed.add(w.itemId);
      // Xato so'z oxirida QAYTADI.
      _queue.add(w);
    }
  }

  void _next() {
    setState(() {
      _pos++;
      _ok = null;
      _c.clear();
    });
    if (_pos >= _queue.length) {
      rewards.onExerciseDone(clean: _missed.isEmpty);
      progress.addXp(5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(context);
    final done = _pos >= _queue.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: done ? _finished(context) : _ask(context, muted),
    );
  }

  Widget _ask(BuildContext context, Color muted) {
    final w = _queue[_pos];
    final hook = mastery.of(w.itemId).hook;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: _pos / _queue.length,
            minHeight: 6,
            backgroundColor: AppColors.brandPurple.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(height: 16),
        Text('Inglizchasini yozing (qaramasdan):',
            style: TextStyle(fontSize: 13, color: muted)),
        const SizedBox(height: 6),
        Text(w.uz,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        TextField(
          key: ValueKey('in$_pos'),
          controller: _c,
          autofocus: true,
          enabled: _ok == null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _ok == null ? _check() : _next(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'inglizcha...',
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
        const SizedBox(height: 12),
        if (_ok == null)
          Pressable3D(
            color: AppColors.actionBlue,
            enabled: _c.text.trim().isNotEmpty,
            onPressed: _c.text.trim().isEmpty ? null : _check,
            child: const Center(
              child: Text('Tekshirish',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          )
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
                      fontSize: 16,
                      color: _ok! ? AppColors.success : AppColors.danger),
                ),
                if (!_ok!) ...[
                  const SizedBox(height: 4),
                  Text(
                    hook.isNotEmpty
                        ? 'Ilgagingizni eslang: $hook'
                        : 'Bu so\'z oxirida yana so\'raladi.',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Pressable3D(
            color: AppColors.brandPurple,
            shadowColor: const Color(0xFF5B22B5),
            onPressed: _next,
            child: const Center(
              child: Text('Keyingisi',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _finished(BuildContext context) {
    final n = widget.words.length;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Text('$_firstTry / $n',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900)),
        Text('birinchi urinishda eslandi',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.muted(context))),
        const SizedBox(height: 18),
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
    );
  }
}
