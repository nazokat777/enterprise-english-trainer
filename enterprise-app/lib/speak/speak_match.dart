/// Aytilgan matn (nutq tanish natijasi) kutilgan javobga mos keladimi.
///
/// Nutq tanish mukammal emas: "a car" o'rniga "car", "colour"/"color",
/// bitta harf farqi. Shuning uchun: normallashtirish + so'zma-so'z
/// taqqoslash + kichik Levenshtein masofasi (uzunlikka qarab).
bool speechMatches(String heard, String expected) {
  final h = _norm(heard);
  final e = _norm(expected);
  if (h.isEmpty || e.isEmpty) return false;
  if (h == e) return true;
  final hw = h.split(' ');
  final ew = e.split(' ');
  // Kutilgan ibora aytilganning ichida (ortiqcha artikl/so'z bo'lsa).
  if (ew.length < hw.length) {
    for (var i = 0; i + ew.length <= hw.length; i++) {
      if (_close(hw.sublist(i, i + ew.length).join(' '), e)) return true;
    }
  }
  return _close(h, e);
}

bool _close(String a, String b) {
  if (a == b) return true;
  final tol = b.length <= 3 ? 0 : (b.length <= 6 ? 1 : b.length ~/ 5);
  return _lev(a, b) <= tol;
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z' ]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int _lev(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  return prev[b.length];
}
