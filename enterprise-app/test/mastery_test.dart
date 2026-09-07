import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/mastery.dart';

/// O'ZLAShTIRISh mezoni.
///
/// "Bir marta to'g'ri javob" yetarli EMAS: o'quvchi variantlardan
/// tanlashni yodlab olishi mumkin, lekin so'zni o'zi ayta olmasligi
/// mumkin. Shuning uchun band faqat ikki XIL shaklda, ulardan biri
/// ishlab chiqarish bo'lganda o'zlashtirilgan hisoblanadi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ItemMastery — mezon', () {
    test('yangi band hech qanday holatda emas', () {
      final m = ItemMastery();
      expect(m.isNew, isTrue);
      expect(m.isStrong, isFalse);
      expect(m.isWeak, isFalse);
    });

    test('bitta shakldagi to\'g\'ri javob YETARLI EMAS', () async {
      final s = MasteryStore();
      await s.load();

      await s.record('t::x::0', AskFormat.choice, ok: true);
      await s.record('t::x::0', AskFormat.choice, ok: true);

      expect(s.of('t::x::0').correct, 2);
      expect(s.of('t::x::0').isStrong, isFalse,
          reason: 'savol ko\'rinishini yodlab olish mumkin');
    });

    test('ikki shakl, lekin ishlab chiqarishsiz — hali emas', () async {
      final s = MasteryStore();
      await s.load();

      await s.record('t::x::0', AskFormat.choice, ok: true);
      await s.record('t::x::0', AskFormat.match, ok: true);

      expect(s.of('t::x::0').isStrong, isFalse,
          reason: 'ikkalasi ham TANISh — o\'zi ayta olishi tekshirilmadi');
    });

    test('tanish + ishlab chiqarish — O\'ZLAShTIRILDI', () async {
      final s = MasteryStore();
      await s.load();

      await s.record('t::x::0', AskFormat.choice, ok: true);
      await s.record('t::x::0', AskFormat.build, ok: true);

      expect(s.of('t::x::0').isStrong, isTrue);
    });

    test('xato o\'sha shaklni bekor qiladi', () async {
      final s = MasteryStore();
      await s.load();

      await s.record('t::x::0', AskFormat.choice, ok: true);
      await s.record('t::x::0', AskFormat.build, ok: true);
      expect(s.of('t::x::0').isStrong, isTrue);

      await s.record('t::x::0', AskFormat.build, ok: false);

      expect(s.of('t::x::0').isStrong, isFalse,
          reason: 'unutilgan shakl qayta so\'ralishi kerak');
      expect(s.of('t::x::0').lapses, 1);
    });

    test('ikki marta xato — ZAIF', () async {
      final s = MasteryStore();
      await s.load();
      await s.record('t::x::0', AskFormat.choice, ok: false);
      expect(s.of('t::x::0').isWeak, isFalse, reason: 'bir xato — oddiy hol');
      await s.record('t::x::0', AskFormat.choice, ok: false);
      expect(s.of('t::x::0').isWeak, isTrue);
    });
  });

  group('MasteryStore — to\'plam bo\'yicha', () {
    Future<MasteryStore> ready() async {
      final s = MasteryStore();
      await s.load();
      return s;
    }

    Future<void> master(MasteryStore s, String id) async {
      await s.record(id, AskFormat.choice, ok: true);
      await s.record(id, AskFormat.produce, ok: true);
    }

    test('100% mezoni', () async {
      final s = await ready();
      const ids = ['a', 'b', 'c'];

      expect(s.allStrong(ids), isFalse);
      expect(s.ratio(ids), 0);

      await master(s, 'a');
      await master(s, 'b');
      expect(s.ratio(ids), closeTo(2 / 3, 0.001));
      expect(s.allStrong(ids), isFalse);

      await master(s, 'c');
      expect(s.allStrong(ids), isTrue);
      expect(s.ratio(ids), 1);
    });

    test('bo\'sh to\'plam 100% hisoblanadi', () async {
      final s = await ready();
      expect(s.allStrong(const []), isTrue);
      expect(s.ratio(const []), 1);
    });

    test('eng zaif bandlar birinchi keladi', () async {
      final s = await ready();
      await s.record('kop-xato', AskFormat.choice, ok: false);
      await s.record('kop-xato', AskFormat.choice, ok: false);
      await s.record('kop-xato', AskFormat.choice, ok: false);
      await s.record('bir-xato', AskFormat.choice, ok: false);
      await master(s, 'bilaman');

      final weak = s.weakest(['kop-xato', 'bir-xato', 'bilaman', 'yangi']);

      expect(weak.first, 'kop-xato');
      expect(weak.contains('bilaman'), isFalse,
          reason: 'o\'zlashtirilgan band ro\'yxatda bo\'lmasin');
      expect(weak.contains('yangi'), isTrue);
    });

    test('holat diskka yoziladi va qayta o\'qiladi', () async {
      final s = await ready();
      await master(s, 'a');
      await s.record('b', AskFormat.choice, ok: false);

      final again = MasteryStore();
      await again.load();

      expect(again.of('a').isStrong, isTrue);
      expect(again.of('b').lapses, 1);
    });

    test('darajalar aralashmaydi', () async {
      final s = await ready();
      await master(s, 'a');
      expect(s.of('a').isStrong, isTrue);

      s.setLevel('elementary');
      expect(s.of('a').isStrong, isFalse,
          reason: 'boshqa kitobning bandi — alohida hisob');

      s.setLevel('beginner');
      expect(s.of('a').isStrong, isTrue);
    });
  });


  group('qisman baho — halqa uchun', () {
    // `isStrong` faqat "tugadi"ni biladi. Halqa faqat shunga qarasa,
    // o\'quvchi olti marta to\'g\'ri javob berib ham 0% ni ko\'radi.
    test('har o\'tilgan shakl halqani siljitadi', () async {
      final s = MasteryStore();
      await s.load();

      expect(s.of('a').score, 0);

      await s.record('a', AskFormat.choice, ok: true);
      expect(s.of('a').score, greaterThan(0));
      expect(s.of('a').score, lessThan(1), reason: 'hali tugamagan');

      await s.record('a', AskFormat.build, ok: true);
      expect(s.of('a').score, 1, reason: 'o\'zlashtirildi');
    });

    test('to\'plam bo\'yicha o\'rtacha', () async {
      final s = MasteryStore();
      await s.load();
      await s.record('a', AskFormat.choice, ok: true);
      await s.record('a', AskFormat.build, ok: true);

      final v = s.progressScore(['a', 'b']);
      expect(v, greaterThan(0.4));
      expect(v, lessThan(1));
      expect(s.ratio(['a', 'b']), 0.5,
          reason: 'ratio faqat TUGAGANni sanaydi — o\'zgarmaydi');
    });
  });
}
