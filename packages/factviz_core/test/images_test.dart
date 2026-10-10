import 'package:factviz_core/factviz_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  test('catalog keys are slugs and photos point at webp files', () {
    for (final a in imageCatalog.values) {
      expect(a.key, matches(RegExp(r'^[a-z_]+$')));
      expect(a.aspect, greaterThan(0));
      if (a.kind == ImageKind.photo) expect(a.src, 'img/${a.key}.webp');
    }
  });

  test('plans may attach catalog images', () {
    final plan = Plan.fromJson(fixture('scale_zoom_planets').plan).valueOrThrow as ScaleZoomPlan;
    expect(plan.items.map((i) => i.image), contains('jupiter'));
    expect(Plan.fromJson(plan.toJson()).valueOrThrow.toJson(), plan.toJson());
  });

  test('unknown images are rejected with the allowed list', () {
    final json = clone(fixture('comparison_whale_bus').plan);
    (json['bars'] as List)[0]['image'] = 'unicorn';
    final issue = Plan.fromJson(json).issues.single.toString();
    expect(issue, startsWith('bars[0].image: unknown image "unicorn"; allowed: sun, mercury'));
  });

  test('images must suit the shape', () {
    final json = clone(fixture('scale_zoom_planets').plan);
    (json['items'] as List)[0]['shape'] = 'tower';
    expect(Plan.fromJson(json).issues.single.toString(), 'items[0].shape: image "mercury" can only be drawn as: circle');
  });

  test('resolved props carry the image', () {
    final f = fixture('comparison_whale_bus');
    final props = const PlanResolver()
        .resolve(Plan.fromJson(f.plan).valueOrThrow, FactsResult.fromJson(f.facts).valueOrThrow)
        .valueOrThrow as ComparisonBarsProps;
    expect(props.bars.first.image?.key, 'blue_whale');
  });

  test('schema lists every image', () {
    final items = ((planJsonSchema['properties']! as Map)['items'] as Map)['items'] as Map;
    expect(((items['properties'] as Map)['image'] as Map)['enum'], imageCatalog.keys.toList());
  });
}
