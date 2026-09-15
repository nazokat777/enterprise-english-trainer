import 'dart:convert';

import 'package:http/http.dart' as http;

/// MR. VAYSAQI — Claude asosidagi ingliz tili o'qituvchisi.
///
/// Suhbat inglizcha, tushuntirish o'zbekcha. Model har javobda
/// QISQA gapiradi (daraja Beginner/Elementary), xato bo'lsa to'g'ri
/// variantini va o'zbekcha izohini alohida beradi — ilova buni
/// foydalanuvchi xabari ostida "tuzatish" sifatida ko'rsatadi.
///
/// Pedagogika: xatoni jazolamasdan, suhbatni to'xtatmasdan
/// to'g'rilash ("recast") — tilni o'rganishda eng samarali fikr-mulohaza.
class AiTutorService {
  final String apiKey;

  /// 'claude' | 'gemini' | 'groq' — uchalasi ham brauzerdan to'g'ridan-
  /// to'g'ri chaqiriladi (CORS ochiq), kalit faqat qurilmada.
  final String provider;
  final http.Client _client;

  AiTutorService({
    required this.apiKey,
    this.provider = 'claude',
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String model = 'claude-sonnet-5';
  static const String endpoint = 'https://api.anthropic.com/v1/messages';

  static const String geminiModel = 'gemini-2.5-flash';
  static const String groqModel = 'llama-3.3-70b-versatile';
  static const String groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static String geminiEndpoint(String key) =>
      'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent?key=$key';

  /// Provayder nomi va kalit qayerdan olinishi (UI uchun).
  static const Map<String, (String, String, String)> providers = {
    'claude': ('Claude (Anthropic)', 'console.anthropic.com', 'sk-ant-...'),
    'gemini': ('Gemini (Google) - bepul', 'aistudio.google.com/apikey', 'AIza...'),
    'groq': ('Groq (Llama) - bepul, tez', 'console.groq.com/keys', 'gsk_...'),
  };

  /// Daraja bo'yicha tizim ko'rsatmasi.
  static String systemPrompt(String level, {List<String> words = const []}) {
    final lvl = level == 'beginner' ? 'A1 (complete beginner)' : 'A2 (elementary)';
    final vocab = words.isEmpty
        ? ''
        : '\nThe student is currently studying these words; use them naturally '
            'when it fits: ${words.take(25).join(', ')}.';
    return '''
You are Mr. Vaysaqi, a warm, patient English teacher for an Uzbek-speaking student at level $lvl (Express Publishing "Enterprise" coursebook).
Rules:
- Speak ONLY simple English at the student's level: short sentences, common words, present tense for A1.
- Keep every reply to 1-3 sentences and ALWAYS end with one easy question to keep the conversation going.
- Never lecture. Never switch to Uzbek in the "reply" field.
- If the student's message has a mistake, give the corrected sentence and a very short Uzbek explanation (max 12 words). If there is no mistake, leave those fields empty.
- Praise briefly when the student uses a new word or a correct structure.$vocab

Respond ONLY with JSON, no markdown:
{"reply": "...", "correction": "corrected sentence or empty", "note_uz": "short Uzbek explanation or empty", "praise": true/false}
''';
  }

  /// Xabar yuboradi; javobni [TutorReply] ga ajratadi.
  Future<TutorReply> send({
    required String level,
    required List<ChatMessage> history,
    required String userText,
    List<String> words = const [],
  }) async {
    switch (provider) {
      case 'gemini':
        return _sendGemini(level, history, userText, words);
      case 'groq':
        return _sendGroq(level, history, userText, words);
      default:
        return _sendClaude(level, history, userText, words);
    }
  }

  Map<String, String> get _json => const {'content-type': 'application/json'};

  Future<TutorReply> _sendGemini(String level, List<ChatMessage> history,
      String userText, List<String> words) async {
    final contents = [
      for (final m in history.takeLast(16))
        {
          'role': m.fromUser ? 'user' : 'model',
          'parts': [
            {'text': m.rawForApi}
          ],
        },
      {
        'role': 'user',
        'parts': [
          {'text': userText}
        ],
      },
    ];
    final res = await _client
        .post(
          Uri.parse(geminiEndpoint(apiKey)),
          headers: _json,
          body: json.encode({
            'system_instruction': {
              'parts': [
                {'text': systemPrompt(level, words: words)}
              ]
            },
            'contents': contents,
            'generationConfig': {
              'maxOutputTokens': 400,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) throw TutorException(_errorText(res));
    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final cands = (body['candidates'] as List?) ?? const [];
    final parts = cands.isEmpty
        ? const []
        : (((cands.first as Map)['content'] as Map?)?['parts'] as List?) ??
            const [];
    final text = parts
        .whereType<Map>()
        .map((p) => p['text'] as String? ?? '')
        .join('\n')
        .trim();
    return TutorReply.parse(text);
  }

  Future<TutorReply> _sendGroq(String level, List<ChatMessage> history,
      String userText, List<String> words) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt(level, words: words)},
      for (final m in history.takeLast(16))
        {'role': m.fromUser ? 'user' : 'assistant', 'content': m.rawForApi},
      {'role': 'user', 'content': userText},
    ];
    final res = await _client
        .post(
          Uri.parse(groqEndpoint),
          headers: {..._json, 'authorization': 'Bearer $apiKey'},
          body: json.encode({
            'model': groqModel,
            'max_tokens': 400,
            'temperature': 0.6,
            'response_format': {'type': 'json_object'},
            'messages': messages,
          }),
        )
        .timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) throw TutorException(_errorText(res));
    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = (body['choices'] as List?) ?? const [];
    final text = choices.isEmpty
        ? ''
        : ((((choices.first as Map)['message'] as Map?)?['content']) as String? ?? '');
    return TutorReply.parse(text.trim());
  }

  Future<TutorReply> _sendClaude(String level, List<ChatMessage> history,
      String userText, List<String> words) async {
    final messages = [
      for (final m in history.takeLast(16))
        {'role': m.fromUser ? 'user' : 'assistant', 'content': m.rawForApi},
      {'role': 'user', 'content': userText},
    ];
    final res = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            // Brauzerdan to'g'ridan-to'g'ri chaqirish uchun (CORS).
            'anthropic-dangerous-direct-browser-access': 'true',
          },
          body: json.encode({
            'model': model,
            'max_tokens': 300,
            'system': systemPrompt(level, words: words),
            'messages': messages,
          }),
        )
        .timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) {
      throw TutorException(_errorText(res));
    }
    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final content = (body['content'] as List?) ?? const [];
    final text = content
        .whereType<Map>()
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String? ?? '')
        .join('\n')
        .trim();
    return TutorReply.parse(text);
  }

  static String _errorText(http.Response res) {
    try {
      final j = json.decode(res.body) as Map<String, dynamic>;
      final err = (j['error'] as Map?)?['message'] as String?;
      if (err != null) return '${res.statusCode}: $err';
    } catch (_) {}
    return switch (res.statusCode) {
      401 => 'API kaliti noto\'g\'ri (401). Sozlamalardan tekshiring.',
      429 => 'Juda ko\'p so\'rov (429). Bir oz kutib qayta urinib ko\'ring.',
      _ => 'Server xatosi (${res.statusCode}).',
    };
  }
}

class TutorException implements Exception {
  final String message;
  TutorException(this.message);
  @override
  String toString() => message;
}

/// Modelning tuzilgan javobi.
class TutorReply {
  final String reply;
  final String correction;
  final String noteUz;
  final bool praise;

  const TutorReply({
    required this.reply,
    this.correction = '',
    this.noteUz = '',
    this.praise = false,
  });

  bool get hasCorrection => correction.trim().isNotEmpty;

  /// JSON bo'lsa ajratadi; bo'lmasa (model qoidani buzsa) matnning
  /// o'zi javob bo'ladi — suhbat to'xtab qolmasin.
  static TutorReply parse(String text) {
    var t = text.trim();
    // ```json ... ``` o'ramini olib tashlash.
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      t = t.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final j = json.decode(t.substring(start, end + 1)) as Map<String, dynamic>;
        final reply = (j['reply'] as String?)?.trim() ?? '';
        if (reply.isNotEmpty) {
          return TutorReply(
            reply: reply,
            correction: (j['correction'] as String?)?.trim() ?? '',
            noteUz: (j['note_uz'] as String?)?.trim() ?? '',
            praise: j['praise'] == true,
          );
        }
      } catch (_) {}
    }
    return TutorReply(reply: t.isEmpty ? '...' : t);
  }
}

/// Suhbatdagi bitta xabar.
class ChatMessage {
  final bool fromUser;
  final String text;

  /// Foydalanuvchi xabariga tuzatish (bo'lsa).
  final String correction;
  final String noteUz;
  final bool praise;
  final int timeMs;

  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.correction = '',
    this.noteUz = '',
    this.praise = false,
    this.timeMs = 0,
  });

  /// API ga yuboriladigan matn: assistant javoblari JSON bo'lib
  /// qolmasin (model o'z formatini ko'rib, uni takrorlaydi — bu
  /// yaxshi, lekin tarixni qisqa tutish uchun faqat reply).
  String get rawForApi => fromUser
      ? text
      : json.encode({'reply': text, 'correction': '', 'note_uz': '', 'praise': false});

  ChatMessage withFeedback(TutorReply r) => ChatMessage(
        fromUser: fromUser,
        text: text,
        correction: r.correction,
        noteUz: r.noteUz,
        praise: r.praise,
        timeMs: timeMs,
      );

  Map<String, dynamic> toJson() => {
        'u': fromUser,
        't': text,
        if (correction.isNotEmpty) 'c': correction,
        if (noteUz.isNotEmpty) 'n': noteUz,
        if (praise) 'p': true,
        'ms': timeMs,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        fromUser: j['u'] == true,
        text: j['t'] as String? ?? '',
        correction: j['c'] as String? ?? '',
        noteUz: j['n'] as String? ?? '',
        praise: j['p'] == true,
        timeMs: (j['ms'] as num?)?.toInt() ?? 0,
      );
}

extension _TakeLast<T> on List<T> {
  Iterable<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}
