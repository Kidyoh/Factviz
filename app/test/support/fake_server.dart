import 'dart:convert';
import 'dart:io';

import 'package:factviz/data/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// One of the five fixed queries in /fixtures/queries.
class QueryFixture {
  QueryFixture(this.name, this.json);
  final String name;
  final Map<String, dynamic> json;

  String get query => json['query'] as String;
  String get expectedTemplate => json['expectedTemplate'] as String;
  Map<String, dynamic> get facts => json['facts'] as Map<String, dynamic>;
  Map<String, dynamic> get plan => json['plan'] as Map<String, dynamic>;
}

List<QueryFixture> loadQueryFixtures() {
  final files = Directory('../fixtures/queries').listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      QueryFixture(f.uri.pathSegments.last.replaceAll('.json', ''),
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>),
  ];
}

QueryFixture fixture(String name) => loadQueryFixtures().firstWhere((f) => f.name == name);

/// A scripted stand-in for the API server, serving recorded responses.
class FakeServer {
  FakeServer({this.facts, this.plan, this.latency = const Duration(milliseconds: 100)});

  /// Response bodies (or [http.Response]/[Exception]) for each route.
  Object? facts;
  Object? plan;
  Duration latency;
  final calls = <String>[];

  FactvizApiClient client() => FactvizApiClient(baseUrl: 'http://test', httpClient: MockClient(_handle));

  Future<http.Response> _handle(http.Request req) async {
    calls.add(req.url.path);
    await Future<void>.delayed(latency);
    final next = switch (req.url.path) {
      '/api/facts' => facts,
      '/api/plan' => plan,
      _ => null,
    };
    if (next is Exception) throw next;
    if (next is http.Response) return next;
    if (next == null) return http.Response('{"error":{"code":"not_found"}}', 404);
    final key = req.url.path == '/api/facts' ? 'facts' : 'plan';
    return http.Response(jsonEncode({key: next}), 200, headers: {'content-type': 'application/json'});
  }

  static http.Response error(int status, String code, [String message = 'error']) =>
      http.Response(jsonEncode({'error': {'code': code, 'message': message}}), status);
}
