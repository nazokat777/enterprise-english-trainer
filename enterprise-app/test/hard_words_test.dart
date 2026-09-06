import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/srs.dart';
import 'package:enterprise_english/stats.dart';

/// "Qaysi so'z yodlanmayapti" — shu savolga javob beradigan mantiq.
///
/// Ilgari ilova buni bilmasdi: `easeFactor` qiyinlikni ko'rsatardi,
/// lekin u 1.3 da to'xtaydi va to'g'ri javoblar bilan yana ko'tariladi —
/// ya'ni "bu so'zni doim unutaman" degan TARIX yo'qolardi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('WordSrs — unutishlar tarixi', () {
    test('xato javob lapses ni oshiradi', () {
      final s = WordSrs();
      expect(s.lapses, 0);

      s.review(Quality.unknown);
      expect(s.lapses, 1);
      s.review(Quality.unknown);
      expect(s.lapses, 2);
    });

    test('to\'g\'ri javob lapses ni kamaytirmaydi — tarix saqlanadi', () {
      final s = WordSrs();
      s.review(Quality.unknown);
      s.review(Quality.good);
      s.review(Quality.easy);

      expect(s.lapses, 1, reason: 'unutgani tarixda qolsin');
    });

    // XATO: mezon faqat `lapses >= 2` edi va `lapses` kamaymaydi —
    // so'z ro'yxatdan HECH QACHON chiqmasdi. O'quvchi uni qayta mashq
    // qilib o'zlashtirsa ham "qiyin" bo'lib qolaverardi.
    test('o\'zlashtirilgan so\'z ro\'yxatdan chiqadi', () {
      final s = WordSrs();
      s.review(Quality.unknown);
      s.review(Quality.unknown);
      expect(s.isHard, isTrue);

      s.review(Quality.good);
      expect(s.isHard, isTrue, reason: 'bitta to\'g\'ri javob yetarli emas');
      s.review(Quality.good);
      expect(s.isHard, isTrue);
      s.review(Quality.good);

      expect(s.isHard, isFalse, reason: 'uch marta ketma-ket');
      expect(s.lapses, 2, reason: 'tarix saqlanadi');
    });

    test('yana unutilsa so\'z darhol qaytadi', () {
      final s = WordSrs();
      s.review(Quality.unknown);
      s.review(Quality.unknown);
      s.review(Quality.good);
      s.review(Quality.good);
      s.review(Quality.good);
      expect(s.isHard, isFalse);

      s.review(Quality.unknown);

      expect(s.isHard, isTrue);
      expect(s.lapses, 3);
    });

    test('ikki marta unutilgan so\'z QIYIN hisoblanadi', () {
      final s = WordSrs();
      expect(s.isHard, isFalse);

      s.review(Quality.unknown);
      expect(s.isHard, isFalse, reason: 'bir marta xato — hali qiyin emas');

      s.review(Quality.unknown);
      expect(s.isHard, isTrue);
    });

    test('bir marta xato qilingan so\'z qiyin deb belgilanmaydi', () {
      // Bitta "Bilmadim" easeFactor ni 2.5 dan 1.96 ga tushiradi —
      // agar mezon shunga bog'lansa, har qanday BIRINChI xato ham
      // "qiyin" bo'lib qolardi.
      final s = WordSrs()..review(Quality.unknown);
      expect(s.easeFactor, lessThan(2.0));
      expect(s.isHard, isFalse);
    });

    test('ko\'p unutilgan so\'z qiyinroq deb baholanadi', () {
      final a = WordSrs()..review(Quality.unknown);
      final b = WordSrs()
        ..review(Quality.unknown)
        ..review(Quality.unknown)
        ..review(Quality.unknown);
      expect(b.difficulty, greaterThan(a.difficulty));
    });

    test('lapses saqlanadi va qayta o\'qiladi', () {
      final s = WordSrs()
        ..review(Quality.unknown)
        ..review(Quality.unknown);
      final back = WordSrs.fromJson(s.toJson());
      expect(back.lapses, 2);
      expect(back.isHard, isTrue);
    });

    test('eski saqlangan holatda lapses bo\'lmasa — 0', () {
      // Ilova yangilanganda eski ma'lumot yiqitmasin.
      final back = WordSrs.fromJson({'ef': 2.1, 'iv': 3, 'rp': 1});
      expect(back.lapses, 0);
    });
  });

  group('Progress — qiyin so\'zlar ro\'yxati', () {
    test('faqat qiyin so\'zlar, eng qiyinidan boshlab', () async {
      final p = Progress();
      await p.load();

      // "oson" — bir marta ham xato emas.
      p.srsFor('easy').review(Quality.good);
      // "orta" — ikki marta unutilgan.
      p.srsFor('orta')
        ..review(Quality.unknown)
        ..review(Quality.unknown);
      // "eng-qiyin" — to'rt marta.
      final hard = p.srsFor('eng-qiyin');
      for (var i = 0; i < 4; i++) {
        hard.review(Quality.unknown);
      }

      final ids = p.hardWordIds();
      expect(ids, ['eng-qiyin', 'orta']);
      expect(p.hardCount(), 2);
    });

    test('boshqa darajaning so\'zlari aralashmaydi', () async {
      final p = Progress();
      await p.load();

      p.srsFor('beginner-soz')
        ..review(Quality.unknown)
        ..review(Quality.unknown);

      await p.setLevel('elementary');
      expect(p.hardWordIds(), isEmpty,
          reason: 'daraja almashsa ro\'yxat ham almashsin');

      await p.setLevel('beginner');
      expect(p.hardWordIds(), ['beginner-soz']);
    });

    test('ro\'yxat cheklanadi', () async {
      final p = Progress();
      await p.load();
      for (var i = 0; i < 60; i++) {
        p.srsFor('w$i')
          ..review(Quality.unknown)
          ..review(Quality.unknown);
      }
      expect(p.hardWordIds(limit: 10).length, 10);
      expect(p.hardCount(), 60);
    });
  });

  group('Progress — mashq takrorlashni talab qiladimi', () {
    test('xatosiz tugatilgan mashq o\'zlashtirilgan hisoblanadi', () async {
      final p = Progress();
      await p.load();

      await p.markExerciseResult('ex::cb::7::5', clean: true);
      expect(p.isDone('ex::cb::7::5'), isTrue);
      expect(p.needsRepeat('ex::cb::7::5'), isFalse);
    });

    test('xato bilan tugatilgan mashq TAKRORLAShDA qoladi', () async {
      // Mashqni bir marta ochib chiqish yetarli emas: xato qilingan
      // bo\'lsa, ro\'yxatda yashil belgi emas, "takrorlash" turadi.
      final p = Progress();
      await p.load();

      await p.markExerciseResult('ex::cb::7::5', clean: false);
      expect(p.isDone('ex::cb::7::5'), isTrue);
      expect(p.needsRepeat('ex::cb::7::5'), isTrue);
    });

    test('keyin xatosiz o\'tilsa — ro\'yxatdan chiqadi', () async {
      final p = Progress();
      await p.load();

      await p.markExerciseResult('ex::cb::7::5', clean: false);
      await p.markExerciseResult('ex::cb::7::5', clean: true);
      expect(p.needsRepeat('ex::cb::7::5'), isFalse);
    });

    test('holat DISKKA yoziladi', () async {
      final p = Progress();
      await p.load();
      await p.markExerciseResult('ex::cb::7::5', clean: false);

      final p2 = Progress();
      await p2.load();
      expect(p2.needsRepeat('ex::cb::7::5'), isTrue,
          reason: 'ilova qayta ochilganda ham eslab qolsin');
    });
  });

  group('normalizeWord — kitob javobini lug\'at bilan bog\'lash', () {
    test('artikl, bosh harf va tinish belgisi hisobga olinmaydi', () {
      expect(normalizeWord('The Sun.'), 'sun');
      expect(normalizeWord('a dog'), 'dog');
      expect(normalizeWord('to run'), 'run');
      expect(normalizeWord('  Book!  '), 'book');
    });
  });

  group('Progress — kitob mashqidagi xato', () {
    test('recordMiss lapses ni oshiradi, JADVALNI buzmaydi', () async {
      // Kitob mashqidagi xato lug'at takrorlash jadvalini
      // (interval, keyingi sana) o'zgartirmasligi kerak.
      final p = Progress();
      await p.load();

      p.srsFor('w1').review(Quality.good); // jadval belgilandi
      final interval = p.srsFor('w1').interval;
      final next = p.srsFor('w1').nextReviewAt;

      await p.recordMiss('w1');

      expect(p.srsFor('w1').lapses, 1);
      expect(p.srsFor('w1').interval, interval, reason: 'jadval tegilmasin');
      expect(p.srsFor('w1').nextReviewAt, next);
    });

    test('ikki marta xato qilingan so\'z qiyinlar ro\'yxatiga tushadi',
        () async {
      final p = Progress();
      await p.load();

      await p.recordMiss('w1');
      expect(p.hardWordIds(), isEmpty);

      await p.recordMiss('w1');
      expect(p.hardWordIds(), ['w1']);
    });
  });

  group('Progress — o\'zlashtirilgan so\'z qayta unutilsa', () {
    // XATO: `recordMiss` faqat `lapses` ni oshirardi. Qayta
    // o\'zlashtirilgan so\'z (repetitions >= 3) kitob mashqida unutilsa
    // ham "Qiyin so\'zlar" ro\'yxatiga QAYTMASDI.
    test('kitob mashqidagi xato so\'zni ro\'yxatga qaytaradi', () async {
      final p = Progress();
      await p.load();

      final s = p.srsFor('w1');
      s.review(Quality.unknown);
      s.review(Quality.unknown);
      s.review(Quality.good);
      s.review(Quality.good);
      s.review(Quality.good);
      expect(s.isHard, isFalse, reason: 'o\'zlashtirildi');

      await p.recordMiss('w1');

      expect(p.srsFor('w1').isHard, isTrue);
      expect(p.hardWordIds(), ['w1']);
    });

    test('jadval baribir buzilmaydi', () async {
      final p = Progress();
      await p.load();
      final s = p.srsFor('w1');
      s.review(Quality.good);
      final iv = s.interval;
      final next = s.nextReviewAt;

      await p.recordMiss('w1');

      expect(p.srsFor('w1').interval, iv);
      expect(p.srsFor('w1').nextReviewAt, next);
    });
  });

  group('Progress — takrorlash ro\'yxati soni', () {
    test('faqat joriy darajaning mashqlari sanaladi', () async {
      final p = Progress();
      await p.load();

      await p.markExerciseResult('ex::cb::7::5', clean: false);
      await p.markExerciseResult('ex::cb::7::6', clean: false);
      await p.markExerciseResult('ex::cb::7::7', clean: true);
      expect(p.needsReviewCount(), 2);

      await p.setLevel('elementary');
      expect(p.needsReviewCount(), 0);

      await p.setLevel('beginner');
      expect(p.needsReviewCount(), 2);
    });

    test('xatosiz qayta o\'tilsa son kamayadi', () async {
      final p = Progress();
      await p.load();

      await p.markExerciseResult('ex::cb::7::5', clean: false);
      expect(p.needsReviewCount(), 1);

      await p.markExerciseResult('ex::cb::7::5', clean: true);
      expect(p.needsReviewCount(), 0);
    });
  });
}
