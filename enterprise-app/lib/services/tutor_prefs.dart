import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mr. Vaysaqi sozlamalari: fe'l, ovoz rejimi, ochiq rejim, izoh tili.
///
/// O'quvchi o'zi tanlaydi — tanlov hissi (autonomy) motivatsiyaning
/// asosi (Deci & Ryan). Har sozlama qurilmada saqlanadi.
class TutorPrefs extends ChangeNotifier {
  /// 0 jahldor · 1 qattiq · 2 muloyim · 3 do'stona.
  int strictness = 2;

  /// 'free' — erkin suhbat (doim tinglaydi), 'push' — bosib turing.
  String voiceMode = 'push';

  /// Ovozli kiritish yoqilganmi (mikrofon tugmasi).
  bool voice = true;

  /// 18+ ochiq rejim — qo'pol hazil/so'zlarga ruxsat.
  bool openMode = false;

  /// Izoh tili: 'uz' | 'en'.
  String noteLang = 'uz';

  static const List<String> strictLabels = [
    'Jahldor',
    'Qattiq',
    'Muloyim',
    'Do\'stona',
  ];

  static const List<String> strictDesc = [
    'Qo\'pol, masxara qiluvchi, doim jahli chiqib turadi - lekin hazil '
        'tarzida. Qiynalsangiz o\'zbekcha yozing: u baribir sizni inglizcha '
        'gapirishga undaydi.',
    'Qisqa va talabchan. Kam maqtaydi, shuning uchun maqtovi qadrli.',
    'Sabrli va yumshoq. Xatoingizni sekin va hurmat bilan to\'g\'irlaydi.',
    'Eng yaqin do\'stingiz kabi: hazil qiladi va har kichik yutuqqa quvonadi.',
  ];

  String get strictLabel => strictLabels[strictness];
  String get strictDescription => strictDesc[strictness];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    strictness = (p.getInt('tutor_strict') ?? 2).clamp(0, 3);
    voiceMode = p.getString('tutor_voice_mode') ?? 'push';
    voice = p.getBool('tutor_voice') ?? true;
    openMode = p.getBool('tutor_open') ?? false;
    noteLang = p.getString('tutor_lang') ?? 'uz';
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('tutor_strict', strictness);
    await p.setString('tutor_voice_mode', voiceMode);
    await p.setBool('tutor_voice', voice);
    await p.setBool('tutor_open', openMode);
    await p.setString('tutor_lang', noteLang);
  }

  Future<void> setStrictness(int v) async {
    strictness = v.clamp(0, 3);
    notifyListeners();
    await _save();
  }

  Future<void> setVoiceMode(String m) async {
    voiceMode = m;
    notifyListeners();
    await _save();
  }

  Future<void> setVoice(bool v) async {
    voice = v;
    notifyListeners();
    await _save();
  }

  Future<void> setOpenMode(bool v) async {
    openMode = v;
    notifyListeners();
    await _save();
  }

  Future<void> setNoteLang(String l) async {
    noteLang = l;
    notifyListeners();
    await _save();
  }
}

/// Global — ilova bo'ylab bitta.
final TutorPrefs tutorPrefs = TutorPrefs();
