import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Inglizcha talaffuz uchun audio xizmati (matndan-nutqqa).
/// Brauzer (web) va mobil qurilma TTS'idan foydalanadi — audio fayllar shart emas.
/// Inglizcha ovoz bo'lmasa, jimgina o'chib qoladi (ilova buzilmaydi).
class Tts {
  Tts._();
  static final Tts instance = Tts._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _available = true;

  /// Hozir nima o'qilyaptini bildiradi (UI holati uchun).
  final ValueNotifier<String?> speakingId = ValueNotifier(null);

  bool get available => _available;

  Future<void> _ensure() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('en-US');
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
    _ready = true;
  }

  /// Inglizcha matnni o'qiydi. [id] — UI'da qaysi element «o'qilyapti»ni ko'rsatish uchun.
  Future<void> speak(String text, {String? id}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
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

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    speakingId.value = null;
  }
}
