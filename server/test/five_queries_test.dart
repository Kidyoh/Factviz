import 'dart:convert';

import 'package:factviz_core/factviz_core.dart';
import 'package:factviz_server/factviz_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support/fake_llm.dart';

/// The five fixed queries, one per template, run through both routes with
/// recorded model output. Each must produce a plan that resolves to the
/// expected template.
void main() {
  const config = ServerConfig(apiKey: 'test-key', rateLimitPerMinute: 0);
  final names = fixtureNames();

  test('there is one fixed query per template', () {
    final templates = names.map((n) => loadFixture(n)['expectedTemplate']).toSet();
    expect(templates, {'scale_zoom', 'timeline', 'exponential_growth', 'comparison_bars', 'process_steps'});
  });

  for (final name in names) {
    test(name, () async {
      final f = loadFixture(name);
      final llm = FakeLlm([f['facts'] as Object, f['plan'] as Object]);
      final handler = buildHandler(config, llm: llm, log: (_) {}, accessLog: false);

      Future<Map<String, dynamic>> post(String path, Object body) async {
        final res = await handler(Request('POST', Uri.parse('http://localhost/$path'), body: jsonEncode(body)));
        final text = await res.readAsString();
        expect(res.statusCode, 200, reason: '$path $text');
        return jsonDecode(text) as Map<String, dynamic>;
      }

      final factsJson = (await post('api/facts', {'query': f['query']}))['facts'];
      final planJson = (await post('api/plan', {'facts': factsJson}))['plan'];

      final viz = Visualization.build(
        FactsResult.fromJson(factsJson).valueOrThrow,
        Plan.fromJson(planJson).valueOrThrow,
      ).valueOrThrow;
      expect(viz.props.template.wire, f['expectedTemplate']);
    });
  }
}
