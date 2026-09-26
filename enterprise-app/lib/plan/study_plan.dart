import 'dart:convert';
import 'dart:math';

/// MNEMONIKA XARITASI — kitobni belgilangan muddatda yodlab tugatish rejasi.
///
/// Davronbek Turdiev tahlilidagi 1-prinsip: "ko'p / kam" emas — HAJMni
/// bil. Kitobda nechta so'z, dars, qoida borligi aniq sanaladi, o'quvchi
/// muddat tanlaydi, reja kunlarga bo'linadi. Har kuni cheklist:
/// yangi so'zlar (ilgak + obraz) → qoida → oraliqli takror → o'zbekchasidan
/// inglizchasini topish → ovoz chiqarib aytish → uxlashdan oldin takror.
///
/// Bu fayl SOF hisob: UI va disk bilan ishlamaydi — test qilinadi.

/// Bitta unit hajmi.
class UnitVolume {
  final int unit;
  final String label;
  final String title;

  /// So'z darslari: har biri shu darsdagi so'zlar id ro'yxati.
  final List<List<String>> lessons;

  /// So'zlar soni (darslardagi jami).
  final int words;

  /// Grammatika qoidalari (nazariya bo'limlari) sarlavhalari.
  final List<String> rules;

  /// Grammatika mashqlari soni (ma'lumot uchun).
  final int grammarExercises;

  const UnitVolume({
    required this.unit,
    required this.label,
    required this.title,
    required this.lessons,
    required this.words,
    required this.rules,
    this.grammarExercises = 0,
  });
}

/// Butun kitob hajmi.
class BookVolume {
  final String level;
  final String bookTitle;
  final List<UnitVolume> units;

  /// Kitobdagi NOYOB so'zlar (unitlar orasidagi takrorlarsiz).
  final int uniqueWords;

  const BookVolume({
    required this.level,
    required this.bookTitle,
    required this.units,
    required this.uniqueWords,
  });

  int get lessons => units.fold(0, (a, u) => a + u.lessons.length);
  int get words => units.fold(0, (a, u) => a + u.words);
  int get rules => units.fold(0, (a, u) => a + u.rules.length);
  int get grammarExercises => units.fold(0, (a, u) => a + u.grammarExercises);

  /// Bir darsdagi o'rtacha so'z.
  double get wordsPerLesson => lessons == 0 ? 0 : words / lessons;
}

/// Kunlik ish turi.
enum PlanKind { lesson, rule }

/// Reja bandi: bitta so'z darsi yoki bitta qoida.
class PlanItem {
  final PlanKind kind;
  final int unit;

  /// Dars uchun: unitdagi dars indeksi (0 dan). Qoida uchun: qoida indeksi.
  final int index;

  /// Qoida sarlavhasi (faqat qoida uchun).
  final String title;

  /// Dars so'zlari (faqat dars uchun) — bajarilganini aniqlash uchun.
  final List<String> itemIds;

  const PlanItem({
    required this.kind,
    required this.unit,
    required this.index,
    this.title = '',
    this.itemIds = const [],
  });

  /// Taxminiy daqiqa: dars ~4 (4 raund × 7 so'z), qoida ~6.
  int get minutes => kind == PlanKind.lesson ? kMinutesPerLesson : kMinutesPerRule;

  String get key => '${kind.name}:$unit:$index';
}

const int kMinutesPerLesson = 4;
const int kMinutesPerRule = 6;

/// Kunlik yuk ko'rsatkichlari (muddat tanlash ekrani uchun).
class Pace {
  final int days;
  final double lessonsPerDay;
  final double wordsPerDay;
  final double rulesPerDay;

  /// Jami daqiqa: yangi + takror (+40%) + faol eslash va gapirish (~5).
  final int minutesPerDay;

  const Pace({
    required this.days,
    required this.lessonsPerDay,
    required this.wordsPerDay,
    required this.rulesPerDay,
    required this.minutesPerDay,
  });

  /// Qiyinlik yorlig'i — "Stockdale": realistik kutish.
  String get difficulty {
    if (minutesPerDay <= 25) return 'Yengil';
    if (minutesPerDay <= 45) return 'O\'rtacha';
    if (minutesPerDay <= 75) return 'Og\'ir';
    return 'Juda og\'ir';
  }
}

Pace paceFor(BookVolume v, int days) {
  final d = max(1, days);
  final lessonsPerDay = v.lessons / d;
  final rulesPerDay = v.rules / d;
  final newMin = lessonsPerDay * kMinutesPerLesson + rulesPerDay * kMinutesPerRule;
  // Oraliqli takror: yangi ishning ~40% i; faol eslash + gapirish ~5 daqiqa.
  final total = (newMin * 1.4 + 5).round();
  return Pace(
    days: d,
    lessonsPerDay: lessonsPerDay,
    wordsPerDay: lessonsPerDay * v.wordsPerLesson,
    rulesPerDay: rulesPerDay,
    minutesPerDay: total,
  );
}

/// Taklif etiladigan muddatlar (kun).
const List<int> kPlanDurations = [30, 60, 90, 120, 180, 270, 365];

/// Tavsiya: kunlik 45 daqiqadan oshmaydigan ENG QISQA muddat.
int recommendedDays(BookVolume v) {
  for (final d in kPlanDurations) {
    if (paceFor(v, d).minutesPerDay <= 45) return d;
  }
  return kPlanDurations.last;
}

/// Kitob tartibida barcha bandlar: har unitda qoidalar darslar orasiga
/// teng taqsimlanadi (qoida — so'zlar tanishgach, mashq qilinadi).
List<PlanItem> planItems(BookVolume v) {
  final out = <PlanItem>[];
  for (final u in v.units) {
    final l = u.lessons.length;
    final r = u.rules.length;
    // Qoida i darslar orasida (i+1)/(r+1) ulushda turadi.
    final ruleAt = [for (var i = 0; i < r; i++) ((i + 1) * l / (r + 1)).floor()];
    var ri = 0;
    for (var li = 0; li <= l; li++) {
      while (ri < r && ruleAt[ri] <= li) {
        out.add(PlanItem(
            kind: PlanKind.rule, unit: u.unit, index: ri, title: u.rules[ri]));
        ri++;
      }
      if (li < l) {
        out.add(PlanItem(
            kind: PlanKind.lesson,
            unit: u.unit,
            index: li,
            itemIds: u.lessons[li]));
      }
    }
  }
  return out;
}

/// Bandlarni kunlarga bo'ladi — daqiqa bo'yicha teng yuk.
List<List<PlanItem>> buildSchedule(BookVolume v, int days) {
  final items = planItems(v);
  final d = max(1, days);
  final total = items.fold<int>(0, (a, e) => a + e.minutes);
  final out = List.generate(d, (_) => <PlanItem>[]);
  var acc = 0;
  for (final it in items) {
    // Bandning O'RTASI qaysi kunga tushsa - o'sha kun.
    final mid = acc + it.minutes / 2;
    final day = total == 0 ? 0 : min(d - 1, (mid * d / total).floor());
    out[day].add(it);
    acc += it.minutes;
  }
  return out;
}

/// Saqlanadigan reja.
class StudyPlan {
  final String level;
  final int days;

  /// Boshlangan kun 'YYYY-MM-DD'.
  final String start;

  const StudyPlan({required this.level, required this.days, required this.start});

  DateTime get startDate => DateTime.tryParse(start) ?? DateTime.now();

  /// Bugun rejaning nechanchi kuni (0 dan), [0, days-1] oralig'ida.
  int dayIndex(DateTime now) {
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final t = DateTime(now.year, now.month, now.day);
    return t.difference(s).inDays.clamp(0, days - 1);
  }

  DateTime get finishDate => startDate.add(Duration(days: days - 1));

  String toJson() => json.encode({'l': level, 'd': days, 's': start});

  static StudyPlan? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = json.decode(raw) as Map<String, dynamic>;
      return StudyPlan(
        level: j['l'] as String? ?? '',
        days: (j['d'] as num?)?.toInt() ?? 60,
        start: j['s'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Reja holati: nechta band bajarilgan, bugungacha nechtasi kerak edi.
class PlanStatus {
  final int done;
  final int expected;
  final int total;

  const PlanStatus({required this.done, required this.expected, required this.total});

  /// Ortda qolgan bandlar (musbat) yoki oldinda (manfiy).
  int get behind => expected - done;

  double get ratio => total == 0 ? 0 : done / total;
}

PlanStatus planStatus(
  List<List<PlanItem>> schedule,
  int todayIndex,
  bool Function(PlanItem) isDone,
) {
  var done = 0, expected = 0, total = 0;
  for (var i = 0; i < schedule.length; i++) {
    for (final it in schedule[i]) {
      total++;
      if (isDone(it)) done++;
      // Bugungi kun ham "kerak edi" hisobiga kirmaydi - kun hali tugamagan.
      if (i < todayIndex) expected++;
    }
  }
  return PlanStatus(done: done, expected: expected, total: total);
}

/// Bugun qilinadigan bandlar: bugungi reja + ORTDA QOLGANLAR (eng ko'pi
/// bilan bir kunlik qo'shimcha — o'quvchi ezilmasin; qolgani qayta
/// taqsimlanadi, jazo yo'q).
List<PlanItem> todayItems(
  List<List<PlanItem>> schedule,
  int todayIndex,
  bool Function(PlanItem) isDone,
) {
  final today = schedule.isEmpty ? <PlanItem>[] : schedule[todayIndex];
  final backlog = <PlanItem>[];
  for (var i = 0; i < todayIndex; i++) {
    backlog.addAll(schedule[i].where((e) => !isDone(e)));
  }
  final extraCap = today.length;
  return [...backlog.take(extraCap), ...today];
}
