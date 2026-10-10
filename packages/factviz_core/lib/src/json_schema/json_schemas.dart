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
          'kind': _enum(['quantity', 'event', 'step'], 'quantity = measurable value, event = dated, step = stage of a process.'),
          'id': _str('Unique lowercase slug [a-z0-9_], max 40 chars.'),
          'label': _str('What this fact is, max 80 chars.'),
          'sourceNote': _str('Kind of source or standard, max 160 chars. No URLs.'),
          'value': {'type': 'number', 'description': 'quantity only. ≥ 0.'},
          'unit': _enum(units.keys.toList(), 'quantity only.'),
          'approximate': {'type': 'boolean', 'description': 'quantity only. True for typical/rounded values.'},
          'year': {'type': 'integer', 'description': 'event only. Negative = BCE.'},
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
      'description': 'scale_zoom only. 2–8 items.',
      'items': {
        'type': 'object',
        'properties': {
          'factId': _str('Id of a quantity fact.'),
          'displayName': _str('Short name, max 40 chars.'),
          'shape': _enum(['circle', 'bar', 'tower'], 'circle for round objects, bar for lengths, tower for heights.'),
        },
        'required': ['factId', 'displayName'],
      },
    },
    // timeline
    'eventFactIds': {
      'type': 'array',
      'description': 'timeline only. 2–30 ids of event facts.',
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
    // none
    'reason': _str('none only. Why no template fits, max 200 chars.'),
  },
  'required': ['template', 'title'],
};
