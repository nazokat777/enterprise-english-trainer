import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// PWA o'rnatish (faqat web).
///
/// Chrome/Edge/Android: `beforeinstallprompt` hodisasi index.html'da
/// ushlanadi (`window.__installPrompt`), bu yerdan `prompt()` chaqiriladi.
/// iOS Safari'da avtomatik taklif yo'q — ko'rsatma beriladi.
class Install {
  /// Bosh ekranga o'rnatilgan holda ochilganmi.
  static bool get isStandalone {
    try {
      if (web.window.matchMedia('(display-mode: standalone)').matches) {
        return true;
      }
      final nav = web.window.navigator as JSObject;
      final s = nav['standalone'];
      return s != null && s.isA<JSBoolean>() && (s as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }

  static bool get canPrompt {
    try {
      final w = web.window as JSObject;
      final p = w['__installPrompt'];
      return p != null && !p.isUndefinedOrNull;
    } catch (_) {
      return false;
    }
  }

  static bool get isIos {
    try {
      final ua = web.window.navigator.userAgent;
      return RegExp(r'iPhone|iPad|iPod').hasMatch(ua);
    } catch (_) {
      return false;
    }
  }

  /// Brauzer o'rnatish oynasini ochadi; qabul qilinsa `true`.
  static Future<bool> prompt() async {
    try {
      final w = web.window as JSObject;
      final p = w['__installPrompt'];
      if (p == null || p.isUndefinedOrNull) return false;
      final ev = p as JSObject;
      ev.callMethod('prompt'.toJS);
      final choice = await (ev['userChoice'] as JSPromise<JSObject>).toDart;
      final outcome = (choice['outcome'] as JSString).toDart;
      w['__installPrompt'] = null;
      return outcome == 'accepted';
    } catch (_) {
      return false;
    }
  }
}
