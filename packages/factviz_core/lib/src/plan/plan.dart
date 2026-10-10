import '../validation/json_reader.dart';
import '../validation/validation.dart';

/// The fixed set of templates the planner may choose from.
enum TemplateId {
  scaleZoom('scale_zoom'),
  timeline('timeline'),
  exponentialGrowth('exponential_growth'),
  comparisonBars('comparison_bars'),
  processSteps('process_steps'),
  none('none');

  const TemplateId(this.wire);
  final String wire;

  static final byWire = {for (final t in values) t.wire: t};
}

enum ScaleMode {
  size,
  distance;

  static const byWire = {'size': size, 'distance': distance};
}

enum ItemShape {
  circle,
  bar;

  static const byWire = {'circle': circle, 'bar': bar};
}

enum TimeAxis {
  linear('linear'),
  logYearsAgo('log_years_ago');

  const TimeAxis(this.wire);
  final String wire;

  static final byWire = {for (final a in values) a.wire: a};
}

enum AxisScale {
  linear,
  log;

  static const byWire = {'linear': linear, 'log': log};
}

enum BarOrientation {
  horizontal,
  vertical;

  static const byWire = {'horizontal': horizontal, 'vertical': vertical};
}

final _idPattern = RegExp(r'^[a-z0-9_]{1,40}$');
const _idHint = 'a fact id from the facts JSON';

/// Output of the planner layer: a template choice plus fact references.
///
/// The planner never supplies factual numbers. It only references facts by
/// id; [PlanResolver] turns those references into typed template props.
sealed class Plan {
  const Plan({required this.title, this.caption});

  final String title;
  final String? caption;

  TemplateId get template;

  /// Fact ids this plan references, in order.
  List<String> get factIds;

  Map<String, Object?> propsToJson();

  Map<String, Object?> toJson() => {
        'template': template.wire,
        'title': title,
        if (caption != null) 'caption': caption,
        ...propsToJson(),
      };

  static ValidationResult<Plan> fromJson(Object? json) => validate((issues) {
        final r = JsonReader.of(json, issues);
        if (r == null) return null;
        final template = r.choice('template', TemplateId.byWire);
        final title = r.string('title', maxLength: 80);
        final caption = r.string('caption', optional: true, maxLength: 160);
        if (template == null) return null;
        final plan = switch (template) {
          TemplateId.scaleZoom => ScaleZoomPlan._read(r, title, caption),
          TemplateId.timeline => TimelinePlan._read(r, title, caption),
          TemplateId.exponentialGrowth => ExponentialGrowthPlan._read(r, title, caption),
          TemplateId.comparisonBars => ComparisonBarsPlan._read(r, title, caption),
          TemplateId.processSteps => ProcessStepsPlan._read(r, title, caption),
          TemplateId.none => NonePlan._read(r, title, caption),
        };
        if (plan != null) _checkDuplicateRefs(r, plan);
        return plan;
      });

  static void _checkDuplicateRefs(JsonReader r, Plan plan) {
    if (plan is ExponentialGrowthPlan) return; // roles are distinct by design
    final seen = <String>{};
    for (final id in plan.factIds) {
      if (!seen.add(id)) r.issue('fact "$id" is referenced more than once');
    }
  }
}

String? _factId(JsonReader r, String key, {bool optional = false}) =>
    r.string(key, optional: optional, pattern: _idPattern, patternHint: _idHint);

List<String>? _factIds(JsonReader r, String key, int min, int max) {
  final ids = r.strings(key, minItems: min, maxItems: max, maxLength: 40);
  if (ids == null) return null;
  for (var i = 0; i < ids.length; i++) {
    if (!_idPattern.hasMatch(ids[i])) r.issue('must be $_idHint', key: '$key[$i]');
  }
  return ids;
}

class ScaleItemRef {
  const ScaleItemRef({required this.factId, required this.displayName, this.shape = ItemShape.circle});

  final String factId;
  final String displayName;
  final ItemShape shape;

  static ScaleItemRef? _read(JsonReader r) {
    final factId = _factId(r, 'factId');
    final displayName = r.string('displayName', maxLength: 40);
    final shape = r.choice('shape', ItemShape.byWire, optional: true) ?? ItemShape.circle;
    if (factId == null || displayName == null) return null;
    return ScaleItemRef(factId: factId, displayName: displayName, shape: shape);
  }

  Map<String, Object?> toJson() =>
      {'factId': factId, 'displayName': displayName, 'shape': shape.name};
}

final class ScaleZoomPlan extends Plan {
  const ScaleZoomPlan({required super.title, super.caption, required this.mode, required this.items});

  final ScaleMode mode;
  final List<ScaleItemRef> items;

  static const minItems = 2, maxItems = 8;

  @override
  TemplateId get template => TemplateId.scaleZoom;

  @override
  List<String> get factIds => [for (final i in items) i.factId];

  static ScaleZoomPlan? _read(JsonReader r, String? title, String? caption) {
    final mode = r.choice('mode', ScaleMode.byWire);
    final items = r.objects('items', ScaleItemRef._read, minItems: minItems, maxItems: maxItems);
    if (title == null || mode == null || items == null) return null;
    return ScaleZoomPlan(title: title, caption: caption, mode: mode, items: items);
  }

  @override
  Map<String, Object?> propsToJson() =>
      {'mode': mode.name, 'items': [for (final i in items) i.toJson()]};
}

final class TimelinePlan extends Plan {
  const TimelinePlan({required super.title, super.caption, required this.eventFactIds, required this.axis});

  final List<String> eventFactIds;
  final TimeAxis axis;

  static const minEvents = 2, maxEvents = 30;

  @override
  TemplateId get template => TemplateId.timeline;

  @override
  List<String> get factIds => eventFactIds;

  static TimelinePlan? _read(JsonReader r, String? title, String? caption) {
    final ids = _factIds(r, 'eventFactIds', minEvents, maxEvents);
    final axis = r.choice('axis', TimeAxis.byWire);
    if (title == null || ids == null || axis == null) return null;
    return TimelinePlan(title: title, caption: caption, eventFactIds: ids, axis: axis);
  }

  @override
  Map<String, Object?> propsToJson() => {'eventFactIds': eventFactIds, 'axis': axis.wire};
}

final class ExponentialGrowthPlan extends Plan {
  const ExponentialGrowthPlan({
    required super.title,
    super.caption,
    required this.initialFactId,
    required this.factorFactId,
    required this.stepsFactId,
    this.targetFactId,
    required this.stepLabel,
    required this.defaultScale,
  });

  final String initialFactId;
  final String factorFactId;
  final String stepsFactId;
  final String? targetFactId;
  final String stepLabel;
  final AxisScale defaultScale;

  @override
  TemplateId get template => TemplateId.exponentialGrowth;

  @override
  List<String> get factIds =>
      [initialFactId, factorFactId, stepsFactId, ?targetFactId];

  static ExponentialGrowthPlan? _read(JsonReader r, String? title, String? caption) {
    final initial = _factId(r, 'initialFactId');
    final factor = _factId(r, 'factorFactId');
    final steps = _factId(r, 'stepsFactId');
    final target = _factId(r, 'targetFactId', optional: true);
    final stepLabel = r.string('stepLabel', maxLength: 20);
    final scale = r.choice('defaultScale', AxisScale.byWire);
    if (title == null || initial == null || factor == null || steps == null) return null;
    if (stepLabel == null || scale == null) return null;
    return ExponentialGrowthPlan(
      title: title,
      caption: caption,
      initialFactId: initial,
      factorFactId: factor,
      stepsFactId: steps,
      targetFactId: target,
      stepLabel: stepLabel,
      defaultScale: scale,
    );
  }

  @override
  Map<String, Object?> propsToJson() => {
        'initialFactId': initialFactId,
        'factorFactId': factorFactId,
        'stepsFactId': stepsFactId,
        if (targetFactId != null) 'targetFactId': targetFactId,
        'stepLabel': stepLabel,
        'defaultScale': defaultScale.name,
      };
}

class BarRef {
  const BarRef({required this.factId, required this.displayName});

  final String factId;
  final String displayName;

  static BarRef? _read(JsonReader r) {
    final factId = _factId(r, 'factId');
    final displayName = r.string('displayName', maxLength: 40);
    if (factId == null || displayName == null) return null;
    return BarRef(factId: factId, displayName: displayName);
  }

  Map<String, Object?> toJson() => {'factId': factId, 'displayName': displayName};
}

final class ComparisonBarsPlan extends Plan {
  const ComparisonBarsPlan({required super.title, super.caption, required this.bars, required this.orientation});

  final List<BarRef> bars;
  final BarOrientation orientation;

  static const minBars = 2, maxBars = 8;

  @override
  TemplateId get template => TemplateId.comparisonBars;

  @override
  List<String> get factIds => [for (final b in bars) b.factId];

  static ComparisonBarsPlan? _read(JsonReader r, String? title, String? caption) {
    final bars = r.objects('bars', BarRef._read, minItems: minBars, maxItems: maxBars);
    final orientation = r.choice('orientation', BarOrientation.byWire);
    if (title == null || bars == null || orientation == null) return null;
    return ComparisonBarsPlan(title: title, caption: caption, bars: bars, orientation: orientation);
  }

  @override
  Map<String, Object?> propsToJson() =>
      {'bars': [for (final b in bars) b.toJson()], 'orientation': orientation.name};
}

final class ProcessStepsPlan extends Plan {
  const ProcessStepsPlan({
    required super.title,
    super.caption,
    required this.stepFactIds,
    required this.autoplayMs,
    required this.loop,
  });

  final List<String> stepFactIds;
  final int autoplayMs;
  final bool loop;

  static const minSteps = 2, maxSteps = 12;
  static const minAutoplayMs = 1500, maxAutoplayMs = 8000;

  @override
  TemplateId get template => TemplateId.processSteps;

  @override
  List<String> get factIds => stepFactIds;

  static ProcessStepsPlan? _read(JsonReader r, String? title, String? caption) {
    final ids = _factIds(r, 'stepFactIds', minSteps, maxSteps);
    final autoplayMs = r.integer('autoplayMs', min: minAutoplayMs, max: maxAutoplayMs);
    final loop = r.boolean('loop', optional: true) ?? false;
    if (title == null || ids == null || autoplayMs == null) return null;
    return ProcessStepsPlan(title: title, caption: caption, stepFactIds: ids, autoplayMs: autoplayMs, loop: loop);
  }

  @override
  Map<String, Object?> propsToJson() =>
      {'stepFactIds': stepFactIds, 'autoplayMs': autoplayMs, 'loop': loop};
}

/// No template fits; the app shows a plain fact card.
final class NonePlan extends Plan {
  const NonePlan({required super.title, super.caption, required this.reason});

  final String reason;

  @override
  TemplateId get template => TemplateId.none;

  @override
  List<String> get factIds => const [];

  static NonePlan? _read(JsonReader r, String? title, String? caption) {
    final reason = r.string('reason', maxLength: 200);
    if (title == null || reason == null) return null;
    return NonePlan(title: title, caption: caption, reason: reason);
  }

  @override
  Map<String, Object?> propsToJson() => {'reason': reason};
}
