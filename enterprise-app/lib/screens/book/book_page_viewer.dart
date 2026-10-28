import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../book_content.dart' show BookExercise;
import '../../teach/clarify.dart' show friendlyRef;
import '../../theme.dart';

/// Kitob betining suratini ko'rsatadi (agar mavjud bo'lsa).
///
/// NEGA BO'SH CHIQADI: Enterprise darsligi mualliflik huquqi bilan
/// himoyalangan, shuning uchun uning betlari ilova bilan birga
/// TARQATILMAYDI. Ilova shunchaki mexanizmni beradi:
///
///   `assets/book_pages/DARAJA_KITOB_BET.jpg`
///   masalan: `assets/book_pages/beginner_coursebook_6.jpg`
///
/// DARAJA nomda BO'LIShI ShART: Beginner va Elementary'da ham
/// 'coursebook' bor va ikkalasida ham 6-bet bor — daraja bo'lmasa
/// Elementary'ning beti Beginner'nikini bosib ketardi.
///
/// Agar egasi o'zi sotib olgan kitobning betlarini shu papkaga qo'ysa,
/// tugma ishlaydi. Fayl bo'lmasa — tugma umuman ko'rsatilmaydi va
/// mashq tavsiflar bilan ishlayveradi.
class BookPageImage {
  BookPageImage._();

  static final Map<String, bool> _cache = {};

  static String assetPath(String level, String book, int page) =>
      'assets/book_pages/${level}_${book}_$page.jpg';

  /// Bet surati mavjudmi (bir marta tekshirilib keshlanadi).
  static Future<bool> exists(String level, String book, int page) async {
    final key = '$level/$book/$page';
    final cached = _cache[key];
    if (cached != null) return cached;
    var found = false;
    try {
      await rootBundle.load(assetPath(level, book, page));
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
  final String level;
  final String book;
  final String bookLabel;
  final int page;

  const BookPageButton({
    super.key,
    required this.level,
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
    BookPageImage.exists(widget.level, widget.book, widget.page).then((v) {
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
                level: widget.level,
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
                    'Kitob betini ko\'rish (${BookExercise.bookName} · '
                    '${widget.bookLabel}, ${widget.page}-bet)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
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
class BookPageViewer extends StatefulWidget {
  final String level;
  final String book;
  final String bookLabel;
  final int page;

  const BookPageViewer({
    super.key,
    required this.level,
    required this.book,
    required this.bookLabel,
    required this.page,
  });

  @override
  State<BookPageViewer> createState() => _BookPageViewerState();
}

class _BookPageViewerState extends State<BookPageViewer> {
  final TransformationController _tc = TransformationController();
  Size _box = Size.zero;

  String get level => widget.level;
  String get book => widget.book;
  String get bookLabel => widget.bookLabel;
  int get page => widget.page;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  /// Markaz atrofida masshtabni [f] marta o'zgartiradi (0.8..5 oralig'ida).
  void _zoom(double f) {
    final cur = _tc.value.getMaxScaleOnAxis();
    final next = (cur * f).clamp(0.8, 5.0);
    final k = next / cur;
    final c = Offset(_box.width / 2, _box.height / 2);
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    _tc.value = m * _tc.value;
  }

  Widget _zoomBtn(IconData i, String tip, VoidCallback f) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: FloatingActionButton.small(
      heroTag: tip,
      tooltip: tip,
      backgroundColor: Colors.white24,
      foregroundColor: Colors.white,
      elevation: 0,
      onPressed: f,
      child: Icon(i),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomBtn(Icons.add_rounded, 'Kattalashtirish', () => _zoom(1.4)),
          _zoomBtn(
            Icons.remove_rounded,
            'Kichiklashtirish',
            () => _zoom(1 / 1.4),
          ),
          _zoomBtn(
            Icons.fit_screen_rounded,
            'Butun sahifa',
            () => _tc.value = Matrix4.identity(),
          ),
        ],
      ),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // "Enterprise 1 · Coursebook (asosiy darslik) · 7-bet" - kitobi
        // yo'q odam ham Coursebook nima ekanini bilsin.
        title: Text(
          friendlyRef('${BookExercise.bookName} · $bookLabel · $page-bet'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          _box = Size(c.maxWidth, c.maxHeight);
          return Center(
            child: InteractiveViewer(
              transformationController: _tc,
              minScale: 0.8,
              maxScale: 5,
              child: Image.asset(
                BookPageImage.assetPath(level, book, page),
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
                        Text(
                          'Bet yuklanmoqda...',
                          style: TextStyle(color: Colors.white70),
                        ),
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
          );
        },
      ),
    );
  }
}
