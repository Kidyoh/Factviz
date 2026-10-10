import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:factviz_core/factviz_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

const _resolver = PlanResolver(referenceYear: 2026);

Visualization _viz(QueryFixture f) => Visualization.build(
      FactsResult.fromJson(f.facts).valueOrThrow,
      Plan.fromJson(f.plan).valueOrThrow,
      resolver: _resolver,
    ).valueOrThrow;

String _encodeRaw(Object json) =>
    base64Url.encode(const GZipEncoder().encodeBytes(utf8.encode(jsonEncode(json)))).replaceAll('=', '');

void main() {
  group('ShareCodec', () {
    test('round-trips every fixture', () {
      for (final f in loadQueryFixtures()) {
        final viz = _viz(f);
        final payload = ShareCodec.encode(viz);
        expect(payload, matches(RegExp(r'^[A-Za-z0-9_-]+$')), reason: f.name);
        final decoded = ShareCodec.decode(payload, resolver: _resolver).valueOrThrow;
        expect(decoded.plan.toJson(), viz.plan.toJson(), reason: f.name);
        expect(decoded.facts.toJson(), viz.facts.toJson(), reason: f.name);
        expect(decoded.props.template, viz.props.template, reason: f.name);
      }
    });

    test('builds factviz:// links and extracts the payload', () {
      final viz = _viz(fixture('comparison_whale_bus'));
      final link = ShareCodec.link(viz);
      expect(link.scheme, 'factviz');
      expect(link.host, 'app');
      expect(link.path, startsWith('/v/'));
      expect(ShareCodec.payloadFromUri(link), ShareCodec.encode(viz));
      expect(ShareCodec.payloadFromUri(Uri.parse('/v/abc')), 'abc');
      expect(ShareCodec.payloadFromUri(Uri.parse('/dev')), isNull);
    });

    test('rejects damaged payloads', () {
      final payload = ShareCodec.encode(_viz(fixture('process_water_cycle')));
      for (final bad in ['', 'not-base64!!', payload.substring(0, payload.length ~/ 2), 'A' * 40000]) {
        final result = ShareCodec.decode(bad);
        expect(result.issues.single.message, 'this share link is damaged or incomplete');
      }
    });

    test('re-validates decoded content', () {
      // Hand-craft a well-formed payload whose plan references a missing fact.
      final f = fixture('comparison_whale_bus');
      final plan = clone(f.plan);
      (plan['bars'] as List)[1]['factId'] = 'ghost';
      final payload = _encodeRaw({'v': 1, 'facts': f.facts, 'plan': plan});
      expect(ShareCodec.decode(payload).issues.map((i) => '$i'), ['bars[1].factId: unknown fact id "ghost"']);

      final broken = clone(f.facts)..remove('topic');
      expect(
        ShareCodec.decode(_encodeRaw({'v': 1, 'facts': broken, 'plan': f.plan})).issues.map((i) => '$i'),
        ['facts.topic: is required'],
      );
    });

    test('rejects unknown versions', () {
      final f = fixture('comparison_whale_bus');
      final payload = _encodeRaw({'v': 99, 'facts': f.facts, 'plan': f.plan});
      expect(ShareCodec.decode(payload).issues.single.message, 'unsupported share link version 99');
    });
  });

  group('Visualization.keyFacts', () {
    test('lists plan facts first, in plan order', () {
      final viz = _viz(fixture('exponential_paper_fold'));
      expect(viz.keyFacts.map((f) => f.id), ['paper_thickness', 'fold_factor', 'fold_count', 'moon_distance']);
    });
  });
}
