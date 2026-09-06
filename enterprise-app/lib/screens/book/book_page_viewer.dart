import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../theme.dart';

/// Kitob betining suratini ko'rsatadi (agar mavjud bo'lsa).
///
/// NEGA BO'SH CHIQADI: Enterprise darsligi mualliflik huquqi bilan
/// himoyalangan, shuning uchun uning betlari ilova bilan birga
/// TARQATILMAYDI. Ilova shunchaki mexanizmni beradi:
///
///   `assets/book_pages/KITOB_BET.jpg`
///   masalan: `assets/book_pages/coursebook_6.jpg`
///
/// Agar egasi o'zi sotib olgan kitobning betlarini shu papkaga qo'ysa,
/// tugma ishlaydi. Fayl bo'lmasa — tugma umuman ko'rsatilmaydi va
/// mashq tavsiflar bilan ishlayveradi.
class BookPageImage {
  BookPageImage._();

  static final Map<String, bool> _cache = {};

  static String assetPath(String book, int page) =>
      'assets/book_pages/${book}_$page.jpg';

  /// Bet surati mavjudmi (bir marta tekshirilib keshlanadi).
  static Future<bool> exists(String book, int page) async {
    final key = '$book/$page';
    final cached = _cache[key];
    if (cached != null) return cached;
    var found = false;
    try {
      await rootBundle.load(assetPath(book, page));
      found = true;
    } catch (_) {
      found = false;
    }
    _cache[key] = found;
    return found;
  }
}

/// "Kitob betini ko'rish" tugmasi — surat bo'lsagina paydo bo'ladi.
class BookPageButton extends StatefulWidget {
  final String book;
  final String bookLabel;
  final int page;

  const BookPageButton({
    super.key,
    required this.book,
    required this.bookLabel,
    required this.page,
  });

  @override
  State<BookPageButton> createState() => _BookPageButtonState();
}

class _BookPageButtonState extends State<BookPageButton> {
  bool? _has;

  @override
  void initState() {
    super.initState();
    BookPageImage.exists(widget.book, widget.page).then((v) {
      if (mounted) setState(() => _has = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_has != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.brandPurple,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookPageViewer(
                book: widget.book,
                bookLabel: widget.bookLabel,
                page: widget.page,
              ),
            ),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                      'Kitob betini ko\'rish (${widget.page}-bet)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bet suratini kattalashtirib ko'rish (zoom va surish bilan).
class BookPageViewer extends StatelessWidget {
  final String book;
  final String bookLabel;
  final int page;

  const BookPageViewer({
    super.key,
    required this.book,
    required this.bookLabel,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('$bookLabel · $page-bet',
            style: const TextStyle(fontSize: 16)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.asset(
            BookPageImage.assetPath(book, page),
            fit: BoxFit.contain,
            // Bet skani ~1 MB. Telefonda mobil internet bilan u
            // bir necha soniya kelishi mumkin edi va shu vaqt
            // davomida ekran QOP-QORA turardi — o'quvchi ilova
            // buzilgan deb o'ylardi.
            frameBuilder: (context, child, frame, wasSyncLoaded) {
              if (wasSyncLoaded || frame != null) return child;
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white70),
                    SizedBox(height: 14),
                    Text('Bet yuklanmoqda...',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              );
            },
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Bet surati topilmadi.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
