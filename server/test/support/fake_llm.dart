import 'dart:convert';
import 'dart:io';

import 'package:factviz_server/factviz_server.dart';

/// Replays scripted responses and records every request.
class FakeLlm implements LlmClient {
  FakeLlm(List<Object> script) : _script = List.of(script);

  final List<Object> _script;
  final requests = <LlmRequest>[];

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    requests.add(request);
    if (_script.isEmpty) throw StateError('FakeLlm: no scripted response left');
    final next = _script.removeAt(0);
    if (next is Exception) throw next;
    return LlmResponse(text: next is String ? next : jsonEncode(next));
  }
}

/// Loads one of the five fixed queries from /fixtures/queries.
Map<String, dynamic> loadFixture(String name) =>
    jsonDecode(File('../fixtures/queries/$name.json').readAsStringSync()) as Map<String, dynamic>;

List<String> fixtureNames() => (Directory('../fixtures/queries')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.json'))
        .map((n) => n.replaceAll('.json', ''))
        .toList()
      ..sort());

Map<String, dynamic> clone(Map<String, dynamic> json) => jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
