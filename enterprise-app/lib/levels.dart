/// DARAJALAR — Enterprise seriyasining kitoblari.
///
/// Ro'yxat BITTA joyda turadi. Ilgari u to'rt joyda takrorlanardi
/// (`content.dart`, `book_content.dart`, `shell.dart` da ikki marta),
/// shuning uchun yangi kitob qo'shish uchun hammasini eslab
/// yangilash kerak edi — bittasi esdan chiqsa, daraja qisman
/// ishlagan bo'lardi.
///
/// Yangi kitob qo'shish: shu ro'yxatga bitta qator + kontentni
/// `assets/content/<vocab>/` va `assets/content/<book>/` ga eksport.
class Level {
  /// Ichki kalit — `Progress.currentLevel` va SharedPreferences da.
  final String id;

  /// Menyuda ko'rinadigan nom.
  final String label;

  /// Lug'at (SRS) kontenti papkasi.
  final String vocabDir;

  /// Kitob (mashqlar) kontenti papkasi.
  final String bookDir;

  const Level({
    required this.id,
    required this.label,
    required this.vocabDir,
    required this.bookDir,
  });
}

const List<Level> kLevels = [
  Level(
    id: 'beginner',
    label: 'Beginner',
    vocabDir: 'assets/content/beginner',
    bookDir: 'assets/content/enterprise1',
  ),
  Level(
    id: 'elementary',
    label: 'Elementary',
    vocabDir: 'assets/content/elementary',
    bookDir: 'assets/content/enterprise2',
  ),
];

/// Birinchi daraja — saqlangan qiymat noto'g'ri bo'lsa shunga qaytadi.
const String kDefaultLevel = 'beginner';

Level levelById(String id) =>
    kLevels.firstWhere((l) => l.id == id, orElse: () => kLevels.first);

String levelLabel(String id) => levelById(id).label;
