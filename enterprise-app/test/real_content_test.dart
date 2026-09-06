import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';

/// HAQIQIY asset'lar ustidan tekshiruv.
///
/// Boshqa testlar kichik namunaviy JSON bilan ishlaydi. Bu yerda esa
/// ilova yuklaydigan fayllarning O'ZI o'qiladi: bitta noto'g'ri unit
/// ilovani ochilishidayoq yiqitishi mumkin, va buni faqat shu daraja
/// tekshiruv ushlaydi.
const _base = 'assets/content';

Map<String, dynamic> _json(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('barcha Enterprise unitlari muammosiz o\'qiladi', () {
    final dir = Directory('$_base/enterprise1');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.split(RegExp(r'[\\/]')).last.startsWith('unit_'))
        .toList();

    expect(files, isNotEmpty, reason: 'unit fayllari topilmadi');

    var exercises = 0;
    var tasks = 0;
    for (final f in files) {
      final u = BookUnit.fromJson(_json(f.path));
      expect(u.sections, isNotEmpty, reason: '${f.path}: bo\'lim yo\'q');

      for (final s in u.sections) {
        for (final e in s.exercises) {
          exercises++;
          tasks += e.tasks.length;
          expect(e.tasks, isNotEmpty,
              reason: '${u.displayLabel} ${e.ref}: band yo\'q');

          for (final t in e.tasks) {
            switch (e.kind) {
              case ExKind.choice:
                expect(t.options.length, greaterThanOrEqualTo(2),
                    reason: '${u.displayLabel} ${e.ref}: variant yetarli emas');
                expect(t.options.map((o) => o.toLowerCase()),
                    contains(t.answer.toLowerCase()),
                    reason: '${u.displayLabel} ${e.ref}: javob variantlar ichida yo\'q');
              case ExKind.match:
                expect(t.left, isNotEmpty);
                expect(t.right, isNotEmpty);
              case ExKind.text:
                expect(t.answer.trim(), isNotEmpty,
                    reason: '${u.displayLabel} ${e.ref}: javob bo\'sh');
              case ExKind.study:
                expect(t.en.trim(), isNotEmpty,
                    reason: '${u.displayLabel} ${e.ref}: o\'qish matni bo\'sh');
            }
          }
        }
      }
    }
    expect(exercises, greaterThan(1000));
    expect(tasks, greaterThan(10000));
  });

  test('moslash o\'yinida o\'ng tomon takrorlanmaydi', () {
    // Bir xil o'ng tomon ikki marta bo'lsa, o'yinni YEChIB BO'LMAYDI:
    // o'quvchi ikkita bir xil yozuvdan qaysinisini bosishni bilolmaydi.
    final dir = Directory('$_base/enterprise1');
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.contains('unit_')) continue;
      final u = BookUnit.fromJson(_json(f.path));
      for (final s in u.sections) {
        for (final e in s.exercises) {
          if (e.kind != ExKind.match) continue;
          final rights = e.tasks.map((t) => t.right).toList();
          expect(rights.toSet().length, rights.length,
              reason: '${u.displayLabel} ${e.ref}: o\'ng tomon takrorlangan');
        }
      }
    }
  });

  test('lug\'at paketlari haqiqiy so\'zlarga ishora qiladi', () {
    final words = (_json('$_base/beginner/words.json')['words'] as List)
        .map((e) => Word.fromJson(e as Map<String, dynamic>))
        .toList();
    final ids = words.map((w) => w.id).toSet();
    expect(ids.length, words.length, reason: 'takror id bor');

    final units = (_json('$_base/beginner/units.json')['units'] as List)
        .map((e) => Unit.fromJson(e as Map<String, dynamic>))
        .toList();

    for (final u in units) {
      for (final c in u.components) {
        for (final p in c.packs) {
          expect(p.wordIds, isNotEmpty, reason: '${u.code} ${p.name}: bo\'sh');
          for (final id in p.wordIds) {
            expect(ids, contains(id),
                reason: '${u.code} ${p.name}: "$id" so\'zi yo\'q');
          }
        }
      }
    }
  });

  test('har bir so\'zning tarjimasi bor', () {
    final words = (_json('$_base/beginner/words.json')['words'] as List)
        .map((e) => Word.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final w in words) {
      expect(w.en.trim(), isNotEmpty);
      expect(w.uz.trim(), isNotEmpty, reason: '${w.en}: tarjima yo\'q');
    }
  });
}
