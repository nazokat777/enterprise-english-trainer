import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'book_content.dart';

/// XATOLAR DAFTARI — o'quvchi xato qilgan bandlar (so'z emas, BAND:
/// grammatika, o'qish, tanlov...).
///
/// Pedagogika: o'z xatolari ustida qayta ishlash (error-driven retrieval)
/// yangi materialdan ko'ra 2-3 barobar samarali. Ilgari xato band faqat
/// mashq ichida navbatga qaytardi va mashq tugagach yo'qolardi.
///
/// Xato band keyin to'g'ri javob berilsa daftardan o'chadi.
class MistakeStore extends ChangeNotifier {
  static const int maxItems = 200;
  final List<Mistake> items = [];
  SharedPreferences? _prefs;
  String _level = 'beginner';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _read();
  }

  void setLevel(String level) {
    _level = level;
    _read();
  }

  String get _key => 'mistakes::$_level';

  void _read() {
    items.clear();
    final raw = _prefs?.getString(_key);
    if (raw != null) {
      for (final j in json.decode(raw) as List) {
        items.add(Mistake.fromJson((j as Map).cast<String, dynamic>()));
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await _prefs?.setString(
        _key, json.encode(items.map((m) => m.toJson()).toList()));
  }

  /// Xato javob: band daftarga tushadi (takror bo'lsa sanagich oshadi).
  Future<void> add(ExTask t, {required String source, String given = ''}) async {
    if (t.prompt.isEmpty || t.answer.isEmpty) return;
    final i = items.indexWhere((m) => m.prompt == t.prompt && m.answer == t.answer);
    if (i >= 0) {
      items[i] = items[i].copyWith(times: items[i].times + 1, at: DateTime.now());
    } else {
      items.insert(0, Mistake(
        prompt: t.prompt,
        promptUz: t.promptUz,
        answer: t.answer,
        options: t.options,
        whyUz: t.whyUz,
        given: given,
        source: source,
        at: DateTime.now(),
      ));
      if (items.length > maxItems) items.removeRange(maxItems, items.length);
    }
    await _save();
    notifyListeners();
  }

  /// To'g'ri javob: shu band daftardan o'chadi (o'zlashtirildi).
  Future<void> resolve(ExTask t) async {
    final before = items.length;
    items.removeWhere((m) => m.prompt == t.prompt && m.answer == t.answer);
    if (items.length != before) {
      await _save();
      notifyListeners();
    }
  }

  /// Daftardan tanlov mashqi (faqat variantli bandlar).
  List<ExTask> quizTasks({int limit = 10}) {
    final pool = items.where((m) => m.options.length >= 2).toList()
      ..sort((a, b) => b.times.compareTo(a.times));
    return [
      for (final m in pool.take(limit))
        ExTask(
          prompt: m.prompt,
          promptUz: m.promptUz,
          answer: m.answer,
          options: m.options,
          whyUz: m.whyUz,
          speakAnswer: m.answer,
        ),
    ];
  }

  Future<void> clear() async {
    items.clear();
    await _save();
    notifyListeners();
  }
}

class Mistake {
  final String prompt, promptUz, answer, whyUz, source;

  /// O'quvchi YOZGAN (xato) javob — tushuntirish shundan chiqariladi.
  final String given;
  final List<String> options;
  final int times;
  final DateTime at;

  const Mistake({
    required this.prompt,
    this.promptUz = '',
    required this.answer,
    this.options = const [],
    this.whyUz = '',
    this.given = '',
    this.source = '',
    this.times = 1,
    required this.at,
  });

  Mistake copyWith({int? times, DateTime? at}) => Mistake(
        prompt: prompt,
        promptUz: promptUz,
        answer: answer,
        options: options,
        whyUz: whyUz,
        given: given,
        source: source,
        times: times ?? this.times,
        at: at ?? this.at,
      );

  Map<String, dynamic> toJson() => {
        'p': prompt,
        'pu': promptUz,
        'a': answer,
        'o': options,
        'w': whyUz,
        'g': given,
        's': source,
        't': times,
        'd': at.toIso8601String(),
      };

  static Mistake fromJson(Map<String, dynamic> j) => Mistake(
        prompt: j['p'] as String? ?? '',
        promptUz: j['pu'] as String? ?? '',
        answer: j['a'] as String? ?? '',
        options: (j['o'] as List? ?? []).map((e) => '$e').toList(),
        whyUz: j['w'] as String? ?? '',
        given: j['g'] as String? ?? '',
        source: j['s'] as String? ?? '',
        times: (j['t'] as num?)?.toInt() ?? 1,
        at: DateTime.tryParse(j['d'] as String? ?? '') ?? DateTime.now(),
      );
}
