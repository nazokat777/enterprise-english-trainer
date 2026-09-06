import 'package:flutter/material.dart';

/// Izoh matnini ko'rsatadi va ichidagi CHIZMA JADVALLARNI buzilmasdan
/// chiqaradi.
///
/// MUAMMO: kontentdagi izohlarning ko'pida kitobning jadvali `┌─┬─┐` kabi
/// belgilar bilan chizilgan (butun bazada 9000 dan ortiq chiziq belgisi,
/// 51 unitning HAMMASIDA uchraydi). Ilovaning asosiy shrifti — Geist/Inter,
/// ya'ni PROPORSIONAL: unda har harfning kengligi har xil, shuning uchun
/// ustunlar bir-biriga to'g'ri kelmaydi va jadval buzilib ko'rinadi.
///
/// YECHIM: matn qatorlarga bo'linadi. Chizma belgisi BOR qatorlar
/// monospace (teng kenglikdagi) shriftda, qolgan matn odatdagidek
/// chiqadi. Shunda nasr o'qishga qulay qoladi, jadval esa tekis turadi.
///
/// Jadval qatorlari yon tomonga sig'masa — o'sha blokning O'ZI
/// gorizontal siljiydi, butun sahifa emas.
class ExplainText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const ExplainText(this.text, {super.key, required this.style});

  /// Kitob jadvallarini chizishda ishlatiladigan belgilar.
  static const String _boxChars = '─│┌┐└┘├┤┬┴┼═║╔╗╚╝╠╣╦╩╬';

  static bool _isTableLine(String line) {
    for (final c in _boxChars.codeUnits) {
      if (line.codeUnits.contains(c)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    if (!lines.any(_isTableLine)) return Text(text, style: style);

    // Ketma-ket kelgan bir xil turdagi qatorlarni bitta blokka yig'amiz.
    final blocks = <({bool table, List<String> lines})>[];
    for (final line in lines) {
      final t = _isTableLine(line);
      if (blocks.isNotEmpty && blocks.last.table == t) {
        blocks.last.lines.add(line);
      } else {
        blocks.add((table: t, lines: [line]));
      }
    }

    final mono = style.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier New', 'DejaVu Sans Mono'],
      fontSize: (style.fontSize ?? 14) - 1.5,
      height: 1.35,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in blocks)
          if (b.table)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(b.lines.join('\n'), style: mono, softWrap: false),
            )
          else
            Text(b.lines.join('\n'), style: style),
      ],
    );
  }
}
