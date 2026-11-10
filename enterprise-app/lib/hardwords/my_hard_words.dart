import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/pron.dart';
import '../services/tts.dart';
import '../theme.dart';

/// QIYIN SO'ZLARIM - foydalanuvchi O'ZI belgilagan so'zlar.
///
/// Mavjud "Qiyin so'zlar" avtomatik (ikki marta unutilgan so'zlar). Bu esa
/// qo'lda: har joyda (so'z ro'yxati, dars natijasi, matn o'quvchi) yulduz
/// bosiladi -> so'z shu daftarga tushadi -> alohida mashq qilinadi.
/// Uch marta ketma-ket to'g'ri topilsa so'z "o'zlashtirildi" bo'ladi.

class HardEntry {
  final String en, uz;
  final int streak; // ketma-ket to'g'ri javoblar
  final int wrong; // jami xatolar
  final bool mastered;
  const HardEntry({
    required this.en,
    required this.uz,
    this.streak = 0,
    this.wrong = 0,
    this.mastered = false,
  });

  HardEntry copyWith({int? streak, int? wrong, bool? mastered, String? uz}) =>
      HardEntry(
        en: en,
        uz: uz ?? this.uz,
        streak: streak ?? this.streak,
        wrong: wrong ?? this.wrong,
        mastered: mastered ?? this.mastered,
      );

  Map<String, dynamic> toJson() =>
      {'en': en, 'uz': uz, 's': streak, 'w': wrong, 'm': mastered};

  factory HardEntry.fromJson(Map<String, dynamic> j) => HardEntry(
        en: (j['en'] ?? '').toString(),
        uz: (j['uz'] ?? '').toString(),
        streak: (j['s'] as num?)?.toInt() ?? 0,
        wrong: (j['w'] as num?)?.toInt() ?? 0,
        mastered: j['m'] == true,
      );
}

class MyHardWords extends ChangeNotifier {
  MyHardWords._();
  static final MyHardWords instance = MyHardWords._();

  /// Necha marta ketma-ket to'g'ri topilsa so'z o'zlashtirilgan hisoblanadi.
  static const int masterAt = 3;

  final List<HardEntry> items = [];
  String _level = '';
  bool _ready = false;

  String _norm(String s) => s.trim().toLowerCase();
  String get _key => 'myhard::$_level';

  /// Joriy daraja daftarini yuklaydi (daraja almashsa qayta o'qiydi).
  Future<void> ensure() async {
    final lv = progress.currentLevel;
    if (_ready && lv == _level) return;
    _level = lv;
    items.clear();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        for (final j in json.decode(raw) as List) {
          items.add(HardEntry.fromJson((j as Map).cast<String, dynamic>()));
        }
      }
    } catch (_) {}
    _ready = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _key, json.encode([for (final e in items) e.toJson()]));
    } catch (_) {}
    notifyListeners();
  }

  int _idx(String en) => items.indexWhere((e) => _norm(e.en) == _norm(en));

  bool has(String en) => _idx(en) >= 0;

  List<HardEntry> get active => [for (final e in items) if (!e.mastered) e];
  List<HardEntry> get mastered => [for (final e in items) if (e.mastered) e];

  /// Yulduz: bor bo'lsa olib tashlaydi, yo'q bo'lsa qo'shadi.
  Future<bool> toggle(String en, String uz) async {
    await ensure();
    final i = _idx(en);
    if (i >= 0) {
      items.removeAt(i);
      await _save();
      return false;
    }
    if (en.trim().isEmpty) return false;
    items.insert(0, HardEntry(en: en.trim(), uz: uz.trim()));
    await _save();
    return true;
  }

  /// Bir nechta so'zni birdan qo'shadi (mavjudlari tegilmaydi).
  Future<int> addAll(Iterable<(String, String)> words) async {
    await ensure();
    var n = 0;
    for (final w in words) {
      if (w.$1.trim().isEmpty || has(w.$1)) continue;
      items.insert(0, HardEntry(en: w.$1.trim(), uz: w.$2.trim()));
      n++;
    }
    if (n > 0) await _save();
    return n;
  }

  Future<void> remove(String en) async {
    final i = _idx(en);
    if (i < 0) return;
    items.removeAt(i);
    await _save();
  }

  /// Mashq natijasi: to'g'ri -> ketma-ketlik +1 (3 ga yetsa o'zlashtirildi),
  /// xato -> ketma-ketlik 0 va xato hisobi +1.
  Future<void> record(String en, bool correct) async {
    final i = _idx(en);
    if (i < 0) return;
    final e = items[i];
    if (correct) {
      final s = e.streak + 1;
      items[i] = e.copyWith(streak: s, mastered: s >= masterAt);
    } else {
      items[i] = e.copyWith(streak: 0, wrong: e.wrong + 1, mastered: false);
    }
    await _save();
  }

  /// O'zlashtirilganni qayta mashqqa qaytarish.
  Future<void> reopen(String en) async {
    final i = _idx(en);
    if (i < 0) return;
    items[i] = items[i].copyWith(streak: 0, mastered: false);
    await _save();
  }
}

/// Yulduz tugmasi: so'zni "qiyin so'zlarim"ga qo'shadi/olib tashlaydi.
class HardStar extends StatefulWidget {
  final String en, uz;
  final double size;
  const HardStar({super.key, required this.en, required this.uz, this.size = 24});

  @override
  State<HardStar> createState() => _HardStarState();
}

class _HardStarState extends State<HardStar> {
  @override
  void initState() {
    super.initState();
    MyHardWords.instance.addListener(_changed);
    MyHardWords.instance.ensure();
  }

  @override
  void dispose() {
    MyHardWords.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final on = MyHardWords.instance.has(widget.en);
    return IconButton(
      tooltip: on
          ? "Qiyin so'zlarimdan olib tashlash"
          : "Qiyin so'zlarimga qo'shish (keyin shu ustida ishlaysiz)",
      visualDensity: VisualDensity.compact,
      iconSize: widget.size,
      icon: Icon(on ? Icons.star_rounded : Icons.star_border_rounded),
      color: on ? AppColors.coin : AppColors.muted(context),
      onPressed: () async {
        final added = await MyHardWords.instance.toggle(widget.en, widget.uz);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(added
                ? "\"${widget.en}\" qiyin so'zlarimga qo'shildi"
                : "\"${widget.en}\" qiyin so'zlarimdan olib tashlandi"),
          ));
      },
    );
  }
}

/// Qiyin so'zlar bo'limining tepasidagi karta.
class MyHardCard extends StatelessWidget {
  const MyHardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = MyHardWords.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final n = s.active.length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: AppColors.coin.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyHardWordsScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 32, color: AppColors.coin),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Mening qiyin so'zlarim ($n)",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15.5)),
                          const SizedBox(height: 2),
                          Text(
                            "O'zingiz yulduzcha (★) bilan belgilagan so'zlar. "
                            "Ularni shu yerda alohida mashq qilasiz.",
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.muted(context)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.muted(context)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════ Ro'yxat ═══════════════════
class MyHardWordsScreen extends StatefulWidget {
  const MyHardWordsScreen({super.key});

  @override
  State<MyHardWordsScreen> createState() => _MyHardWordsScreenState();
}

class _MyHardWordsScreenState extends State<MyHardWordsScreen> {
  final _addEn = TextEditingController();
  final _addUz = TextEditingController();

  @override
  void initState() {
    super.initState();
    MyHardWords.instance.ensure();
  }

  @override
  void dispose() {
    _addEn.dispose();
    _addUz.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final en = _addEn.text.trim();
    if (en.isEmpty) return;
    var uz = _addUz.text.trim();
    if (uz.isEmpty) {
      // Lug'atdan topishga urinamiz.
      final c = repo.forLevel(progress.currentLevel);
      final id = c.idByEn[en.toLowerCase()];
      if (id != null) uz = c.wordsById[id]?.uz.trim() ?? '';
    }
    await MyHardWords.instance.addAll([(en, uz)]);
    _addEn.clear();
    _addUz.clear();
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Mening qiyin so'zlarim")),
      body: ListenableBuilder(
        listenable: MyHardWords.instance,
        builder: (context, _) {
          final s = MyHardWords.instance;
          final act = s.active;
          final done = s.mastered;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Text(
                "Qiyin deb belgilagan so'zlaringiz. Mashqda har so'z 3 marta "
                "ketma-ket to'g'ri topilsa, \"o'zlashtirildi\" bo'ladi. "
                "Xato qilsangiz, hisob qaytadan boshlanadi.",
                style: TextStyle(fontSize: 13.5, height: 1.45, color: muted),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: act.isEmpty
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MyHardDrillScreen()),
                        ),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.fitness_center_rounded),
                label: Text(act.isEmpty
                    ? "Mashq uchun so'z yo'q"
                    : "Mashq qilish (${min(act.length, MyHardDrillScreen.size)} ta so'z)"),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _addEn,
                      decoration: const InputDecoration(
                          isDense: true,
                          hintText: "So'z (inglizcha)",
                          border: OutlineInputBorder()),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _addUz,
                      decoration: const InputDecoration(
                          isDense: true,
                          hintText: "Tarjimasi (ixtiyoriy)",
                          border: OutlineInputBorder()),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  IconButton(
                    tooltip: "Qo'shish",
                    onPressed: _add,
                    icon: const Icon(Icons.add_circle_rounded),
                    color: AppColors.brandPurple,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (act.isEmpty && done.isEmpty)
                Text(
                  "Hali so'z yo'q. Dars so'zlari, dars natijasi va matn "
                  "o'quvchida so'z yonidagi yulduzcha (★) ni bosing - so'z "
                  "shu yerga tushadi. Yoki yuqoridagi maydondan o'zingiz "
                  "yozing.",
                  style: TextStyle(height: 1.45, color: muted),
                ),
              for (final e in act) _row(context, e, false),
              if (done.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text("O'zlashtirilgan (${done.length})",
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.success)),
                const SizedBox(height: 6),
                for (final e in done) _row(context, e, true),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, HardEntry e, bool done) {
    final muted = AppColors.muted(context);
    final snd = Pron.of(e.en);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: (done ? AppColors.success : AppColors.coin)
            .withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.en,
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w900)),
                if (snd.isNotEmpty)
                  Text('[$snd]', style: TextStyle(fontSize: 12.5, color: muted)),
                Text(e.uz.isEmpty ? "(tarjima yo'q)" : e.uz,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                if (!done)
                  Text(
                      "Ketma-ket to'g'ri: ${e.streak}/${MyHardWords.masterAt}"
                      "${e.wrong > 0 ? ' · xato: ${e.wrong}' : ''}",
                      style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: "Tinglash",
            icon: const Icon(Icons.volume_up_rounded),
            color: AppColors.brandPurple,
            onPressed: () => Tts.instance.speak(e.en, id: 'w::${e.en}'),
          ),
          if (done)
            IconButton(
              tooltip: "Qayta mashqqa qaytarish",
              icon: const Icon(Icons.replay_rounded),
              onPressed: () => MyHardWords.instance.reopen(e.en),
            ),
          IconButton(
            tooltip: "Ro'yxatdan olib tashlash",
            icon: const Icon(Icons.delete_outline_rounded),
            color: muted,
            onPressed: () => MyHardWords.instance.remove(e.en),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════ Mashq ═══════════════════
enum _Kind { pickUz, pickEn, typeEn }

class MyHardDrillScreen extends StatefulWidget {
  /// Bir mashqdagi eng ko'p so'z.
  static const int size = 8;
  const MyHardDrillScreen({super.key});

  @override
  State<MyHardDrillScreen> createState() => _MyHardDrillScreenState();
}

class _MyHardDrillScreenState extends State<MyHardDrillScreen> {
  final _rng = Random();
  late List<HardEntry> _queue;
  final Set<String> _gotRight = {};
  final Set<String> _gotWrong = {};
  int _asked = 0;
  _Kind _kind = _Kind.pickUz;
  late HardEntry _cur;
  List<String> _options = const [];
  String? _picked;
  bool _revealed = false;
  bool? _ok;
  final _typed = TextEditingController();
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final act = MyHardWords.instance.active
      ..sort((a, b) {
        final c = a.streak.compareTo(b.streak);
        return c != 0 ? c : b.wrong.compareTo(a.wrong);
      });
    _queue = act.take(MyHardDrillScreen.size).toList();
    _next();
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// Distraktorlar: boshqa qiyin so'zlar + daraja lug'atidan tasodifiylar.
  List<String> _makeOptions(HardEntry e, bool uz) {
    final correct = uz ? e.uz : e.en;
    final pool = <String>{};
    for (final o in MyHardWords.instance.items) {
      final v = uz ? o.uz : o.en;
      if (v.isNotEmpty && v != correct) pool.add(v);
    }
    final words = repo.forLevel(progress.currentLevel).wordsById.values.toList()
      ..shuffle(_rng);
    for (final w in words) {
      if (pool.length >= 12) break;
      final v = uz ? w.uz.trim() : w.en.trim();
      if (v.isNotEmpty && v != correct) pool.add(v);
    }
    final list = pool.toList()..shuffle(_rng);
    final out = [correct, ...list.take(3)]..shuffle(_rng);
    return out;
  }

  void _next() {
    if (_queue.isEmpty) {
      setState(() => _finished = true);
      return;
    }
    _cur = _queue.removeAt(0);
    // Tarjimasi yo'q so'z uchun faqat yozish mashqi emas - tanlov ishlamaydi.
    if (_cur.uz.isEmpty) {
      _kind = _Kind.typeEn;
    } else if (_cur.streak == 0) {
      _kind = _Kind.pickUz;
    } else if (_cur.streak == 1) {
      _kind = _Kind.pickEn;
    } else {
      _kind = _Kind.typeEn;
    }
    _options = _kind == _Kind.typeEn
        ? const []
        : _makeOptions(_cur, _kind == _Kind.pickUz);
    _picked = null;
    _revealed = false;
    _ok = null;
    _typed.clear();
    if (_kind == _Kind.pickUz) {
      Tts.instance.speak(_cur.en, id: 'w::${_cur.en}');
    }
    setState(() {});
  }

  Future<void> _answer(bool correct, {String? picked}) async {
    if (_ok != null) return;
    _asked++;
    if (correct) {
      _gotRight.add(_cur.en);
    } else {
      _gotWrong.add(_cur.en);
    }
    await MyHardWords.instance.record(_cur.en, correct);
    if (!mounted) return;
    setState(() {
      _ok = correct;
      _picked = picked;
    });
    Tts.instance.speak(_cur.en, id: 'w::${_cur.en}');
  }

  void _submitTyped() {
    final a = _typed.text.trim().toLowerCase();
    if (a.isEmpty) return;
    _answer(a == _cur.en.trim().toLowerCase());
  }

  void _dontKnow() {
    _revealed = true;
    _answer(false);
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Qiyin so'zlarni mashq qilish")),
      body: _finished ? _summary(context) : _question(context, muted),
    );
  }

  Widget _question(BuildContext context, Color muted) {
    final prompt = switch (_kind) {
      _Kind.pickUz => "Bu so'zning o'zbekcha ma'nosi qaysi?",
      _Kind.pickEn => "Bu ma'noga mos inglizcha so'zni tanlang:",
      _Kind.typeEn => "Inglizchasini yozing:",
    };
    final big = _kind == _Kind.pickUz ? _cur.en : _cur.uz;
    final snd = _kind == _Kind.pickUz ? Pron.of(_cur.en) : '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text("Qolgan so'zlar: ${_queue.length + 1}",
            style: TextStyle(fontSize: 12.5, color: muted)),
        const SizedBox(height: 10),
        Text(prompt, style: TextStyle(fontSize: 14.5, color: muted)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(big,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900)),
            ),
            if (_kind == _Kind.pickUz)
              IconButton(
                tooltip: "Tinglash",
                icon: const Icon(Icons.volume_up_rounded),
                color: AppColors.brandPurple,
                onPressed: () =>
                    Tts.instance.speak(_cur.en, id: 'w::${_cur.en}'),
              ),
          ],
        ),
        if (snd.isNotEmpty)
          Text('[$snd]', style: TextStyle(fontSize: 14, color: muted)),
        const SizedBox(height: 16),
        if (_kind == _Kind.typeEn) ...[
          TextField(
            controller: _typed,
            enabled: _ok == null,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), hintText: "Shu yerga yozing"),
            onSubmitted: (_) => _submitTyped(),
          ),
          const SizedBox(height: 10),
          if (_ok == null)
            FilledButton(
              onPressed: _submitTyped,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPurple,
                  padding: const EdgeInsets.symmetric(vertical: 13)),
              child: const Text("Tekshirish"),
            ),
        ] else
          for (final o in _options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                onPressed: _ok != null
                    ? null
                    : () {
                        final right =
                            o == (_kind == _Kind.pickUz ? _cur.uz : _cur.en);
                        _answer(right, picked: o);
                      },
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  backgroundColor: _ok == null
                      ? null
                      : o == (_kind == _Kind.pickUz ? _cur.uz : _cur.en)
                          ? AppColors.success.withValues(alpha: 0.18)
                          : o == _picked
                              ? AppColors.danger.withValues(alpha: 0.18)
                              : null,
                ),
                child: Text(o, style: const TextStyle(fontSize: 16)),
              ),
            ),
        if (_ok == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _dontKnow,
              icon: const Icon(Icons.help_outline_rounded),
              label: const Text("Bilmayman - javobni ko'rsat"),
            ),
          ),
        if (_ok != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_ok! ? AppColors.success : AppColors.danger)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              _ok!
                  ? "To'g'ri! ${_cur.en} - ${_cur.uz}"
                  : "${_revealed ? 'Javob' : "Noto'g'ri. To'g'ri javob"}: "
                      "${_cur.en}${_cur.uz.isEmpty ? '' : ' - ${_cur.uz}'}. "
                      "Bu so'z yana qaytadi.",
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              // Xato so'z shu mashq oxirida yana bir marta so'raladi.
              if (_ok == false && _asked < 40) _queue.add(_cur);
              _next();
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text("Keyingisi"),
          ),
        ],
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final s = MyHardWords.instance;
    final masteredNow = [
      for (final e in s.mastered)
        if (_gotRight.contains(e.en)) e.en
    ];
    final still = [
      for (final e in s.active)
        if (_gotRight.contains(e.en) || _gotWrong.contains(e.en)) e
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        const Icon(Icons.emoji_events_rounded,
            size: 56, color: AppColors.coin),
        const SizedBox(height: 10),
        const Text("Mashq tugadi!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        if (masteredNow.isNotEmpty)
          Text("O'zlashtirildi: ${masteredNow.join(', ')}",
              style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  height: 1.4)),
        if (still.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text("Hali ustida ishlash kerak (${still.length}):",
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: AppColors.danger)),
          for (final e in still)
            Text("• ${e.en} - ${e.uz}  (ketma-ket to'g'ri: "
                "${e.streak}/${MyHardWords.masterAt})"),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: s.active.isEmpty
              ? null
              : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyHardDrillScreen()),
                  ),
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandPurple,
              padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text("Yana mashq qilish"),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Orqaga"),
        ),
      ],
    );
  }
}
