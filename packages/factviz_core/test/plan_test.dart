import 'package:factviz_core/factviz_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

List<String> _issues(Object? json) => Plan.fromJson(json).issues.map((i) => '$i').toList();

void main() {
  group('Plan.fromJson', () {
    test('parses every fixture into the expected variant', () {
      final expected = {
        'scale_zoom': isA<ScaleZoomPlan>(),
        'timeline': isA<TimelinePlan>(),
        'exponential_growth': isA<ExponentialGrowthPlan>(),
        'comparison_bars': isA<ComparisonBarsPlan>(),
        'process_steps': isA<ProcessStepsPlan>(),
      };
      for (final f in loadQueryFixtures()) {
        final plan = Plan.fromJson(f.plan).valueOrThrow;
        expect(plan.template.wire, f.expectedTemplate, reason: f.name);
        expect(plan, expected[f.expectedTemplate], reason: f.name);
      }
    });

    test('round-trips through toJson', () {
      for (final f in loadQueryFixtures()) {
        final plan = Plan.fromJson(f.plan).valueOrThrow;
        expect(Plan.fromJson(plan.toJson()).valueOrThrow.toJson(), plan.toJson(), reason: f.name);
      }
    });

    test('parses the none template', () {
      final plan = Plan.fromJson({
        'template': 'none',
        'title': 'Best pizza topping',
        'reason': 'This is a matter of taste, not a measurable fact.',
      }).valueOrThrow;
      expect(plan, isA<NonePlan>());
      expect(plan.factIds, isEmpty);
    });

    test('rejects unknown templates', () {
      expect(_issues({'template': 'pie_chart', 'title': 'x'}), [
        'template: must be one of: scale_zoom, timeline, exponential_growth, comparison_bars, process_steps, none',
      ]);
    });

    test('reports every missing field for a variant', () {
      expect(_issues({'template': 'exponential_growth', 'title': 'Growth'}), unorderedEquals([
        'initialFactId: is required',
        'factorFactId: is required',
        'stepsFactId: is required',
        'stepLabel: is required',
        'defaultScale: is required',
      ]));
    });

    test('defaults optional fields', () {
      final plan = Plan.fromJson({
        'template': 'scale_zoom',
        'title': 'Whale vs bus',
        'mode': 'size',
        'items': [
          {'factId': 'a', 'displayName': 'A'},
          {'factId': 'b', 'displayName': 'B'},
        ],
      }).valueOrThrow as ScaleZoomPlan;
      expect(plan.items.first.shape, ItemShape.circle);
    });

    test('enforces item counts', () {
      final json = clone(fixture('scale_zoom_planets').plan);
      (json['items'] as List).removeRange(1, 8);
      expect(_issues(json), ['items: must have at least 2 items (got 1)']);
    });

    test('rejects duplicate fact references', () {
      final json = clone(fixture('comparison_whale_bus').plan);
      (json['bars'] as List)[1]['factId'] = 'blue_whale_mass';
      expect(_issues(json), ['fact "blue_whale_mass" is referenced more than once']);
    });

    test('enforces the autoplay range', () {
      final json = clone(fixture('process_water_cycle').plan)..['autoplayMs'] = 200;
      expect(_issues(json), ['autoplayMs: must be ≥ 1500 (got 200)']);
    });

    test('rejects malformed fact id references', () {
      final json = clone(fixture('timeline_spaceflight').plan);
      (json['eventFactIds'] as List)[0] = 'Sputnik 1';
      expect(_issues(json), ['eventFactIds[0]: must be a fact id from the facts JSON']);
    });
  });
}
