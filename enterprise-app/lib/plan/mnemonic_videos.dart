import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/hover_lift.dart';

/// MNEMONIKA DARSLIKLARI — Davronbek Turdiev video darslari (YouTube).
///
/// Ilovadagi reja shu darslardagi usullarga asoslangan. Mnemonikani
/// hali tushunmagan o'quvchi avval shularni ko'radi. Videolar ilovaga
/// yuklanmaydi (muallif huquqi) — faqat havola.
class MnemonicVideo {
  final String id;
  final String title;
  final String length;
  final String about;
  const MnemonicVideo(this.id, this.title, this.length, this.about);

  String get url => 'https://youtu.be/$id';
}

const List<MnemonicVideo> kMnemonicVideos = [
  MnemonicVideo(
    'dR-Q07BhKj8',
    'Xotirani kuchaytiradigan 3 prinsip',
    '11:38',
    'Boshlash uchun eng yaxshisi: hajm, konkretlik, bog\'lash.',
  ),
  MnemonicVideo(
    'n1MI3p0KpzY',
    'Chet tili so\'zlarini eslab qolishning 7 qadamli algoritmi',
    '42:17',
    'Eng muhimi: ilgak, obraz, yopib eslash, oraliqli takror.',
  ),
  MnemonicVideo(
    'ruaSbmL9ErE',
    '30 daqiqalik amaliy dars',
    '32:50',
    'Qarmoq usuli - 15 so\'zni tartib bilan eslab qolish mashqi.',
  ),
  MnemonicVideo(
    'fyxL4D1WF9M',
    'Til o\'rganishda orqaga tortayotgan 9 ta xato',
    '58:39',
    'Maqsad, intizom, qo\'rquv, diqqat - va ularning yechimi.',
  ),
  MnemonicVideo(
    'hX_L9p8ZEIg',
    '1 kunda 1000 ta so\'z yodlash mumkinmi?',
    '9:09',
    'Savol-javob: real kutish, grammatika, ishtiyoq.',
  ),
  MnemonicVideo(
    'Wc7p4NgO_SU',
    'Xorijiy so\'zlarni yodlashning ko\'pchilik bilmaydigan usuli',
    '4:06',
    '"Super usul" kitobi haqida qisqa tanishtiruv.',
  ),
];

Future<void> openVideo(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Mnemonika bo'limidagi video darsliklar kartasi.
class MnemonicVideosCard extends StatelessWidget {
  const MnemonicVideosCard({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎬', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Mnemonika darsliklari',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Mnemonika nima ekanini tushunmagan bo\'lsangiz - avval shu '
            'videolarni ko\'ring (Davronbek Turdiev, YouTube). Ilovadagi reja '
            'shu usullarga asoslangan. Tartib bilan ko\'rish tavsiya etiladi.',
            style: TextStyle(fontSize: 12.5, height: 1.45, color: muted),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < kMnemonicVideos.length; i++)
            _VideoRow(n: i + 1, v: kMnemonicVideos[i]),
        ],
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  final int n;
  final MnemonicVideo v;
  const _VideoRow({required this.n, required this.v});

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => openVideo(v.url),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0033).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFFFF0033), size: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$n. ${v.title}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('${v.length} · ${v.about}',
                        style: TextStyle(fontSize: 11.5, height: 1.35, color: muted)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 16, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
