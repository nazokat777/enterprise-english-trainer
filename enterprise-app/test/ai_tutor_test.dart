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
    expect(find.text('Saqlash va boshlash'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'sk-ant-xyz');
    await t.tap(find.text('Saqlash va boshlash'));
    await t.pump();
    await t.pump();
    expect(app.progress.apiKey, 'sk-ant-xyz');
    expect(find.text('Hello! I am Mr. Vaysaqi. 👋'), findsOneWidget);
    expect(find.text('Write in English...'), findsOneWidget);
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
}
