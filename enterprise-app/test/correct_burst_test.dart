import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_english/widgets/correct_burst.dart';

/// XATO: "To'g'ri ✓" MATN sifatida chizilardi. Sarlavha shrifti
/// Geist da U+2713 belgisi yo'q — shrift tarmoqdan yuklanib bo'lgach
/// o'quvchi "To'g'ri ▯" (bo'sh quti) ko'rardi.
void main() {
  testWidgets('to\'g\'ri javob belgisi ikonka, matn emas', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    showCorrectBurst(ctx);
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    // Hech bir matnda shriftda yo'q belgi bo'lmasin.
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      final s = w.data ?? '';
      expect(s.runes.any((r) => r > 0x2000 && r < 0x2500), isFalse,
          reason: 'shriftda yo\'q belgi: $s');
    }
  });
}
