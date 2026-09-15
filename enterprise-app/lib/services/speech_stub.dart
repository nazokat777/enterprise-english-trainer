import 'dart:async';

/// Web bo'lmagan platformalar: nutq tanish yo'q.
class Speech {
  static bool get supported => false;
  bool get listening => false;
  Stream<String> start({bool continuous = false, String lang = 'en-US'}) =>
      const Stream.empty();
  void stop() {}
}
