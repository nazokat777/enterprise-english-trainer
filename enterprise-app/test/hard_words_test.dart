import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
