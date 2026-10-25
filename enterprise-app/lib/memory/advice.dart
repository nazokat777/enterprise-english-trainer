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
      return HomeAdvice('🛟', '$fading ta so\'zni unutib qo\'yishingiz mumkin - avval takrorlang');
    }
    if (examUnit > 0 && !examPassed) {
      return HomeAdvice(
          '📝', '1-$examUnit unitlar (boblar) bo\'yicha imtihon topshirishingiz mumkin');
    }
    if (nextLesson != null) {
      return HomeAdvice('📖', 'Keyingi dars: $nextLesson');
    }
    if (goalMet) {
      return const HomeAdvice('⚡', '60 soniyalik tezlik o\'yini bilan tezlikni oshiring');
    }
    return const HomeAdvice('🚀', '3 daqiqalik qisqa mashqdan boshlang');
  }
}
