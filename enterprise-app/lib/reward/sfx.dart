import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ovoz effektlari + haptika.
///
/// Fayllar `assets/sfx/*.wav` — sintez qilingan (mualliflik muammosi yo'q).
/// Bir vaqtda bir necha ovoz chalinishi uchun kichik pleerlar hovuzi.
/// Web'da brauzer BIRINChI foydalanuvchi bosishigacha ovozni bloklaydi —
/// shuning uchun xato bo'lsa jim o'tib ketadi.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  bool enabled = true;
  bool haptics = true;

  /// Kombo balandligi bilan ovoz tezligi (pitch) oshadi — "isish" hissi.
  double _rate = 1.0;

  final List<AudioPlayer> _pool = [];
  int _next = 0;
  static const int _poolSize = 4;

  AudioPlayer _player() {
    if (_pool.length < _poolSize) {
      final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _pool.add(p);
      return p;
    }
    final p = _pool[_next];
    _next = (_next + 1) % _poolSize;
    return p;
  }

  Future<void> _play(String name, {double volume = 1, double? rate}) async {
    if (!enabled) return;
    try {
      final p = _player();
      await p.stop();
      await p.setPlaybackRate(rate ?? 1.0);
      await p.play(AssetSource('sfx/$name.wav'), volume: volume);
    } catch (e) {
      // Web autoplay siyosati yoki test muhiti — jim.
      if (kDebugMode) debugPrint('sfx: $e');
    }
  }

  void _hap(Future<void> Function() f) {
    if (!haptics || kIsWeb) return;
    f();
  }

  void correct(int combo) {
    // Har 1 kombo = +2 % tezlik (max +40 %): ketma-ket javoblar
    // "ko'tarilayotgan" tuyuladi.
    _rate = (1.0 + combo * 0.02).clamp(1.0, 1.4);
    _play('correct', rate: _rate);
    _hap(HapticFeedback.lightImpact);
  }

  void wrong() {
    _play('wrong', volume: 0.8);
    _hap(HapticFeedback.heavyImpact);
  }

  void combo() {
    _play('combo');
    _hap(HapticFeedback.mediumImpact);
  }

  void crit() {
    _play('crit');
    _hap(HapticFeedback.heavyImpact);
  }

  void coin() {
    _play('coin', volume: 0.7);
    _hap(HapticFeedback.selectionClick);
  }

  void chest() {
    _play('chest');
    _hap(HapticFeedback.mediumImpact);
  }

  void levelUp() {
    _play('levelup');
    _hap(HapticFeedback.heavyImpact);
  }

  void quest() {
    _play('quest');
    _hap(HapticFeedback.mediumImpact);
  }

  void achievement() {
    _play('achievement');
    _hap(HapticFeedback.mediumImpact);
  }

  void tick() {
    _play('tick', volume: 0.5);
    _hap(HapticFeedback.selectionClick);
  }
}
