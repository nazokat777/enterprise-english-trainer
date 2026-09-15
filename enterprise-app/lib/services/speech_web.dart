import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Brauzer nutq tanish (Web Speech API) — faqat web.
///
/// Chrome/Edge/Safari'da ishlaydi, kalit talab qilmaydi. Firefox'da yo'q.
class Speech {
  web.SpeechRecognition? _rec;
  bool _listening = false;
  bool _continuous = false;
  StreamController<String>? _out;

  static bool get supported {
    try {
      final w = web.window as JSObject;
      return w.hasProperty('SpeechRecognition'.toJS).toDart ||
          w.hasProperty('webkitSpeechRecognition'.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  bool get listening => _listening;

  /// Tinglashni boshlaydi; har yakuniy natija oqimga tushadi.
  /// [continuous] — erkin suhbat (to'xtatilguncha tinglaydi).
  Stream<String> start({bool continuous = false, String lang = 'en-US'}) {
    stop();
    final ctrl = StreamController<String>.broadcast();
    _out = ctrl;
    _continuous = continuous;
    try {
      final w = web.window as JSObject;
      final ctor = (w.hasProperty('SpeechRecognition'.toJS).toDart
          ? w['SpeechRecognition']
          : w['webkitSpeechRecognition']) as JSFunction;
      final rec = ctor.callAsConstructor<web.SpeechRecognition>();
      rec.lang = lang;
      rec.continuous = continuous;
      rec.interimResults = false;
      rec.maxAlternatives = 1;
      rec.onresult = ((web.SpeechRecognitionEvent e) {
        final results = e.results;
        for (var i = e.resultIndex; i < results.length; i++) {
          final r = results.item(i);
          if (r.isFinal) {
            final t = r.item(0).transcript.trim();
            if (t.isNotEmpty) ctrl.add(t);
          }
        }
      }).toJS;
      rec.onend = ((web.Event _) {
        // Erkin rejimda brauzer o'zi to'xtatsa (jimlik) — qayta yoqamiz.
        if (_continuous && _listening && _rec == rec) {
          try {
            rec.start();
            return;
          } catch (_) {}
        }
        _listening = false;
        if (!ctrl.isClosed) ctrl.close();
      }).toJS;
      rec.onerror = ((web.Event _) {
        _listening = false;
      }).toJS;
      _rec = rec;
      _listening = true;
      rec.start();
    } catch (e) {
      _listening = false;
      ctrl.addError(e);
      ctrl.close();
    }
    return ctrl.stream;
  }

  void stop() {
    _listening = false;
    _continuous = false;
    final r = _rec;
    _rec = null;
    if (r != null) {
      try {
        r.stop();
      } catch (_) {}
    }
    final o = _out;
    _out = null;
    if (o != null && !o.isClosed) o.close();
  }
}
