/// TUShUNTIRISh DVIGATELI — har bir XATO javobga o'zbekcha izoh.
///
/// Muammo: kitob bandlarining yarmida (`whyUz`) izoh bor, yarmida yo'q.
/// Izohsiz xato — o'rgatmaydi, faqat "noto'g'ri" deb qo'yadi. Bu yerda
/// javob bilan to'g'ri variant FARQIDAN izoh tug'iladi: qaysi qoida
/// buzilgan (artikl, ko'plik, fe'l shakli, to be, tartib, imlo...).
///
/// Tartib: 1) kitobning o'z izohi, 2) bo'lim qoidasi, 3) farqdan
/// chiqarilgan qoida, 4) oxirgi chora — to'g'ri javobni ko'rsatish.
library;

/// Bitta tushuntirish: sarlavha + matn (+ ixtiyoriy qoida nomi).
class Explanation {
  /// Qisqa sarlavha — "Artikl", "Ko'plik", "Fe'l shakli"...
  final String title;

  /// O'zbekcha izoh matni.
  final String text;

  /// Manba: 'book' (kitob izohi), 'rule' (bo'lim qoidasi),
  /// 'diff' (farqdan chiqarilgan), 'answer' (faqat javob).
  final String source;

  const Explanation({
    required this.title,
    required this.text,
    required this.source,
  });
}

/// Javobni normallashtirish — taqqoslash uchun.
String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<String> _words(String s) =>
    _norm(s).split(' ').where((w) => w.isNotEmpty).toList();

/// Ikki matn orasidagi birinchi farqli so'z juftligi (bor bo'lsa).
({String got, String want})? _firstDiff(String given, String correct) {
  final a = _words(given);
  final b = _words(correct);
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return (got: a[i], want: b[i]);
  }
  if (a.length != b.length) {
    return (
      got: a.length > b.length ? a[n] : '',
      want: b.length > a.length ? b[n] : '',
    );
  }
  return null;
}

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

const _articles = {'a', 'an', 'the'};
const _beForms = {'am', 'is', 'are', 'was', 'were', 'be', 'been', 'being'};
const _auxForms = {
  'do', 'does', 'did', 'have', 'has', 'had', 'can', 'could', 'will',
  'would', 'should', 'must', 'may', 'might',
};
const _prepositions = {
  'in', 'on', 'at', 'to', 'for', 'from', 'of', 'with', 'by', 'about',
  'into', 'over', 'under', 'between', 'near', 'behind', 'after', 'before',
};
const _pronouns = {
  'i', 'you', 'he', 'she', 'it', 'we', 'they', 'me', 'him', 'her', 'us',
  'them', 'my', 'your', 'his', 'its', 'our', 'their',
};

/// ENG KO'P UChRAYDIGAN so'zlar lug'ati — kitob lug'atida yo'q,
/// lekin har gapda keladigan xizmatchi so'zlar. Tarjimasiz qoida
/// tushunarsiz: "she kerak" deyish o'rniga "she - u (ayol)" deyiladi.
const Map<String, String> kCoreWords = {
  'i': 'men', 'you': 'siz / sen', 'he': 'u (erkak)', 'she': 'u (ayol)',
  'it': 'u (narsa)', 'we': 'biz', 'they': 'ular',
  'me': 'meni / menga', 'him': 'uni (erkak)', 'her': 'uni (ayol) / uning',
  'us': 'bizni', 'them': 'ularni',
  'my': 'mening', 'your': 'sizning', 'his': 'uning (erkak)',
  'its': 'uning (narsa)', 'our': 'bizning', 'their': 'ularning',
  'am': 'man (I bilan)', 'is': 'dir (u bilan)', 'are': 'siz/ular bilan',
  'was': 'edi (birlik)', 'were': 'edi (ko\'plik)', 'be': 'bo\'lmoq',
  'do': 'qilmoq / yordamchi', 'does': 'yordamchi (u bilan)',
  'did': 'yordamchi (o\'tgan zamon)',
  'have': 'ega bo\'lmoq', 'has': 'ega (u bilan)', 'had': 'ega edi',
  'can': 'ola bilmoq', 'will': 'kelasi zamon', 'not': 'emas',
  'a': 'bitta (noaniq)', 'an': 'bitta (unli oldidan)', 'the': 'aniq artikl',
  'and': 'va', 'but': 'lekin', 'or': 'yoki', 'because': 'chunki',
  'what': 'nima', 'who': 'kim', 'where': 'qayerda', 'when': 'qachon',
  'why': 'nega', 'how': 'qanday', 'which': 'qaysi',
  'this': 'bu', 'that': 'anavi / u', 'these': 'bular', 'those': 'anavilar',
  'here': 'bu yerda', 'there': 'u yerda', 'yes': 'ha', 'no': 'yo\'q',
  'please': 'iltimos', 'thanks': 'rahmat', 'sorry': 'kechirasiz',
  'very': 'juda', 'too': 'ham / juda', 'also': 'shuningdek',
  'in': 'ichida', 'on': 'ustida', 'at': 'da (nuqta)', 'to': 'ga',
  'from': 'dan', 'with': 'bilan', 'for': 'uchun', 'of': 'ning',
  'old': 'yosh / eski', 'name': 'ism', 'years': 'yil',
};

/// Tartibsiz ko'plik shakllari — "childs" kabi xatolar uchun.
const _irregularPlural = {
  'child': 'children',
  'man': 'men',
  'woman': 'women',
  'person': 'people',
  'foot': 'feet',
  'tooth': 'teeth',
  'mouse': 'mice',
};

/// FARQDAN QOIDA — eng muhim qism: nima uchun xato bo'lgani.
Explanation? explainDiff(String given, String correct) {
  final g = _norm(given);
  final c = _norm(correct);
  if (g.isEmpty || c.isEmpty || g == c) return null;

  final d = _firstDiff(given, correct);
  final got = d?.got ?? '';
  final want = d?.want ?? '';

  // Bir nechta so'z yetishmasa/ortiqcha bo'lsa - avval TUZILISh haqida
  // aytiladi: bitta so'zning qoidasi bu yerda ikkinchi darajali.
  final givenWords = _words(given);
  final correctWords = _words(correct);
  final leftover = [...givenWords];
  final missing = [...correctWords]..removeWhere(leftover.remove);
  if (missing.length + leftover.length >= 2 &&
      givenWords.length != correctWords.length) {
    if (correctWords.length > givenWords.length) {
      return Explanation(
        title: 'So\'z tushib qolgan',
        text: 'Javobingizda ${missing.length} ta so\'z yetishmayapti'
            '${missing.isEmpty ? '' : ' ("${missing.join('", "')}")'}. '
            'To\'liq gapda ega ham, fe\'l ham bo\'lishi kerak.',
        source: 'diff',
      );
    }
    return Explanation(
      title: 'Ortiqcha so\'z',
      text: 'Javobingizda ${leftover.length} ta ortiqcha so\'z bor'
          '${leftover.isEmpty ? '' : ' ("${leftover.join('", "')}")'}. '
          'Inglizchada takror ega yoki ortiqcha yordamchi qo\'yilmaydi.',
      source: 'diff',
    );
  }

  // 1) ARTIKL: a / an / the
  if (_articles.contains(want) || _articles.contains(got)) {
    if (want == 'an' && got == 'a') {
      return const Explanation(
        title: 'Artikl: a yoki an',
        text: 'Keyingi so\'z UNLI tovush bilan boshlansa "an" qo\'yiladi: '
            'an apple, an hour. Undosh bilan boshlansa "a": a book, a car.',
        source: 'diff',
      );
    }
    if (want == 'a' && got == 'an') {
      return const Explanation(
        title: 'Artikl: a yoki an',
        text: 'Keyingi so\'z UNDOSH tovush bilan boshlansa "a" qo\'yiladi: '
            'a book, a university. Unli bilan boshlansa "an": an egg.',
        source: 'diff',
      );
    }
    if (want == 'the') {
      return const Explanation(
        title: 'Artikl: the',
        text: 'Gapiruvchi ham, tinglovchi ham BILGAN aniq narsaga "the" '
            'qo\'yiladi (ikkinchi marta eslatilganda, yagona narsalarda: '
            'the sun, the door).',
        source: 'diff',
      );
    }
    if (got == 'the' && (want == 'a' || want == 'an')) {
      return const Explanation(
        title: 'Artikl: a/an yoki the',
        text: 'Narsa BIRINChI marta, noaniq tarzda aytilsa "a/an" ishlatiladi. '
            '"The" esa aniq, ma\'lum narsaga qo\'yiladi.',
        source: 'diff',
      );
    }
    // Ortiqcha artikl: javobda qolib ketgan (to'g'ri javobda yo'q).
    if (_articles.contains(got) && leftover.contains(got)) {
      return const Explanation(
        title: 'Ortiqcha artikl',
        text: 'Bu yerda artikl kerak emas: ko\'plik va sanalmaydigan '
            'so\'zlar oldida (water, books) hamda atoqli otlarda '
            '(Tashkent) artikl qo\'yilmaydi. Takror artikl ham bo\'lmaydi.',
        source: 'diff',
      );
    }
    if (want.isEmpty && _articles.contains(got)) {
      return const Explanation(
        title: 'Ortiqcha artikl',
        text: 'Bu yerda artikl kerak emas: ko\'plik va sanalmaydigan '
            'so\'zlar oldida (water, books) hamda atoqli otlarda '
            '(Tashkent) artikl qo\'yilmaydi.',
        source: 'diff',
      );
    }
    if (got.isEmpty && _articles.contains(want)) {
      return Explanation(
        title: 'Artikl tushib qolgan',
        text: 'Birlikdagi sanaladigan ot artiklsiz turmaydi - "$want" '
            'qo\'shiladi.',
        source: 'diff',
      );
    }
  }

  // 2) TO BE: am / is / are / was / were
  if (_beForms.contains(want) || _beForms.contains(got)) {
    if (want == 'is' || want == 'am' || want == 'are') {
      const who = {
        'am': 'I (men) bilan',
        'is': 'he / she / it va birlikdagi ot bilan',
        'are': 'you / we / they va ko\'plik bilan',
      };
      return Explanation(
        title: 'To be shakli',
        text: '"$want" - ${who[want]} ishlatiladi. Qolip: I am, he/she/it is, '
            'you/we/they are.',
        source: 'diff',
      );
    }
    if (want == 'was' || want == 'were') {
      return Explanation(
        title: 'O\'tgan zamon: was / were',
        text: '"$want" - o\'tgan zamon shakli. I/he/she/it bilan "was", '
            'you/we/they bilan "were".',
        source: 'diff',
      );
    }
  }

  // 3) FE'L SHAKLI: -s (3-shaxs birlik), -ed, -ing
  if (want.isNotEmpty && got.isNotEmpty) {
    if (want == '${got}s' || want == '${got}es') {
      return Explanation(
        title: 'Fe\'lga -s',
        text: 'Present Simple da he / she / it (va birlikdagi ot) bilan '
            'fe\'lga -s qo\'shiladi: he works, she goes. To\'g\'risi: "$want".',
        source: 'diff',
      );
    }
    if (got == '${want}s' || got == '${want}es') {
      return Explanation(
        title: 'Ortiqcha -s',
        text: 'I / you / we / they bilan fe\'l -s SIZ turadi: they work. '
            'Shuningdek do/does, can kabi yordamchidan keyin ham asl shakl '
            'keladi: he doesn\'t work.',
        source: 'diff',
      );
    }
    if (want == '${got}ed' || want == '${got}d') {
      return Explanation(
        title: 'O\'tgan zamon: -ed',
        text: 'To\'g\'ri fe\'llar o\'tgan zamonda -ed oladi: work - worked. '
            'To\'g\'risi: "$want".',
        source: 'diff',
      );
    }
    if (want == '${got}ing' || (got.isNotEmpty && want == '${got.substring(0, got.length - (got.endsWith('e') ? 1 : 0))}ing')) {
      return Explanation(
        title: 'Davomiy shakl: -ing',
        text: 'Hozir davom etayotgan ish: am/is/are + fe\'l-ing '
            '(I am working). To\'g\'risi: "$want".',
        source: 'diff',
      );
    }
  }

  // 4) KO'PLIK
  if (want.isNotEmpty && got.isNotEmpty) {
    final gotStem =
        got.endsWith('s') ? got.substring(0, got.length - 1) : got;
    if (_irregularPlural[got] == want || _irregularPlural[gotStem] == want) {
      return Explanation(
        title: 'Tartibsiz ko\'plik',
        text: '"$gotStem" ning ko\'pligi -s bilan emas: "$want". Bunday so\'zlar '
            'yod olinadi: child-children, man-men, person-people.',
        source: 'diff',
      );
    }
    if (_irregularPlural.containsValue(got) &&
        _irregularPlural[want] == got) {
      return Explanation(
        title: 'Birlik shakli kerak',
        text: 'Bu yerda birlik shakl turishi kerak: "$want".',
        source: 'diff',
      );
    }
  }

  // 5) YORDAMChI FE'L
  if (_auxForms.contains(want) && want != got) {
    if (want == 'does' || want == 'do') {
      return Explanation(
        title: 'do / does',
        text: 'Savol va inkorda: he/she/it bilan "does", qolganlari bilan '
            '"do" (Does she work? They don\'t work).',
        source: 'diff',
      );
    }
    return Explanation(
      title: 'Yordamchi fe\'l',
      text: 'Bu yerda "$want" yordamchi fe\'li kerak. Yordamchidan keyin '
          'asosiy fe\'l ASL shaklida turadi.',
      source: 'diff',
    );
  }

  // 6) PREDLOG
  if (_prepositions.contains(want) || _prepositions.contains(got)) {
    const hint = {
      'in': 'in - ichida, katta joy va oy/yil: in Tashkent, in May',
      'on': 'on - ustida, kun va sana: on Monday, on the table',
      'at': 'at - aniq nuqta va soat: at home, at 5 o\'clock',
      'to': 'to - yo\'nalish: go to school',
      'from': 'from - qayerdan: from Uzbekistan',
      'for': 'for - kim/nima uchun, muddat: for me, for two hours',
      'of': 'of - qarashlilik: a cup of tea',
      'with': 'with - bilan (birga): with my friend',
    };
    return Explanation(
      title: 'Predlog',
      text: hint[want] != null
          ? 'To\'g\'ri predlog - "$want". ${hint[want]}.'
          : 'Bu yerda "$want" predlogi kerak. Predloglar ibora bilan birga '
              'yod olinadi.',
      source: 'diff',
    );
  }

  // 7) OLMOSh
  if (_pronouns.contains(want) && _pronouns.contains(got)) {
    return Explanation(
      title: 'Olmosh',
      text: 'Bu yerda "$want" olmoshi kerak. Egalik: my/your/his/her, '
          'ega: I/you/he/she, to\'ldiruvchi: me/you/him/her.',
      source: 'diff',
    );
  }

  // 8) SO'Z TARTIBI — so'zlar bir xil, joylashuvi boshqacha
  final ga = _words(given)..sort();
  final cb = _words(correct)..sort();
  if (ga.length == cb.length && ga.join(' ') == cb.join(' ')) {
    return const Explanation(
      title: 'So\'z tartibi',
      text: 'So\'zlar to\'g\'ri, lekin TARTIB boshqacha. Inglizchada odatdagi '
          'tartib: EGA + FE\'L + TO\'LDIRUVChI (I read books). Savolda '
          'yordamchi oldinga chiqadi: Do you read books?',
      source: 'diff',
    );
  }

  // 9) IMLO — bitta-ikkita harf farqi
  if (want.isNotEmpty && got.isNotEmpty) {
    final dist = _lev(got, want);
    if ((dist == 1 && want.length >= 3) || (dist <= 2 && want.length >= 5)) {
      return Explanation(
        title: 'Imlo',
        text: 'Deyarli to\'g\'ri! "$got" emas, "$want" - harflarni diqqat '
            'bilan solishtiring.',
        source: 'diff',
      );
    }
  }

  // 10) SO'Z TUShIB QOLGAN / ORTIQCHA
  final gl = _words(given).length;
  final cl = _words(correct).length;
  if (gl < cl) {
    return Explanation(
      title: 'So\'z tushib qolgan',
      text: 'Javobingizda ${cl - gl} ta so\'z yetishmayapti. To\'liq gapda '
          'ega ham, fe\'l ham bo\'lishi kerak.',
      source: 'diff',
    );
  }
  if (gl > cl) {
    return Explanation(
      title: 'Ortiqcha so\'z',
      text: 'Javobingizda ${gl - cl} ta ortiqcha so\'z bor. Inglizchada '
          'takror ega yoki ortiqcha yordamchi qo\'yilmaydi.',
      source: 'diff',
    );
  }

  // 11) BOShQA SO'Z
  if (want.isNotEmpty) {
    return Explanation(
      title: 'Boshqa so\'z',
      text: '"$got" emas, "$want" kerak edi. So\'zning ma\'nosini va '
          'ishlatilishini eslab qoling.',
      source: 'diff',
    );
  }
  return null;
}

/// TARJIMA — to'g'ri javobning o'zbekchasi.
///
/// Qoidani tushunish uchun avval MA'NOni bilish kerak: o'quvchi
/// "an apple" nega "an" ekanini o'qishdan oldin uning "olma" ekanini
/// bilishi shart. [uz] - banddagi tayyor tarjima; bo'lmasa [lookup]
/// orqali lug'atdan so'zma-so'z qidiriladi.
Explanation? translationOf(
  String correct, {
  String uz = '',
  String Function(String word)? lookup,
}) {
  final answer = correct.trim();
  if (answer.isEmpty) return null;

  final ready = uz.trim();
  if (ready.isNotEmpty && _norm(ready) != _norm(answer)) {
    return Explanation(
      title: 'Tarjima',
      text: '"$answer" - $ready',
      source: 'tr',
    );
  }
  // Avval HAQIQIY lug'at (mazmunli so'zlar), topilmasa - xizmatchi
  // so'zlar lug'ati. Gapda "an - bitta (unli oldidan)" kabi izohlar
  // asosiy ma'noni bosib ketmasin.
  String meaning(String w, {bool core = false}) {
    final fromDict = lookup?.call(w).trim() ?? '';
    if (fromDict.isNotEmpty) return fromDict;
    return core ? (kCoreWords[w] ?? '') : '';
  }

  // Gap bo'lsa - har bir so'zning ma'nosi (bilmagan so'zi topilsin).
  final words = _words(answer);
  List<String> collect({required bool core}) {
    final out = <String>[];
    final seen = <String>{};
    for (final w in words) {
      if (seen.contains(w)) continue;
      final m = meaning(w, core: core);
      if (m.isEmpty) continue;
      seen.add(w);
      out.add('$w - $m');
      if (out.length >= 6) break;
    }
    return out;
  }

  var parts = collect(core: false);
  if (parts.isEmpty) parts = collect(core: true);
  if (parts.isEmpty) return null;
  return Explanation(
    title: parts.length == 1 ? 'Tarjima' : "So'zlar ma'nosi",
    text: parts.join(' · '),
    source: 'tr',
  );
}

/// TO'LIQ TUShUNTIRISh — barcha manbalardan eng foydalisi.
///
/// [whyUz] — kitobning o'z izohi (bo'lsa, birinchi o'rinda).
/// [ruleUz] — bo'lim/mashq qoidasi (`explanationUz`).
/// [given] — o'quvchi javobi, [correct] — to'g'ri javob.
/// [uz] — banddagi tarjima, [lookup] — lug'atdan so'z ma'nosi.
List<Explanation> explainAnswer({
  required String correct,
  String given = '',
  String whyUz = '',
  String ruleUz = '',
  String uz = '',
  String Function(String word)? lookup,
  bool isCorrect = false,
}) {
  final out = <Explanation>[];

  // TARJIMA birinchi: ma'nosiz qoida yodda qolmaydi.
  final tr = translationOf(correct, uz: uz, lookup: lookup);
  if (tr != null) out.add(tr);

  if (whyUz.trim().isNotEmpty) {
    out.add(Explanation(
        title: 'Izoh', text: whyUz.trim(), source: 'book'));
  }

  if (!isCorrect) {
    final d = explainDiff(given, correct);
    if (d != null) out.add(d);
  }

  if (out.where((e) => e.source != 'tr').isEmpty &&
      ruleUz.trim().isNotEmpty) {
    // Qoida uzun bo'lishi mumkin - birinchi 2 jumla yetadi.
    final r = ruleUz.trim();
    final cut = r.length > 320 ? '${r.substring(0, 317)}...' : r;
    out.add(Explanation(title: 'Qoida', text: cut, source: 'rule'));
  }

  if (out.where((e) => e.source != 'tr').isEmpty &&
      !isCorrect &&
      correct.trim().isNotEmpty) {
    out.add(Explanation(
      title: 'To\'g\'ri javob',
      text: '"${correct.trim()}" - shu variantni ovoz chiqarib o\'qing va '
          'yodda tuting.',
      source: 'answer',
    ));
  }

  return out;
}
