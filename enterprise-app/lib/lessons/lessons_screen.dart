import 'package:flutter/material.dart';

import '../book_content.dart';
import '../blitz/blitz_screen.dart';
import '../drill/drill_item.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/entrance.dart';
import '../widgets/pressable3d.dart';
import 'lesson_screen.dart';
import 'word_lesson.dart';

/// UNITNING SO'Z DARSLARI — yo'l xaritasi (Duolingo "path").
///
/// Darslar KETMA-KET ochiladi: keyingisi oldingisi 100% bo'lganda.
/// Tugagan darsni istalgan vaqt takrorlash mumkin.
class LessonsScreen extends StatefulWidget {
  final BookUnit unit;
  const LessonsScreen({super.key, required this.unit});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  late final List<WordLesson> _lessons = lessonsOf(widget.unit);

  /// Chalg'ituvchilar uchun unitning butun lug'ati.
  late final List<DrillSource> _pool = [
    for (final l in _lessons) ...l.sources,
  ];

  bool _done(WordLesson l) => mastery.allStrong(l.itemIds);

  /// Birinchi tugallanmagan dars — "hozir shu".
  int get _currentIndex {
    final i = _lessons.indexWhere((l) => !_done(l));
    return i < 0 ? _lessons.length : i;
  }

  Future<void> _open(WordLesson l) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          lesson: l,
          unitLabel: widget.unit.displayLabel,
          pool: _pool,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unit;
    final doneCount = _lessons.where(_done).length;
    final cur = _currentIndex;
    return Scaffold(
      appBar: AppBar(title: Text('${u.displayLabel} — so\'zlar')),
      body: AnimatedBuilder(
        animation: mastery,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(u.title, style: AppTheme.heading(context)),
            const SizedBox(height: 4),
            Text(
              '${_lessons.length} ta dars · '
              '${_lessons.fold(0, (s, l) => s + l.words.length)} ta so\'z · '
              '$doneCount tasi tugadi',
              style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: _lessons.isEmpty ? 1 : doneCount / _lessons.length,
                minHeight: 10,
                backgroundColor: AppColors.brandPurple.withValues(alpha: 0.15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
            const SizedBox(height: 18),
            if (cur < _lessons.length) ...[
              Pressable3D(
                color: AppColors.success,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                onPressed: () => _open(_lessons[cur]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                          '${cur + 1}-darsni boshlash · ${_lessons[cur].words.length} so\'z',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Avval so\'zlar ko\'rsatiladi, so\'ng 3-4 bosqichda so\'raladi '
                '(oxirgisi - gap ichida). '
                'Xato qilingan so\'z qaytadi.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12, color: AppColors.muted(context)),
              ),
              const SizedBox(height: 20),
            ],
            // ⚡ BLITZ — unit so'zlari bilan 60 soniya. Darslar tugagach
            // ham qaytib keladigan sabab: o'z rekordini yangilash.
            if (_pool.length >= 4) ...[
              _BlitzButton(pool: _pool, unit: u),
              const SizedBox(height: 16),
            ],
            for (var i = 0; i < _lessons.length; i++)
              EntranceFade(
                delay: Duration(milliseconds: 30 * (i < 20 ? i : 20)),
                child: _LessonTile(
                  lesson: _lessons[i],
                  state: i < cur
                      ? _TileState.done
                      : i == cur
                          ? _TileState.current
                          : _TileState.locked,
                  onTap: i <= cur ? () => _open(_lessons[i]) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _TileState { done, current, locked }

class _LessonTile extends StatelessWidget {
  final WordLesson lesson;
  final _TileState state;
  final VoidCallback? onTap;
  const _LessonTile(
      {required this.lesson, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (state) {
      _TileState.done => AppColors.success,
      _TileState.current => AppColors.brandPurple,
      _TileState.locked => AppColors.muted(context),
    };
    final preview = lesson.words.map((w) => w.en).take(4).join(', ') +
        (lesson.words.length > 4 ? ' …' : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: state == _TileState.locked ? 0.55 : 1,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: state == _TileState.current
                    ? Border.all(color: AppColors.brandPurple, width: 1.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
                      blurRadius: 10),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: state == _TileState.done
                          ? Icon(Icons.check_rounded, color: color)
                          : state == _TileState.locked
                              ? Icon(Icons.lock_rounded, color: color, size: 20)
                              : Text('${lesson.index}',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: color)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${lesson.index}-dars · ${lesson.words.length} so\'z',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.muted(context))),
                      ],
                    ),
                  ),
                  if (state == _TileState.done)
                    Text('Takrorlash',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlitzButton extends StatefulWidget {
  final List<DrillSource> pool;
  final BookUnit unit;
  const _BlitzButton({required this.pool, required this.unit});

  @override
  State<_BlitzButton> createState() => _BlitzButtonState();
}

class _BlitzButtonState extends State<_BlitzButton> {
  int _best = 0;
  String get _key => '${book.level}::u${widget.unit.unit}';

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
                sources: widget.pool,
                label: widget.unit.displayLabel,
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
                          ? 'Rekordingiz: $_best ochko - yangilaysizmi?'
                          : '${widget.pool.length} ta so\'z, iloji boricha ko\'p javob',
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
