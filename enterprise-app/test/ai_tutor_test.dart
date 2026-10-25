import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enterprise_english/main.dart' as app;
import 'package:enterprise_english/mastery.dart';
import 'package:enterprise_english/screens/ai_tutor_screen.dart';
import 'package:enterprise_english/services/ai_tutor_service.dart';
import 'package:enterprise_english/stats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TutorReply.parse: JSON, code fence, oddiy matn', () {
    final a = TutorReply.parse(
        '{"reply":"Nice! Where do you live?","correction":"I live in Tashkent.","note_uz":"live in + shahar","praise":true}');
    expect(a.reply, 'Nice! Where do you live?');
    expect(a.correction, 'I live in Tashkent.');
    expect(a.noteUz, 'live in + shahar');
    expect(a.praise, isTrue);
    expect(a.hasCorrection, isTrue);

    final b = TutorReply.parse('```json\n{"reply":"Hello!","correction":"","note_uz":"","praise":false}\n```');
    expect(b.reply, 'Hello!');
    expect(b.hasCorrection, isFalse);

    final c = TutorReply.parse('Just plain text answer.');
    expect(c.reply, 'Just plain text answer.');
  });

  test('send: so\'rov tuzilishi va javob ajratilishi', () async {
    Map<String, dynamic>? sent;
    final client = MockClient((req) async {
      sent = json.decode(req.body) as Map<String, dynamic>;
      expect(req.headers['x-api-key'], 'sk-test');
      expect(req.headers['anthropic-dangerous-direct-browser-access'], 'true');
      return http.Response(
          json.encode({
            'content': [
              {
                'type': 'text',
                'text': '{"reply":"Good! What is your job?","correction":"I am a student.","note_uz":"a student - artikl kerak","praise":false}'
              }
            ]
          }),
          200);
    });
    final svc = AiTutorService(apiKey: 'sk-test', client: client);
    final r = await svc.send(
      level: 'beginner',
      history: const [
        ChatMessage(fromUser: true, text: 'Hello'),
        ChatMessage(fromUser: false, text: 'Hi! How are you?'),
      ],
      userText: 'I student',
      words: const ['job', 'student'],
    );
    expect(r.reply, 'Good! What is your job?');
    expect(r.correction, 'I am a student.');
    expect(sent!['model'], AiTutorService.model);
    expect((sent!['messages'] as List).length, 3);
    expect((sent!['system'] as String), contains('A1'));
    expect((sent!['system'] as String), contains('student'));
  });

  test('send: 401 tushunarli xato', () async {
    final client = MockClient((req) async => http.Response(
        json.encode({'error': {'message': 'invalid x-api-key'}}), 401));
    final svc = AiTutorService(apiKey: 'bad', client: client);
    expect(
      () => svc.send(level: 'beginner', history: const [], userText: 'hi'),
      throwsA(isA<TutorException>()),
    );
  });

  test('xato matni: avval o\'zbekcha jumla, server matni oxirida (texnik)',
      () async {
    final client = MockClient((req) async => http.Response(
        json.encode({'error': {'message': 'Resource has been exhausted'}}),
        429));
    final svc = AiTutorService(apiKey: 'k', client: client);
    try {
      await svc.send(level: 'beginner', history: const [], userText: 'hi');
      fail('TutorException kutilgan edi');
    } on TutorException catch (e) {
      expect(e.message, startsWith('Bepul limit vaqtincha tugadi'));
      expect(e.message,
          endsWith('(texnik: 429: Resource has been exhausted)'));
    }
  });

  test('tarmoq xatosida ekranga chiqadigan matnda kalit ko\'rinmaydi',
      () async {
    final client = MockClient((req) async => throw http.ClientException(
        'XMLHttpRequest error.', req.url));
    try {
      await AiTutorService.sendWithFallback(
        keys: const {'gemini': 'AIzaSECRETKEY123'},
        preferred: 'gemini',
        level: 'beginner',
        history: const [],
        userText: 'hi',
        client: client,
      );
      fail('TutorException kutilgan edi');
    } on TutorException catch (e) {
      expect(e.message, startsWith('AI xizmatiga ulanib bo\'lmadi'));
      expect(e.message, contains('(texnik:'));
      expect(e.message, isNot(contains('AIzaSECRETKEY123')));
    }
  });

  testWidgets('kalit ekrani va suhbat boshlanishi tor telefonda sig\'adi',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    await Future.wait([app.progress.load(), app.mastery.load()]);
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: AiTutorScreen())));
    await t.pump();
    expect(t.takeException(), isNull);
    // Kalit saqlangach: boshlang'ich ekran (tushuntirish + tarjimali gaplar).
    await app.progress.setAiKey('gemini', 'AIza-test');
    await t.pump();
    await t.pump();
    expect(find.textContaining('Beginner'), findsOneWidget);
    // Boshlang'ich gaplar o'zbekcha ma'nosi bilan (ro'yxat pastda - suramiz).
    await t.scrollUntilVisible(
        find.textContaining('Nima yozishni bilmasangiz'), 100,
        scrollable: find.byType(Scrollable).first);
    await t.pump();
    expect(find.textContaining('Nima yozishni bilmasangiz'), findsOneWidget);
    await t.scrollUntilVisible(
        find.text('Oilam haqida gaplashamizmi?'), 100,
        scrollable: find.byType(Scrollable).first);
    await t.pump();
    expect(find.text('Can we talk about my family?'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('kalit bo\'lmasa kiritish ekrani, kiritilsa suhbat', (t) async {
    SharedPreferences.setMockInitialValues({});
    app.progress = Progress();
    app.mastery = MasteryStore();
    await Future.wait([app.progress.load(), app.mastery.load()]);
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: AiTutorScreen())));
    await t.pump();
    // Kalit nima ekani, bepulligi va raqamlangan qadamlar tushuntirilgan.
    expect(find.textContaining('uzun maxfiy kod'), findsOneWidget);
    expect(find.textContaining('Create API key'), findsOneWidget);
    expect(find.text('aistudio.google.com/apikey'), findsOneWidget);
    // Qadamlar ekrandan uzun: saqlash tugmasi pastda (ListView) - suramiz.
    await t.scrollUntilVisible(find.text('Saqlash va boshlash'), 200);
    await t.pump();
    expect(find.text('Saqlash va boshlash'), findsOneWidget);
    expect(find.text('Avval kodni katakka qo\'ying.'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'sk-ant-xyz');
    await t.tap(find.text('Saqlash va boshlash'));
    await t.pump();
    await t.pump();
    expect(app.progress.activeAiKey, 'sk-ant-xyz');
    expect(app.progress.aiProvider, 'gemini', reason: 'standart - bepul provayder');
    expect(find.text('Hello! I am Mr. Vaysaqi. 👋'), findsOneWidget);
    expect(find.text('Inglizcha yozing... (Write in English)'), findsOneWidget);
  });

  test('gemini: so\'rov shakli va javob', () async {
    Map<String, dynamic>? sent;
    Uri? uri;
    final client = MockClient((req) async {
      uri = req.url;
      sent = json.decode(req.body) as Map<String, dynamic>;
      return http.Response(
          json.encode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"reply":"Great! And you?","correction":"","note_uz":"","praise":true}'}
                  ]
                }
              }
            ]
          }),
          200);
    });
    final r = await AiTutorService(apiKey: 'AIza1', provider: 'gemini', client: client)
        .send(level: 'elementary', history: const [], userText: 'I am fine');
    expect(r.reply, 'Great! And you?');
    expect(r.praise, isTrue);
    expect(uri!.host, 'generativelanguage.googleapis.com');
    expect(uri!.queryParameters['key'], 'AIza1');
    expect(sent!['system_instruction'], isNotNull);
    expect((sent!['contents'] as List).length, 1);
    expect((sent!['system_instruction'] as Map)['parts'][0]['text'], contains('A2'));
  });

  test('groq: OpenAI-mos so\'rov va javob', () async {
    Map<String, dynamic>? sent;
    String? auth;
    final client = MockClient((req) async {
      auth = req.headers['authorization'];
      sent = json.decode(req.body) as Map<String, dynamic>;
      return http.Response(
          json.encode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': '{"reply":"Nice to meet you! Where are you from?","correction":"My name is Ali.","note_uz":"name - katta harf emas","praise":false}'
                }
              }
            ]
          }),
          200);
    });
    final r = await AiTutorService(apiKey: 'gsk_1', provider: 'groq', client: client)
        .send(level: 'beginner', history: const [
      ChatMessage(fromUser: true, text: 'hi'),
      ChatMessage(fromUser: false, text: 'Hello!'),
    ], userText: 'my Name is Ali');
    expect(r.correction, 'My name is Ali.');
    expect(auth, 'Bearer gsk_1');
    expect(sent!['model'], AiTutorService.groqModel);
    final msgs = sent!['messages'] as List;
    expect(msgs.length, 4);
    expect((msgs.first as Map)['role'], 'system');
  });

  test('Progress: provayder va kalitlar alohida saqlanadi', () async {
    SharedPreferences.setMockInitialValues({'apiKey': 'sk-old'});
    final p = Progress();
    await p.load();
    expect(p.aiProvider, 'claude');
    expect(p.activeAiKey, 'sk-old', reason: 'eski kalit ko\'chadi');
    await p.setAiKey('groq', 'gsk_x');
    await p.setAiProvider('groq');
    expect(p.activeAiKey, 'gsk_x');
    final again = Progress();
    await again.load();
    expect(again.aiProvider, 'groq');
    expect(again.aiKeys['claude'], 'sk-old');
    expect(again.aiKeys['groq'], 'gsk_x');
  });

  test('rankedAttempts: eng zo\'ri birinchi, faqat kaliti borlar', () {
    final a = AiTutorService.rankedAttempts({'gemini': 'g', 'groq': 'q'});
    expect(a.first, ('gemini', 'gemini-2.5-flash'));
    expect(a[1], ('groq', 'llama-3.3-70b-versatile'));
    expect(a[2], ('gemini', 'gemini-2.5-flash-lite'));
    expect(a.any((e) => e.$1 == 'claude'), isFalse);
    expect(AiTutorService.rankedAttempts({'claude': 'c'}).first, ('claude', ''));
    expect(AiTutorService.rankedAttempts({}), isEmpty);
  });

  test('sendWithFallback: 429 da keyingi model/provayderga o\'tadi', () async {
    final hits = <String>[];
    final client = MockClient((req) async {
      final url = req.url.toString();
      if (url.contains('gemini-2.5-flash:')) {
        hits.add('gemini-2.5-flash');
        return http.Response('{"error":{"message":"quota"}}', 429);
      }
      if (url.contains('groq')) {
        final model = (json.decode(req.body) as Map)['model'] as String;
        hits.add(model);
        if (model == 'llama-3.3-70b-versatile') {
          return http.Response('{"error":{"message":"rate"}}', 429);
        }
        return http.Response(
            json.encode({
              'choices': [
                {
                  'message': {
                    'content': '{"reply":"Hi from llama 8b","correction":"","note_uz":"","praise":false}'
                  }
                }
              ]
            }),
            200);
      }
      if (url.contains('gemini-2.5-flash-lite')) {
        hits.add('gemini-2.5-flash-lite');
        return http.Response('{"error":{"message":"quota"}}', 429);
      }
      if (url.contains('gemini-2.0-flash:')) {
        hits.add('gemini-2.0-flash');
        return http.Response('{"error":{"message":"quota"}}', 429);
      }
      hits.add('other');
      return http.Response('{}', 500);
    });
    final (r, via) = await AiTutorService.sendWithFallback(
      keys: {'gemini': 'g', 'groq': 'q'},
      preferred: 'gemini',
      level: 'beginner',
      history: const [],
      userText: 'hello',
      client: client,
    );
    expect(r.reply, 'Hi from llama 8b');
    expect(via, 'groq/llama-3.1-8b-instant');
    expect(hits, [
      'gemini-2.5-flash',
      'llama-3.3-70b-versatile',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash',
      'llama-3.1-8b-instant',
    ]);
  });

  test('sendWithFallback: hech biri ishlamasa oxirgi xato', () async {
    final client = MockClient((req) async => http.Response('{}', 429));
    expect(
      () => AiTutorService.sendWithFallback(
        keys: {'groq': 'q'},
        preferred: 'groq',
        level: 'beginner',
        history: const [],
        userText: 'x',
        client: client,
      ),
      throwsA(isA<TutorException>()),
    );
  });

  test("server kaliti: so'rov /api/tutor ga ketadi, kalit URL'da yo'q", () async {
    Map<String, dynamic>? sent;
    Uri? uri;
    final client = MockClient((req) async {
      uri = req.url;
      sent = json.decode(req.body) as Map<String, dynamic>;
      return http.Response(
          json.encode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"reply":"Hello!","correction":"","note_uz":"","praise":false}'}
                  ]
                }
              }
            ]
          }),
          200);
    });
    final r = await AiTutorService(
            apiKey: AiTutorService.serverKey,
            provider: 'gemini',
            model: 'gemini-2.5-flash-lite',
            client: client)
        .send(level: 'beginner', history: const [], userText: 'Hi');
    expect(r.reply, 'Hello!');
    expect(uri!.path, '/api/tutor');
    expect(uri!.host, isNot('generativelanguage.googleapis.com'));
    expect(uri!.queryParameters.containsKey('key'), isFalse);
    expect(sent!['model'], 'gemini-2.5-flash-lite');
    expect(sent!['system_instruction'], isNotNull);
  });
}
