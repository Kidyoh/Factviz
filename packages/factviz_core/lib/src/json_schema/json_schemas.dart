import '../images/image_catalog.dart';
import '../plan/plan.dart';
import '../units/units.dart';

// JSON Schemas sent to the LLM provider for structured output.
//
// Discriminated unions are expressed as one flat object whose discriminator
// (`kind`, `template`) decides which optional fields apply. That shape is
// accepted by every provider's structured-output mode; the Dart validators
// in this package are what actually enforce the per-variant rules.

Map<String, Object?> _str(String description) => {'type': 'string', 'description': description};
Map<String, Object?> _enum(List<String> values, String description) =>
    {'type': 'string', 'enum': values, 'description': description};

/// Schema for [FactsResult].
final Map<String, Object?> factsJsonSchema = {
  'type': 'object',
  'properties': {
    'query': _str('The user question, verbatim.'),
    'topic': _str('Short topic name, max 80 chars.'),
    'confidence': _enum(['high', 'medium', 'low'], 'How sure you are of the key figures.'),
    'confidenceNote': _str('Required when confidence is low: why.'),
    'explanation': _str('2–4 plain sentences, max 600 chars. No numbers that are not in facts.'),
    'facts': {
      'type': 'array',
      'maxItems': 30,
      'items': {
        'type': 'object',
        'properties': {
          'kind': _enum(['quantity', 'event', 'step', 'place'],
              'quantity = measurable value, event = dated, step = stage of a process, place = location on Earth.'),
          'id': _str('Unique lowercase slug [a-z0-9_], max 40 chars.'),
          'label': _str('What this fact is, max 80 chars.'),
          'sourceNote': _str('Kind of source or standard, max 160 chars. No URLs.'),
          'value': {'type': 'number', 'description': 'quantity only. ≥ 0.'},
          'unit': _enum(units.keys.toList(), 'quantity only.'),
          'approximate': {'type': 'boolean', 'description': 'quantity only. True for typical/rounded values.'},
          'year': {
            'type': 'integer',
            'description': 'event: required. quantity: optional, the year the value applies to (needed for line_series and slope). Negative = BCE.',
          },
          'lat': {'type': 'number', 'description': 'place only. Latitude, -90..90.'},
          'lon': {'type': 'number', 'description': 'place only. Longitude, -180..180.'},
          'month': {'type': 'integer', 'description': 'event only, optional. 1–12.'},
          'day': {'type': 'integer', 'description': 'event only, optional. 1–31.'},
          'description': _str('event (optional, max 200) or step (required, max 240).'),
          'order': {'type': 'integer', 'description': 'step only. 1..n, contiguous.'},
          'title': _str('step only. Max 60 chars.'),
        },
        'required': ['kind', 'id', 'label', 'sourceNote'],
      },
    },
  },
  'required': ['query', 'topic', 'confidence', 'explanation', 'facts'],
};

/// Schema for [Plan].
final Map<String, Object?> planJsonSchema = {
  'type': 'object',
  'properties': {
    'template': _enum([for (final t in TemplateId.values) t.wire], 'The chosen template.'),
    'title': _str('Short title, max 80 chars, no numbers.'),
    'caption': _str('Optional one-line caption, max 160 chars.'),
    // scale_zoom
    'mode': _enum(['size', 'distance'], 'scale_zoom only.'),
    'items': {
      'type': 'array',
      'description': 'scale_zoom (2–8), donut (2–8), stacked_bar (2–8), waffle (1–4), treemap (3–30), '
          'bubble_pack (3–40), lollipop (3–25), number_line (2–15).',
      'items': {
        'type': 'object',
        'properties': {
          'factId': _str('Id of a quantity fact.'),
          'displayName': _str('Short name, max 40 chars.'),
          'shape': _enum(['circle', 'bar', 'tower'], 'scale_zoom only. circle for round objects, bar for lengths, tower for heights.'),
          'image': _enum(imageCatalog.keys.toList(), 'Optional bundled picture of this object.'),
        },
        'required': ['factId', 'displayName'],
      },
    },
    // timeline
    'eventFactIds': {
      'type': 'array',
      'description': 'timeline (2–30) or cosmic_clock (3–15): ids of event facts.',
      'items': {'type': 'string'},
    },
    'axis': _enum(['linear', 'log_years_ago'], 'timeline only.'),
    // exponential_growth
    'initialFactId': _str('exponential_growth only. Starting quantity.'),
    'factorFactId': _str('exponential_growth only. Ratio fact, > 1.'),
    'stepsFactId': _str('exponential_growth only. Count fact, whole number 1–200.'),
    'targetFactId': _str('exponential_growth only, optional. Same dimension as initial.'),
    'stepLabel': _str('exponential_growth only. Singular noun, e.g. "fold".'),
    'defaultScale': _enum(['linear', 'log'], 'exponential_growth only.'),
    // comparison_bars
    'bars': {
      'type': 'array',
      'description': 'comparison_bars only. 2–8 bars.',
      'items': {
        'type': 'object',
        'properties': {
          'factId': _str('Id of a quantity fact.'),
          'displayName': _str('Short name, max 40 chars.'),
          'image': _enum(imageCatalog.keys.toList(), 'Optional bundled picture of this object.'),
        },
        'required': ['factId', 'displayName'],
      },
    },
    'orientation': _enum(['horizontal', 'vertical'], 'comparison_bars only.'),
    // process_steps
    'stepFactIds': {
      'type': 'array',
      'description': 'process_steps only. 2–12 ids of step facts.',
      'items': {'type': 'string'},
    },
    'autoplayMs': {'type': 'integer', 'description': 'process_steps only. 1500–8000.'},
    'loop': {'type': 'boolean', 'description': 'process_steps only.'},
    // items templates
    'totalFactId': _str('donut / stacked_bar (optional): the whole the items are parts of. pictogram (required): the big thing.'),
    'scale': _enum(['linear', 'log'], 'number_line, lollipop, line_series only. Default linear.'),
    // pictogram
    'unitFactId': _str('pictogram only. The small thing counted.'),
    'unitName': _str('pictogram only. Plural name of the small thing, max 30 chars.'),
    'totalName': _str('pictogram only. Name of the big thing, max 30 chars.'),
    'image': _enum(imageCatalog.keys.toList(), 'pictogram only, optional. Picture of the small thing.'),
    // pairs templates
    'rows': {
      'type': 'array',
      'description': 'slope (1–10: a = before, b = after), range_bars (2–12: a = low, b = high), '
          'versus (2–8: a = left subject, b = right subject), rate_counter (1–4: a = amount, b = period).',
      'items': {
        'type': 'object',
        'properties': {
          'label': _str('Row label, max 40 chars.'),
          'aFactId': _str('Id of a quantity fact.'),
          'bFactId': _str('Id of a quantity fact.'),
        },
        'required': ['label', 'aFactId', 'bFactId'],
      },
    },
    'aName': _str('versus: left subject (required). slope: optional label for the "before" column.'),
    'bName': _str('versus: right subject (required). slope: optional label for the "after" column.'),
    'aImage': _enum(imageCatalog.keys.toList(), 'versus only, optional. Picture of the left subject.'),
    'bImage': _enum(imageCatalog.keys.toList(), 'versus only, optional. Picture of the right subject.'),
    // line_series
    'series': {
      'type': 'array',
      'description': 'line_series only. 1–4 lines.',
      'items': {
        'type': 'object',
        'properties': {
          'displayName': _str('Line name, max 30 chars.'),
          'factIds': {'type': 'array', 'description': '3–60 quantity facts that each have a year.', 'items': {'type': 'string'}},
        },
        'required': ['displayName', 'factIds'],
      },
    },
    // map_points
    'points': {
      'type': 'array',
      'description': 'map_points only. 1–30 points.',
      'items': {
        'type': 'object',
        'properties': {
          'placeFactId': _str('Id of a place fact.'),
          'displayName': _str('Short name, max 40 chars.'),
          'valueFactId': _str('Optional quantity fact sizing the dot. All points or none.'),
        },
        'required': ['placeFactId', 'displayName'],
      },
    },
    // none
    'reason': _str('none only. Why no template fits, max 200 chars.'),
  },
  'required': ['template', 'title'],
};
