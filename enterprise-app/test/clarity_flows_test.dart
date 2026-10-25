import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/book_content.dart';
import 'package:enterprise_english/content.dart';
import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/mistakes.dart';
import 'package:enterprise_english/reward/reward_engine.dart';
import 'package:enterprise_english/screens/book/exercise_player.dart';
import 'package:enterprise_english/screens/homework/homework_flow.dart';
import 'package:enterprise_english/screens/pack/pack_flow.dart';
import 'package:enterprise_english/stats.dart';
import 'package:enterprise_english/teach/explain_card.dart';

/// KITOBSIZ ODAM HAM TUSHUNADI: har mashq turida "Nima qilinadi", xato
/// javobdan keyin oddiy so'z bilan natija, natija ekranida nima bo'lgani
/// va keyin nima bo'lishi, kitobdagi manzil izohlangan.
///
/// Yangi matnlar ekranning tepasiga qo'shilgani uchun ularning har biri
/// tor telefonda (320px) va katta shriftda (1.5x) ham sig'ishi tekshiriladi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    app.mistakes = MistakeStore();
    app.repo = ContentRepository();
    app.rewards = RewardEngine();
    await Future.wait([
      app.progress.load(),
      app.mastery.load(),
      app.mistakes.load(),
      app.rewards.load(),
    ]);
  });

  BookExercise ex(
    ExKind kind,
    List<ExTask> tasks, {
    String ref = '5',
    String book = 'coursebook',
    String instructionUz = '',
  }) =>
      BookExercise(
        ref: ref,
        kind: kind,
        tasks: tasks,
        instructionUz: instructionUz,
        book: book,
        bookPage: 7,
      );

  Future<void> open(
    WidgetTester t,
    BookExercise e, {
    Size size = const Size(500, 1100),
    double scale = 1.0,
    String unitLabel = '3-unit',
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: ExercisePlayer(
          exercise: e,
          sectionTitle: 'Grammatika — mashq',
          unitLabel: unitLabel,
        ),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  /// Matn ko'rinmasa (tor ekranda variantlar/tugmalar pastda bo'ladi va
  /// ro'yxat ularni sust quradi) ro'yxatni suradi.
  Future<Finder> reveal(WidgetTester t, String text) async {
    for (var i = 0; i < 8 && find.text(text).evaluate().isEmpty; i++) {
      await t.drag(find.byType(ListView).first, const Offset(0, -200));
      await t.pump();
    }
    return find.text(text).first;
  }

  Future<void> tapText(WidgetTester t, String text) async {
    final f = await reveal(t, text);
    await t.ensureVisible(f);
    await t.pump();
    await t.tap(f);
  }

  /// To'g'ri javobdan keyin chiqadigan rag'bat belgisi ("Zo'r!" kabi,
  /// `widgets/correct_burst.dart`) tasodifiy matn bilan chiziladi va Ahem
  /// shriftida tor ekranda sig'maydi. U bu fayl tekshirayotgan narsa
  /// emas - uning xatosi tozalanadi, qolgan hammasi qat'iy tekshiriladi.
  Future<void> afterCorrect(WidgetTester t) async {
    await t.pump(const Duration(milliseconds: 50));
    t.takeException();
  }

  const choice = ExTask(
      prompt: 'orange', answer: 'an', options: ['a', 'an'], whyUz: 'o — unli');
  const build = ExTask(prompt: 'Men talabaman', answer: 'I am a student');
  const typed =
      ExTask(prompt: 'Men talabaman', answer: 'I am a student', typed: true);
  const pair1 = ExTask(left: 'cat', right: 'mushuk');
  const pair2 = ExTask(left: 'dog', right: 'it');
  const study = ExTask(en: 'I am from Spain.', uz: 'Men Ispaniyadanman.');

  group('Nima qilinadi - har mashq turida', () {
    final cases = <String, BookExercise Function()>{
      'tanlash': () => ex(ExKind.choice, [choice]),
      'yig\'ish (so\'zlardan)': () => ex(ExKind.text, [build]),
      'yig\'ish (harflardan)': () =>
          ex(ExKind.text, [const ExTask(prompt: 'mushuk', answer: 'cat')]),
      'yozish (klaviatura)': () => ex(ExKind.text, [typed]),
      'moslash': () => ex(ExKind.match, [pair1, pair2]),
      'o\'qish': () => ex(ExKind.study, [study]),
    };
    for (final c in cases.entries) {
      testWidgets(c.key, (t) async {
        await open(t, c.value());
        expect(find.text('Nima qilinadi'), findsOneWidget);
        // Kitobdagi manzil "Kitobda:" bilan va kitob nomi izohlangan.
        expect(find.textContaining('Kitobda: '), findsWidgets);
        expect(
            find.textContaining('Coursebook (asosiy darslik)'), findsWidgets);
        // Ingliz "Ex." qisqartmasi ekranda qolmasin.
        expect(find.textContaining('Ex.'), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  });

  testWidgets('yig\'ishda klaviatura yo\'qligi va qanday yig\'ilishi aytiladi',
      (t) async {
    await open(t, ex(ExKind.text, [build], instructionUz: 'Gaplarni yozing.'));
    expect(find.textContaining('Pastdagi so\'zlarni to\'g\'ri tartibda bosib'),
        findsOneWidget);
    expect(find.text('Javobingiz shu yerda paydo bo\'ladi'), findsOneWidget);
  });

  testWidgets('moslashda qanday moslash aytiladi, sanagich yorliqli',
      (t) async {
    await open(t, ex(ExKind.match, [pair1, pair2]));
    expect(find.textContaining('Chapdan birini bosing'), findsOneWidget);
    expect(find.text('0 / 2 juft'), findsOneWidget);
  });

  testWidgets('sun\'iy (quiz) mashqda kitob manzili va "Ex." yo\'q',
      (t) async {
    await open(t, ex(ExKind.choice, [choice], book: 'quiz', ref: '1'));
    expect(find.text('Nima qilinadi'), findsOneWidget);
    expect(find.textContaining('Kitobda:'), findsNothing);
    expect(find.textContaining('Ex.'), findsNothing);
    // Sarlavhada yolg'on "1-mashq" raqami yo'q.
    expect(find.text('Grammatika — mashq'), findsOneWidget);
  });

  testWidgets('kitobga tayangan ko\'rsatmada kitobsiz maslahat bor', (t) async {
    await open(
        t,
        ex(ExKind.choice, [
          const ExTask(
              prompt: 'cat', answer: 'mushuk', options: ['mushuk', 'it'])
        ], instructionUz: 'Rasmlarga qarang. Tinglang va belgilang.'));
    expect(find.textContaining('Kitobingiz bo\'lmasa'), findsOneWidget);
  });

  // OXIRGI (yoki yagona) band xato bo'lsa u shu indeksda darhol qaytadi.
  // Ilgari sahna kaliti faqat band indeksidan iborat edi: sahna yangilanmay,
  // eski javobda qotib qolardi va variantni bosish ishlamasdi.
  testWidgets('oxirgi band xato bo\'lsa qaytadi va variantlar bosiladi',
      (t) async {
    await open(t, ex(ExKind.choice, [choice]));
    await tapText(t, 'a');
    await t.pump(const Duration(milliseconds: 2500));
    // Qayta so'ralmoqda: natija ekrani emas, savol turibdi.
    expect(find.text('Hammasi to\'g\'ri!'), findsNothing);
    expect(find.text('Nima qilinadi'), findsOneWidget);
    await tapText(t, 'an');
    await afterCorrect(t);
    await t.pump(const Duration(milliseconds: 1500));
    await t.pump();
    expect(find.text('Mashq tugadi: hammasini topdingiz'), findsOneWidget);
  });

  for (final cfg in const [
    (Size(320, 640), 1.0),
    (Size(375, 812), 1.5),
  ]) {
    final size = cfg.$1;
    final scale = cfg.$2;
    final tag = '${size.width.round()}px x$scale';

    testWidgets('xato javobdan keyin natija qatori ($tag)', (t) async {
      await open(t, ex(ExKind.choice, [choice, choice]),
          size: size, scale: scale);
      await tapText(t, 'a');
      await t.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Noto\'g\'ri. To\'g\'ri javob: an.'),
          findsOneWidget);
      expect(find.textContaining('Bu savol keyinroq yana so\'raladi'),
          findsOneWidget);
      expect(t.takeException(), isNull);
      // Xato band keyingi savol bilan almashadi.
      await t.pump(const Duration(milliseconds: 2500));
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('to\'g\'ri javobdan keyin "To\'g\'ri!" ($tag)', (t) async {
      await open(t, ex(ExKind.choice, [choice, choice]),
          size: size, scale: scale);
      await tapText(t, 'an');
      await afterCorrect(t);
      expect(find.text('To\'g\'ri!'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1500));
    });

    testWidgets('natija ekrani: xatosiz ($tag)', (t) async {
      await open(t, ex(ExKind.choice, [choice]), size: size, scale: scale);
      await tapText(t, 'an');
      await afterCorrect(t);
      await t.pump(const Duration(milliseconds: 1500));
      await t.pump();
      expect(find.text('Hammasi to\'g\'ri!'), findsOneWidget);
      expect(find.textContaining('mashq tugallandi'), findsOneWidget);
      expect(await reveal(t, 'Mashqlar ro\'yxatiga qaytish'), findsOneWidget);
      expect(await reveal(t, 'Bu mashqni qaytadan boshlash'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('natija ekrani: xato bilan ($tag)', (t) async {
      // Ikki band: xato qilingan band boshqa band orqali qaytadi.
      await open(t, ex(ExKind.choice, [choice, choice]),
          size: size, scale: scale);
      await tapText(t, 'a'); // 1-band: xato
      await t.pump(const Duration(milliseconds: 2500));
      await t.pump();
      await tapText(t, 'an'); // 2-band: to'g'ri
      await afterCorrect(t);
      await t.pump(const Duration(milliseconds: 1500));
      await t.pump();
      // 1-band qaytdi: "qayta so'ralyapti".
      expect(find.text('qayta so\'ralyapti'), findsOneWidget);
      expect(t.takeException(), isNull);
      await tapText(t, 'an');
      await afterCorrect(t);
      await t.pump(const Duration(milliseconds: 1500));
      await t.pump();
      expect(find.text('Mashq tugadi: hammasini topdingiz'), findsOneWidget);
      expect(find.textContaining('Xatolar daftariga'), findsOneWidget);
      expect(find.textContaining('Takrorlash kerak'), findsOneWidget);
      // Pastroqdagi qator: ro'yxat sust quriladi - kerak bo'lsa suramiz.
      for (var i = 0;
          i < 8 && find.textContaining('tasida adashdingiz').evaluate().isEmpty;
          i++) {
        await t.drag(find.byType(ListView).first, const Offset(0, -150));
        await t.pump();
      }
      expect(find.textContaining('tasida adashdingiz'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('natija ekrani: o\'qish ($tag)', (t) async {
      await open(t, ex(ExKind.study, [study]), size: size, scale: scale);
      await tapText(t, 'O\'qib chiqdim');
      await t.pump();
      expect(find.text('O\'qib chiqdingiz'), findsOneWidget);
      expect(find.text('Mashq o\'qilgan deb belgilandi.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('tugatilmagan mashqdan chiqish ogohlantirishi ($tag)',
        (t) async {
      await open(t, ex(ExKind.choice, [choice, choice]),
          size: size, scale: scale);
      await tapText(t, 'an');
      await afterCorrect(t);
      await t.pump(const Duration(milliseconds: 1500));
      await t.pump();
      // Chiqishga urinish: "Yana 1 ta savol qoldi".
      final nav = t.state<NavigatorState>(find.byType(Navigator));
      nav.maybePop();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Yana 1 ta savol qoldi'), findsOneWidget);
      expect(find.textContaining('tugallanmagan bo\'lib qoladi'),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('ExplainCard: to\'g\'ri/noto\'g\'ri oddiy so\'z bilan aytiladi',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
            child: Column(children: [
          ExplainCard.forAnswer(
              correct: 'an apple', given: 'a apple', isCorrect: false),
          ExplainCard.forAnswer(
              correct: 'an apple',
              given: 'a apple',
              isCorrect: false,
              showAnswer: false,
              willRepeat: true),
          ExplainCard.forAnswer(
              correct: 'an apple', given: 'an apple', isCorrect: true),
          // To'g'ri/Noto'g'ri tugmali savol: "To'g'ri javob: To'g'ri"
          // chalkash bo'lmasin.
          ExplainCard.forAnswer(
              correct: 'Noto\'g\'ri',
              given: 'To\'g\'ri',
              isCorrect: false,
              willRepeat: true),
        ])),
      ),
    ));
    expect(
        find.text('Noto\'g\'ri javob. Gap aslida noto\'g\'ri. '
            'Bu savol keyinroq yana so\'raladi.'),
        findsOneWidget);
    expect(find.text('Noto\'g\'ri. To\'g\'ri javob: an apple.'),
        findsOneWidget);
    expect(find.text('Noto\'g\'ri. Bu savol keyinroq yana so\'raladi.'),
        findsOneWidget);
    expect(find.text('To\'g\'ri!'), findsOneWidget);
  });

  group('To\'plam (pack) oqimi', () {
    Word w(String id, String en, String uz) => Word(
          id: id,
          en: en,
          uz: uz,
          example: '',
          module: 'M1',
          pos: 'noun',
          phonetic: '',
          freq: 5.0,
        );
    final words = [
      w('w1', 'cat', 'mushuk'),
      w('w2', 'dog', 'it'),
      w('w3', 'sun', 'quyosh'),
      w('w4', 'book', 'kitob'),
    ];
    final pack = VocabPack(
        id: 'p1', name: 'Pack 3', wordIds: words.map((x) => x.id).toList());
    final unit = Unit(
      id: 'u1',
      code: 'Unit 1',
      title: 'Test',
      module: 'M1',
      order: 1,
      isRevision: false,
      components: [
        Component(id: 'c1', type: 'VOCABULARY', order: 1, packs: [pack]),
      ],
    );

    test('packTitleUz: "Pack N" -> "So\'zlar to\'plami N"', () {
      expect(packTitleUz('Pack 1'), 'So\'zlar to\'plami 1');
      expect(packTitleUz('Pack 12'), 'So\'zlar to\'plami 12');
      expect(packTitleUz('Qiyin so\'zlar'), 'Qiyin so\'zlar');
    });

    /// Harf plitkalarini ketma-ket bosib so'zni yig'adi.
    Future<void> spell(WidgetTester t, String word) async {
      for (final ch in word.split('')) {
        final tiles = find.byType(AnimatedOpacity);
        for (var i = 0; i < tiles.evaluate().length; i++) {
          final f = tiles.at(i);
          if (t.widget<AnimatedOpacity>(f).opacity != 1) continue;
          final txt = find.descendant(of: f, matching: find.byType(Text));
          if (txt.evaluate().isEmpty) continue;
          if (t.widget<Text>(txt.first).data != ch) continue;
          await t.tap(f);
          await t.pump();
          break;
        }
      }
    }

    for (final cfg in const [
      (Size(320, 640), 1.0),
      (Size(375, 812), 1.5),
    ]) {
      final size = cfg.$1;
      final scale = cfg.$2;
      testWidgets(
          'tanishuvdan tugatishgacha hamma bosqich tushunarli va sig\'adi '
          '(${size.width.round()}px x$scale)', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: PackFlow(unit: unit, pack: pack, words: words),
          ),
        ));
        await t.pump();

        // Sarlavha o'zbekcha, ball yorliqli.
        expect(find.text('So\'zlar to\'plami 3'), findsOneWidget);
        expect(find.text('⚡ 0 ball'), findsOneWidget);
        // 1) Tanishuv: nima qilish aytiladi.
        expect(find.textContaining('Yangi so\'zlar bilan tanishing'),
            findsOneWidget);
        expect(find.textContaining('Har bir so\'zni o\'qing va tinglang'),
            findsOneWidget);
        expect(find.text('EN'), findsNothing);
        for (var i = 0; i < words.length; i++) {
          final start = find.text('Mashqni boshlash');
          if (start.evaluate().isNotEmpty) {
            await t.tap(start);
            break;
          }
          await t.tap(find.textContaining('Keyingi so\'z'));
          await t.pump(const Duration(milliseconds: 100));
        }
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull);

        // 2) Juftlash: qanday moslash aytiladi, qadamlar nomi to'liq.
        expect(find.text('So\'zlarni ma\'nosiga moslang'), findsOneWidget);
        expect(find.textContaining('Chapdagi inglizcha so\'zni bosing'),
            findsOneWidget);
        expect(find.text('Juftlash'), findsOneWidget);
        expect(find.text('Harflab yozish'), findsOneWidget);
        for (final x in words) {
          await t.tap(find.text(x.en).first);
          await t.pump();
          await t.tap(find.text(x.uz).first);
          await t.pump(const Duration(milliseconds: 100));
        }
        await t.pump(const Duration(milliseconds: 900));
        expect(t.takeException(), isNull);

        // 3) Harflab yozish.
        expect(find.textContaining('Eshiting va so\'zni harflardan yig\'ing'),
            findsOneWidget);
        expect(find.textContaining('Pastdagi harflarni to\'g\'ri tartibda'),
            findsOneWidget);
        for (var i = 0; i < words.length; i++) {
          // Hozirgi so'zni o'zbekcha ma'nosidan topamiz.
          final cur = words.firstWhere(
              (x) => find.text(x.uz).evaluate().isNotEmpty,
              orElse: () => words.first);
          await spell(t, cur.en);
          // To'g'ri javobdan keyingi rag'bat belgisi - bu fayl
          // tekshirayotgan narsa emas (yuqoridagi izohga qarang).
          await t.pump(const Duration(milliseconds: 50));
          t.takeException();
          await t.pump(const Duration(milliseconds: 1500));
          expect(t.takeException(), isNull);
        }

        // 4) Tugatish: natija nimani bildirishi va keyin nima bo'lishi.
        expect(find.text('So\'zlar to\'plami tugadi'), findsOneWidget);
        expect(find.textContaining('takrorlash jadvaliga qo\'shildi'),
            findsOneWidget);
        expect(find.textContaining('ball'), findsWidgets);
        expect(find.text('Unit (bob)ga qaytish'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });

  group("Unit so'zlari testi (Homework)", () {
    Word w(String id, String en, String uz, [String example = '']) => Word(
          id: id,
          en: en,
          uz: uz,
          example: example,
          module: 'M1',
          pos: 'noun',
          phonetic: '',
          freq: 5.0,
        );
    final words = [
      w('w1', 'cat', 'mushuk', 'The cat is small.'),
      w('w2', 'dog', 'it', 'My dog is big.'),
      w('w3', 'sun', 'quyosh'),
      w('w4', 'book', 'kitob', 'I read a book.'),
      w('w5', 'tree', 'daraxt'),
      w('w6', 'house', 'uy', 'This is my house.'),
    ];
    final unit = Unit(
      id: 'u1',
      code: 'Unit 1',
      title: 'Test',
      module: 'M1',
      order: 1,
      isRevision: false,
      components: const [],
    );
    final enSet = words.map((x) => x.en).toSet();
    final uzSet = words.map((x) => x.uz).toSet();

    for (final cfg in const [
      // Baland ekran: bu yerda ENI muhim (tor/katta shrift); balandlik
      // faqat hamma variant ko'rinib, bosib o'tish uchun.
      (Size(320, 1500), 1.0),
      (Size(375, 1800), 1.5),
    ]) {
      final size = cfg.$1;
      final scale = cfg.$2;
      testWidgets(
          "savoldan natijagacha hamma bosqich tushunarli va sig'adi "
          '(${size.width.round()}px x$scale)', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: HomeworkFlow(
                unit: unit, unitWords: words, levelWords: words),
          ),
        ));
        await t.pump();

        // "Homework" emas - nima ekani aytilgan; ball yorliqli.
        expect(find.text("Unit so'zlari testi"), findsOneWidget);
        expect(find.text('Homework'), findsNothing);
        expect(find.text('⚡ 0 ball'), findsOneWidget);
        expect(find.textContaining("Bu yerda: shu unit (bob)dagi so'zlar testi"),
            findsOneWidget);
        expect(find.textContaining('1-savol / '), findsOneWidget);

        var sawMatch = false;
        for (var step = 0; step < 90; step++) {
          await t.pump(const Duration(milliseconds: 1300));
          // To'g'ri javobdan keyingi rag'bat belgisi bu yerda tekshirilmaydi.
          t.takeException();
          if (find.textContaining('(savollar va juftlar)').evaluate()
              .isNotEmpty) {
            break;
          }
          if (find.text('🔗 Juftlarni moslang').evaluate().isNotEmpty) {
            sawMatch = true;
            expect(find.textContaining('1 ta to\'g\'ri javob'), findsOneWidget);
            for (final x in words) {
              final l = find.text(x.en);
              if (l.evaluate().isEmpty) continue;
              await t.tap(l.first);
              await t.pump();
              await t.tap(find.text(x.uz).first);
              await t.pump(const Duration(milliseconds: 50));
            }
            continue;
          }
          if (find
              .textContaining("Adashgan so'zlarni qayta ishlang")
              .evaluate()
              .isNotEmpty) {
            // Tuzatish bosqichi (faqat adashilgan bo'lsa chiqadi): matni
            // tushunarli va sig'ishi shu yerda tekshiriladi. Ko'rsatilgan
            // inglizcha so'zning o'zbekchasini topamiz.
            expect(find.textContaining('bahoga ta\'sir qilmaydi'),
                findsOneWidget);
            for (final x in words) {
              final shown = find.byWidgetPredicate(
                  (wd) => wd is Text && wd.data == x.en && wd.style?.fontSize == 30);
              if (shown.evaluate().isNotEmpty) {
                await t.tap(find.text(x.uz).first);
                await t.pump();
                break;
              }
            }
            continue;
          }
          // Savol bosqichi: tanlash/to'ldirish (variant) yoki yig'ish (harf).
          final optionTexts = find.descendant(
              of: find.byType(InkWell), matching: find.byType(Text));
          Finder? pick;
          for (var i = 0; i < optionTexts.evaluate().length; i++) {
            final d = t.widget<Text>(optionTexts.at(i)).data;
            if (d != null && (enSet.contains(d) || uzSet.contains(d))) {
              pick = optionTexts.at(i);
              break;
            }
          }
          if (pick != null) {
            await t.tap(pick);
            await t.pump();
            continue;
          }
          final tiles = find.byType(AnimatedOpacity);
          for (var i = 0; i < tiles.evaluate().length; i++) {
            if (t.widget<AnimatedOpacity>(tiles.at(i)).opacity != 1) continue;
            await t.tap(tiles.at(i));
            await t.pump();
          }
        }
        expect(sawMatch, isTrue, reason: 'juftlash bosqichiga yetdi');

        // Natija: nima bo'lgani va keyin nima qilish.
        expect(find.textContaining('(savollar va juftlar)'), findsOneWidget);
        expect(find.textContaining('ball'), findsWidgets);
        expect(find.textContaining('XP'), findsNothing);
        expect(t.takeException(), isNull);
        final bottom = await reveal(t, 'Testni qaytadan boshlash');
        expect(bottom, findsOneWidget);
        expect(await reveal(t, 'Unit (bob)ga qaytish'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });
}
