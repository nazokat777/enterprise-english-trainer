import 'package:enterprise_english/services/tts.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kalit Python (`ingest/gen_audio.py`) bilan BIR XIL bo'lishi shart —
/// aks holda MP3 topilmaydi va brauzer TTS'iga tushib ketadi.
void main() {
  test('FNV-1a 64 kaliti Python bilan mos', () {
    expect(Tts.keyOf('married'), 'c741a6068ace6857');
    expect(Tts.keyOf('  I am NOT   married. '), 'bde9f2f7ce5a7e8b');
    expect(Tts.keyOf('Married'), Tts.keyOf('married'));
  });
}
