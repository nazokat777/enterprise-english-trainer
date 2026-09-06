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
      'Kitobdagi barcha grammatika qoidalari bir ro\'yxatda — misollari '
          'va o\'zbekcha izohi bilan.'
    ),
    (
      Icons.account_tree_rounded,
      'So\'z yasalishi',
      'Bitta o\'zakdan yasalgan so\'zlar oilasi: teach — teacher, '
          'happy — unhappy.'
    ),
    (
      Icons.forum_rounded,
      'Suhbatlar',
      'Kitobdagi barcha dialoglar bir joyda. Har bir qatorni tinglab, '
          'ovoz chiqarib takrorlang.'
    ),
  ];

  static const List<(String, String)> _rules = [
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
          'himoyalash mumkin.'
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
          'Ilova Enterprise 1 (Beginner) kitobi bo\'yicha ishlaydi. '
          'Quyida har bir bo\'lim nima qilishi yozilgan.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted(context)),
        ),
        const SizedBox(height: 16),
        const _Sub('Bo\'limlar'),
        for (final s in _sections) _SectionCard(icon: s.$1, title: s.$2, body: s.$3),
        const SizedBox(height: 10),
        const _Sub('Qanday o\'rgatadi'),
        for (final r in _rules) _RuleCard(title: r.$1, body: r.$2),
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
