import 'package:factviz_core/factviz_core.dart';
import 'package:test/test.dart';

const _resolver = PlanResolver(referenceYear: 2026);

Map<String, Object?> _q(String id, num value, String unit, {int? year, bool approx = false}) => {
      'kind': 'quantity',
      'id': id,
      'label': id,
      'value': value,
      'unit': unit,
      'approximate': approx,
      'year': ?year,
      'sourceNote': 'test',
    };

Map<String, Object?> _facts(List<Map<String, Object?>> facts) =>
    {'query': 'q', 'topic': 't', 'confidence': 'high', 'explanation': 'e', 'facts': facts};

ValidationResult<TemplateProps> _resolve(List<Map<String, Object?>> facts, Map<String, Object?> plan) =>
    _resolver.resolve(Plan.fromJson({'title': 'T', ...plan}).valueOrThrow, FactsResult.fromJson(_facts(facts)).valueOrThrow);

List<String> _issues(List<Map<String, Object?>> facts, Map<String, Object?> plan) =>
    _resolve(facts, plan).issues.map((i) => '$i').toList();

List<Map<String, Object?>> _items(List<String> ids) => [for (final id in ids) {'factId': id, 'displayName': id}];

void main() {
  group('facts', () {
    test('place facts validate coordinates', () {
      final ok = FactsResult.fromJson(_facts([
        {'kind': 'place', 'id': 'paris', 'label': 'Paris', 'lat': 48.86, 'lon': 2.35, 'sourceNote': 's'},
      ]));
      expect(ok.valueOrThrow.facts.single, isA<PlaceFact>());
      final bad = FactsResult.fromJson(_facts([
        {'kind': 'place', 'id': 'x', 'label': 'X', 'lat': 95, 'lon': 2, 'sourceNote': 's'},
      ]));
      expect(bad.issues.map((i) => i.path), contains('facts[0].lat'));
    });

    test('percent above 100 is rejected', () {
      expect(FactsResult.fromJson(_facts([_q('p', 120, 'percent')])).issues.single.path, 'facts[0].value');
    });

    test('quantity year round-trips', () {
      final f = FactsResult.fromJson(_facts([_q('co2', 420, 'count', year: 2023)])).valueOrThrow;
      expect((f.facts.single as QuantityFact).year, 2023);
      expect(f.toJson()['facts'], [containsPair('year', 2023)]);
    });
  });

  group('plan parsing', () {
    test('item limits are per template', () {
      final r = Plan.fromJson({'template': 'waffle', 'title': 'T', 'items': _items(['a', 'b', 'c', 'd', 'e'])});
      expect(r.issues.map((i) => i.path), ['items']);
    });

    test('versus requires subject names', () {
      final r = Plan.fromJson({
        'template': 'versus',
        'title': 'T',
        'rows': [
          {'label': 'x', 'aFactId': 'a', 'bFactId': 'b'},
          {'label': 'y', 'aFactId': 'c', 'bFactId': 'd'},
        ],
      });
      expect(r.issues.map((i) => i.path), containsAll(['aName', 'bName']));
    });

    test('every template round-trips through toJson', () {
      final plans = <Map<String, Object?>>[
        {'template': 'treemap', 'title': 'T', 'items': _items(['a', 'b', 'c'])},
        {'template': 'number_line', 'title': 'T', 'items': _items(['a', 'b']), 'scale': 'log'},
        {'template': 'pictogram', 'title': 'T', 'unitFactId': 'a', 'totalFactId': 'b', 'unitName': 'buses', 'totalName': 'whale'},
        {
          'template': 'line_series',
          'title': 'T',
          'series': [
            {'displayName': 'S', 'factIds': ['a', 'b', 'c']},
          ],
        },
        {'template': 'cosmic_clock', 'title': 'T', 'eventFactIds': ['a', 'b', 'c']},
        {
          'template': 'map_points',
          'title': 'T',
          'points': [
            {'placeFactId': 'a', 'displayName': 'A'},
          ],
        },
      ];
      for (final json in plans) {
        final plan = Plan.fromJson(json).valueOrThrow;
        expect(plan.toJson(), json, reason: json['template'] as String);
      }
    });
  });

  group('donut / stacked_bar', () {
    test('adds a remainder slice up to the total', () {
      final p = _resolve([_q('a', 30, 'km2'), _q('b', 20, 'km2'), _q('t', 100, 'km2')], {
        'template': 'donut',
        'items': _items(['a', 'b']),
        'totalFactId': 't',
      }).valueOrThrow as ItemsProps;
      expect(p.items.map((i) => i.displayName), ['a', 'b', 'Other']);
      expect(p.items.last.remainder, isTrue);
      expect(p.items.last.quantity.value, closeTo(50, 1e-9));
      expect(p.shareOf(p.items.first), closeTo(0.3, 1e-9));
    });

    test('percent parts are shares of 100%', () {
      final p = _resolve([_q('n', 78, 'percent'), _q('o', 21, 'percent')], {
        'template': 'stacked_bar',
        'items': _items(['n', 'o']),
      }).valueOrThrow as ItemsProps;
      expect(p.items.last.displayName, 'Other');
      expect(p.shareOf(p.items.first), closeTo(0.78, 1e-9));
      expect(renderJson(p)['items'], [
        containsPair('shareDisplay', '78%'),
        containsPair('shareDisplay', '21%'),
        containsPair('shareDisplay', '1%'),
      ]);
    });

    test('rejects parts larger than the whole', () {
      expect(
        _issues([_q('a', 80, 'percent'), _q('b', 30, 'percent')], {'template': 'donut', 'items': _items(['a', 'b'])}),
        [startsWith('items: the parts add up to more than the whole')],
      );
    });

    test('rejects mixed dimensions', () {
      expect(
        _issues([_q('a', 1, 'kg'), _q('b', 1, 'km')], {'template': 'donut', 'items': _items(['a', 'b'])}),
        ['items: all facts must share one dimension (found mass, length)'],
      );
    });
  });

  test('waffle needs percentages', () {
    expect(_issues([_q('a', 3, 'count')], {'template': 'waffle', 'items': _items(['a'])}),
        ['items: waffle needs percent facts (got count)']);
    final p = _resolve([_q('a', 71, 'percent')], {'template': 'waffle', 'items': _items(['a'])}).valueOrThrow;
    expect(annotationsFor(p).single.text, 'About 7 in every 10');
  });

  test('treemap sorts largest first and rejects zero', () {
    final facts = [_q('a', 1, 't'), _q('b', 5, 't'), _q('c', 3, 't')];
    final p = _resolve(facts, {'template': 'treemap', 'items': _items(['a', 'b', 'c'])}).valueOrThrow as ItemsProps;
    expect(p.items.map((i) => i.displayName), ['b', 'c', 'a']);
    expect(annotationsFor(p).single.text, 'b: 56% of the total');
    expect(
      _issues([_q('a', 0, 't'), _q('b', 5, 't'), _q('c', 3, 't')], {'template': 'bubble_pack', 'items': _items(['a', 'b', 'c'])}),
      ['items[0].factId: fact "a" must be greater than 0 to have an area'],
    );
  });

  test('number_line sorts smallest first; log needs positive values', () {
    final facts = [_q('atom', 1e-10, 'm'), _q('cell', 1e-5, 'm'), _q('earth', 12742, 'km')];
    final p = _resolve(facts, {'template': 'number_line', 'items': _items(['earth', 'atom', 'cell']), 'scale': 'log'})
        .valueOrThrow as ItemsProps;
    expect(p.items.map((i) => i.displayName), ['atom', 'cell', 'earth']);
    expect(annotationsFor(p).single.text, 'atom to earth: 17 orders of magnitude');
    expect(
      _issues([_q('a', 0, 'm'), _q('b', 1, 'm')], {'template': 'number_line', 'items': _items(['a', 'b']), 'scale': 'log'}),
      ['items: a log scale needs every value to be greater than 0'],
    );
    expect(
      _issues([_q('a', 1, 'm'), _q('b', 2, 'm'), _q('c', 3, 'm')], {'template': 'treemap', 'items': _items(['a', 'b', 'c']), 'scale': 'log'}),
      ['scale: only number_line and lollipop can use a log scale'],
    );
  });

  group('pairs', () {
    test('slope computes change and checks year order', () {
      final facts = [_q('a', 100, 'count', year: 1990), _q('b', 145, 'count', year: 2020)];
      final p = _resolve(facts, {
        'template': 'slope',
        'rows': [
          {'label': 'Thing', 'aFactId': 'a', 'bFactId': 'b'},
        ],
      }).valueOrThrow as PairsProps;
      expect((renderJson(p)['rows'] as List).single, containsPair('change', '+45%'));
      expect(annotationsFor(p).single.text, '+45%');
      expect(
        _issues(facts, {
          'template': 'slope',
          'rows': [
            {'label': 'Thing', 'aFactId': 'b', 'bFactId': 'a'},
          ],
        }),
        ['rows[0]: aFactId is the earlier value: year 2020 is after 1990'],
      );
    });

    test('range_bars needs low ≤ high', () {
      expect(
        _issues([_q('a', 5, 'yr'), _q('b', 3, 'yr'), _q('c', 1, 'yr'), _q('d', 2, 'yr')], {
          'template': 'range_bars',
          'rows': [
            {'label': 'x', 'aFactId': 'a', 'bFactId': 'b'},
            {'label': 'y', 'aFactId': 'c', 'bFactId': 'd'},
          ],
        }),
        ['rows[0]: aFactId is the low end and must not exceed bFactId'],
      );
    });

    test('versus rows may differ in dimension but not within a row', () {
      final facts = [_q('ca', 120, 'km/h'), _q('ga', 72, 'km/h'), _q('cm', 50, 'kg'), _q('gm', 30, 'kg')];
      final plan = {
        'template': 'versus',
        'aName': 'Cheetah',
        'bName': 'Greyhound',
        'rows': [
          {'label': 'Top speed', 'aFactId': 'ca', 'bFactId': 'ga'},
          {'label': 'Weight', 'aFactId': 'cm', 'bFactId': 'gm'},
        ],
      };
      final p = _resolve(facts, plan).valueOrThrow as PairsProps;
      expect((renderJson(p)['rows'] as List).first, allOf(containsPair('winner', 'a'), containsPair('ratio', '1.7×')));
      final bad = {
        ...plan,
        'rows': [
          {'label': 'Top speed', 'aFactId': 'ca', 'bFactId': 'gm'},
          {'label': 'Weight', 'aFactId': 'cm', 'bFactId': 'ga'},
        ],
      };
      expect(_issues(facts, bad), hasLength(2));
    });

    test('rate_counter converts to a per-second rate', () {
      final p = _resolve([_q('births', 134e6, 'count'), _q('year', 1, 'yr')], {
        'template': 'rate_counter',
        'rows': [
          {'label': 'Births', 'aFactId': 'births', 'bFactId': 'year'},
        ],
      }).valueOrThrow as PairsProps;
      final row = (renderJson(p)['rows'] as List).single as Map;
      expect(row['perSecond'] as double, closeTo(4.246, 0.01));
      expect(row['rateDisplay'], '≈ 4.25 every second');
      expect(
        _issues([_q('births', 134e6, 'count'), _q('year', 1, 'km')], {
          'template': 'rate_counter',
          'rows': [
            {'label': 'Births', 'aFactId': 'births', 'bFactId': 'year'},
          ],
        }),
        ['rows[0].bFactId: must be a duration greater than 0, e.g. 1 yr'],
      );
    });
  });

  test('pictogram counts units and bounds the count', () {
    final p = _resolve([_q('whale', 150, 't'), _q('bus', 11, 't')], {
      'template': 'pictogram',
      'unitFactId': 'bus',
      'totalFactId': 'whale',
      'unitName': 'school buses',
      'totalName': 'blue whale',
      'image': 'school_bus',
    }).valueOrThrow as PictogramProps;
    expect(p.count, closeTo(13.6, 0.1));
    expect(renderJson(p)['headline'], '14 school buses = 1 blue whale');
    expect(
      _issues([_q('whale', 150, 't'), _q('bus', 11, 't')], {
        'template': 'pictogram',
        'unitFactId': 'whale',
        'totalFactId': 'bus',
        'unitName': 'whales',
        'totalName': 'bus',
      }),
      [startsWith('totalFactId: the total is smaller than one unit')],
    );
  });

  test('line_series needs a year on every point', () {
    final facts = [_q('a', 1, 'count', year: 2000), _q('b', 2, 'count', year: 2010), _q('c', 4, 'count')];
    final plan = {
      'template': 'line_series',
      'series': [
        {'displayName': 'S', 'factIds': ['b', 'a', 'c']},
      ],
    };
    expect(_issues(facts, plan), ['series[0].factIds[2]: fact "c" needs a year to be placed on a time axis']);
    facts[2] = _q('c', 4, 'count', year: 2020);
    final p = _resolve(facts, plan).valueOrThrow as SeriesProps;
    expect(p.series.single.points.map((pt) => pt.year), [2000, 2010, 2020]);
    expect(annotationsFor(p).single.text, '4× since 2000');
  });

  test('cosmic_clock maps history onto one day', () {
    Map<String, Object?> ev(String id, int year) =>
        {'kind': 'event', 'id': id, 'label': id, 'year': year, 'sourceNote': 's'};
    final p = _resolve([ev('bb', -13800000000), ev('earth', -4540000000), ev('humans', -300000)], {
      'template': 'cosmic_clock',
      'eventFactIds': ['bb', 'earth', 'humans'],
    }).valueOrThrow as ClockProps;
    expect(p.events.first.clockTime, '00:00:00');
    expect(p.events[1].clockTime, '16:06:15');
    expect(p.events.last.clockTime, '23:59:58');
    expect(annotationsFor(p).single.text, 'humans: 23:59:58, 1 s before midnight');
    expect(
      _issues([ev('a', 1990), ev('b', 2000), ev('c', 2010)], {'template': 'cosmic_clock', 'eventFactIds': ['a', 'b', 'c']}),
      [startsWith('eventFactIds: cosmic_clock needs a long history')],
    );
  });

  test('map_points needs place facts and all-or-none values', () {
    Map<String, Object?> place(String id) =>
        {'kind': 'place', 'id': id, 'label': id, 'lat': 10, 'lon': 20, 'sourceNote': 's'};
    final facts = [place('a'), place('b'), _q('va', 3, 'count'), _q('vb', 5, 'count')];
    final p = _resolve(facts, {
      'template': 'map_points',
      'points': [
        {'placeFactId': 'a', 'displayName': 'A', 'valueFactId': 'va'},
        {'placeFactId': 'b', 'displayName': 'B', 'valueFactId': 'vb'},
      ],
    }).valueOrThrow as MapProps;
    expect(p.dimension, Dimension.count);
    expect((renderJson(p)['points'] as List).first, allOf(containsPair('lat', 10.0), contains('value')));
    expect(
      _issues(facts, {
        'template': 'map_points',
        'points': [
          {'placeFactId': 'a', 'displayName': 'A', 'valueFactId': 'va'},
          {'placeFactId': 'b', 'displayName': 'B'},
        ],
      }),
      ['points: give every point a valueFactId, or none'],
    );
    expect(
      _issues(facts, {
        'template': 'map_points',
        'points': [
          {'placeFactId': 'va', 'displayName': 'A'},
        ],
      }),
      ['points[0].placeFactId: fact "va" is a quantity fact; expected a place fact'],
    );
  });

  test('formatShare and changeText', () {
    expect(formatShare(0.4567), '46%');
    expect(formatShare(0.045), '4.5%');
    expect(formatShare(0.0004), '<0.1%');
    expect(changeText(10, 7), '−30%');
    expect(changeText(10, 32), '3.2×');
    expect(changeText(0, 5), isNull);
  });
}
