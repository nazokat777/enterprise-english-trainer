/// Web bo'lmagan platformalar: o'rnatish taklifi yo'q.
class Install {
  static bool get isStandalone => true;
  static bool get canPrompt => false;
  static bool get isIos => false;
  static Future<bool> prompt() async => false;
}
