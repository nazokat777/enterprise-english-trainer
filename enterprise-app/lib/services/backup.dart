import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// ZAXIRA NUSXA — butun progress (XP, streak, SRS, mukofotlar) bitta
/// matn ko'rinishida.
///
/// Ilova web'da: hamma narsa brauzer xotirasida. Brauzer tozalansa yoki
/// boshqa qurilmaga o'tilsa — hammasi yo'qoladi, bu esa tashlab ketishning
/// eng katta sababi. Matnni nusxalab (Telegram'ga o'ziga yuborib) saqlash
/// va keyin tiklash mumkin.
class Backup {
  static const _magic = 'enterprise-backup-v1';

  /// Barcha kalitlarni JSON matnga aylantiradi.
  static Future<String> export() async {
    final p = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final k in p.getKeys()) {
      final v = p.get(k);
      if (v is List<String>) {
        data[k] = {'_list': v};
      } else {
        data[k] = v;
      }
    }
    return json.encode({
      'format': _magic,
      'at': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  /// JSON matndan tiklaydi. Muvaffaqiyatli bo'lsa `true`.
  /// Mavjud ma'lumot USTIGA yoziladi (avval tozalanadi).
  static Future<bool> import(String text) async {
    Map<String, dynamic> j;
    try {
      j = json.decode(text.trim()) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }
    if (j['format'] != _magic || j['data'] is! Map) return false;
    final p = await SharedPreferences.getInstance();
    await p.clear();
    for (final e in (j['data'] as Map).entries) {
      final k = e.key as String;
      final v = e.value;
      if (v is Map && v['_list'] is List) {
        await p.setStringList(k, (v['_list'] as List).map((x) => '$x').toList());
      } else if (v is bool) {
        await p.setBool(k, v);
      } else if (v is int) {
        await p.setInt(k, v);
      } else if (v is double) {
        await p.setDouble(k, v);
      } else if (v is String) {
        await p.setString(k, v);
      }
    }
    return true;
  }
}
