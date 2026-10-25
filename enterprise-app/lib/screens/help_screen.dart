import 'package:flutter/material.dart';

import '../theme.dart';

/// YORDAM - ilova qanday ishlashi, o'zbek tilida.
///
/// Kitobi yo'q, o'yin ilovalarini bilmaydigan odam ham tushunishi kerak:
/// avval "qanday boshlayman" (4 qadam), keyin qisqa savol-javob, bo'limlar
/// va eng oxirida - yig'ilgan holda - batafsil izohlar.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  /// 1) Boshlash - eng muhim 4 qadam.
  static const List<(String, String)> _steps = [
    (
      "Bosh ekrandagi \"Davom eting\" kartasini bosing",
      "U sizni aynan keyingi qadamga olib boradi: qaysi unit, qaysi dars. "
          "Nima qilishni o'ylab o'tirish shart emas.",
    ),
    (
      "So'z darsi: avval ro'yxat, keyin savollar",
      "Dars boshida 5-8 ta yangi so'z ro'yxati chiqadi: tarjimasi, "
          "o'qilishi va ovozi bilan. Ko'zdan kechirib, tinglab, "
          "\"Yodlashni boshlash\"ni bosing.",
    ),
    (
      "Bilmasangiz - \"Bilmayman - ko'rsat\"",
      "Har savol ostida shu tugma bor: to'g'ri javobni tarjimasi bilan "
          "ko'rasiz, so'z esa keyinroq yana so'raladi - shunda o'zingiz "
          "topasiz. \"O'tkazib yuborish\" ham bor.",
    ),
    (
      "Unit oxirida imtihon",
      "Har unit (bob) tugagach \"Unit imtihoni\": so'zlar, grammatika "
          "va gap tuzish, oldingi unitlardan takror bilan. 90% va undan "
          "yuqori - o'tdingiz.",
    ),
  ];

  /// 2) Tez-tez so'raladigan savollar.
  static const List<(String, String)> _faq = [
    (
      "Kitob kerakmi?",
      "Yo'q. Enterprise kitoblaridagi so'zlar, qoidalar va mashqlar shu "
          "yerning o'zida. Har mashq tepasida qaysi kitob va qaysi bet "
          "ekani yozilgan - xohlasangiz kitobdan ham ko'rishingiz mumkin.",
    ),
    (
      "Mashq nimani so'rayotgani tushunarsiz bo'lsa?",
      "Har savol tepasida \"Nima qilinadi\" qatori turadi. Javob "
          "berolmasangiz \"Bilmayman - ko'rsat\" bosing. Xato qilsangiz "
          "ilova nima uchun xato ekanini tushuntiradi.",
    ),
    (
      "Xato qilsam nima bo'ladi?",
      "Hech narsa - jazo yo'q. Xato qilingan savol navbat oxirida qayta "
          "so'raladi, to'g'ri topguningizcha. Xatolar \"Qiyin so'zlar\" "
          "bo'limiga ham yig'iladi.",
    ),
    (
      "Tepadagi raqamlar nima?",
      "Ketma-ket kunlar, bugungi ball, jami ball va tangalar. Ularning "
          "yonidagi \"?\" tugmasini bosing - har birining ma'nosi yoziladi.",
    ),
    (
      "Mnemonika nima?",
      "Butun kitobni siz tanlagan muddatda (masalan, 2 oyda) yodlab "
          "tugatish rejasi: har kuni nechta so'z va qoida o'rganishingiz "
          "aytiladi, yodlash usullari bilan.",
    ),
    (
      "Mikrofon ishlamasa?",
      "Talaffuz savolida \"o'tkazish\" tugmasini bosing - xato "
          "hisoblanmaydi. Mikrofon Chrome, Edge va Safari'da ishlaydi, "
          "Firefox'da yo'q.",
    ),
    (
      "Ma'lumotlarim qayerda saqlanadi?",
      "Faqat shu brauzerda (telefonda yoki kompyuterda). Hisob ochish "
          "kerak emas. Boshqa qurilmaga o'tkazish uchun Sozlamalardagi "
          "\"Zaxira nusxa\" dan foydalaning.",
    ),
  ];

  /// 3) Menyu bo'limlari - bir-ikki gapda.
  static const List<(IconData, String, String)> _sections = [
    (
      Icons.school_rounded,
      "Darslar",
      "Asosiy kurs: unitlar ketma-ket, har birida so'z darslari, "
          "grammatika, mashqlar va imtihon.",
    ),
    (
      Icons.psychology_alt_rounded,
      "Mnemonika",
      "Kitobni belgilangan muddatda yodlash rejasi va yodlash usullari.",
    ),
    (
      Icons.style_rounded,
      "Lug'at",
      "So'zlar to'plami: mashq qilib yodlang. Takrorlash vaqtini ilova "
          "o'zi hisoblaydi.",
    ),
    (
      Icons.priority_high_rounded,
      "Qiyin so'zlar",
      "Ikki marta va undan ko'p unutgan so'zlaringiz - ular ustida "
          "alohida qisqa mashq.",
    ),
    (
      Icons.rule_rounded,
      "Grammatika",
      "Barcha qoidalar unit bo'yicha: misollar va o'zbekcha izoh bilan. "
          "Qidirish va tezkor test bor.",
    ),
    (
      Icons.account_tree_rounded,
      "So'z yasalishi",
      "Bitta o'zakdan yasalgan so'zlar oilasi: teach - teacher, "
          "happy - unhappy.",
    ),
    (
      Icons.forum_rounded,
      "Suhbatlar",
      "Kitobdagi dialoglar: tinglang, ovoz chiqarib takrorlang yoki rol "
          "o'ynang.",
    ),
    (
      Icons.smart_toy_rounded,
      "AI o'qituvchi (Mr. Vaysaqi)",
      "AI o'qituvchi bilan inglizcha suhbat: yozasiz yoki gapirasiz, u "
          "javob beradi va xatoyingizni o'zbekcha tushuntiradi. Bepul "
          "AI kaliti kerak - birinchi ochilganda qadamma-qadam ko'rsatiladi.",
    ),
  ];

  /// 4) Batafsil - yig'ilgan holda: xotira va mukofotlar tizimi.
  static const List<(String, String, String)> _details = [
    (
      "🧠",
      "Xotira jadvali",
      "Har so'z uchun takrorlash muddati bor: 1 - 3 - 7 - 14 - 30 - 60 - "
          "120 kun. Muddat kelganda so'z \"o'chib ketmoqda\" ro'yxatiga "
          "tushadi - bosh ekrandagi \"Hozir takrorlash\" tugmasi bilan eslab "
          "aytsangiz, keyingi muddat uzayadi. Xato - 1 kunga qaytaradi. "
          "So'z bosqichlari: 🌱 Urug' - 🌿 Nihol - 🌳 Daraxt - 💎 Kristall - "
          "🏆 Abadiy (60+ kun). 2+ marta xato qilingan so'zga o'z "
          "eslatmangizni (💡) yozing - +3 ball va so'z yaxshiroq yodda "
          "qoladi.",
    ),
    (
      "📝",
      "Imtihonlar",
      "Unit imtihoni - shu unit (va oldingi unitlardan takror). "
          "Yig'ma imtihon - 1-unitdan shu unitgacha hammasi. Xato savol "
          "oxirida qaytadi; baho birinchi urinish bo'yicha, 90%+ - o'tdi. "
          "Yakunda zaif bandlar ro'yxati va \"qayta ishlash\".",
    ),
    (
      "⚡",
      "Ball va daraja",
      "Har to'g'ri javob 2 ball. Ball yig'ilib darajangiz oshadi (40 ta "
          "daraja, har birining unvoni bor). Har 500 ballda reyting jadvalida "
          "yangi bosqich.",
    ),
    (
      "🔥",
      "Ketma-ket to'g'ri javoblar",
      "Xatosiz ketma-ket javoblar bonus ball beradi (3, 5, 10, 20, 50 "
          "tada). Bitta xato - hisob noldan boshlanadi.",
    ),
    (
      "🌟",
      "Ikki-uch barobar ball",
      "Ba'zan to'g'ri javob uchun ball 2 barobar bo'ladi. Ba'zi "
          "savollar \"oltin\" deb belgilanadi - to'g'ri javob 3 barobar "
          "ball. Har kuni bir soat (tepadagi ⏰ belgi) ham ball 2 "
          "barobar.",
    ),
    (
      "🎁",
      "Sovg'a qutisi",
      "Dars yoki mashq tugaganda sovg'a qutisi chiqishi mumkin: bosib "
          "oching - tanga, ball yoki \"muzlatgich\" (bir kunni qoldirib "
          "yuborsangiz ham ketma-ket kunlar uzilmaydi).",
    ),
    (
      "🎯",
      "Kunlik vazifalar va Omad g'ildiragi",
      "Har kuni 3 ta vazifa; uchalasi bajarilsa - katta sovg'a. Omad "
          "g'ildiragi kuniga bir marta, 5 ta to'g'ri javobdan keyin "
          "ochiladi (100 tangagacha).",
    ),
    (
      "✨",
      "Avatar",
      "Sizga ism qo'yiladigan do'st: darajangiz oshgan sari rivojlanadi "
          "(Spark - Star - Nova - Comet - ... - Cosmos). Bir kun mashq "
          "qilmasangiz \"uxlab\" qoladi.",
    ),
    (
      "🏆",
      "Yutuqlar",
      "29 ta medal: birinchi mashq, 100 to'g'ri javob, 10 ta ketma-ket "
          "to'g'ri javob, 7 kun ketma-ket va h.k. Yuqoridagi daraja "
          "aylanasini bosing.",
    ),
    (
      "🔊",
      "Ovoz va talaffuz",
      "So'z va gaplar sifatli britancha ovozda yozib qo'yilgan. Ovoz "
          "effektlari (ball, g'alaba tovushlari) standart o'chirilgan - "
          "Sozlamalardan yoqiladi. Brauzer birinchi bosishgacha ovozni "
          "bloklaydi - bu normal.",
    ),
    (
      "📲",
      "Telefonga o'rnatish",
      "Chrome'da saytni oching, menyudan \"Bosh ekranga qo'shish\" ni "
          "tanlang. iPhone'da Safari: Ulashish - \"Bosh ekranga qo'shish\". "
          "Ilova belgisi bosh ekranga tushadi va to'liq ekranda ochiladi.",
    ),
    (
      "💾",
      "Zaxira nusxa",
      "Hamma narsa brauzerda saqlanadi. Sozlamalar - Zaxira nusxa: "
          "\"Nusxalash\" matn beradi (Telegram'da o'zingizga yuboring), "
          "\"Tiklash\" uni qaytaradi - boshqa qurilmada ham.",
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
          "Ilova Enterprise 1 (Beginner) va Enterprise 2 (Elementary) "
          "darsliklari asosida ingliz tilini o'rgatadi. Kitob shart emas. "
          "Darajani yuqoridagi tugmadan tanlaysiz.",
          style: TextStyle(fontSize: 12.5, color: AppColors.muted(context)),
        ),
        const SizedBox(height: 16),
        const _Sub("Qanday boshlayman? (4 qadam)"),
        for (var i = 0; i < _steps.length; i++)
          _StepCard(n: i + 1, title: _steps[i].$1, body: _steps[i].$2),
        const SizedBox(height: 10),
        const _Sub("Tez-tez so'raladigan savollar"),
        for (final f in _faq) _RuleCard(title: f.$1, body: f.$2),
        const SizedBox(height: 10),
        const _Sub("Bo'limlar"),
        for (final s in _sections)
          _SectionCard(icon: s.$1, title: s.$2, body: s.$3),
        const SizedBox(height: 10),
        Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: const Text("Batafsil: xotira, ball va mukofotlar",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              subtitle: Text("Ixtiyoriy - bilib qo'ysangiz yaxshi",
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.muted(context))),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              children: [
                for (final r in _details)
                  _RuleCard(title: '${r.$1} ${r.$2}', body: r.$3),
              ],
            ),
          ),
        ),
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

class _StepCard extends StatelessWidget {
  final int n;
  final String title;
  final String body;
  const _StepCard({required this.n, required this.title, required this.body});

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
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: Text('$n',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14.5)),
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
