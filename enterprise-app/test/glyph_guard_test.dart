import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Ilova shrifti (Geist) va Flutter web'ning CanvasKit chizuvchisi
/// hamma belgini ko'rsata olmaydi. Chizilmagan belgi o'rniga o'quvchi
/// BO'SH QUTI ko'radi — bu ikki marta sodir bo'lgan:
///
///  * "To'g'ri ✓" (U+2713) — Geist da bu belgi yo'q;
///  * "🇬🇧" — bayroq ikkita "hududiy indikator" belgisidan yasaladi,
///    CanvasKit ularni birlashtirmaydi.
///
/// Shuning uchun kod matnlarida bunday belgilar taqiqlanadi. Kerak
/// bo'lsa `Icon` ishlatiladi.
void main() {
  test('kod matnlarida chizilmaydigan belgi yo\'q', () {
    final bad = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Faqat MATN literallari tekshiriladi — izohdagi belgi
        // ekranga chiqmaydi.
        final line = lines[i];
        final literals = RegExp(r"'(?:[^'\\]|\\.)*'")
            .allMatches(line)
            .map((m) => m[0]!)
            .join();
        for (final r in literals.runes) {
          // Bayroqlar: hududiy indikator belgilari.
          final isFlag = r >= 0x1F1E6 && r <= 0x1F1FF;
          // Oddiy emoji (⚡, ❌, ὒ5...) CanvasKit'da
          // yaxshi chiziladi — ular taqiqlanmaydi. Muammo faqat
          // MATN belgilarida: ular ilova shriftidan qidiriladi.
          final isCheck = r == 0x2713 || r == 0x2714 || r == 0x2717;
          final isArrowGlyph = r >= 0x2190 && r <= 0x21FF;
          if (isFlag || isCheck || isArrowGlyph) {
            bad.add('${f.path}:${i + 1}  U+${r.toRadixString(16)}');
          }
        }
      }
    }

    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
