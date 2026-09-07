import '../main.dart';
import 'drill_item.dart';

/// ZAIF MAVZU — "qaysi joyini o'zlashtirolmayapti" savoliga javob.
///
/// Band darajasidagi hisob (`MasteryStore`) bor edi, lekin u
/// MAVZUGA bog'lanmagandi: o'quvchi "grammatikam zaif" yoki "uy
/// jihozlari so'zlari yodlanmayapti" degan xulosani chiqara olmasdi.
class WeakTopic {
  /// Bo'lim nomi ("Grammatika", "Lug'at", "O'qish"...).
  final String topic;

  /// Shu mavzudagi bandlar.
  final List<DrillSource> sources;

  /// O'zlashtirilish ulushi (0..1).
  final double ratio;

  /// Hali o'zlashtirilmagan bandlar soni.
  final int left;

  const WeakTopic({
    required this.topic,
    required this.sources,
    required this.ratio,
    required this.left,
  });
}

/// Kitobning O'RGANILGAN qismidan zaif mavzularni yig'adi.
///
/// Faqat o'quvchi TEGINGAN bandlar hisobga olinadi: hali ochilmagan
/// dars "zaif" emas, u shunchaki yangi. Aks holda ro'yxat butun
/// kitobdan iborat bo'lib qolardi va hech qanday ma'no bermasdi.
Future<List<WeakTopic>> weakTopics({int limit = 8}) async {
  final byTopic = <String, List<DrillSource>>{};

  // Unitlar BIR VAQTDA yuklanadi. Birin-ketin yuklashda ekran 20
  // soniyadan ko'p aylanardi — takrorlash va suhbatlar ekranlarida
  // ham aynan shu xato bo'lgan edi.
  final loaded = await Future.wait(book.units.map((b) => book.load(b.unit)));

  for (final u in loaded) {
    if (u == null) continue;
    for (final s in sourcesFromUnit(u)) {
      final m = mastery.of(s.itemId);
      if (m.isNew) continue; // hali boshlanmagan — zaif emas
      byTopic.putIfAbsent(s.topic, () => []).add(s);
    }
  }

  final out = <WeakTopic>[];
  byTopic.forEach((topic, list) {
    final left = list.where((e) => !mastery.of(e.itemId).isStrong).length;
    if (left == 0) return; // bu mavzu tugagan
    out.add(WeakTopic(
      topic: topic,
      sources: list,
      ratio: mastery.progressScore(list.map((e) => e.itemId)),
      left: left,
    ));
  });

  // Eng zaifdan boshlab.
  out.sort((a, b) => a.ratio.compareTo(b.ratio));
  return out.take(limit).toList();
}

/// Shu mavzuning eng zaif bandlari — mashq uchun.
List<DrillSource> weakestOf(WeakTopic t, {int limit = 10}) {
  final ids = mastery.weakest(t.sources.map((e) => e.itemId), limit: limit);
  final byId = {for (final s in t.sources) s.itemId: s};
  return [
    for (final id in ids)
      if (byId[id] != null) byId[id]!,
  ];
}
