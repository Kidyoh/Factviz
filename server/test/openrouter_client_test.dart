import 'dart:convert';

import 'package:factviz_server/factviz_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

LlmRequest _request() => const LlmRequest(
      model: 'google/gemini-3.8-flash',
      system: 'sys',
      messages: [LlmMessage.user('hello')],
      schemaName: 'thing',
      schema: {'type': 'object'},
    );

http.Response _ok(String content) => http.Response(
      jsonEncode({
        'model': 'google/gemini-3.8-flash',
        'choices': [
          {'message': {'role': 'assistant', 'content': content}},
        ],
      }),
      200,
    );

void main() {
  test('sends a structured-output chat completion with auth headers', () async {
    late http.Request sent;
    final client = OpenRouterClient(
      apiKey: 'sk-secret',
      baseUrl: 'https://openrouter.ai/api/v1',
      appUrl: 'https://factviz.app',
      appTitle: 'Explain It Visually',
      httpClient: MockClient((req) async {
        sent = req;
        return _ok('{"ok":true}');
      }),
    );
    final res = await client.complete(_request());
    expect(res.text, '{"ok":true}');
    expect(res.model, 'google/gemini-3.8-flash');

    expect(sent.url.toString(), 'https://openrouter.ai/api/v1/chat/completions');
    expect(sent.headers['Authorization'], 'Bearer sk-secret');
    expect(sent.headers['HTTP-Referer'], 'https://factviz.app');
    expect(sent.headers['X-Title'], 'Explain It Visually');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['model'], 'google/gemini-3.8-flash');
    expect(body['messages'], [
      {'role': 'system', 'content': 'sys'},
      {'role': 'user', 'content': 'hello'},
    ]);
    expect(body['response_format'], {
      'type': 'json_schema',
      'json_schema': {'name': 'thing', 'strict': false, 'schema': {'type': 'object'}},
    });
    expect(body['provider'], {'require_parameters': true});
  });

  test('falls back to JSON mode when the schema is rejected', () async {
    final formats = <Object?>[];
    final client = OpenRouterClient(
      apiKey: 'k',
      baseUrl: 'https://x',
      httpClient: MockClient((req) async {
        final format = (jsonDecode(req.body) as Map)['response_format'] as Map;
        formats.add(format['type']);
        if (format['type'] == 'json_schema') {
          return http.Response(jsonEncode({'error': {'message': 'schema not supported', 'code': 400}}), 400);
        }
        return _ok('{}');
      }),
    );
    await client.complete(_request());
    expect(formats, ['json_schema', 'json_object']);
  });

  test('surfaces provider errors', () async {
    final client = OpenRouterClient(
      apiKey: 'k',
      baseUrl: 'https://x',
      httpClient: MockClient((_) async => http.Response(jsonEncode({'error': {'message': 'No credits', 'code': 402}}), 402)),
    );
    expect(
      () => client.complete(_request()),
      throwsA(isA<LlmException>().having((e) => e.statusCode, 'status', 402).having((e) => e.message, 'message', 'No credits')),
    );
  });

  test('treats an empty completion as an error', () async {
    final client = OpenRouterClient(apiKey: 'k', baseUrl: 'https://x', httpClient: MockClient((_) async => _ok('  ')));
    expect(() => client.complete(_request()), throwsA(isA<LlmException>()));
  });

  test('errors embedded in a 200 response are surfaced', () async {
    final client = OpenRouterClient(
      apiKey: 'k',
      baseUrl: 'https://x',
      httpClient: MockClient((_) async => http.Response(jsonEncode({'error': {'message': 'overloaded', 'code': 502}}), 200)),
    );
    expect(() => client.complete(_request()), throwsA(isA<LlmException>().having((e) => e.statusCode, 'status', 502)));
  });
}
