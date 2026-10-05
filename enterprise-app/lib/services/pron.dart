import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// SO'Z O'QILIShI (o'zbek harflarida) - `assets/tts/pron.json`.
///
/// `enterprise-trainer/ingest/gen_pron.py` CMU talaffuz lug'atidan
/// yaratadi (urg'uli unli belgili: "married" -> "mérid", britancha R).
/// Lug'atda yo'q so'z uchun bo'sh qaytadi - noto'g'ri ko'rsatgandan
/// ko'rsatmagan yaxshi (ovoz tugmasi baribir bor).
class Pron {
  Pron._();

  static Map<String, String>? _map;

  static String key(String en) => en
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z' ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Future<void> load() async {
    if (_map != null) return;
    try {
      final raw = await rootBundle.loadString('assets/tts/pron.json');
      _map = (json.decode(raw) as Map).map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      _map = const {};
    }
  }

  /// Yuklangan bo'lsa - o'qilishi, aks holda bo'sh.
  static String of(String en) => _map?[key(en)] ?? '';
}
