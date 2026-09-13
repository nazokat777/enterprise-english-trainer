import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';

/// Inglizcha talaffuz uchun audio xizmati (matndan-nutqqa).
/// Brauzer (web) va mobil qurilma TTS'idan foydalanadi — audio fayllar shart emas.
///
/// MUHIM: faqat `setLanguage('en-US')` yetarli emas. Agar qurilmaning
/// standart ovozi o'zbek/rus bo'lsa, u inglizcha matnni O'Z talaffuzi bilan
/// o'qiydi ("married" -> "mirid"). Shuning uchun aniq INGLIZCHA OVOZ tanlanadi.
class Tts {
  Tts._();
  static final Tts instance = Tts._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _available = true;

  /// Inglizcha ovoz topildimi. Topilmasa UI ogohlantirishi mumkin.
  final ValueNotifier<bool> englishVoiceFound = ValueNotifier(true);

  /// Tanlangan ovoz nomi (sozlamalarda ko'rsatish uchun).
  String? selectedVoice;

  /// Hozir nima o'qilyaptini bildiradi (UI holati uchun).
  final ValueNotifier<String?> speakingId = ValueNotifier(null);

  bool get available => _available;

  // ─────────── Oldindan yozilgan NEURAL ovoz (assets/tts) ───────────
  //
  // Brauzer TTS'i qurilmaga qarab juda sun'iy yoki noto'g'ri talaffuz
  // bilan o'qiydi. `ingest/gen_audio.py` so'zlar va namunaviy gaplarni
  // Microsoft neural ovozi (en-GB-Sonia) bilan MP3 qilib yozib qo'ygan.
  // Matn kaliti FNV-1a 64 — Python bilan bir xil. Fayl bo'lsa u
  // chalinadi, bo'lmasa brauzer TTS.
  Set<String>? _audioKeys;
  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  bool _playerHooked = false;

  /// Neural ovoz mavjud matnlar soni (sozlamalarda ko'rsatish uchun).
  int get neuralCount => _audioKeys?.length ?? 0;

  static String _norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// FNV-1a 64 (gen_audio.py bilan bir xil).
  static String keyOf(String text) {
    var h = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final b in utf8.encode(_norm(text).toLowerCase())) {
      h = h ^ BigInt.from(b);
      h = (h * prime) & mask;
    }
    return h.toRadixString(16).padLeft(16, '0');
  }

  Future<void> _loadIndex() async {
    if (_audioKeys != null) return;
    try {
      final raw = await rootBundle.loadString('assets/tts/index.json');
      _audioKeys = (json.decode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      _audioKeys = <String>{};
    }
  }

  /// Shu matn uchun neural MP3 bormi.
  bool hasNeural(String text) => _audioKeys?.contains(keyOf(text)) ?? false;

  Future<bool> _playNeural(String text, String id) async {
    await _loadIndex();
    final k = keyOf(text);
    if (!_audioKeys!.contains(k)) return false;
    try {
      if (!_playerHooked) {
        _playerHooked = true;
        _player.onPlayerComplete.listen((_) => speakingId.value = null);
      }
      await _tts.stop();
      await _player.stop();
      speakingId.value = id;
      // MP3'lar Flutter asseti EMAS — `web/tts/` da oddiy fayl (12 000+
      // faylni asset qilib bundle qilish har test/build'ni daqiqalarga
      // cho'zardi). Web'da sahifaga nisbatan URL bilan chalinadi.
      if (!kIsWeb) return false;
      await _player.play(UrlSource('tts/$k.mp3'));
      return true;
    } catch (_) {
      speakingId.value = null;
      return false;
    }
  }

  /// Ovozlarni afzallik tartibida baholaydi: qanchalik yuqori — shuncha yaxshi.
  /// en-GB va en-US eng mos (darslik Britan inglizchasida).
  static int _score(String locale, String name) {
    final l = locale.toLowerCase().replaceAll('_', '-');
    if (!(l == 'en' || l.startsWith('en-'))) return -1; // inglizcha emas
    final n = name.toLowerCase();
    var s = 10;
    if (l.startsWith('en-gb')) {
      s += 6; // darslik Britan inglizchasida
    } else if (l.startsWith('en-us')) {
      s += 5;
    } else if (l.startsWith('en-au') || l.startsWith('en-ie')) {
      s += 2;
    }
    // Tabiiy/neural ovozlar sun'iyroqlaridan yaxshiroq.
    if (n.contains('natural') || n.contains('neural') || n.contains('online')) {
      s += 3;
    }
    if (n.contains('google')) s += 2;
    if (n.contains('microsoft')) s += 1;
    return s;
  }

  /// Mavjud ovozlardan eng mos inglizchasini tanlaydi.
  Future<void> _pickEnglishVoice() async {
    try {
      // Web'da ovozlar asinxron yuklanadi — bir necha marta urinib ko'ramiz.
      List<dynamic> voices = const [];
      for (var attempt = 0; attempt < 3; attempt++) {
        voices = (await _tts.getVoices as List?) ?? const [];
        if (voices.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 350));
      }
      if (voices.isEmpty) return; // ovoz ro'yxati yo'q — lang bilan davom etamiz

      String? bestName;
      String? bestLocale;
      var best = 0;
      for (final v in voices) {
        if (v is! Map) continue;
        final name = (v['name'] ?? '').toString();
        final locale = (v['locale'] ?? v['language'] ?? '').toString();
        final s = _score(locale, name);
        if (s > best) {
          best = s;
          bestName = name;
          bestLocale = locale;
        }
      }

      if (bestName == null || bestLocale == null) {
        englishVoiceFound.value = false;
        return;
      }
      await _tts.setVoice({'name': bestName, 'locale': bestLocale});
      selectedVoice = '$bestName ($bestLocale)';
      englishVoiceFound.value = true;
    } catch (_) {
      // Ovoz tanlash ishlamadi — setLanguage bilan davom etamiz.
    }
  }

  Future<void> _ensure() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.setLanguage('en-GB');
      await _pickEnglishVoice();
      await _tts.setSpeechRate(kIsWeb ? 0.85 : 0.45); // sekinroq — o'rganish uchun
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() => speakingId.value = null);
      _tts.setCancelHandler(() => speakingId.value = null);
      _tts.setErrorHandler((_) => speakingId.value = null);
    } catch (_) {
      _available = false;
    }
  }

  /// Ovoz tanlashni oldindan ishga tushiradi.
  ///
  /// Sozlamalar ekrani `englishVoiceFound` va `selectedVoice` ni
  /// ko'rsatadi — ular esa faqat birinchi `speak` dan keyin
  /// to'ldirilardi. Ya'ni o'quvchi hech narsa tinglamaguncha
  /// "inglizcha ovoz topilmadi" ogohlantirishini ko'rmasdi.
  Future<void> warmUp() => _ensure();

  /// Inglizcha matnni o'qiydi. [id] — UI'da qaysi element «o'qilyapti»ni
  /// ko'rsatish uchun.
  Future<void> speak(String text, {String? id}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    // 1) Neural MP3 bo'lsa — u (sifat ancha yuqori).
    if (await _playNeural(clean, id ?? clean)) return;
    // 2) Aks holda brauzer/qurilma TTS'i.
    await _ensure();
    if (!_available) return;
    try {
      await _tts.stop();
      speakingId.value = id ?? clean;
      await _tts.speak(clean);
    } catch (_) {
      speakingId.value = null;
    }
  }

  /// Indeksni oldindan yuklash (birinchi bosishda kechikmasin).
  Future<void> preload() => _loadIndex();

  Future<void> stop() async {
    try {
      await _tts.stop();
      await _player.stop();
    } catch (_) {}
    speakingId.value = null;
  }
}
