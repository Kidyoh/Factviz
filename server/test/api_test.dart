import 'dart:convert';

import 'package:factviz_core/factviz_core.dart';
import 'package:factviz_server/factviz_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support/fake_llm.dart';

const _config = ServerConfig(apiKey: 'test-key', rateLimitPerMinute: 0);

Future<(int, Map<String, dynamic>)> _post(Handler h, String path, Object body) async {
  final res = await h(Request('POST', Uri.parse('http://localhost/$path'), body: jsonEncode(body)));
  return (res.statusCode, jsonDecode(await res.readAsString()) as Map<String, dynamic>);
}

Handler _handler(FakeLlm llm, [List<String>? logs]) =>
    buildHandler(_config, llm: llm, log: logs?.add ?? (_) {}, accessLog: false);

void main() {
  final fixture = loadFixture('exponential_paper_fold');
  final facts = fixture['facts'] as Map<String, dynamic>;
  final plan = fixture['plan'] as Map<String, dynamic>;

  group('POST /api/facts', () {
    test('returns validated facts and echoes the user query', () async {
      final llm = FakeLlm([clone(facts)..['query'] = 'something the model rewrote']);
      final (status, body) = await _post(_handler(llm), 'api/facts', {'query': '  Fold a paper   42 times to reach the Moon '});
      expect(status, 200);
      expect(body['facts']['query'], 'Fold a paper 42 times to reach the Moon');
      expect(FactsResult.fromJson(body['facts']).isValid, isTrue);
      expect(body['meta'], {'attempts': 1});
      expect(llm.requests.single.model, ServerConfig.defaultModel);
    });

    test('rejects missing or out-of-range queries without calling the model', () async {
      final llm = FakeLlm([]);
      for (final body in [<String, Object>{}, {'query': 42}, {'query': 'hi'}, {'query': 'x' * 301}]) {
        final (status, json) = await _post(_handler(llm), 'api/facts', body);
        expect(status, 400, reason: '$body');
        expect(json['error']['code'], 'bad_request');
      }
      expect(llm.requests, isEmpty);
    });

    test('returns 422 with a friendly message after two invalid outputs', () async {
      final broken = clone(facts)..['facts'] = 'none';
      final logs = <String>[];
      final (status, body) = await _post(_handler(FakeLlm([broken, broken]), logs), 'api/facts', {'query': 'Fold paper'});
      expect(status, 422);
      expect(body['error']['code'], 'unvisualizable');
      expect(body['error']['message'], "Couldn't visualize this one, try rephrasing.");
      expect(body['error']['details'], ['facts: expected an array']);
      expect(logs.single, contains('facts invalid after 2 attempts'));
    });

    test('returns 502 when the provider fails', () async {
      final llm = FakeLlm([const LlmException('boom', statusCode: 503)]);
      final (status, body) = await _post(_handler(llm), 'api/facts', {'query': 'How far is the Moon?'});
      expect(status, 502);
      expect(body['error']['code'], 'upstream');
      expect(body['error']['message'], isNot(contains('boom')));
    });
  });

  group('POST /api/plan', () {
    test('returns a plan that resolves against the facts', () async {
      final llm = FakeLlm([plan]);
      final (status, body) = await _post(_handler(llm), 'api/plan', {'facts': facts});
      expect(status, 200);
      expect(body['plan']['template'], 'exponential_growth');
      expect(llm.requests.single.messages.single.content, startsWith('Facts JSON:'));
    });

    test('feeds resolver errors back to the model', () async {
      final bad = clone(plan)..['targetFactId'] = 'mars_distance';
      final llm = FakeLlm([bad, plan]);
      final (status, _) = await _post(_handler(llm), 'api/plan', {'facts': facts});
      expect(status, 200);
      expect(llm.requests[1].messages.last.content, contains('targetFactId: unknown fact id "mars_distance"'));
    });

    test('rejects invalid facts from the client', () async {
      final llm = FakeLlm([]);
      final (status, body) = await _post(_handler(llm), 'api/plan', {'facts': clone(facts)..remove('explanation')});
      expect(status, 400);
      expect(body['error']['details'], ['explanation: is required']);
      expect(llm.requests, isEmpty);
    });

    test('short-circuits to "none" when there are no facts', () async {
      final empty = clone(facts)
        ..['facts'] = <Object>[]
        ..['confidence'] = 'low'
        ..['confidenceNote'] = 'Opinion.';
      final llm = FakeLlm([]);
      final (status, body) = await _post(_handler(llm), 'api/plan', {'facts': empty});
      expect(status, 200);
      expect(body['plan']['template'], 'none');
      expect(llm.requests, isEmpty);
    });
  });

  group('routing', () {
    test('health check', () async {
      final res = await _handler(FakeLlm([]))(Request('GET', Uri.parse('http://localhost/healthz')));
      expect(res.statusCode, 200);
    });

    test('unknown paths, wrong methods and bad bodies', () async {
      final h = _handler(FakeLlm([]));
      expect((await h(Request('GET', Uri.parse('http://localhost/nope')))).statusCode, 404);
      expect((await h(Request('GET', Uri.parse('http://localhost/api/facts')))).statusCode, 405);
      final bad = await h(Request('POST', Uri.parse('http://localhost/api/facts'), body: 'not json'));
      expect(bad.statusCode, 400);
      final huge = await h(Request('POST', Uri.parse('http://localhost/api/facts'), body: 'x' * 70000));
      expect(huge.statusCode, 400);
    });
  });

  group('rate limit', () {
    test('allows N requests per minute per client, then 429', () async {
      var now = DateTime(2026, 1, 1, 12);
      final h = const Pipeline()
          .addMiddleware(rateLimit(perMinute: 2, now: () => now))
          .addHandler((_) => Response.ok('ok'));
      Future<int> hit([String path = 'api/facts']) async =>
          (await h(Request('POST', Uri.parse('http://localhost/$path')))).statusCode;
      expect(await hit(), 200);
      expect(await hit(), 200);
      expect(await hit(), 429);
      expect(await hit('healthz'), 200);
      now = now.add(const Duration(minutes: 1));
      expect(await hit(), 200);
    });
  });
}
