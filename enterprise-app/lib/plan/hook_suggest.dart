/// ILGAK TAKLIFI — inglizcha so'zga TOVUSHI o'xshash o'zbekcha so'z.
///
/// Atkinson (1975) "keyword" usuli: begona tovush tanish tovushga
/// ilinadi (book -> buqa, kettle -> katta). Mukammal qofiya shart emas —
/// birinchi bo'g'in yetadi. Bu yerda so'z imlosidan taxminiy o'qilish
/// chiqariladi va konkret (tasavvur qilsa bo'ladigan) o'zbekcha otlar
/// ro'yxatidan boshi eng uzun mos keladigani tanlanadi. Bu faqat TAKLIF:
/// o'quvchi o'z ilgagini yozadi (o'zi topgani yaxshiroq yodda qoladi).
library;

/// Konkret, ko'z oldiga keltirsa bo'ladigan o'zbekcha so'zlar.
const List<String> kUzImageWords = [
  'olma', 'anor', 'uzum', 'qovun', 'tarvuz', 'nok', 'shaftoli', 'o\'rik',
  'gilos', 'limon', 'banan', 'sabzi', 'piyoz', 'kartoshka', 'bodring',
  'pomidor', 'karam', 'qalampir', 'non', 'somsa', 'palov', 'lag\'mon',
  'manti', 'shashlik', 'sut', 'qatiq', 'pishloq', 'tuxum', 'asal', 'qand',
  'choy', 'kofe', 'shakar', 'tuz', 'yog\'', 'go\'sht', 'baliq', 'tovuq',
  'xamir', 'kulcha', 'patir', 'sho\'rva', 'qozon', 'choynak', 'piyola',
  'kosa', 'qoshiq', 'pichoq', 'sanchqi', 'likopcha', 'stakan', 'shisha',
  'kitob', 'daftar', 'qalam', 'ruchka', 'sumka', 'doska', 'bo\'r', 'parta',
  'stol', 'stul', 'divan', 'karavot', 'yostiq', 'ko\'rpa', 'gilam', 'parda',
  'deraza', 'eshik', 'devor', 'tom', 'zina', 'kalit', 'qulf', 'chiroq',
  'lampa', 'televizor', 'telefon', 'kompyuter', 'soat', 'ko\'zgu', 'taroq',
  'sovun', 'sochiq', 'tish', 'til', 'lab', 'burun', 'ko\'z', 'quloq',
  'bosh', 'soch', 'qo\'l', 'oyoq', 'barmoq', 'tirnoq', 'yurak', 'bel',
  'qorin', 'yelka', 'tizza', 'tovon', 'mushuk', 'it', 'ot', 'eshak',
  'sigir', 'qo\'y', 'echki', 'tuya', 'sher', 'yo\'lbars', 'ayiq', 'bo\'ri',
  'tulki', 'quyon', 'sichqon', 'ilon', 'baqa', 'toshbaqa', 'maymun', 'fil',
  'jirafa', 'zebra', 'kaptar', 'qarg\'a', 'bulbul', 'burgut', 'o\'rdak',
  'g\'oz', 'xo\'roz', 'buqa', 'kapalak', 'asalari', 'chumoli', 'pashsha',
  'chivin', 'o\'rgimchak', 'daraxt', 'gul', 'atirgul', 'lola', 'barg',
  'shox', 'ildiz', 'o\'t', 'tosh', 'qum', 'tog\'', 'daryo', 'ko\'l',
  'dengiz', 'suv', 'olov', 'muz', 'qor', 'yomg\'ir', 'bulut', 'quyosh',
  'oy', 'yulduz', 'shamol', 'chaqmoq', 'kamalak', 'mashina', 'avtobus',
  'poyezd', 'samolyot', 'kema', 'qayiq', 'velosiped', 'mototsikl', 'taksi',
  'yo\'l', 'ko\'prik', 'bozor', 'do\'kon', 'maktab', 'bank', 'kasalxona',
  'masjid', 'bog\'', 'hovli', 'uy', 'shahar', 'qishloq', 'pul', 'tanga',
  'kiyim', 'ko\'ylak', 'shim', 'kurtka', 'palto', 'shlyapa', 'do\'ppi',
  'ro\'mol', 'etik', 'tufli', 'paypoq', 'qo\'lqop', 'kamar', 'uzuk',
  'marjon', 'sirg\'a', 'buket', 'bayroq', 'to\'p', 'qo\'g\'irchoq',
  'sharik', 'baraban', 'gitara', 'dutor', 'nay', 'qo\'ng\'iroq', 'arra',
  'bolta', 'bolg\'a', 'mix', 'qaychi', 'igna', 'ip', 'arqon', 'zanjir',
  'savat', 'qop', 'quti', 'chelak', 'tog\'ora', 'supurgi', 'bel', 'ketmon',
  'traktor', 'kombayn', 'raketa', 'robot', 'kamera', 'rasm', 'xarita',
  'globus', 'kitobxon', 'bola', 'qiz', 'o\'g\'il', 'ona', 'ota', 'buvi',
  'bobo', 'aka', 'uka', 'opa', 'singil', 'doktor', 'o\'qituvchi', 'haydovchi',
  'oshpaz', 'dehqon', 'askar', 'politsiya', 'kosmonavt', 'pilot', 'sartarosh',
  'maymoq', 'dev', 'pari', 'ajdar', 'kaltak', 'pilla', 'katta', 'kichik',
  'pista', 'bodom', 'yong\'oq', 'kishmish', 'sumalak', 'halva', 'tort',
  'muzqaymoq', 'sharbat', 'limonad', 'kisel', 'kompot', 'mayiz', 'bedana',
];

/// Imlodan TAXMINIY o'qilish (o'zbek harflarida) — mukammal emas, lekin
/// boshlang'ich tovushni to'g'ri beradi.
String approxSound(String en) {
  var s = en.toLowerCase().trim();
  s = s.replaceAll(RegExp(r"[^a-z ]"), '');
  if (s.isEmpty) return '';
  s = s.split(' ').first; // iboralarda birinchi so'z
  const pairs = [
    ['tion', 'shn'], ['sh', 'sh'], ['ch', 'ch'], ['ph', 'f'], ['th', 't'],
    ['ck', 'k'], ['qu', 'kv'], ['oo', 'u'], ['ee', 'i'], ['ea', 'i'],
    ['ai', 'ey'], ['ay', 'ey'], ['ou', 'au'], ['ow', 'ou'], ['igh', 'ay'],
    ['wh', 'v'], ['w', 'v'], ['x', 'ks'], ['c', 'k'], ['y', 'i'],
  ];
  for (final p in pairs) {
    s = s.replaceAll(p[0], p[1]);
  }
  // Oxirdagi "tovushsiz e": make -> meyk emas, mak ~ yetarli.
  if (s.length > 3 && s.endsWith('e')) s = s.substring(0, s.length - 1);
  return s;
}

int _commonPrefix(String a, String b) {
  final n = a.length < b.length ? a.length : b.length;
  var i = 0;
  while (i < n && a[i] == b[i]) {
    i++;
  }
  return i;
}

/// Eng yaxshi ilgak taklifi (bo'lmasa bo'sh): boshi eng uzun mos kelgan
/// so'z; teng bo'lsa uzunligi yaqinrog'i. [meaningUz] ichidagi so'z
/// taklif qilinmaydi (u ilgak emas, tarjimaning o'zi).
String suggestHook(String en, {String meaningUz = ''}) {
  final snd = approxSound(en);
  if (snd.length < 2) return '';
  final avoid = meaningUz.toLowerCase();
  var best = '';
  var bestP = 1, bestD = 1 << 20;
  for (final w in kUzImageWords) {
    final plain = w.replaceAll("'", '');
    if (avoid.isNotEmpty && avoid.contains(plain)) continue;
    final p = _commonPrefix(snd, plain);
    if (p < 2) continue;
    final d = (plain.length - snd.length).abs();
    if (p > bestP || (p == bestP && d < bestD)) {
      best = w;
      bestP = p;
      bestD = d;
    }
  }
  return best;
}

/// Sahna shabloni: ilgak va ma'no BIR KADRDA.
String sceneTemplate(String hook, String meaningUz) {
  if (hook.isEmpty) return '';
  final m = meaningUz.split(RegExp(r'[,;/]')).first.trim();
  return 'Ulkan $hook $m bilan ... (nima qilyapti? g\'alati, harakatli qiling)';
}
