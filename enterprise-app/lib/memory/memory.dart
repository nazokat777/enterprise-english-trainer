import '../drill/drill_item.dart';
import '../lessons/word_lesson.dart';
import '../mastery.dart';

/// XOTIRA QUTQARUVI — o'chib ketayotgan so'zlarni qaytarib olish.
///
/// Nevrobiologiya: eslash muddati o'tib ketgan, lekin hali unutilmagan
/// so'zni QAYTA ESLAB AYTISh ("desirable difficulty", Bjork) xotira
/// izini eng kuchli mustahkamlaydi — oson takrordan ko'ra ko'proq.
/// Ilova aynan shu paytni topib beradi: interval tugagan, so'z
/// "so'nmoqda". O'quvchi uni "qutqaradi" — bu yo'qotishdan qochish
/// (loss aversion) va qahramonlik hissi: dofamin ikki manbadan.
///
/// Seans: `LessonScreen` bilan, tanishuvsiz (avval eslab ko'rish!),
/// so'zlar `MasteryStore` da saqlangan `en/uz` juftidan tuziladi.
class MemoryRescue {
  /// Bir seansda nechta so'z.
  static const int size = 8;

  /// Qutqaruv darsi; so'z bo'lmasa `null`.
  static WordLesson? lesson(MasteryStore m, {int? nowMs}) {
    final ids = m.fadingIds(limit: size, nowMs: nowMs);
    if (ids.isEmpty) return null;
    final words = <LessonWord>[
      for (final id in ids)
        LessonWord(en: _en(m, id), uz: m.of(id).uz),
    ];
    return WordLesson(index: 0, unit: 0, words: words);
  }

  /// Aralash takror uchun 1-3 ta o'chayotgan so'z (darsdagilar
  /// chiqarib tashlanadi).
  static List<DrillSource> extras(MasteryStore m, WordLesson current,
      {int limit = 3, int? nowMs}) {
    final mine = current.itemIds.toSet();
    final out = <DrillSource>[];
    for (final id in m.fadingIds(limit: limit + mine.length, nowMs: nowMs)) {
      if (mine.contains(id)) continue;
      out.add(DrillSource(
        itemId: id,
        en: _en(m, id),
        uz: m.of(id).uz,
        unit: 0,
        topic: 'Takror',
      ));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// `w::<so'z>` kalitidan inglizchasi — saqlangan asl yozuv bo'lsa u,
  /// bo'lmasa kalitning o'zi.
  static String _en(MasteryStore m, String id) {
    final e = m.of(id).en;
    if (e.isNotEmpty) return e;
    return id.startsWith('w::') ? id.substring(3) : id;
  }
}
