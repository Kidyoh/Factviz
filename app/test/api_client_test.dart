import 'dart:convert';

import 'package:factviz/data/api_client.dart';
import 'package:factviz_core/factviz_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_server.dart';

FactvizApiClient _client(http.Response Function(http.Request) respond) =>
    FactvizApiClient(baseUrl: 'http://test/', httpClient: MockClient((r) async => respond(r)));

void main() {
  final f = fixture('process_water_cycle');

  test('posts the query and validates the facts', () async {
    late http.Request sent;
    final client = _client((r) {
      sent = r;
      return http.Response(jsonEncode({'facts': f.facts}), 200);
    });
    final facts = await client.fetchFacts('How the water cycle works');
    expect(facts.facts, hasLength(4));
    expect(sent.url.toString(), 'http://test/api/facts');
    expect(jsonDecode(sent.body), {'query': 'How the water cycle works'});
  });

  test('posts facts and validates the plan', () async {
    final facts = FactsResult.fromJson(f.facts).valueOrThrow;
    final client = _client((r) => http.Response(jsonEncode({'plan': f.plan}), 200));
    expect(await client.fetchPlan(facts), isA<ProcessStepsPlan>());
  });

  test('maps errors to friendly kinds', () async {
    Future<ApiErrorKind> kindFor(http.Response res) async {
      try {
        await _client((_) => res).fetchFacts('q?');
        fail('expected an ApiException');
      } on ApiException catch (e) {
        return e.kind;
      }
    }

    expect(await kindFor(FakeServer.error(422, 'unvisualizable')), ApiErrorKind.unvisualizable);
    expect(await kindFor(FakeServer.error(429, 'rate_limited')), ApiErrorKind.rateLimited);
    expect(await kindFor(FakeServer.error(400, 'bad_request')), ApiErrorKind.badRequest);
    expect(await kindFor(FakeServer.error(502, 'upstream')), ApiErrorKind.server);
    expect(await kindFor(http.Response('<html>', 500)), ApiErrorKind.server);
    expect(await kindFor(http.Response(jsonEncode({'facts': {'nope': 1}}), 200)), ApiErrorKind.unvisualizable);
  });

  test('network failures become a network error', () async {
    final client = FactvizApiClient(baseUrl: 'http://test', httpClient: MockClient((_) => throw http.ClientException('down')));
    expect(() => client.fetchFacts('q?'), throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network)));
  });
}
