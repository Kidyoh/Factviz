import 'package:factviz_core/factviz_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

const _resolver = PlanResolver(referenceYear: 2026);

ValidationResult<TemplateProps> _resolve(Map<String, dynamic> facts, Map<String, dynamic> plan) =>
    _resolver.resolve(Plan.fromJson(plan).valueOrThrow, FactsResult.fromJson(facts).valueOrThrow);

List<String> _issues(Map<String, dynamic> facts, Map<String, dynamic> plan) =>
    _resolve(facts, plan).issues.map((i) => '$i').toList();

void main() {
  group('PlanResolver', () {
    test('every fixed query resolves to its template', () {
      final fixtures = loadQueryFixtures();
      expect(fixtures, hasLength(5));
      expect(fixtures.map((f) => f.expectedTemplate).toSet(), hasLength(5));
      for (final f in fixtures) {
        final props = _resolve(f.facts, f.plan).valueOrThrow;
        expect(props.template.wire, f.expectedTemplate, reason: f.name);
      }
    });

    test('rejects unknown fact ids with the plan path', () {
      final f = fixture('scale_zoom_planets');
      final plan = clone(f.plan);
      (plan['items'] as List)[2]['factId'] = 'pluto_diameter';
      expect(_issues(f.facts, plan), ['items[2].factId: unknown fact id "pluto_diameter"']);
    });

    test('rejects facts of the wrong kind', () {
      final f = fixture('exponential_paper_fold');
      final facts = clone(f.facts);
      (facts['facts'] as List).add({
        'kind': 'event', 'id': 'first_fold', 'label': 'x', 'year': 2000, 'sourceNote': 'y',
      });
      final plan = clone(f.plan)..['stepsFactId'] = 'first_fold';
      expect(_issues(facts, plan), ['stepsFactId: fact "first_fold" is a event fact; expected a quantity fact']);
    });

    group('scale_zoom', () {
      test('sorts items smallest to largest and computes range', () {
        final f = fixture('scale_zoom_planets');
        final props = _resolve(f.facts, f.plan).valueOrThrow as ScaleZoomProps;
        expect(props.items.first.displayName, 'Mercury');
        expect(props.items.last.displayName, 'Jupiter');
        expect(props.dimension, Dimension.length);
        expect(props.minSi, 4879e3);
        expect(props.log10Range, closeTo(1.467, 0.001));
        expect(props.items.first.quantity.sourceNote, contains('NASA'));
      });

      test('converts mixed length units to one base', () {
        final f = fixture('scale_zoom_planets');
        final facts = clone(f.facts);
        (facts['facts'] as List)[0]
          ..['value'] = 3031.6
          ..['unit'] = 'mi';
        final props = _resolve(facts, f.plan).valueOrThrow as ScaleZoomProps;
        expect(props.items.first.valueSi, closeTo(4879e3, 1e3));
      });

      test('rejects mixed dimensions', () {
        final f = fixture('scale_zoom_planets');
        final facts = clone(f.facts);
        (facts['facts'] as List)[0]['unit'] = 'kg';
        expect(_issues(facts, f.plan), ['items: all facts must share one dimension (found mass, length)']);
      });

      test('rejects non-spatial dimensions', () {
        final f = fixture('comparison_whale_bus');
        final plan = {
          'template': 'scale_zoom',
          'title': 'Weights',
          'mode': 'size',
          'items': [
            {'factId': 'blue_whale_mass', 'displayName': 'Whale'},
            {'factId': 'school_bus_mass', 'displayName': 'Bus'},
          ],
        };
        expect(_issues(f.facts, plan).single, startsWith('items: scale_zoom needs length, area or volume facts'));
      });

      test('rejects zero values and absurd ranges', () {
        final f = fixture('scale_zoom_planets');
        final facts = clone(f.facts);
        (facts['facts'] as List)[0]['value'] = 0;
        expect(_issues(facts, f.plan), ['items[0].factId: fact "mercury_diameter" must be greater than 0 to draw to scale']);

        final huge = clone(f.facts);
        (huge['facts'] as List)[0]
          ..['value'] = 1e-9
          ..['unit'] = 'nm';
        (huge['facts'] as List)[1]
          ..['value'] = 1e15
          ..['unit'] = 'pc';
        expect(_issues(huge, f.plan).single, startsWith('items: range between smallest and largest item is too large'));
      });
    });

    group('timeline', () {
      test('sorts events and positions them on a linear axis', () {
        final f = fixture('timeline_spaceflight');
        final plan = clone(f.plan);
        (plan['eventFactIds'] as List).shuffle();
        final props = _resolve(f.facts, plan).valueOrThrow as TimelineProps;
        expect(props.events.first.factId, 'sputnik_1');
        expect(props.events.last.factId, 'crew_dragon');
        expect(props.positionOf(props.events.first), 0);
        expect(props.positionOf(props.events.last), 1);
        final apollo = props.events.firstWhere((e) => e.factId == 'apollo_11');
        expect(props.positionOf(apollo), closeTo((1969.55 - 1957.75) / (2020.4 - 1957.75), 0.01));
      });

      test('uses years-ago on a log axis', () {
        final f = fixture('timeline_spaceflight');
        final facts = clone(f.facts);
        (facts['facts'] as List)[0]
          ..['year'] = -4500000000
          ..remove('month')
          ..remove('day');
        final plan = clone(f.plan)..['axis'] = 'log_years_ago';
        final props = _resolve(facts, plan).valueOrThrow as TimelineProps;
        expect(props.events.first.yearsAgo, 4500002026);
        expect(props.positionOf(props.events.first), 0);
        expect(props.positionOf(props.events.last), 1);
        // On a log axis, 1957 and 2020 are far from the Earth's formation.
        final gagarin = props.events.firstWhere((e) => e.factId == 'gagarin');
        expect(props.positionOf(gagarin), greaterThan(0.8));
      });
    });

    group('exponential_growth', () {
      test('computes growth and the step that reaches the target', () {
        final f = fixture('exponential_paper_fold');
        final props = _resolve(f.facts, f.plan).valueOrThrow as ExponentialGrowthProps;
        expect(props.factor, 2);
        expect(props.steps, 42);
        expect(props.valueAtStepSi(0), closeTo(1e-4, 1e-12));
        expect(props.valueAtStepSi(10), closeTo(0.1024, 1e-6));
        expect(props.finalValueSi, closeTo(4.398e8, 1e6));
        expect(props.targetStep, 42);
        expect(props.formatValueSi(props.finalValueSi), '439,805 km');
      });

      test('targetStep is null when the target is out of reach', () {
        final f = fixture('exponential_paper_fold');
        final facts = clone(f.facts);
        (facts['facts'] as List)[2]['value'] = 20;
        final props = _resolve(facts, f.plan).valueOrThrow as ExponentialGrowthProps;
        expect(props.targetStep, isNull);
      });

      test('validates factor, steps and target', () {
        final f = fixture('exponential_paper_fold');
        final facts = clone(f.facts);
        final list = facts['facts'] as List;
        list[1]['unit'] = 'count';
        list[2]['value'] = 42.5;
        list[3]['unit'] = 'kg';
        expect(_issues(facts, f.plan), unorderedEquals([
          'factorFactId: fact "fold_factor" must use unit "ratio" (got "count")',
          'stepsFactId: fact "fold_count" must be a whole number from 1 to 200 (got 42.5)',
          'targetFactId: fact "moon_distance" (mass) must match the initial value\'s dimension (length)',
        ]));
      });

      test('rejects a factor of 1 or less', () {
        final f = fixture('exponential_paper_fold');
        final facts = clone(f.facts);
        (facts['facts'] as List)[1]['value'] = 1;
        expect(_issues(facts, f.plan), ['factorFactId: fact "fold_factor" must be > 1 and ≤ 1000.0 (got 1.0)']);
      });

      test('rejects growth that overflows', () {
        final f = fixture('exponential_paper_fold');
        final facts = clone(f.facts);
        (facts['facts'] as List)[1]['value'] = 1000;
        (facts['facts'] as List)[2]['value'] = 200;
        expect(_issues(facts, f.plan).single, startsWith('stepsFactId: growth overflows'));
      });
    });

    group('comparison_bars', () {
      test('keeps planner order and carries provenance', () {
        final f = fixture('comparison_whale_bus');
        final props = _resolve(f.facts, f.plan).valueOrThrow as ComparisonBarsProps;
        expect(props.bars.map((b) => b.displayName), ['Blue whale', 'School bus', 'African elephant']);
        expect(props.maxSi, 150000);
        expect(props.bars.first.quantity.displayValue, '~150 t');
        expect(props.dimension, Dimension.mass);
      });

      test('rejects comparing different currencies', () {
        final facts = {
          'query': 'q', 'topic': 't', 'confidence': 'high', 'explanation': 'e',
          'facts': [
            {'kind': 'quantity', 'id': 'a', 'label': 'A', 'value': 1, 'unit': 'USD', 'sourceNote': 's'},
            {'kind': 'quantity', 'id': 'b', 'label': 'B', 'value': 1, 'unit': 'EUR', 'sourceNote': 's'},
          ],
        };
        final plan = {
          'template': 'comparison_bars', 'title': 'Money', 'orientation': 'vertical',
          'bars': [
            {'factId': 'a', 'displayName': 'A'},
            {'factId': 'b', 'displayName': 'B'},
          ],
        };
        expect(_issues(facts, plan), ['bars: all facts must share one dimension (found money:USD, money:EUR)']);
      });
    });

    group('process_steps', () {
      test('sorts by step order regardless of plan order', () {
        final f = fixture('process_water_cycle');
        final plan = clone(f.plan)..['stepFactIds'] = ['collection', 'evaporation', 'precipitation', 'condensation'];
        final props = _resolve(f.facts, plan).valueOrThrow as ProcessStepsProps;
        expect(props.steps.map((s) => s.title), ['Evaporation', 'Condensation', 'Precipitation', 'Collection']);
        expect(props.autoplay, const Duration(milliseconds: 3500));
        expect(props.loop, isTrue);
      });

      test('rejects quantity facts', () {
        final f = fixture('process_water_cycle');
        final facts = clone(f.facts);
        (facts['facts'] as List).add({
          'kind': 'quantity', 'id': 'ocean_share', 'label': 'x', 'value': 97, 'unit': 'count', 'sourceNote': 's',
        });
        final plan = clone(f.plan);
        (plan['stepFactIds'] as List)[0] = 'ocean_share';
        expect(_issues(facts, plan), ['stepFactIds[0]: fact "ocean_share" is a quantity fact; expected a step fact']);
      });
    });

    test('none resolves to NoneProps', () {
      final f = fixture('process_water_cycle');
      final props = _resolve(f.facts, {'template': 'none', 'title': 'Hmm', 'reason': 'Nothing fits.'}).valueOrThrow;
      expect(props, isA<NoneProps>().having((p) => p.reason, 'reason', 'Nothing fits.'));
    });
  });
}
