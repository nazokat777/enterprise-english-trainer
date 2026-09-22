import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../book_content.dart';
import '../../content.dart';
import '../../drill/drill_screen.dart' show OptionTile, OptionState;
import '../../main.dart';
import '../../stats.dart';
import '../../teach/explain_card.dart';
import '../../teach/vocab_lookup.dart';
import '../../theme.dart';
import '../../services/speech.dart';
import '../../services/tts.dart';
import '../../speak/role_play_screen.dart';
import '../../reward/reward_engine.dart';
import '../../reward/reward_widgets.dart';
import '../../widgets/correct_burst.dart';
import '../../widgets/entrance.dart';
import '../../widgets/explain_text.dart';
import '../../widgets/pressable3d.dart';
import '../pack/pack_flow.dart' show RoundPlay;
import 'type_stage.dart';

/// Bitta mashqni o'ynatadi. 4 xil o'yin turi:
/// choice (tanlash) · text (yig'ish) · match (moslash) · study (o'qish).
class ExercisePlayer extends StatefulWidget {
  final BookExercise exercise;
  final String sectionTitle;

  /// Unit yorlig'i — sarlavhada to'liq manzil ko'rsatish uchun
  /// ("3-unit" yoki hikoya betlarida "1-epizod"). Bo'sh bo'lsa
  /// faqat kitob va bet ko'rsatiladi.
  final String unitLabel;

  /// Shu bo'limdagi barcha mashqlar — natija ekranida "Keyingi mashq"
  /// zanjiri uchun (o'quvchi ro'yxatga qaytmasdan davom etsin).
  final List<BookExercise> siblings;

  /// Unitdagi jami mashqlar — "unit tugadi" nishonlashi uchun.
  final int? unitTotal;

  const ExercisePlayer({
    super.key,
    required this.exercise,
    required this.sectionTitle,
    this.unitLabel = '',
    this.siblings = const [],
    this.unitTotal,
  });

  @override
  State<ExercisePlayer> createState() => _ExercisePlayerState();
}

class _ExercisePlayerState extends State<ExercisePlayer> {
  /// So'raladigan bandlar NAVBATI (band indekslari).
  ///
  /// Ilgari bandlar 0 dan oxirigacha BIR MARTA so'ralardi: xato javob
  /// shunchaki o'tib ketardi va o'quvchi o'sha bandni boshqa ko'rmasdi.
  /// Endi xato qilingan band navbatga QAYTADI va mashq faqat HAMMA band
  /// to'g'ri javob berilgandan keyin tugaydi — ya'ni o'quvchi mavzuni
  /// o'zlashtirmaguncha mashq tugamaydi.
  final List<int> _queue = <int>[];

  /// Navbatdagi o'rin.
  int _pos = 0;

  /// Joriy band OLTIN SAVOLmi (XP ×3) — sahna boshida qur'a.
  bool _golden = false;

  /// Joriy band qachon ko'rsatildi — tezlik bonusi uchun.
  DateTime _shownAt = DateTime.now();
  int _shownFor = -1;

  void _armQuestion() {
    if (_shownFor == _index) return;
    _shownFor = _index;
    _shownAt = DateTime.now();
    _golden = rewards.rollGolden();
  }

  /// To'g'ri javob berilgan bandlar.
  final Set<int> _mastered = <int>{};

  /// Har bir band bo'yicha xato soni — natijada ko'rsatiladi.
  final Map<int, int> _misses = <int, int>{};

  /// Uzun ko'rsatma to'liq ochilganmi.
  bool _instrOpen = false;

  /// Moslash mashqida topilgan juftlar — sarlavhadagi chiziq uchun.
  int _matchDone = 0;

  int _correct = 0;
  int _xp = 0;
  bool _done = false;

  BookExercise get ex => widget.exercise;

  @override
  void initState() {
    super.initState();
    _queue.addAll(List<int>.generate(ex.tasks.length, (i) => i));
    // "Davom etish" uchun joyni eslab qolamiz: o'quvchi 1545 mashq
    // ichida qayerda qolganini o'zi eslashi shart emas.
    progress.rememberExercise(
      unit: ex.unitNo,
      id: ex.progressId,
      label: '${widget.sectionTitle} · ${ex.title}',
    );
  }

  /// Oxirgi yozilgan/tanlangan javob — xatolar daftariga tushadi va
  /// tushuntirish shundan chiqariladi.
  String _lastGiven = '';

  /// Hozir so'ralayotgan bandning indeksi.
  int get _index =>
      _queue.isEmpty ? 0 : _queue[_pos.clamp(0, _queue.length - 1)];

  /// Xato qilingan band navbatga QAYTADI.
  ///
  /// Darhol emas — orasiga bir necha boshqa band qo'yiladi, aks holda
  /// o'quvchi javobni eslab qoladi, tushunib emas. Navbat oxiriga ham
  /// tashlanmaydi: uzoq mashqda band juda kech qaytardi.
  void _requeue(int taskIndex) {
    const gap = 3;
    final at = (_pos + gap).clamp(0, _queue.length);
    _queue.insert(at, taskIndex);
  }

  @override
  void dispose() {
    Tts.instance.stop();
    super.dispose();
  }

  /// Band yakunlandi: XP va SRS (lug'at ko'nikmasi).
  Future<void> _answered(bool ok, {bool nearMiss = false, String given = ''}) async {
    _lastGiven = given;
    final taskIndex = _index;
    final firstTime = !_mastered.contains(taskIndex);
    final elapsed = DateTime.now().difference(_shownAt);
    final base = _golden ? 2 * RewardEngine.goldenMultiplier : 2;

    final task = ex.tasks[taskIndex];
    if (ok) {
      _mastered.add(taskIndex);
      if (firstTime) _correct++;
      // Xatolar daftaridagi band to'g'ri topildi — o'chadi.
      if (_misses[taskIndex] == null) mistakes.resolve(task);
      // XP faqat BIRINCHI to'g'ri javob uchun — xato qilib, keyin
      // qayta topgan band uchun ikki marta ball berilmasin.
      if (firstTime && _misses[taskIndex] == null) {
        // Dvigatel KRIT/kombo/tezlik bonusini qaytaradi — u ham XP ga
        // qo'shiladi.
        final bonus = rewards.onAnswer(true, baseXp: base, elapsed: elapsed);
        _xp += base + bonus;
        await progress.addXp(base + bonus, skill: _skillOf(ex));
      } else {
        rewards.onAnswer(true, baseXp: 0);
      }
    } else {
      rewards.onAnswer(false, nearMiss: nearMiss);
      _misses[taskIndex] = (_misses[taskIndex] ?? 0) + 1;
      // Xatolar daftari — keyin alohida ishlash uchun.
      mistakes.add(task,
          source: ex.bookRef.isNotEmpty ? ex.bookRef : widget.sectionTitle,
          given: _lastGiven);
      await _noteWeakWord(ex.tasks[taskIndex]);
    }

    if (!mounted) return;
    setState(() {
      if (!ok) _requeue(taskIndex);
      _pos++;
      if (_mastered.length >= ex.tasks.length || _pos >= _queue.length) {
        _done = true;
        _finish();
      }
    });
  }

  /// Kitob mashqida xato qilingan band lug'atdagi so'zga tegishli
  /// bo'lsa, o'sha so'z "qiyin" hisobiga qo'shiladi.
  ///
  /// Ilgari faqat lug'at mashqlari hisobga olinardi: o'quvchi kitob
  /// mashqlarida bir xil so'zda qayta-qayta qoqilsa ham, "Qiyin
  /// so'zlar" ro'yxatida u ko'rinmasdi.
  Future<void> _noteWeakWord(ExTask t) async {
    final ids = repo.forLevel(progress.currentLevel).idByEn;
    // Javob inglizcha bo'lsa — o'sha, aks holda savol matni.
    for (final candidate in [t.answer, t.right, t.prompt, t.en]) {
      final key = normalizeWord(candidate);
      if (key.isEmpty || key.contains(' ')) continue; // faqat bitta so'z
      final id = ids[key];
      if (id != null) {
        await progress.recordMiss(id);
        return;
      }
    }
  }

  Skill _skillOf(BookExercise e) {
    if (e.audio) return Skill.listening;
    return switch (e.kind) {
      ExKind.match => Skill.vocab,
      ExKind.text => Skill.grammar,
      _ => Skill.vocab,
    };
  }

  /// Mashq XATOSIZ o'tildimi.
  ///
  /// Moslash rejimida bandlar `_MatchStage` ichida sanaladi va
  /// `_misses` bo'sh qoladi — shu sababli xato qilingan moslash mashqi
  /// ham "xatosiz" deb yozilardi va "Takrorlash kerak" ro'yxatiga
  /// tushmasdi.
  bool get _cleanRun =>
      ex.kind == ExKind.match ? _correct >= ex.tasks.length : _misses.isEmpty;

  void _finish() {
    final id = ex.progressId;
    final first = !progress.isDone(id);
    // Xatosiz o'tilganda mashq O'ZLAShTIRILGAN hisoblanadi. Aks holda
    // u "takrorlash kerak" bo'lib qoladi va ro'yxatda shunday
    // ko'rsatiladi — bir marta ochib chiqish yetarli emas.
    progress.markExerciseResult(
      id,
      clean: _cleanRun,
      unit: ex.unitNo,
      unitTotal: widget.unitTotal,
      unitLabel: widget.unitLabel,
    );
    if (ex.kind != ExKind.study) {
      rewards.onExerciseDone(clean: _cleanRun);
      if (ex.kind == ExKind.match) rewards.onWordLearned(_correct);
    }
    if (first) {
      progress.addXp(3); // mashqni tugatgani uchun bonus
      _xp += 3;
    }
  }

  /// Mashq o'rtasida chiqib ketish — Zeigarnik: "yana N ta qoldi".
  /// Faqat boshlangan-u tugamagan mashqda so'raladi.
  bool get _midway =>
      !_done &&
      ex.kind != ExKind.study &&
      (_mastered.isNotEmpty || _misses.isNotEmpty || _matchDone > 0);

  Future<bool> _confirmLeave() async {
    final left = ex.kind == ExKind.match
        ? ex.tasks.length - _matchDone
        : ex.tasks.length - _mastered.length;
    final combo = rewards.combo;
    final stay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Yana $left ta band qoldi'),
        content: Text(
          combo >= 3
              ? '$combo lik komboingiz yo\'qoladi. Tugatib qo\'ymaysizmi?'
              : (left <= 5
                    ? 'Oz qoldi — tugatib qo\'ymaysizmi?'
                    : 'Boshlangan ish chala qolmasin — davom etamizmi?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Chiqish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Davom etaman'),
          ),
        ],
      ),
    );
    return stay != true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_midway,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) nav.pop();
      },
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.sectionTitle} · ${ex.title}',
              style: const TextStyle(fontSize: 17),
            ),
            // Qaysi kitobning qaysi beti — o'quvchi adashmasin.
            Text(
              widget.unitLabel.isNotEmpty
                  ? ex.locationLabel(widget.unitLabel)
                  : ex.sourceLabel,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.brandPurple,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.coin.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '⚡ $_xp XP',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.coin,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (ex.tasks.isEmpty) {
      return const Center(child: Text('Bu mashqda band yo\'q'));
    }
    if (_done) return _result();

    return Column(
      children: [
        _header(),
        Expanded(child: _stage()),
      ],
    );
  }

  Widget _header() {
    final simple = ex.kind == ExKind.study || ex.kind == ExKind.match;
    final total = simple ? 1 : ex.tasks.length;
    // Chiziq NAVBATDAGI o'rinni emas, O'ZLAShTIRILGAN bandlarni
    // ko'rsatadi: xato qilinsa u orqaga qaytadi va bu halol.
    //
    // Moslashda chiziq ilgari BOShIDANOQ to'la turardi — 50 juftlik
    // lug'at ro'yxatida o'quvchi qancha qolganini bilolmasdi.
    final value = ex.kind == ExKind.match
        ? (ex.tasks.isEmpty ? 1.0 : _matchDone / ex.tasks.length)
        : (simple ? 1.0 : _mastered.length / total);
    // Bu band ilgari xato qilinganmi — o'quvchi qaytganini bilsin.
    final repeat = !simple && (_misses[_index] ?? 0) > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: AppColors.actionBlue.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.actionBlue,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                // Ba'zi ko'rsatmalar juda uzun (280 belgigacha). Tor
                // telefonda ular sarlavhani cho'zib, o'yin joyini
                // siqib qo'yardi — "RenderFlex overflowed" chizig'i
                // chiqardi. Endi uch qatorgacha ko'rsatiladi, bosilsa
                // to'liq ochiladi (matn yo'qolmaydi).
                child: GestureDetector(
                  onTap: () => setState(() => _instrOpen = !_instrOpen),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: _instrOpen
                          ? MediaQuery.of(context).size.height * 0.3
                          : double.infinity,
                    ),
                    child: SingleChildScrollView(
                      physics: _instrOpen
                          ? null
                          : const NeverScrollableScrollPhysics(),
                      child: Text(
                        ex.instructionUz,
                        maxLines: _instrOpen ? null : 3,
                        overflow: _instrOpen
                            ? TextOverflow.clip
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (repeat)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.homework.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.replay_rounded,
                          size: 13,
                          color: AppColors.homework,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'takror',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.homework,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!simple)
                Text(
                  '${_mastered.length} / ${ex.tasks.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted(context),
                  ),
                ),
            ],
          ),
          if (ex.bookRef.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '📖 ${ex.bookRef}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.brandPurple,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stage() {
    if (ex.kind == ExKind.choice || ex.kind == ExKind.text) _armQuestion();
    switch (ex.kind) {
      case ExKind.choice:
        return _ChoiceStage(
          key: ValueKey('c$_index'),
          golden: _golden,
          task: ex.tasks[_index],
          explanation: _index == 0 ? ex.explanationUz : '',
          // Audio izohi HAR BIR bandda ko'rinadi: u mashqni qanday
          // yechish kerakligini aytadi ("javoblarni 4-mashqdan
          // toping"), shuning uchun uni bir marta ko'rsatish yetarli
          // emas.
          audioNote: ex.audioNoteUz,
          onDone: _answered,
        );
      case ExKind.text:
        if (ex.tasks[_index].typed) {
          return TypeStage(
            key: ValueKey('y$_index'),
            golden: _golden,
            task: ex.tasks[_index],
            explanation: _index == 0 ? ex.explanationUz : '',
            audioNote: ex.audioNoteUz,
            onDone: _answered,
            onNearMiss: () => _answered(false, nearMiss: true),
          );
        }
        return _BuildStage(
          key: ValueKey('t$_index'),
          golden: _golden,
          task: ex.tasks[_index],
          explanation: _index == 0 ? ex.explanationUz : '',
          audioNote: ex.audioNoteUz,
          onDone: _answered,
          onNearMiss: () => _answered(false, nearMiss: true),
        );
      case ExKind.match:
        return _MatchStage(
          tasks: ex.tasks,
          explanation: ex.explanationUz,
          audioNote: ex.audioNoteUz,
          onProgress: (done, total) {
            if (mounted) setState(() => _matchDone = done);
          },
          onDone: (right) {
            _correct = right;
            // XATO edi: moslash faqat mashq bonusini (+3) berardi.
            // Tanlash mashqi esa HAR BAND uchun +2 beradi — natijada
            // 50 juftlik lug'at ro'yxatini moslash 3 XP, to'rt bandli
            // kichik mashq esa 11 XP olib kelardi.
            _xp += right * 2;
            progress.addXp(right * 2, skill: _skillOf(ex));
            setState(() {
              _done = true;
              _finish();
            });
          },
        );
      case ExKind.study:
        return _StudyStage(
          exercise: ex,
          onDone: () => setState(() {
            _done = true;
            _finish();
          }),
          // ROL O'YNASH - dialog bo'lsa va brauzer nutq tanishni qo'llasa.
          onRolePlay: Speech.supported && DialogueLine.of(ex).isNotEmpty
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RolePlayScreen(
                        exercise: ex,
                        title: 'Rol o\'ynash · ${widget.unitLabel}',
                      ),
                    ),
                  )
              : null,
          onMemorize: ex.tasks.any((t) => t.en.trim().isNotEmpty)
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExercisePlayer(
                        exercise: memorizeExerciseFrom(ex),
                        sectionTitle: '${widget.sectionTitle} · yodlash',
                        unitLabel: widget.unitLabel,
                      ),
                    ),
                  )
              : null,
        );
    }
  }

  /// Zanjirdagi keyingi mashq: avval hali tugatilmagani, bo'lmasa
  /// ro'yxatdagi navbatdagisi.
  BookExercise? get _nextExercise {
    final sib = widget.siblings;
    final i = sib.indexWhere((e) => e.progressId == ex.progressId);
    if (i < 0) return null;
    for (var k = i + 1; k < sib.length; k++) {
      if (!progress.isDone(sib[k].progressId)) return sib[k];
    }
    return i + 1 < sib.length ? sib[i + 1] : null;
  }

  Widget _result() {
    final total = ex.tasks.length;
    // Mashq faqat HAMMA band o'zlashtirilganda tugaydi, shuning uchun
    // natija "nechtasini BIRINCHI urinishda topdi" degani.
    final clean = total - _misses.length;
    final retried = _misses.length;
    // XATO edi: mezon faqat `_mastered` bo'lgan, moslash rejimida esa
    // u HECH QAChON to'ldirilmaydi (juftlar `_MatchStage` ichida
    // sanaladi). Shu sababli barcha juftni xatosiz moslagan o'quvchi
    // ham to'q sariq "qayta urinish" belgisini ko'rardi.
    // "O'zlashtirildi" — HAMMA band oxir-oqibat to'g'ri bajarilgan.
    // Bu `_cleanRun` dan FARQ qiladi: xato qilib, keyin topgan
    // o'quvchi ham mashqni o'zlashtirgan hisoblanadi, lekin mashq
    // baribir "takrorlash kerak" ro'yxatida qoladi.
    //
    // Moslash bosqichi faqat HAMMA juft topilganda tugaydi, shuning
    // uchun u yerda bu doim rost.
    final good = switch (ex.kind) {
      ExKind.study => true,
      ExKind.match => true,
      _ => _mastered.length >= total,
    };
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: good ? AppColors.success : AppColors.homework,
            ),
            child: Icon(
              good ? Icons.check_rounded : Icons.replay_rounded,
              color: Colors.white,
              size: 58,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            ex.kind == ExKind.study
                ? 'O\'qib chiqdingiz'
                : (good ? 'O\'zlashtirildi' : '$_correct / $total'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: good ? AppColors.success : AppColors.homework,
            ),
          ),
        ),
        if (ex.kind != ExKind.study) ...[
          const SizedBox(height: 16),
          ResultStatsRow(xp: _xp, clean: _cleanRun),
        ],
        // Moslashda bandlar `_MatchStage` ichida sanaladi — nechtasi
        // birinchi urinishda topilgani `_correct` da.
        if (ex.kind == ExKind.match && _correct < total) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              '$_correct / $total birinchi urinishda · '
              '${total - _correct} ta juft takrorlandi',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
            ),
          ),
        ],
        if (ex.kind != ExKind.study &&
            ex.kind != ExKind.match &&
            retried > 0) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              '$clean / $total birinchi urinishda · '
              '$retried ta band takrorlandi',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.coin.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '+$_xp XP',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.coin,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        // ZANJIR: "yana bitta" — ro'yxatga qaytish o'rniga to'g'ridan-
        // to'g'ri keyingi mashq. Chiqish nuqtasi qancha kam bo'lsa,
        // sessiya shuncha uzun.
        if (_nextExercise != null) ...[
          Pressable3D(
            color: AppColors.success,
            shadowColor: const Color(0xFF15803D),
            onPressed: () {
              final n = _nextExercise!;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ExercisePlayer(
                    exercise: n,
                    sectionTitle: widget.sectionTitle,
                    unitLabel: widget.unitLabel,
                    siblings: widget.siblings,
                    unitTotal: widget.unitTotal,
                  ),
                ),
              );
            },
            child: Center(
              child: Text(
                'Keyingi mashq: ${_nextExercise!.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Pressable3D(
          color: AppColors.brandPurple,
          shadowColor: const Color(0xFF5B22B5),
          onPressed: () => Navigator.pop(context),
          child: const Center(
            child: Text(
              'Bo\'limga qaytish',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
        if (ex.kind != ExKind.study) ...[
          const SizedBox(height: 12),
          Pressable3D(
            color: AppColors.actionBlue,
            onPressed: () => setState(() {
              // Boshidan: navbat qayta tuziladi, o'zlashtirilganlar
              // tozalanadi.
              _queue
                ..clear()
                ..addAll(List<int>.generate(ex.tasks.length, (i) => i));
              _pos = 0;
              _mastered.clear();
              _misses.clear();
              _correct = 0;
              _done = false;
            }),
            child: const Center(
              child: Text(
                'Qayta ishlash',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Mashq bandining vizuali. Kitob rasmlari mualliflik huquqi bilan
/// himoyalangan, shuning uchun ko'chirilmaydi. O'rniga:
///   * emoji — buyum/kasb uchun (offline, bepul)
///   * `assets/...` yo'li — erkin litsenziyali rasm bo'lsa
class TaskVisual extends StatelessWidget {
  final String visual;
  final double size;
  const TaskVisual({super.key, required this.visual, this.size = 72});

  bool get _isAsset => visual.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    if (visual.isEmpty) return const SizedBox.shrink();
    if (_isAsset) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.asset(
          visual,
          height: size * 2.1,
          fit: BoxFit.cover,
          // Fayllar to'liq o'lchamda (1500px gacha), ekranda esa
          // ~150px ko'rinadi. `cacheHeight` siz butun rasm xotiraga
          // ochilardi — arzon telefonda behuda yuk.
          cacheHeight: (size * 2.1 * 3).round(),
          // Rasm topilmasa ilova buzilmasin.
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }
    return Text(visual, style: TextStyle(fontSize: size));
  }
}

/// AUDIO IZOHI — "kitobda shu yerda audio bor, javoblarni N-mashqdan
/// toping" kabi yo'l-yo'riq.
///
/// Ilgari bu izoh FAQAT o'qish (study) rejimida chiqardi. 30 ta
/// mashqda esa u tanlash/yozish/moslash rejimida edi va o'quvchi uni
/// umuman ko'rmasdi — mashq javobsizdek tuyulardi.
class AudioNoteCard extends StatelessWidget {
  final String text;
  const AudioNoteCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.homework.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.headphones_rounded,
            size: 18,
            color: AppColors.homework,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════ Izoh kartasi (barcha turlar uchun) ═══════════════
class ExplanationCard extends StatelessWidget {
  final String text;
  const ExplanationCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandPurple.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
          left: BorderSide(color: AppColors.brandPurple, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 18,
            color: AppColors.brandPurple,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ExplainText(
              text,
              style: const TextStyle(fontSize: 13.5, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════ 1) Tanlash ═══════════════
class _ChoiceStage extends StatefulWidget {
  final ExTask task;
  final String explanation;
  final String audioNote;
  final void Function(bool ok, {String given}) onDone;
  final bool golden;

  const _ChoiceStage({
    super.key,
    required this.task,
    required this.explanation,
    this.audioNote = '',
    required this.onDone,
    this.golden = false,
  });

  @override
  State<_ChoiceStage> createState() => _ChoiceStageState();
}

class _ChoiceStageState extends State<_ChoiceStage> {
  final _rnd = Random();
  late List<String> _options;
  String? _chosen;
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    _options = List.of(widget.task.options)..shuffle(_rnd);
    if (_options.isEmpty) _options = [widget.task.answer];
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  void _tap(String o) {
    if (_chosen != null) return;
    final ok = widget.task.isCorrect(o);
    setState(() => _chosen = o);
    if (ok) showCorrectBurst(context, text: cheer(_rnd));
    Tts.instance.speak(widget.task.speakAnswer, id: 'ex');
    _advance = Timer(Duration(milliseconds: ok ? 900 : 1900), () {
      if (mounted) widget.onDone(ok, given: o);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        ExplanationCard(text: widget.explanation),
        AudioNoteCard(text: widget.audioNote),
        if (widget.golden) const GoldenBanner(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.3 : 0.05),
                blurRadius: 14,
              ),
            ],
          ),
          child: Column(
            children: [
              if (t.visual.isNotEmpty) ...[
                TaskVisual(visual: t.visual),
                const SizedBox(height: 12),
              ],
              Text(
                t.prompt,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: t.prompt.length > 40 ? 17 : 24,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                  color: dark ? AppColors.darkHeading : AppColors.lightHeading,
                ),
              ),
              if (t.promptUz.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  t.promptUz,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.muted(context),
                  ),
                ),
              ],
              if (t.canSpeak) ...[
                const SizedBox(height: 12),
                RoundPlay(text: t.speakText),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Variantlar birin-ketin "kirib keladi" (stagger) — ko'z
        // harakatni kuzatadi, e'tibor tortiladi.
        for (var i = 0; i < _options.length; i++)
          EntranceFade(
            delay: Duration(milliseconds: 60 * i),
            offsetY: 12,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OptionTile(
                index: i,
                text: _options[i],
                state: _chosen == null
                    ? OptionState.idle
                    : t.isCorrect(_options[i])
                        ? OptionState.right
                        : _options[i] == _chosen
                            ? OptionState.wrong
                            : OptionState.dim,
                onTap: _chosen == null ? () => _tap(_options[i]) : null,
              ),
            ),
          ),
        // Har xato TUShUNTIRILADI: kitob izohi bo'lmasa ham qoida
        // javob bilan to'g'ri variant farqidan chiqariladi.
        if (_chosen != null)
          ExplainCard.forAnswer(
            correct: t.answer,
            given: _chosen!,
            whyUz: t.whyUz,
            ruleUz: widget.explanation,
            uz: t.uz.isNotEmpty ? t.uz : t.promptUz,
            lookup: meaningOf,
            isCorrect: t.isCorrect(_chosen!),
          ),
      ],
    );
  }

}

// ═══════════════ 2) Yig'ish ═══════════════
class _BuildStage extends StatefulWidget {
  final ExTask task;
  final String explanation;
  final String audioNote;
  final void Function(bool ok, {String given}) onDone;
  final VoidCallback? onNearMiss;
  final bool golden;

  const _BuildStage({
    super.key,
    required this.task,
    required this.explanation,
    this.audioNote = '',
    required this.onDone,
    this.onNearMiss,
    this.golden = false,
  });

  @override
  State<_BuildStage> createState() => _BuildStageState();
}

class _BuildStageState extends State<_BuildStage> {
  final _rnd = Random();
  late List<String> _pieces;
  final List<int> _picked = [];
  bool? _result;
  bool _near = false;

  /// Levenshtein masofasi (kichik satrlar uchun yetarli).
  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    final m = a.length, n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;
    var prev = List<int>.generate(n + 1, (j) => j);
    for (var i = 1; i <= m; i++) {
      final cur = List<int>.filled(n + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      prev = cur;
    }
    return prev[n];
  }

  Timer? _advance;

  @override
  void initState() {
    super.initState();
    final target = widget.task.buildPieces;
    final s = List.of(target)..shuffle(_rnd);
    if (s.join() == target.join() && target.length > 1) s.shuffle(_rnd);
    _pieces = s;
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  void _tap(int i) {
    if (_result != null || _picked.contains(i)) return;
    setState(() => _picked.add(i));
    if (_picked.length == _pieces.length) _check();
  }

  void _undo() {
    if (_result != null || _picked.isEmpty) return;
    setState(() => _picked.removeLast());
  }

  void _check() {
    final built = _picked
        .map((k) => _pieces[k])
        .join(widget.task.buildSeparator);
    final ok = widget.task.isCorrect(built);
    // YAQIN XATO: bitta belgi farq — "deyarli" deb aytiladi (near-miss).
    final near =
        !ok &&
        widget.onNearMiss != null &&
        _editDistance(built.toLowerCase(), widget.task.answer.toLowerCase()) <=
            1;
    setState(() {
      _result = ok;
      _near = near;
    });
    if (ok) showCorrectBurst(context, text: cheer(_rnd));
    Tts.instance.speak(widget.task.speakAnswer, id: 'ex');
    _advance = Timer(Duration(milliseconds: ok ? 950 : 2100), () {
      if (!mounted) return;
      if (near) {
        widget.onNearMiss!();
      } else {
        widget.onDone(ok, given: built);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final built = _picked.map((k) => _pieces[k]).join(t.buildSeparator);
    final long = _pieces.length > 12;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        ExplanationCard(text: widget.explanation),
        AudioNoteCard(text: widget.audioNote),
        if (widget.golden) const GoldenBanner(),
        if (_near) const NearMissNote(),
        if (t.visual.isNotEmpty) ...[
          Center(child: TaskVisual(visual: t.visual, size: 64)),
          const SizedBox(height: 12),
        ],
        Center(
          child: Text(
            t.prompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: t.prompt.length > 40 ? 16 : 22,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (t.promptUz.isNotEmpty) ...[
          const SizedBox(height: 6),
          Center(
            child: Text(
              t.promptUz,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
            ),
          ),
        ],
        if (t.canSpeak) ...[
          const SizedBox(height: 14),
          Center(child: RoundPlay(text: t.speakText, size: 48)),
        ],
        const SizedBox(height: 18),
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _result == null
                  ? Colors.black26
                  : _result!
                  ? AppColors.success
                  : AppColors.danger,
              width: 2,
            ),
          ),
          child: Text(
            built.isEmpty ? '…' : built,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: t.isPhrase ? 17 : 24,
              fontWeight: FontWeight.w800,
              letterSpacing: t.isPhrase ? 0 : 2,
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: _result == false
              ? Center(
                  child: Text(
                    'To\'g\'risi: ${t.answer}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : _picked.isNotEmpty
              ? Center(
                  child: TextButton.icon(
                    onPressed: _undo,
                    icon: const Icon(Icons.backspace_outlined, size: 18),
                    label: const Text('Orqaga'),
                  ),
                )
              : const SizedBox(),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _pieces.length; i++)
              GestureDetector(
                onTap: () => _tap(i),
                child: AnimatedOpacity(
                  opacity: _picked.contains(i) ? 0.25 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.isPhrase ? 14 : 0,
                      vertical: 10,
                    ),
                    width: t.isPhrase ? null : (long ? 40 : 48),
                    height: long ? 40 : 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.brandPurple.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _pieces[i],
                      style: TextStyle(
                        fontSize: long ? 15 : 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_result != null)
          ExplainCard.forAnswer(
            correct: t.answer,
            given: built,
            whyUz: t.whyUz,
            ruleUz: widget.explanation,
            uz: t.uz.isNotEmpty ? t.uz : t.promptUz,
            lookup: meaningOf,
            isCorrect: _result!,
          ),
      ],
    );
  }
}

// ═══════════════ 3) Moslash ═══════════════
class _MatchStage extends StatefulWidget {
  final List<ExTask> tasks;
  final String audioNote;
  final String explanation;
  final ValueChanged<int> onDone;

  /// Nechta juft topilgani — sarlavhadagi chiziq uchun.
  ///
  /// Ilgari moslash mashqida chiziq BOShIDANOQ to'la ko'rinardi.
  /// Kitob oxiridagi 50 juftlik lug'at ro'yxatida bu ayniqsa
  /// aldamchi edi: o'quvchi qancha qolganini bilolmasdi.
  final void Function(int done, int total)? onProgress;

  const _MatchStage({
    required this.tasks,
    required this.explanation,
    this.audioNote = '',
    required this.onDone,
    this.onProgress,
  });

  @override
  State<_MatchStage> createState() => _MatchStageState();
}

class _MatchStageState extends State<_MatchStage> {
  /// Bir bosqichda ko'rsatiladigan juftlar soni.
  ///
  /// Lug'at ro'yxatlarida 100 dan ortiq juft bo'ladi. Hammasini bir ekranga
  /// chiqarish — cheksiz aylantirish va bir o'tirishda 116 ta moslash degani.
  /// Shuning uchun mashq kichik bosqichlarga bo'linadi.
  static const int _roundSize = 8;

  final _rnd = Random();
  late List<ExTask> _all;
  int _round = 0;
  late List<ExTask> _left;
  late List<ExTask> _right;
  final Set<String> _matched = {};
  final Set<String> _failed = {};
  String? _sel;
  String? _wrongFlash;
  Timer? _advance;
  Timer? _flash;

  @override
  void initState() {
    super.initState();
    _all = List.of(widget.tasks)..shuffle(_rnd);
    _startRound();
  }

  int get _roundCount => (_all.length + _roundSize - 1) ~/ _roundSize;

  void _startRound() {
    final start = _round * _roundSize;
    final end = min(start + _roundSize, _all.length);
    final cur = _all.sublist(start, end);
    _left = List.of(cur)..shuffle(_rnd);
    _right = List.of(cur)..shuffle(_rnd);
    _sel = null;
  }

  @override
  void dispose() {
    _advance?.cancel();
    _flash?.cancel();
    super.dispose();
  }

  void _tapRight(ExTask r) {
    final sel = _sel;
    if (sel == null || _matched.contains(r.left)) return;
    if (sel == r.left) {
      setState(() {
        _matched.add(r.left);
        _sel = null;
      });
      widget.onProgress?.call(
        _round * _roundSize + _matched.length,
        widget.tasks.length,
      );
      Tts.instance.speak(r.speakAnswer, id: r.left);
      final roundDone = _left.every((t) => _matched.contains(t.left));
      if (!roundDone) return;
      if (_round + 1 >= _roundCount) {
        _advance = Timer(const Duration(milliseconds: 650), () {
          if (mounted) {
            widget.onDone(widget.tasks.length - _failed.length);
          }
        });
      } else {
        _advance = Timer(const Duration(milliseconds: 650), () {
          if (mounted) {
            setState(() {
              _round++;
              _startRound();
            });
          }
        });
      }
    } else {
      setState(() {
        _failed.add(sel);
        _wrongFlash = r.left;
      });
      _flash = Timer(const Duration(milliseconds: 420), () {
        if (mounted) setState(() => _wrongFlash = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        ExplanationCard(text: widget.explanation),
        AudioNoteCard(text: widget.audioNote),
        if (_roundCount > 1) ...[
          Center(
            child: Text(
              '${_round + 1} / $_roundCount',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final t in _left)
                    _tile(
                      label: t.left,
                      done: _matched.contains(t.left),
                      selected: _sel == t.left,
                      onTap: () {
                        if (_matched.contains(t.left)) return;
                        setState(() => _sel = t.left);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  for (final t in _right)
                    _tile(
                      label: t.right,
                      done: _matched.contains(t.left),
                      wrong: _wrongFlash == t.left,
                      onTap: () => _tapRight(t),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile({
    required String label,
    required VoidCallback onTap,
    bool done = false,
    bool selected = false,
    bool wrong = false,
  }) {
    Color border = Colors.black12;
    Color bg = Theme.of(context).colorScheme.surface;
    if (done) {
      border = AppColors.success;
      bg = AppColors.success.withValues(alpha: 0.12);
    } else if (wrong) {
      border = AppColors.danger;
      bg = AppColors.danger.withValues(alpha: 0.12);
    } else if (selected) {
      border = AppColors.brandPurple;
      bg = AppColors.brandPurple.withValues(alpha: 0.10);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: done ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: border, width: 1.8),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: done ? AppColors.success : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════ 4) O'qish ═══════════════
class _StudyStage extends StatelessWidget {
  final BookExercise exercise;
  final VoidCallback onDone;

  /// YODLASh — shu satrlarni so'zlardan yig'ib, so'ng harfma-harf
  /// yozib mustahkamlash (o'qish passiv; yozish faol).
  final VoidCallback? onMemorize;

  /// ROL O'YNASH — dialogda bir rolni ovoz chiqarib aytish.
  final VoidCallback? onRolePlay;

  const _StudyStage(
      {required this.exercise,
      required this.onDone,
      this.onMemorize,
      this.onRolePlay});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        ExplanationCard(text: exercise.explanationUz),
        AudioNoteCard(text: exercise.audioNoteUz),
        for (final t in exercise.tasks) _line(context, t),
        const SizedBox(height: 22),
        if (onRolePlay != null) ...[
          Pressable3D(
            color: AppColors.pink,
            shadowColor: const Color(0xFFBE185D),
            onPressed: onRolePlay,
            child: const Center(
              child: Text(
                '🎭 Rol o\'ynash: o\'zingiz gapiring',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (onMemorize != null) ...[
          Pressable3D(
            color: AppColors.brandPurple,
            shadowColor: const Color(0xFF5B22B5),
            onPressed: onMemorize,
            child: const Center(
              child: Text(
                'Yodlash: tinglab yig\'ish + yozish',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Pressable3D(
          color: AppColors.success,
          shadowColor: const Color(0xFF0F7A37),
          onPressed: onDone,
          child: const Center(
            child: Text(
              'O\'qib chiqdim',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(BuildContext context, ExTask t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Tts.instance.speak(t.speakText, id: 'study'),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.en,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      // Grammatika sarlavhalarida ("Present Continuous")
                      // o'zbekcha maydon aynan inglizchasini takrorlaydi
                      // — atamaning o'zi shu. Ikkala qatorni chizsak,
                      // o'quvchi bir xil matnni ikki marta ko'radi va
                      // buni xato deb o'ylaydi.
                      if (t.uz.isNotEmpty &&
                          t.uz.trim().toLowerCase() !=
                              t.en.trim().toLowerCase()) ...[
                        const SizedBox(height: 3),
                        Text(
                          t.uz,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted(context),
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (t.note.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          t.note,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.brandPurple,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.volume_up_rounded,
                  size: 20,
                  color: AppColors.actionBlue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
