import '../images/image_catalog.dart';
import '../validation/json_reader.dart';
import '../validation/validation.dart';

part 'plan_extra.dart';

/// The fixed set of templates the planner may choose from.
enum TemplateId {
  scaleZoom('scale_zoom'),
  timeline('timeline'),
  exponentialGrowth('exponential_growth'),
  comparisonBars('comparison_bars'),
  processSteps('process_steps'),
  pictogram('pictogram'),
  donut('donut'),
  stackedBar('stacked_bar'),
  waffle('waffle'),
  treemap('treemap'),
  bubblePack('bubble_pack'),
  lollipop('lollipop'),
  numberLine('number_line'),
  slope('slope'),
  rangeBars('range_bars'),
  versus('versus'),
  rateCounter('rate_counter'),
  lineSeries('line_series'),
  cosmicClock('cosmic_clock'),
  mapPoints('map_points'),
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

/// How a scale_zoom item is drawn: a circle (planets, balls), a horizontal
/// bar (lengths: whales, buses) or a vertical tower (heights: people,
/// mountains, buildings).
enum ItemShape {
  circle,
  bar,
  tower;

  static const byWire = {'circle': circle, 'bar': bar, 'tower': tower};
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
          TemplateId.pictogram => PictogramPlan._read(r, title, caption),
          TemplateId.donut ||
          TemplateId.stackedBar ||
          TemplateId.waffle ||
          TemplateId.treemap ||
          TemplateId.bubblePack ||
          TemplateId.lollipop ||
          TemplateId.numberLine =>
            ItemsPlan._read(template, r, title, caption),
          TemplateId.slope ||
          TemplateId.rangeBars ||
          TemplateId.versus ||
          TemplateId.rateCounter =>
            PairsPlan._read(template, r, title, caption),
          TemplateId.lineSeries => SeriesPlan._read(r, title, caption),
          TemplateId.cosmicClock => ClockPlan._read(r, title, caption),
          TemplateId.mapPoints => MapPlan._read(r, title, caption),
        };
        if (plan != null) _checkDuplicateRefs(r, plan);
        return plan;
      });

  static void _checkDuplicateRefs(JsonReader r, Plan plan) {
    if (plan is ExponentialGrowthPlan) return; // roles are distinct by design
    // Rate rows may share one period ("per 1 yr"); only the amounts must differ.
    final ids = plan is PairsPlan && plan.template == TemplateId.rateCounter
        ? [for (final r in plan.rows) r.aFactId]
        : plan.factIds;
    final seen = <String>{};
    for (final id in ids) {
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

/// Optional picture key; must be in the bundled image catalog.
String? _image(JsonReader r) {
  final key = r.string('image', optional: true, maxLength: 30);
  if (key != null && !imageCatalog.containsKey(key)) {
    r.issue('unknown image "$key"; allowed: ${imageCatalog.keys.join(', ')}', key: 'image');
    return null;
  }
  return key;
}

class ScaleItemRef {
  const ScaleItemRef({required this.factId, required this.displayName, this.shape = ItemShape.circle, this.image});

  final String factId;
  final String displayName;
  final ItemShape shape;

  /// Optional picture from [imageCatalog].
  final String? image;

  static ScaleItemRef? _read(JsonReader r) {
    final factId = _factId(r, 'factId');
    final displayName = r.string('displayName', maxLength: 40);
    final shape = r.choice('shape', ItemShape.byWire, optional: true) ?? ItemShape.circle;
    final image = _image(r);
    if (image != null && !imageCatalog[image]!.shapes.contains(shape)) {
      r.issue('image "$image" can only be drawn as: ${imageCatalog[image]!.shapes.map((s) => s.name).join(', ')}',
          key: 'shape');
    }
    if (factId == null || displayName == null) return null;
    return ScaleItemRef(factId: factId, displayName: displayName, shape: shape, image: image);
  }

  Map<String, Object?> toJson() =>
      {'factId': factId, 'displayName': displayName, 'shape': shape.name, 'image': ?image};
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
  const BarRef({required this.factId, required this.displayName, this.image});

  final String factId;
  final String displayName;

  /// Optional picture from [imageCatalog], shown beside the label.
  final String? image;

  static BarRef? _read(JsonReader r) {
    final factId = _factId(r, 'factId');
    final displayName = r.string('displayName', maxLength: 40);
    final image = _image(r);
    if (factId == null || displayName == null) return null;
    return BarRef(factId: factId, displayName: displayName, image: image);
  }

  Map<String, Object?> toJson() => {'factId': factId, 'displayName': displayName, 'image': ?image};
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
