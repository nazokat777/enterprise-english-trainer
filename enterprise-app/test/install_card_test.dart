import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/widgets/install_card.dart';

/// O'rnatish kartasi: test (VM) muhitida o'rnatish imkoni yo'q -
/// karta chiqmaydi va xato bermaydi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VM da (stub) karta yashirin, xatosiz', (t) async {
    SharedPreferences.setMockInitialValues({'rw_ex': 5});
    app.rewards = RewardEngine();
    await app.rewards.load();
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: InstallCard())));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Telefonga o\'rnating'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
