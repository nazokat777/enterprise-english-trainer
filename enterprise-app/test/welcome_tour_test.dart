import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/theme.dart';
import 'package:enterprise_english/widgets/welcome_tour.dart';

/// Xush kelibsiz turi: 3 sahifa, bir marta, o'tkazib yuborish mumkin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('3 sahifa, Keyingisi -> Boshlash, tugagach belgilanadi',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    expect(await WelcomeTour.isDone(), isFalse);
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: SizedBox());
      }),
    ));
    final fut = WelcomeTour.showIfNeeded(ctx);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Enterprise kitobi'), findsOneWidget);
    expect(find.text('Keyingisi'), findsOneWidget);
    await t.tap(find.text('Keyingisi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Xotira ilmi'), findsOneWidget);
    await t.tap(find.text('Keyingisi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Boshlash'), findsOneWidget);
    await t.tap(find.text('Boshlash'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await fut;
    expect(await WelcomeTour.isDone(), isTrue);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Boshlash'), findsNothing);
  });

  testWidgets('bir marta ko\'rilgan bo\'lsa qayta chiqmaydi', (t) async {
    SharedPreferences.setMockInitialValues({'welcome_tour_done': true});
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: SizedBox());
      }),
    ));
    await WelcomeTour.showIfNeeded(ctx);
    await t.pump();
    expect(find.text('Keyingisi'), findsNothing);
  });
}
