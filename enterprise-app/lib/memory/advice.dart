/// BUGUNGI TAVSIYA — bosh ekran hero'sida bitta aniq keyingi qadam.
///
/// Qaror charchog'i (decision fatigue) boshlashning eng katta to'sig'i:
/// "nima qilay?" degan savolga ilova o'zi javob beradi. Tartib —
/// xotira ilmi bo'yicha muhimlik: avval o'chib ketayotgan so'zlar
/// (unutish egri chizig'i kutmaydi), so'ng tayyor imtihon (tugatilgan
/// unitni mustahkamlash), so'ng keyingi dars, oxiri tezlik mashqi.
class HomeAdvice {
  final String emoji;
  final String text;
  const HomeAdvice(this.emoji, this.text);

  static HomeAdvice compute({
    required int fading,
    required int examUnit,
    required bool examPassed,
    required String? nextLesson,
    required bool goalMet,
  }) {
    if (fading >= 3) {
      return HomeAdvice('🛟', '$fading so\'z o\'chib ketmoqda - avval qutqaring');
    }
    if (examUnit > 0 && !examPassed) {
      return HomeAdvice('📝', '1-$examUnit unitlar imtihoni tayyor');
    }
    if (nextLesson != null) {
      return HomeAdvice('📖', 'Keyingi: $nextLesson');
    }
    if (goalMet) return const HomeAdvice('⚡', 'Blitz bilan tezlikni oshiring');
    return const HomeAdvice('🚀', '3 daqiqalik tez mashqdan boshlang');
  }
}
