import '../units/format.dart';
import '../units/units.dart';
import '../validation/json_reader.dart';
import '../validation/validation.dart';

enum Confidence {
  high,
  medium,
  low;

  static const byWire = {'high': high, 'medium': medium, 'low': low};
}

final _idPattern = RegExp(r'^[a-z0-9_]{1,40}$');

/// Oldest representable event: the Big Bang, with headroom.
const int maxAbsEventYear = 14000000000;

/// One fact returned by the facts layer. Discriminated by `kind`.
sealed class Fact {
  const Fact({required this.id, required this.label, required this.sourceNote});

  final String id;
  final String label;

  /// Short note naming the kind of source, e.g. "NASA mean Earth–Moon distance".
  final String sourceNote;

  String get kind;

  Map<String, Object?> toJson();

  static Fact? read(JsonReader r) {
    final kind = r.choice('kind', const {
      'quantity': 'quantity',
      'event': 'event',
      'step': 'step',
    });
    final id = r.string('id', pattern: _idPattern, patternHint: 'lowercase slug [a-z0-9_], max 40 chars');
    final label = r.string('label', maxLength: 80);
    final sourceNote = r.string('sourceNote', maxLength: 160);
    if (kind == null) return null;

    switch (kind) {
      case 'quantity':
        final value = r.number('value', min: 0);
        final unitCode = r.string('unit', maxLength: 10);
        final unit = unitCode == null ? null : units[unitCode];
        if (unitCode != null && unit == null) {
          r.issue('unknown unit "$unitCode"; allowed: ${units.keys.join(', ')}', key: 'unit');
        }
        final approximate = r.boolean('approximate', optional: true) ?? false;
        if (id == null || label == null || sourceNote == null || value == null || unit == null) {
          return null;
        }
        return QuantityFact(
          id: id,
          label: label,
          sourceNote: sourceNote,
          value: value,
          unit: unit,
          approximate: approximate,
        );
      case 'event':
        final year = r.integer('year', min: -maxAbsEventYear, max: 9999);
        final month = r.integer('month', optional: true, min: 1, max: 12);
        final day = r.integer('day', optional: true, min: 1, max: 31);
        if (day != null && !r.has('month')) r.issue('requires month', key: 'day');
        final description = r.string('description', optional: true, maxLength: 200);
        if (id == null || label == null || sourceNote == null || year == null) return null;
        return EventFact(
          id: id,
          label: label,
          sourceNote: sourceNote,
          year: year,
          month: month,
          day: day,
          description: description,
        );
      case 'step':
        final order = r.integer('order', min: 1, max: 20);
        final title = r.string('title', maxLength: 60);
        final description = r.string('description', maxLength: 240);
        if (id == null || label == null || sourceNote == null || order == null) return null;
        if (title == null || description == null) return null;
        return StepFact(
          id: id,
          label: label,
          sourceNote: sourceNote,
          order: order,
          title: title,
          description: description,
        );
    }
    return null;
  }

  Map<String, Object?> _base() =>
      {'kind': kind, 'id': id, 'label': label, 'sourceNote': sourceNote};
}

/// A measurable value with a unit.
final class QuantityFact extends Fact {
  const QuantityFact({
    required super.id,
    required super.label,
    required super.sourceNote,
    required this.value,
    required this.unit,
    this.approximate = false,
  });

  final double value;
  final Unit unit;
  final bool approximate;

  @override
  String get kind => 'quantity';

  double get valueSi => unit.toBase(value);

  String get displayValue => formatQuantity(value, unit, approximate: approximate);

  @override
  Map<String, Object?> toJson() => {
        ..._base(),
        'value': value,
        'unit': unit.code,
        'approximate': approximate,
      };
}

/// Something that happened at a point in time. Negative years are BCE.
final class EventFact extends Fact {
  const EventFact({
    required super.id,
    required super.label,
    required super.sourceNote,
    required this.year,
    this.month,
    this.day,
    this.description,
  });

  final int year;
  final int? month;
  final int? day;
  final String? description;

  @override
  String get kind => 'event';

  /// Year as a decimal, used to position the event on a time axis.
  double get fractionalYear {
    if (month == null) return year.toDouble();
    return year + (month! - 1) / 12 + ((day ?? 1) - 1) / 365;
  }

  String get displayDate {
    final y = year.abs();
    final String yearText;
    if (year < -9999) {
      yearText = '${formatNumber(y.toDouble())} years ago';
    } else if (year < 0) {
      yearText = '$y BCE';
    } else {
      yearText = '$year';
    }
    if (month == null || year < -9999) return yearText;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return day == null ? '${months[month! - 1]} $yearText' : '$day ${months[month! - 1]} $yearText';
  }

  @override
  Map<String, Object?> toJson() => {
        ..._base(),
        'year': year,
        if (month != null) 'month': month,
        if (day != null) 'day': day,
        if (description != null) 'description': description,
      };
}

/// One stage of a process.
final class StepFact extends Fact {
  const StepFact({
    required super.id,
    required super.label,
    required super.sourceNote,
    required this.order,
    required this.title,
    required this.description,
  });

  final int order;
  final String title;
  final String description;

  @override
  String get kind => 'step';

  @override
  Map<String, Object?> toJson() => {
        ..._base(),
        'order': order,
        'title': title,
        'description': description,
      };
}

/// Output of the facts layer.
class FactsResult {
  const FactsResult({
    required this.query,
    required this.topic,
    required this.confidence,
    this.confidenceNote,
    required this.explanation,
    required this.facts,
  });

  final String query;
  final String topic;
  final Confidence confidence;
  final String? confidenceNote;
  final String explanation;
  final List<Fact> facts;

  static const int maxFacts = 30;

  Fact? byId(String id) {
    for (final f in facts) {
      if (f.id == id) return f;
    }
    return null;
  }

  static ValidationResult<FactsResult> fromJson(Object? json) => validate((issues) {
        final r = JsonReader.of(json, issues);
        if (r == null) return null;
        final query = r.string('query', maxLength: 300);
        final topic = r.string('topic', maxLength: 80);
        final confidence = r.choice('confidence', Confidence.byWire);
        final confidenceNote = r.string('confidenceNote', optional: true, maxLength: 300);
        final explanation = r.string('explanation', maxLength: 600);
        final facts = r.objects('facts', Fact.read, maxItems: maxFacts);

        if (confidence == Confidence.low && confidenceNote == null) {
          r.issue('is required when confidence is "low"', key: 'confidenceNote');
        }
        if (facts != null) {
          if (facts.isEmpty && confidence != null && confidence != Confidence.low) {
            r.issue('may only be empty when confidence is "low"', key: 'facts');
          }
          _checkIds(r, facts);
          _checkStepOrder(r, facts);
        }
        if (query == null || topic == null || confidence == null) return null;
        if (explanation == null || facts == null) return null;
        return FactsResult(
          query: query,
          topic: topic,
          confidence: confidence,
          confidenceNote: confidenceNote,
          explanation: explanation,
          facts: List.unmodifiable(facts),
        );
      });

  static void _checkIds(JsonReader r, List<Fact> facts) {
    final seen = <String>{};
    for (final f in facts) {
      if (!seen.add(f.id)) r.issue('duplicate fact id "${f.id}"', key: 'facts');
    }
  }

  static void _checkStepOrder(JsonReader r, List<Fact> facts) {
    final orders = facts.whereType<StepFact>().map((s) => s.order).toList()..sort();
    for (var i = 0; i < orders.length; i++) {
      if (orders[i] != i + 1) {
        r.issue('step orders must be unique and run 1..${orders.length} (got ${orders.join(', ')})', key: 'facts');
        return;
      }
    }
  }

  Map<String, Object?> toJson() => {
        'query': query,
        'topic': topic,
        'confidence': confidence.name,
        if (confidenceNote != null) 'confidenceNote': confidenceNote,
        'explanation': explanation,
        'facts': [for (final f in facts) f.toJson()],
      };
}
