import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../book_content.dart';
import '../lessons/word_lesson.dart';
import '../levels.dart';
import '../main.dart';
import 'study_plan.dart';

/// Rejani saqlash + kitob hajmini haqiqiy kontentdan hisoblash.
class PlanStore extends ChangeNotifier {
  SharedPreferences? _prefs;

  /// Daraja bo'yicha hajm (bir marta hisoblanadi).
  final Map<String, BookVolume> _volumes = {};

  /// Daraja bo'yicha unitlar (qoida mashqlarini ochish uchun).
  final Map<String, Map<int, BookUnit>> _units = {};

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  String get level => progress.currentLevel;

  // ─────────── Reja ───────────
  Future<StudyPlan?> plan() async =>
      StudyPlan.fromJson((await _p).getString('plan::$level'));

  Future<void> savePlan(int days, {DateTime? start}) async {
    final p = StudyPlan(
        level: level, days: days, start: ymd(start ?? DateTime.now()));
    await (await _p).setString('plan::$level', p.toJson());
    notifyListeners();
  }

  Future<void> clearPlan() async {
    await (await _p).remove('plan::$level');
    notifyListeners();
  }

  // ─────────── Kunlik belgilar (faol eslash, gapirish, kechki) ───────────
  String _dayKey(DateTime d) => 'plan_done::$level::${ymd(d)}';

  Future<Set<String>> doneToday() async =>
      ((await _p).getStringList(_dayKey(DateTime.now())) ?? const [])
          .toSet();

  Future<void> markToday(String id) async {
    final p = await _p;
    final k = _dayKey(DateTime.now());
    final s = (p.getStringList(k) ?? const []).toSet()..add(id);
    await p.setStringList(k, s.toList());
    notifyListeners();
  }

  // ─────────── Hajm ───────────
  /// Kitob hajmi — asosiy unitlar (qo'shimcha: epizod, test, lug'at
  /// ro'yxati kirmaydi). Darslar ilovadagi so'z darslari bilan AYNAN bir
  /// xil bo'linadi (`lessonsOf`).
  Future<BookVolume> volume() {
    final lvl = level;
    final cached = _volumes[lvl];
    if (cached != null) return Future.value(cached);
    // Bir vaqtda bir necha joy (bosh karta + ekran) so'rasa - bitta hisob.
    // DIQQAT: `whenComplete(() => _inflight.remove(lvl))` bo'lmasin - u
    // olib tashlangan Future'ni QAYTARADI va Future o'zini o'zi kutib
    // qotib qoladi. Blok tanasi hech narsa qaytarmaydi.
    return _inflight[lvl] ??= _compute(lvl).whenComplete(() {
      _inflight.remove(lvl);
    });
  }

  final Map<String, Future<BookVolume>> _inflight = {};

  Future<BookVolume> _compute(String lvl) async {
    final units = <UnitVolume>[];
    final byNo = <int, BookUnit>{};
    final unique = <String>{};
    // NUSXA: hisob davomida daraja almashsa `book.units` qayta to'ladi -
    // asl ro'yxat ustida aylanish ConcurrentModificationError berardi.
    final briefs = List.of(book.units);
    for (final b in briefs) {
      // Daraja almashdi - bu hisob eskirdi, yangisi boshlanadi.
      if (level != lvl) return volume();
      if (b.isExtra || b.unit < 1) continue;
      final u = await book.load(b.unit);
      if (u == null) continue;
      byNo[u.unit] = u;
      final lessons = lessonsOf(u);
      for (final l in lessons) {
        for (final w in l.words) {
          unique.add(w.en.trim().toLowerCase());
        }
      }
      final rules = <String>[];
      var gx = 0;
      for (final s in u.sections) {
        if (s.kind == 'grammar_theory') {
          final t = s.titleUz.isNotEmpty ? s.titleUz : s.title;
          if (t.isNotEmpty && !rules.contains(t)) rules.add(t);
        }
        if (s.kind == 'grammar_exercise' || s.kind == 'grammar') {
          gx += s.exercises.length;
        }
      }
      units.add(UnitVolume(
        unit: u.unit,
        label: u.displayLabel,
        title: u.title,
        lessons: [for (final l in lessons) l.itemIds],
        words: lessons.fold(0, (a, l) => a + l.words.length),
        rules: rules,
        grammarExercises: gx,
      ));
    }
    final v = BookVolume(
      level: lvl,
      bookTitle: levelBookTitle(lvl),
      units: units,
      uniqueWords: unique.length,
    );
    if (level != lvl) return volume();
    _volumes[lvl] = v;
    _units[lvl] = byNo;
    return v;
  }

  /// Rejadagi band uchun unit (ochish uchun).
  BookUnit? unitOf(int unit) => _units[level]?[unit];

  /// Qoida bandining bo'limi (grammar_theory).
  BookSection? ruleSection(PlanItem it) {
    final u = unitOf(it.unit);
    if (u == null) return null;
    final secs = u.sections.where((s) => s.kind == 'grammar_theory').toList();
    final title = it.title;
    for (final s in secs) {
      if ((s.titleUz.isNotEmpty ? s.titleUz : s.title) == title) return s;
    }
    return null;
  }

  /// Band bajarilganmi (haqiqiy holatdan).
  bool isDone(PlanItem it) {
    if (it.kind == PlanKind.lesson) {
      return it.itemIds.isNotEmpty && mastery.allStrong(it.itemIds);
    }
    final s = ruleSection(it);
    if (s == null || s.exercises.isEmpty) return false;
    return s.exercises.every((e) => progress.isDone(e.progressId));
  }

  /// Rejadagi dars (ochish uchun).
  WordLesson? lessonOf(PlanItem it) {
    final u = unitOf(it.unit);
    if (u == null) return null;
    final ls = lessonsOf(u);
    return it.index < ls.length ? ls[it.index] : null;
  }
}
