import 'package:flutter/material.dart';

import '../theme.dart';

/// YORDAM — ilova qanday ishlashi, o'zbek tilida.
///
/// Menyudagi bu band ham "keyingi fazalarda" degan bo'sh ekran edi.
/// Ilova oila uchun: birinchi marta ochgan odam qaysi bo'lim nima
/// qilishini bilishi kerak.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<(IconData, String, String)> _sections = [
    (
      Icons.school_rounded,
      'Darslar',
      'Enterprise 1 kitobining o\'zi: Coursebook, Workbook va Grammar '
          'kitoblaridan yig\'ilgan 51 ta dars. Har bir mashq o\'yin '
          'ko\'rinishida — tanlash, yozish yoki moslash.'
    ),
    (
      Icons.style_rounded,
      'Lug\'at',
      'So\'z yodlash mashqlari. Har bir so\'z tanishuv, moslash, imlo '
          'va so\'z yig\'ish bosqichlaridan o\'tadi. Takrorlash vaqtini '
          'ilova o\'zi hisoblaydi — qaysi so\'zni qachon qayta so\'rashni '
          'unutishlaringizga qarab tanlaydi.'
    ),
    (
      Icons.priority_high_rounded,
      'Qiyin so\'zlar',
      'Ikki marta va undan ko\'p unutilgan so\'zlar shu yerga tushadi. '
          'Ular ustida alohida, qisqa mashq qilish mumkin.'
    ),
    (
      Icons.rule_rounded,
      'Grammatika',
      'Uchala kitobdagi barcha grammatika qoidalari (300 ga yaqin) unit '
          'bo\'yicha, misollari va o\'zbekcha izohi bilan. Qidiruv bor; '
          '"10 savollik test" tugmasi barcha unitlardan tasodifiy savol '
          'beradi; har qoidadan o\'sha unit mashqlariga o\'tish mumkin.'
    ),
    (
      Icons.account_tree_rounded,
      'So\'z yasalishi',
      'Bitta o\'zakdan yasalgan so\'zlar oilasi: teach — teacher, '
          'happy — unhappy.'
    ),
    (
      Icons.smart_toy_rounded,
      'Mr. Vaysaqi',
      'AI o\'qituvchi bilan inglizcha suhbat: siz yozasiz, u oddiy '
          'inglizchada javob beradi va savol beradi; xatoni xabaringiz '
          'ostida to\'g\'ri variant + o\'zbekcha izoh bilan ko\'rsatadi. '
          'Har xabar +3 XP. Avval o\'qituvchi fe\'lini tanlaysiz (jahldor - '
          'qattiq - muloyim - do\'stona), ovoz rejimini (erkin suhbat / bosib '
          'turing - mikrofon bilan gapirasiz, u eshitib javob beradi), 18+ '
          'ochiq rejim va izoh tilini (UZ/EN). Claude, Gemini yoki Groq API '
          'kaliti kerak (Gemini va Groq bepul) - Sozlamalarda tanlanadi.'
    ),
    (
      Icons.forum_rounded,
      'Suhbatlar',
      'Kitobdagi barcha dialoglar bir joyda. Har bir qatorni tinglab, '
          'ovoz chiqarib takrorlang.'
    ),
  ];

  /// Mukofot tizimi — o'quvchi nima uchun ball olayotganini bilsin.
  static const List<(String, String, String)> _rewards = [
    ('🧠', 'Xotira jadvali',
        'Har so\'z uchun takrorlash muddati bor: 1 - 3 - 7 - 14 - 30 - 60 - '
            '120 kun. Muddat kelganda so\'z "o\'chib ketmoqda" ro\'yxatiga '
            'tushadi — bosh ekrandagi 🛟 Qutqarish tugmasi bilan eslab '
            'aytsangiz, keyingi muddat uzayadi. Xato — 1 kunga qaytaradi. '
            'So\'z bosqichlari: 🌱 Urug\' - 🌿 Nihol - 🌳 Daraxt - 💎 Kristall - '
            '🏆 Abadiy (60+ kun). Yangi darsga eski so\'zlardan 1-3 tasi '
            'aralashtiriladi, kechqurun esa uxlashdan oldingi 1 daqiqalik '
            'takror taklif qilinadi. 2+ marta xato qilingan so\'zga o\'z '
            'eslatmangizni (💡) yozing — +3 XP va so\'z 3 barobar yaxshi '
            'yodda qoladi.'),
    ('🎤', 'Talaffuz raundi',
        'So\'z darsida, harflab yozishdan keyin: so\'z ko\'rsatiladi, '
            'mikrofonni bosib ovoz chiqarib aytasiz - brauzer tanib '
            'tekshiradi (Chrome/Edge/Safari, kalit shart emas). Namuna '
            'tugmasi to\'g\'ri talaffuzni eshittiradi. Mikrofon bo\'lmasa '
            '"o\'tkazish" - xato hisoblanmaydi. Ovoz chiqarib aytilgan so\'z '
            'og\'iz xotirasi bilan ham yodlanadi.'),
    ('📝', 'Yig\'ma imtihon',
        'N-unitni tugatganingizda bosh ekranda "Imtihon · 1-N unitlar" '
            'chiqadi: 1-unitdan shu unitgacha HAMMA lug\'at (tanlash + '
            'harflab yozish), grammatika savollari va gaplarni klaviaturada '
            'yozish. Eng zaif bandlar birinchi so\'raladi. Xato band navbat '
            'oxiriga qaytadi - hammasi to\'g\'ri bo\'lguncha tugamaydi; baho '
            'birinchi urinish bo\'yicha, 90%+ - o\'tdi (50 tanga, medal). '
            'Yakunda o\'zlashtirilmagan bandlar ro\'yxati va "qayta ishlash". '
            'Unit ekranida imtihonni istalgan vaqt boshlash mumkin.'),
    ('⚡', 'Blitz - 60 soniya',
        'Unit so\'zlari (yoki barcha o\'rganilgan so\'zlar) bilan tezlik '
            'sinovi: 1 ochko, 5 ketma-ket to\'g\'ridan boshlab x2, 10 dan x3, '
            'xato - ko\'paytirgich nolga. Ochko = XP, yangi rekord +15 XP. '
            'Tez eslab aytish so\'zni "avtomatik" darajaga olib chiqadi.'),
    ('⚡', 'XP va daraja',
        'Har to\'g\'ri javob 2 XP. XP yig\'ilib 40 ta darajadan o\'tasiz, har '
            'darajaning o\'z unvoni bor ("Yangi o\'quvchi" dan "Enterprise '
            'chempioni" gacha). Har 500 XP — yangi liga.'),
    ('🔥', 'Kombo',
        'Ketma-ket to\'g\'ri javoblar kombo hosil qiladi. 3, 5, 10, 20, 50 da '
            'bonus XP. Bitta xato — kombo nolga tushadi.'),
    ('🌟', 'KRIT va oltin savol',
        'Har to\'g\'ri javobda 12 % ehtimol bilan KRIT — XP ikki barobar. '
            'Ba\'zi savollar oldindan "oltin" deb e\'lon qilinadi — to\'g\'ri '
            'javob 3 barobar XP.'),
    ('🎁', 'Bonus box',
        'Har 5-9 ta to\'g\'ri javobdan keyin bonus box keladi: bosib oching - '
            'tanga, XP yoki streak muzlatgich. Streak 3/7/14/30 kunda ham '
            'bonus beriladi.'),
    ('🎯', 'Kunlik missiyalar',
        'Har kuni 3 ta missiya. Uchalasi bajarilsa - mega bonus.'),
    ('🎡', 'Lucky Spin',
        'Kuniga bir marta, 5 ta to\'g\'ri javobdan keyin ochiladi. 100 '
            'tangagacha yutish mumkin.'),
    ('⚡', 'Power Hour',
        'Har kuni bitta soat (yuqori paneldagi belgi ko\'rsatadi) - hamma XP '
            'ikki barobar.'),
    ('✨', 'Avatar',
        'Sizga ism beriladigan avatar beriladi. Darajangiz oshgan sari u '
            'rivojlanadi: Spark - Star - Nova - Comet - Orbit - Aurora - Nebula - '
            'Cosmos. Bugun mashq qilmasangiz uxlab qoladi.'),
    ('🏆', 'Yutuqlar',
        '29 ta medal: birinchi mashq, 100 to\'g\'ri javob, 10 lik kombo, 7 '
            'kunlik streak va h.k. Sozlamalar - Yutuqlar, yoki yuqoridagi '
            'daraja halqasini bosing.'),
    ('💾', 'Zaxira nusxa',
        'Hamma narsa brauzerda saqlanadi. Sozlamalar - Zaxira nusxa: '
            '"Nusxalash" matnni beradi (Telegram\'da o\'zingizga yuboring), '
            '"Tiklash" uni qaytaradi - boshqa qurilmada ham.'),
    ('🔊', 'Ovoz',
        'To\'g\'ri javob, kombo, sandiq ovozlari Sozlamalardan o\'chiriladi. '
            'Brauzer birinchi bosishgacha ovozni bloklaydi — bu normal.'),
    ('🗣', 'Talaffuz',
        'Lug\'at so\'zlari va namunaviy gaplar sifatli neural ovozda (Britan '
            'inglizchasi) oldindan yozib qo\'yilgan — qaysi qurilma bo\'lsa ham '
            'bir xil, to\'g\'ri talaffuz. Mashq bandlaridagi boshqa matnlar '
            'qurilmaning o\'z ovozida o\'qiladi.'),
  ];

  static const List<(String, String)> _rules = [
    (
      "Telefonga ilova sifatida o'rnatish",
      "Chrome'da saytni oching, menyudan \"Bosh ekranga qo'shish\" "
          "(Add to Home screen) ni tanlang. iPhone'da Safari: Ulashish - "
          "\"Bosh ekranga qo'shish\". Shunda ilova belgisi va to'liq ekran "
          "bilan ochiladi, internet sekin bo'lsa ham tez ishlaydi."
    ),
    (
      'Mashq o\'zlashtirilgunicha tugamaydi',
      'Xato javob bergan bandingiz navbat oxiriga qaytadi va yana '
          'so\'raladi. Mashq faqat HAMMA bandni to\'g\'ri bilganingizda '
          'tugaydi.'
    ),
    (
      'Takrorlash kerak',
      'Mashqni xato bilan tugatsangiz, u "Takrorlash kerak" ro\'yxatiga '
          'tushadi va xatosiz o\'tguningizcha shu yerda turadi.'
    ),
    (
      'XP faqat birinchi urinishga',
      'Ball birinchi marta to\'g\'ri javob berganingiz uchun beriladi. '
          'Xato qilib, keyin topsangiz ball qo\'shilmaydi — shuning uchun '
          'ko\'rsatkich haqiqiy bilimni ko\'rsatadi.'
    ),
    (
      'Seriya (kunlar)',
      'Har kuni dars qilsangiz seriya o\'sadi. Bir kun qoldirsangiz '
          'uziladi — Sozlamalardan "muzlatgich" sotib olib, bir kunni '
          'himoyalash mumkin. Uzilib ketsa ham 2 kun ichida bosh '
          'sahifadagi kartadan tanga evaziga tiklanadi.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Text('Yordam', style: AppTheme.heading(context)),
        const SizedBox(height: 2),
        Text(
          'Ilova Enterprise 1 (Beginner) va Enterprise 2 (Elementary) '
          'kitoblari bo\'yicha ishlaydi — darajani yuqoridagi tugmadan '
          'tanlang. Quyida har bir bo\'lim nima qilishi yozilgan.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted(context)),
        ),
        const SizedBox(height: 16),
        const _Sub('Bo\'limlar'),
        for (final s in _sections) _SectionCard(icon: s.$1, title: s.$2, body: s.$3),
        const SizedBox(height: 10),
        const _Sub('Qanday o\'rgatadi'),
        for (final r in _rules) _RuleCard(title: r.$1, body: r.$2),
        const SizedBox(height: 10),
        const _Sub('Mukofotlar va o\'yin'),
        for (final r in _rewards) _RuleCard(title: '${r.$1} ${r.$2}', body: r.$3),
      ],
    );
  }
}

class _Sub extends StatelessWidget {
  final String text;
  const _Sub(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      );
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _SectionCard(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.brandPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: AppColors.brandPurple, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(body,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppColors.muted(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final String title;
  final String body;
  const _RuleCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.brandPurple.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 3),
            Text(body,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.muted(context))),
          ],
        ),
      ),
    );
  }
}
