import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/srs.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/screens/settings_screen.dart';
import 'package:enterprise_english/services/tts.dart';

/// Sozlamalar ekrani ilgari "keyingi fazalarda" degan bo'sh sahifa edi.
/// Shu sababli `buyStreakFreeze` (pulli imkoniyat) va kunlik maqsadni
/// o'zgartirish hech qayerdan chaqirilmasdi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.repo = ContentRepository();
    await Future.wait([app.mastery.load(), app.progress.load(), app.repo.load()]);
  });

  Future<void> pump(WidgetTester t, {Size size = const Size(420, 900)}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())));
    await t.pump();
  }

  testWidgets('telefon o\'lchamida chiqib ketmaydi', (t) async {
    await pump(t, size: const Size(320, 900));
    expect(t.takeException(), isNull);
  });

  testWidgets('kunlik maqsad o\'zgaradi', (t) async {
    await pump(t);
    expect(app.progress.dailyGoal, 20);

    await t.tap(find.text('50 ball'));
    await t.pump();

    expect(app.progress.dailyGoal, 50);
  });

  testWidgets('muzlatgich tanga yetganda sotib olinadi', (t) async {
    await pump(t);
    // Tanga yo'q — tugma o'chirilgan bo'lishi kerak.
    expect(find.textContaining('Tanga yetmaydi'), findsOneWidget);

    await app.progress.addXp(Progress.freezeCost * 10);
    await t.pump();

    final buy = find.textContaining('Sotib olish');
    await t.ensureVisible(buy);
    await t.pump();
    await t.tap(buy);
    await t.pump();

    expect(app.progress.streakFreezeCount, 1);
  });

  testWidgets('jarayonni o\'chirish hammasini tozalaydi', (t) async {
    await app.progress.addXp(120);
    await app.progress.markExerciseResult('ex::cb::7::1', clean: false);
    await app.progress.reviewWord('vocab-be-0001', Quality.unknown);
    expect(app.progress.xp, 120);

    await pump(t);
    final btn = find.widgetWithText(
        OutlinedButton, 'Hammasini o\'chirish');
    // ListView bandlarni KERAK BO'LGANDA quradi — tugma hali
    // qurilmagan bo'lishi mumkin, avval pastga suramiz.
    await t.scrollUntilVisible(btn, 200,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(btn);
    await t.pumpAndSettle();
    // Dialog nima o'chishini aniq sanaydi (kalit va suhbatlar ham).
    expect(find.textContaining('AI kalitlari'), findsWidgets);
    expect(find.text('Hamma natijalar o\'chirilsinmi?'), findsOneWidget);
    await t.tap(find.text('Ha, hammasini o\'chirish'));
    await t.pumpAndSettle();

    expect(app.progress.xp, 0);
    expect(app.progress.needsReviewCount(), 0);
    expect(app.progress.hardCount(), 0);
    expect(app.progress.currentStreak, 0);
  });

  testWidgets('bekor qilinsa hech nima o\'chmaydi', (t) async {
    await app.progress.addXp(120);

    await pump(t);
    final btn = find.widgetWithText(
        OutlinedButton, 'Hammasini o\'chirish');
    // ListView bandlarni KERAK BO'LGANDA quradi — tugma hali
    // qurilmagan bo'lishi mumkin, avval pastga suramiz.
    await t.scrollUntilVisible(btn, 200,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(btn);
    await t.pumpAndSettle();
    await t.tap(find.text('Yo\'q, qoldirish'));
    await t.pumpAndSettle();

    expect(app.progress.xp, 120);
  });

  // `Tts.englishVoiceFound` allaqachon hisoblanardi ("topilmasa UI
  // ogohlantirishi mumkin" deb yozilgan edi), lekin uni HECH BIR ekran
  // ko\'rsatmasdi. Qurilmada inglizcha ovoz bo\'lmasa, talaffuz noto\'g\'ri
  // bo\'lardi va o\'quvchi sababini bilmasdi.
  testWidgets('talaffuz ovozi ko\'rsatiladi', (t) async {
    await pump(t);
    // Sozlamalar guruhlarga bo'lingan: ovoz kartasi "Ko'rinish va ovoz"da.
    await t.scrollUntilVisible(find.text('Inglizcha o\'qish ovozi'), 200,
        scrollable: find.byType(Scrollable).first);
    await t.pump();
    expect(find.text('Inglizcha o\'qish ovozi'), findsOneWidget);
    expect(find.text('Ovozni eshitib ko\'rish'), findsOneWidget);
  });

  testWidgets('inglizcha ovoz topilmasa ogohlantiradi', (t) async {
    Tts.instance.englishVoiceFound.value = false;
    addTearDown(() => Tts.instance.englishVoiceFound.value = true);

    await pump(t);
    await t.scrollUntilVisible(find.text('Inglizcha o\'qish ovozi'), 200,
        scrollable: find.byType(Scrollable).first);
    await t.pump();

    expect(find.textContaining('inglizcha ovoz yo\'q'), findsOneWidget);
  });

  // `Progress.skills` har XP olinganda yozilardi va diskka ham
  // saqlanardi, lekin `skillPercent` ni HECH BIR ekran o\'qimasdi —
  // o\'quvchi qaysi ko\'nikmasi orqada qolayotganini bilolmasdi.
  testWidgets('ko\'nikmalar darajasi ko\'rsatiladi', (t) async {
    await app.progress.addXp(10, skill: Skill.grammar);
    await app.progress.addXp(10, skill: Skill.grammar);

    await pump(t);
    final card = find.text('Ko\'nikmalar');
    await t.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();

    expect(card, findsOneWidget);
    expect(find.text('Grammatika'), findsOneWidget);
    expect(find.text('4%'), findsOneWidget, reason: 'ikki marta +2');
    expect(find.text('Tinglash'), findsOneWidget);
  });

  testWidgets('sarlavha izohli, kartalar guruhlarga bo\'lingan, "XP" yo\'q',
      (t) async {
    await pump(t);
    expect(find.text('Ilova sozlamalari va natijalaringiz shu yerda.'),
        findsOneWidget);
    expect(find.text('O\'QISH MAQSADI'), findsOneWidget);
    // Birinchi ko'rinadigan kartalarda o'yin so'zi (XP) yo'q.
    expect(find.textContaining('XP'), findsNothing);
    expect(find.textContaining('Kuniga necha ball'), findsOneWidget);
    // Xavfli amal alohida guruhda, pastda.
    await t.scrollUntilVisible(find.text('XAVFLI JOY'), 200,
        scrollable: find.byType(Scrollable).first);
    await t.pump();
    expect(find.text('XAVFLI JOY'), findsOneWidget);
    expect(find.text('Hamma natijalarni o\'chirish'), findsOneWidget);
  });

  testWidgets('kunlik maqsad variantlari modeldan olinadi', (t) async {
    await pump(t);
    for (final g in Progress.goalOptions) {
      expect(find.text('$g ball'), findsOneWidget);
    }
  });
}
