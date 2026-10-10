import 'package:factviz_core/factviz_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

Map<String, dynamic> _validFacts() => clone(fixture('exponential_paper_fold').facts);

List<String> _issues(Object? json) => FactsResult.fromJson(json).issues.map((i) => '$i').toList();

void main() {
  group('FactsResult.fromJson', () {
    test('accepts every fixture', () {
      for (final f in loadQueryFixtures()) {
        final result = FactsResult.fromJson(f.facts);
        expect(result.issues, isEmpty, reason: f.name);
      }
    });

    test('parses each fact kind', () {
      final facts = FactsResult.fromJson(fixture('exponential_paper_fold').facts).valueOrThrow;
      final thickness = facts.byId('paper_thickness')! as QuantityFact;
      expect(thickness.unit.code, 'mm');
      expect(thickness.valueSi, closeTo(1e-4, 1e-12));
      expect(thickness.approximate, isTrue);

      final events = FactsResult.fromJson(fixture('timeline_spaceflight').facts).valueOrThrow;
      final apollo = events.byId('apollo_11')! as EventFact;
      expect(apollo.displayDate, '20 Jul 1969');
      expect(apollo.fractionalYear, closeTo(1969.5, 0.1));

      final steps = FactsResult.fromJson(fixture('process_water_cycle').facts).valueOrThrow;
      expect((steps.byId('condensation')! as StepFact).order, 2);
    });

    test('round-trips through toJson', () {
      for (final f in loadQueryFixtures()) {
        final once = FactsResult.fromJson(f.facts).valueOrThrow;
        final twice = FactsResult.fromJson(once.toJson()).valueOrThrow;
        expect(twice.toJson(), once.toJson(), reason: f.name);
      }
    });

    test('rejects a non-object', () {
      expect(_issues([1, 2]), ['expected an object']);
      expect(_issues(null), ['expected an object']);
    });

    test('requires confidenceNote when confidence is low', () {
      final json = _validFacts()..['confidence'] = 'low';
      expect(_issues(json), ['confidenceNote: is required when confidence is "low"']);
      json['confidenceNote'] = 'Figures disagree between sources.';
      expect(_issues(json), isEmpty);
    });

    test('allows empty facts only with low confidence', () {
      final json = _validFacts()..['facts'] = <Object>[];
      expect(_issues(json), ['facts: may only be empty when confidence is "low"']);
      json
        ..['confidence'] = 'low'
        ..['confidenceNote'] = 'This is a matter of opinion.';
      expect(_issues(json), isEmpty);
    });

    test('rejects unknown units with the allowed list', () {
      final json = _validFacts();
      (json['facts'] as List)[0]['unit'] = 'furlong';
      final issues = _issues(json);
      expect(issues.single, startsWith('facts[0].unit: unknown unit "furlong"; allowed: nm, um, mm'));
    });

    test('rejects missing and mistyped fields with paths', () {
      final json = _validFacts();
      final fact = (json['facts'] as List)[1] as Map<String, dynamic>;
      fact.remove('sourceNote');
      fact['value'] = 'two';
      expect(_issues(json), unorderedEquals([
        'facts[1].sourceNote: is required',
        'facts[1].value: expected a finite number',
      ]));
    });

    test('rejects negative quantities and bad ids', () {
      final json = _validFacts();
      (json['facts'] as List)[0]
        ..['value'] = -1
        ..['id'] = 'Paper Thickness';
      expect(_issues(json), unorderedEquals([
        'facts[0].id: must match lowercase slug [a-z0-9_], max 40 chars',
        'facts[0].value: must be ≥ 0.0 (got -1.0)',
      ]));
    });

    test('rejects duplicate fact ids', () {
      final json = _validFacts();
      (json['facts'] as List)[1]['id'] = 'paper_thickness';
      expect(_issues(json), ['facts: duplicate fact id "paper_thickness"']);
    });

    test('rejects unknown fact kinds', () {
      final json = _validFacts();
      (json['facts'] as List)[0]['kind'] = 'opinion';
      expect(_issues(json).single, 'facts[0].kind: must be one of: quantity, event, step');
    });

    test('validates event dates', () {
      final json = clone(fixture('timeline_spaceflight').facts);
      final facts = json['facts'] as List;
      facts[0]['month'] = 13;
      facts[1].remove('month');
      facts[2]['year'] = 1963.5;
      expect(_issues(json), unorderedEquals([
        'facts[0].month: must be ≤ 12 (got 13)',
        'facts[1].day: requires month',
        'facts[2].year: expected an integer',
      ]));
    });

    test('accepts deep-time events', () {
      final json = clone(fixture('timeline_spaceflight').facts);
      (json['facts'] as List)[0]
        ..['year'] = -4.5e9
        ..remove('month')
        ..remove('day');
      final facts = FactsResult.fromJson(json).valueOrThrow;
      expect((facts.facts.first as EventFact).displayDate, '4.5 billion years ago');
    });

    test('requires contiguous step orders', () {
      final json = clone(fixture('process_water_cycle').facts);
      (json['facts'] as List)[3]['order'] = 7;
      expect(_issues(json), ['facts: step orders must be unique and run 1..4 (got 1, 2, 3, 7)']);
    });

    test('enforces length limits', () {
      final json = _validFacts()..['explanation'] = 'x' * 601;
      expect(_issues(json), ['explanation: must be at most 600 characters (got 601)']);
    });
  });
}
