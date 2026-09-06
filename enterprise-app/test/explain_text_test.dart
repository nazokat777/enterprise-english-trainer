import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_english/widgets/explain_text.dart';

/// Izohdagi chizma jadvallar PROPORSIONAL shriftda buzilib ko'rinardi:
/// `┌──┬──┐` belgilari bilan chizilgan ustunlar bir-biriga to'g'ri
/// kelmasdi. Butun bazada 9000 dan ortiq chiziq belgisi bor va ular
/// 51 unitning hammasida uchraydi.
void main() {
  const base = TextStyle(fontSize: 14, height: 1.6);

  Future<void> pump(WidgetTester t, String text) => t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExplainText(text, style: base),
            ),
          ),
        ),
      );

  List<TextStyle> stylesOf(WidgetTester t) => t
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.style ?? const TextStyle())
      .toList();

  testWidgets('jadvalsiz matn bitta Text bo\'lib, shrift o\'zgarmaydi',
      (t) async {
    await pump(t, 'Oddiy izoh.\nIkkinchi qator.');

    final styles = stylesOf(t);
    expect(styles, hasLength(1));
    expect(styles.single.fontFamily, isNull);
    expect(styles.single.fontSize, 14);
  });

  testWidgets('jadval qatorlari monospace shriftga o\'tadi', (t) async {
    await pump(
      t,
      "KITOBDAGI JADVAL:\n"
      "  ┌──────────┬──────────┐\n"
      "  │ Name:    │ Diana    │\n"
      "  └──────────┴──────────┘\n"
      "Jadvaldan keyingi izoh.",
    );

    final styles = stylesOf(t);
    // Uch blok: nasr -> jadval -> nasr.
    expect(styles, hasLength(3));
    expect(styles[0].fontFamily, isNull);
    expect(styles[1].fontFamily, 'monospace');
    expect(styles[2].fontFamily, isNull);
  });

  testWidgets('jadval bloki yon tomonga siljiydi — sahifa emas', (t) async {
    await pump(t, '─' * 400);

    // Jadval o'z ichida gorizontal aylanadi, shuning uchun uzun qator
    // ekranga sig'masa ham "overflow" xatosi chiqmaydi.
    expect(find.byType(SingleChildScrollView), findsNWidgets(2));
    expect(hasOverflow(t), isFalse);
  });
}

/// Flutter overflow xatosini bayroq sifatida qaytaradi.
bool hasOverflow(WidgetTester t) =>
    t.takeException().toString().contains('overflowed');
