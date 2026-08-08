import 'dart:convert';
import 'package:flutter/services.dart';

/// Lug'at so'zi.
class Word {
  final String id, en, uz, example, module, pos, phonetic;
  final double freq;
  const Word({
    required this.id,
    required this.en,
    required this.uz,
    required this.example,
    required this.module,
    required this.pos,
    required this.phonetic,
    required this.freq,
  });

  bool get hasExample => example.trim().isNotEmpty;

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        id: j['id'] as String,
        en: j['en'] as String? ?? '',
        uz: j['uz'] as String? ?? '',
        example: j['example'] as String? ?? '',
        module: j['module'] as String? ?? '',
        pos: j['pos'] as String? ?? '',
        phonetic: j['phonetic'] as String? ?? '',
        freq: (j['freq'] as num?)?.toDouble() ?? 0.0,
      );
}

/// So'z pack'i (5–6 so'z) — word id'lar orqali.
class VocabPack {
  final String id, name;
  final List<String> wordIds;
  const VocabPack({required this.id, required this.name, required this.wordIds});

  factory VocabPack.fromJson(Map<String, dynamic> j) => VocabPack(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        wordIds: (j['wordIds'] as List).map((e) => e as String).toList(),
      );
}

/// Unit komponenti: VOCABULARY yoki HOMEWORK.
class Component {
  final String id, type; // VOCABULARY | HOMEWORK
  final int order;
  final List<VocabPack> packs;
  const Component({
    required this.id,
    required this.type,
    required this.order,
    required this.packs,
  });

  bool get isVocabulary => type == 'VOCABULARY';

  factory Component.fromJson(Map<String, dynamic> j) => Component(
        id: j['id'] as String,
        type: j['type'] as String,
        order: (j['order'] as num?)?.toInt() ?? 0,
        packs: (j['packs'] as List? ?? [])
            .map((e) => VocabPack.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Dars (Unit) — game-map tuguni.
class Unit {
  final String id, code, title, module;
  final int order;
  final bool isRevision;
  final List<Component> components;
  const Unit({
    required this.id,
    required this.code,
    required this.title,
    required this.module,
    required this.order,
    required this.isRevision,
    required this.components,
  });

  List<Component> get vocabComponents =>
      components.where((c) => c.isVocabulary).toList();

  int get wordCount => vocabComponents
      .expand((c) => c.packs)
      .fold(0, (s, p) => s + p.wordIds.length);

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
        id: j['id'] as String,
        code: j['code'] as String,
        title: j['title'] as String,
        module: j['module'] as String? ?? '',
        order: (j['order'] as num?)?.toInt() ?? 0,
        isRevision: j['isRevision'] as bool? ?? false,
        components: (j['components'] as List)
            .map((e) => Component.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Grammatika mavzusi.
class GrammarTopic {
  final String id, topic, ruleUz;
  final List<String> examples;
  const GrammarTopic({
    required this.id,
    required this.topic,
    required this.ruleUz,
    required this.examples,
  });

  factory GrammarTopic.fromJson(Map<String, dynamic> j) => GrammarTopic(
        id: j['id'] as String,
        topic: j['topic'] as String,
        ruleUz: j['rule_uz'] as String? ?? '',
        examples: (j['examples'] as List? ?? []).map((e) => e as String).toList(),
      );
}

/// So'z oilasi (word formation).
class WordFamily {
  final String id, base, uz;
  final List<String> forms;
  const WordFamily({
    required this.id,
    required this.base,
    required this.uz,
    required this.forms,
  });

  factory WordFamily.fromJson(Map<String, dynamic> j) => WordFamily(
        id: j['id'] as String,
        base: j['base'] as String,
        uz: j['uz'] as String? ?? '',
        forms: (j['forms'] as List? ?? []).map((e) => e as String).toList(),
      );
}

/// Bitta darajaning butun kontenti.
class LevelContent {
  final List<Unit> units;
  final Map<String, Word> wordsById;
  final List<GrammarTopic> grammar;
  final List<WordFamily> families;

  const LevelContent({
    required this.units,
    required this.wordsById,
    required this.grammar,
    required this.families,
  });

  bool get isEmpty => units.isEmpty && wordsById.isEmpty;

  List<Word> wordsOf(VocabPack pack) =>
      pack.wordIds.map((id) => wordsById[id]).whereType<Word>().toList();

  static const empty = LevelContent(
    units: [], wordsById: {}, grammar: [], families: [],
  );
}

/// Barcha darajalar kontentini asset'lardan yuklaydigan repozitoriy.
class ContentRepository {
  final Map<String, LevelContent> _levels = {};

  Future<void> load() async {
    for (final level in ['beginner', 'elementary']) {
      _levels[level] = await _loadLevel(level);
    }
  }

  LevelContent forLevel(String level) => _levels[level] ?? LevelContent.empty;

  Future<LevelContent> _loadLevel(String level) async {
    Future<dynamic> read(String file) async {
      try {
        final s = await rootBundle.loadString('assets/content/$level/$file.json');
        return json.decode(s);
      } catch (_) {
        return null; // fayl yo'q/bo'sh — bardoshli
      }
    }

    final w = await read('words');
    final u = await read('units');
    final g = await read('grammar');
    final f = await read('word_formation');

    final words = <String, Word>{};
    if (w is Map && w['words'] is List) {
      for (final e in w['words'] as List) {
        final word = Word.fromJson(e as Map<String, dynamic>);
        words[word.id] = word;
      }
    }
    final units = (u is Map && u['units'] is List)
        ? (u['units'] as List)
            .map((e) => Unit.fromJson(e as Map<String, dynamic>))
            .toList()
        : <Unit>[];
    final grammar = (g is Map && g['topics'] is List)
        ? (g['topics'] as List)
            .map((e) => GrammarTopic.fromJson(e as Map<String, dynamic>))
            .toList()
        : <GrammarTopic>[];
    final families = (f is Map && f['families'] is List)
        ? (f['families'] as List)
            .map((e) => WordFamily.fromJson(e as Map<String, dynamic>))
            .toList()
        : <WordFamily>[];

    return LevelContent(
      units: units,
      wordsById: words,
      grammar: grammar,
      families: families,
    );
  }
}
