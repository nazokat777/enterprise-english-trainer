import '../content.dart';
import '../main.dart';

/// LUG'ATDAN MA'NO — bitta inglizcha so'zning o'zbekchasi.
///
/// Tushuntirishda ishlatiladi: bandda tayyor tarjima bo'lmasa, javob
/// ichidagi so'zlarning ma'nosi shu yerdan olinadi.
String meaningOf(String word) {
  final key = normalizeWord(word);
  if (key.isEmpty || key.contains(' ')) return '';
  final c = repo.forLevel(progress.currentLevel);
  final id = c.idByEn[key];
  if (id == null) return '';
  return c.wordsById[id]?.uz.trim() ?? '';
}
