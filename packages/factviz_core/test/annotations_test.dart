import 'package:factviz_core/factviz_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

const _resolver = PlanResolver(referenceYear: 2026);

TemplateProps _props(String name, {Map<String, dynamic> Function(Map<String, dynamic>)? facts, Map<String, dynamic> Function(Map<String, dynamic>)? plan}) {
  final f = fixture(name);
  final factsJson = facts == null ? f.facts : facts(clone(f.facts));
  final planJson = plan == null ? f.plan : plan(clone(f.plan));
  return _resolver.resolve(Plan.fromJson(planJson).valueOrThrow, FactsResult.fromJson(factsJson).valueOrThrow).valueOrThrow;
}

void main() {
  test('formatRatio', () {
    expect(formatRatio(2.64), '2.6×');
    expect(formatRatio(3), '3×');
    expect(formatRatio(29.3), '29×');
    expect(formatRatio(1234), '1,200×');
  });

  test('scale_zoom compares largest to smallest by shape', () {
    final a = annotationsFor(_props('scale_zoom_planets'));
    expect(a.single.text, 'Jupiter is 29× as wide as Mercury');
    expect(a.single.anchor, AnchorKind.item);
    expect(a.single.index, 7);
  });

  test('timeline reports span and the standout gap', () {
    final a = annotationsFor(_props('timeline_spaceflight'));
    expect(a.map((x) => x.text), ['63 years from first to last', 'A 20-year gap']);
    expect(a.last.anchor, AnchorKind.gap);
    expect((a.last.index, a.last.index2), (7, 8));
  });

  test('timeline log axis reports how long ago the first event was', () {
    final props = _props('timeline_spaceflight', facts: (j) {
      (j['facts'] as List)[0]
        ..['year'] = -4540000000
        ..remove('month')
        ..remove('day');
      return j;
    }, plan: (j) => j..['axis'] = 'log_years_ago');
    final a = annotationsFor(props);
    expect(a.first.text, 'Sputnik 1 launched: 4.54 billion years ago');
    expect(a.last.anchor, AnchorKind.gap);
  });

  test('growth explains the slow start and the target', () {
    final a = annotationsFor(_props('exponential_paper_fold'));
    expect(a.map((x) => x.text), [
      'Fold 36: still only 6,872 km',
      'Fold 42: Average Earth–Moon distance reached',
    ]);
    expect(a.last.index, 42);
  });

  test('growth reports progress when the target is out of reach', () {
    final props = _props('exponential_paper_fold', facts: (j) {
      (j['facts'] as List)[2]['value'] = 30;
      return j;
    });
    expect(annotationsFor(props).last.text, 'Average Earth–Moon distance: 0.03% of the way');
  });

  test('bars use a verb for the dimension', () {
    final a = annotationsFor(_props('comparison_whale_bus'));
    expect(a.single.text, 'Blue whale weighs 25× as much as African elephant');
    expect(a.single.index, 0);
  });

  test('process steps have no annotations', () {
    expect(annotationsFor(_props('process_water_cycle')), isEmpty);
  });
}
