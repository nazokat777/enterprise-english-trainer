import 'dart:math';

/// Javob sifati — 4 baho tugmasi (SM-2 uchun q qiymati).
enum Quality {
  unknown(1), // "Bilmadim"
  hard(3), //    "Qiyin"
  good(4), //    "Yaxshi"
  easy(5); //    "Oson"

  final int q;
  const Quality(this.q);
}

/// Baho bo'yicha ishlab topiladigan XP (pack oqimi + stats birga ishlatadi).
int xpForQuality(Quality q) => switch (q) {
      Quality.easy => 3,
      Quality.good => 2,
      Quality.hard => 1,
      Quality.unknown => 0,
    };

/// Bitta so'zning SM-2 (soddalashtirilgan) takrorlash holati — dinamik SRS.
/// Vaqt `now` orqali beriladi (sof, test qilish oson).
class WordSrs {
  double easeFactor; // default 2.5, min 1.3
  int interval; //      keyingi takrorlashgacha kun
  int repetitions; //   ketma-ket to'g'ri javoblar
  DateTime? lastReviewedAt;
  DateTime? nextReviewAt;

  /// NEChA MARTA unutilgan (SM-2 da "lapse").
  ///
  /// `easeFactor` qiyinlikni ko'rsatadi, lekin u 1.3 da to'xtaydi va
  /// to'g'ri javoblar bilan yana ko'tariladi — ya'ni "bu so'zni doim
  /// unutaman" degan tarixni yo'qotadi. Shuning uchun xatolar ALOHIDA
  /// sanaladi: qaysi so'z ustida qo'shimcha ishlash kerakligi shundan
  /// aniqlanadi.
  int lapses;

  WordSrs({
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    this.lapses = 0,
    this.lastReviewedAt,
    this.nextReviewAt,
  });

  /// Hali ko'rilmagan (yangi so'z).
  bool get isNew => nextReviewAt == null;

  /// "Mature" (Anki ~21 kun) — ma'lum so'z.
  bool get isKnown => interval >= 21;

  /// Takrorlash muddati kelganmi?
  bool isDue(DateTime now) =>
      nextReviewAt != null && !nextReviewAt!.isAfter(now);

  /// SM-2 (soddalashtirilgan) — prompt formulasi bo'yicha kartani yangilaydi.
  void review(Quality quality, {DateTime? now}) {
    now ??= DateTime.now();
    final q = quality.q;

    if (q < 3) {
      // Xato — boshidan.
      repetitions = 0;
      interval = 1;
      lapses += 1;
    } else {
      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * easeFactor).round();
      }
      repetitions += 1;
    }

    // EaseFactor barcha holatda yangilanadi (q past bo'lsa — kamayadi).
    easeFactor = max(1.3, easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)));

    lastReviewedAt = now;
    nextReviewAt = now.add(Duration(days: interval));
  }

  /// Eslab qolish ehtimoli (0..1). Rejalashtirilgan interval nuqtasida ~0.9
  /// (maqsadli retention 85–90%). 0.9 dan pastga tushsa — takrorlash vaqti.
  double recallProbability(DateTime now) {
    if (nextReviewAt == null || lastReviewedAt == null || interval < 1) {
      return 1.0;
    }
    final elapsedDays =
        now.difference(lastReviewedAt!).inMinutes / (60 * 24);
    const k = 0.10536; // -ln(0.9): interval nuqtasida R=0.9
    return exp(-k * elapsedDays / interval).clamp(0.0, 1.0);
  }

  /// Bu so'z qiyinmi — qo'shimcha mashq kerakmi.
  ///
  /// Mezon: kamida IKKI marta unutilgan. Bir marta xato qilish oddiy
  /// hol — yangi so'z bilan tanishishning bir qismi. Takror unutish esa
  /// "bu so'z yodda qolmayapti" degani.
  ///
  /// `easeFactor` mezon sifatida ishlatilmaydi: bitta "Bilmadim" ni ham
  /// u 2.5 dan 1.96 ga tushiradi, ya'ni har qanday chegara bir martalik
  /// xatoni ham qiyin deb belgilab qo'yardi.
  ///
  /// XATO edi: mezon faqat `lapses >= 2` bo'lgani uchun so'z ro'yxatdan
  /// HECH QACHON chiqmasdi — `lapses` kamaymaydi. O'quvchi so'zni qayta
  /// mashq qilib o'zlashtirsa ham u "qiyin" bo'lib qolaverardi va
  /// ro'yxat faqat o'sardi. Endi oxirgi xatodan keyin KETMA-KET uch
  /// marta to'g'ri javob berilsa, so'z ro'yxatdan chiqadi. Tarix
  /// (`lapses`) saqlanadi: yana unutilsa, so'z darhol qaytadi.
  static const int _relearned = 3;

  bool get isHard => lapses >= 2 && repetitions < _relearned;

  /// Qiyinlik darajasi — ro'yxatni tartiblash uchun (katta = qiyinroq).
  double get difficulty => lapses * 10 + (2.5 - easeFactor) * 4;

  Map<String, dynamic> toJson() => {
        'ef': easeFactor,
        'iv': interval,
        'rp': repetitions,
        'lp': lapses,
        'lr': lastReviewedAt?.toIso8601String(),
        'nr': nextReviewAt?.toIso8601String(),
      };

  factory WordSrs.fromJson(Map<String, dynamic> j) => WordSrs(
        easeFactor: (j['ef'] as num?)?.toDouble() ?? 2.5,
        interval: (j['iv'] as num?)?.toInt() ?? 0,
        repetitions: (j['rp'] as num?)?.toInt() ?? 0,
        lapses: (j['lp'] as num?)?.toInt() ?? 0,
        lastReviewedAt: j['lr'] != null ? DateTime.parse(j['lr'] as String) : null,
        nextReviewAt: j['nr'] != null ? DateTime.parse(j['nr'] as String) : null,
      );
}
