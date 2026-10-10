@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:factviz_core/factviz_core.dart';
import 'package:factviz_server/factviz_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support/fake_llm.dart';

/// End-to-end run of the five fixed queries against the configured provider.
/// Skipped by default; see dart_test.yaml.
void main() {
  final env = Platform.environment;
  final config = ServerConfig.fromEnvironment({...env, 'RATE_LIMIT_PER_MINUTE': '0'});
  final handler = buildHandler(config, accessLog: false);

  for (final name in fixtureNames()) {
    final fixture = loadFixture(name);
    test('${fixture['query']} → ${fixture['expectedTemplate']}', () async {
      Future<Map<String, dynamic>> post(String path, Object body) async {
        final res = await handler(Request('POST', Uri.parse('http://localhost/$path'), body: jsonEncode(body)));
        final text = await res.readAsString();
        expect(res.statusCode, 200, reason: text);
        return jsonDecode(text) as Map<String, dynamic>;
      }

      final facts = (await post('api/facts', {'query': fixture['query']}))['facts'];
      final plan = (await post('api/plan', {'facts': facts}))['plan'];
      final viz = Visualization.build(
        FactsResult.fromJson(facts).valueOrThrow,
        Plan.fromJson(plan).valueOrThrow,
      ).valueOrThrow;
      printOnFailure(const JsonEncoder.withIndent('  ').convert({'facts': facts, 'plan': plan}));
      expect(viz.props.template.wire, fixture['expectedTemplate']);
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
