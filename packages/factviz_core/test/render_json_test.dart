import 'dart:convert';

import 'package:factviz_core/factviz_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

const _resolver = PlanResolver(referenceYear: 2026);

Map<String, dynamic> _render(String name) {
  final f = fixture(name);
  final props = _resolver.resolve(Plan.fromJson(f.plan).valueOrThrow, FactsResult.fromJson(f.facts).valueOrThrow).valueOrThrow;
  // Round-trip through JSON text, exactly as it reaches the renderer.
  return jsonDecode(jsonEncode(renderJson(props))) as Map<String, dynamic>;
}

void main() {
  test('every fixture renders to JSON with its template and annotations', () {
    for (final f in loadQueryFixtures()) {
      final r = _render(f.name);
      expect(r['version'], 1);
      expect(r['template'], f.expectedTemplate);
      expect(r['title'], f.plan['title']);
      expect(r['annotations'], isA<List<dynamic>>());
    }
  });

  test('scale_zoom items are sorted with display strings, images and units', () {
    final r = _render('scale_zoom_planets');
    final items = r['items'] as List;
    expect(items.first['name'], 'Mercury');
    expect(items.first['display'], '4,879 km');
    expect(items.first['image']['src'], 'img/mercury.webp');
    expect(items.last['linearSi'], 142984000);
    expect((r['units']['ladder'] as List).map((u) => u['symbol']), contains('km'));
  });

  test('growth carries a precomputed series with display strings', () {
    final r = _render('exponential_paper_fold');
    final series = r['series'] as List;
    expect(series, hasLength(43));
    expect(series.first['display'], '100 µm');
    expect(series.last['display'], '439,805 km');
    expect(r['targetStep'], 42);
    expect(r['target']['display'], '~384,400 km');
  });

  test('timeline, bars and steps carry their fields', () {
    final t = _render('timeline_spaceflight');
    expect((t['events'] as List).first['date'], '4 Oct 1957');
    final b = _render('comparison_whale_bus');
    expect((b['bars'] as List).first['image']['kind'], 'silhouette');
    final s = _render('process_water_cycle');
    expect(s['autoplayMs'], 3500);
    expect((s['steps'] as List).last['title'], 'Collection');
  });
}
