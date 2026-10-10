import 'dart:math' as math;

import '../facts/facts.dart';
import '../images/image_catalog.dart';
import '../plan/plan.dart';
import '../templates/template_props.dart';
import '../units/units.dart';
import '../validation/validation.dart';

/// Maps a [Plan]'s fact references onto typed [TemplateProps].
///
/// This is the only place template data is created: numbers are read from
/// [FactsResult], never from the plan. Any reference that is unknown, of the
/// wrong kind, or dimensionally inconsistent is reported as a
/// [ValidationIssue] whose path matches the plan JSON.
class PlanResolver {
  const PlanResolver({this.referenceYear});

  /// "Now" for years-ago timelines. Defaults to the current year.
  final int? referenceYear;

  static const double maxScaleRange = 1e30;
  static const double maxGrowthFactor = 1000;
  static const int maxGrowthSteps = 200;

  ValidationResult<TemplateProps> resolve(Plan plan, FactsResult facts) =>
      validate((issues) => _Resolution(facts, issues, referenceYear ?? DateTime.now().year).run(plan));
}

class _Resolution {
  _Resolution(this.facts, this.issues, this.referenceYear);

  final FactsResult facts;
  final List<ValidationIssue> issues;
  final int referenceYear;

  void _issue(String path, String message) => issues.add(ValidationIssue(path, message));

  T? _fact<T extends Fact>(String id, String path, String kindName) {
    final f = facts.byId(id);
    if (f == null) {
      _issue(path, 'unknown fact id "$id"');
      return null;
    }
    if (f is! T) {
      _issue(path, 'fact "$id" is a ${f.kind} fact; expected a $kindName fact');
      return null;
    }
    return f;
  }

  ResolvedQuantity _quantity(QuantityFact f) => ResolvedQuantity(
        factId: f.id,
        label: f.label,
        value: f.value,
        unit: f.unit,
        approximate: f.approximate,
        sourceNote: f.sourceNote,
      );

  /// All quantities must share one compatibility group; returns it.
  Unit? _sameDimension(List<(QuantityFact, String)> refs, String path) {
    if (refs.isEmpty) return null;
    final first = refs.first.$1.unit;
    final mismatched = refs.where((r) => !r.$1.unit.isCompatibleWith(first));
    if (mismatched.isNotEmpty) {
      final found = {for (final r in refs) r.$1.unit.compatibilityKey}.join(', ');
      _issue(path, 'all facts must share one dimension (found $found)');
      return null;
    }
    return first;
  }

  TemplateProps? run(Plan plan) => switch (plan) {
        ScaleZoomPlan() => _scaleZoom(plan),
        TimelinePlan() => _timeline(plan),
        ExponentialGrowthPlan() => _growth(plan),
        ComparisonBarsPlan() => _bars(plan),
        ProcessStepsPlan() => _steps(plan),
        NonePlan() => NoneProps(title: plan.title, caption: plan.caption, reason: plan.reason),
      };

  ScaleZoomProps? _scaleZoom(ScaleZoomPlan plan) {
    final refs = <(QuantityFact, String)>[];
    final items = <ScaleItem>[];
    for (var i = 0; i < plan.items.length; i++) {
      final ref = plan.items[i];
      final path = 'items[$i].factId';
      final f = _fact<QuantityFact>(ref.factId, path, 'quantity');
      if (f == null) continue;
      if (f.value <= 0) {
        _issue(path, 'fact "${f.id}" must be greater than 0 to draw to scale');
        continue;
      }
      refs.add((f, path));
      items.add(ScaleItem(
        displayName: ref.displayName,
        shape: ref.shape,
        quantity: _quantity(f),
        image: ref.image == null ? null : imageCatalog[ref.image],
      ));
    }
    final unit = _sameDimension(refs, 'items');
    if (unit == null || items.length != plan.items.length) return null;
    if (!unit.dimension.isSpatial) {
      _issue('items', 'scale_zoom needs length, area or volume facts (got ${unit.dimension.name}); '
          'use comparison_bars instead');
      return null;
    }
    items.sort((a, b) => a.valueSi.compareTo(b.valueSi));
    final range = items.last.valueSi / items.first.valueSi;
    if (range > PlanResolver.maxScaleRange) {
      _issue('items', 'range between smallest and largest item is too large to draw (${range.toStringAsExponential(1)}×)');
      return null;
    }
    return ScaleZoomProps(
      title: plan.title,
      caption: plan.caption,
      mode: plan.mode,
      dimension: unit.dimension,
      items: List.unmodifiable(items),
    );
  }

  TimelineProps? _timeline(TimelinePlan plan) {
    final events = <TimelineEvent>[];
    for (var i = 0; i < plan.eventFactIds.length; i++) {
      final f = _fact<EventFact>(plan.eventFactIds[i], 'eventFactIds[$i]', 'event');
      if (f == null) continue;
      events.add(TimelineEvent(
        factId: f.id,
        label: f.label,
        displayDate: f.displayDate,
        fractionalYear: f.fractionalYear,
        yearsAgo: math.max(1, referenceYear - f.fractionalYear),
        sourceNote: f.sourceNote,
        description: f.description,
      ));
    }
    if (events.length != plan.eventFactIds.length) return null;
    events.sort((a, b) => a.fractionalYear.compareTo(b.fractionalYear));
    return TimelineProps(
      title: plan.title,
      caption: plan.caption,
      axis: plan.axis,
      referenceYear: referenceYear,
      events: List.unmodifiable(events),
    );
  }

  ExponentialGrowthProps? _growth(ExponentialGrowthPlan plan) {
    final initial = _fact<QuantityFact>(plan.initialFactId, 'initialFactId', 'quantity');
    final factor = _fact<QuantityFact>(plan.factorFactId, 'factorFactId', 'quantity');
    final steps = _fact<QuantityFact>(plan.stepsFactId, 'stepsFactId', 'quantity');
    final target = plan.targetFactId == null
        ? null
        : _fact<QuantityFact>(plan.targetFactId!, 'targetFactId', 'quantity');

    var ok = initial != null && factor != null && steps != null;
    if (plan.targetFactId != null && target == null) ok = false;

    if (initial != null) {
      if (initial.value <= 0) {
        _issue('initialFactId', 'fact "${initial.id}" must be greater than 0');
        ok = false;
      }
      if (initial.unit.dimension == Dimension.ratio) {
        _issue('initialFactId', 'fact "${initial.id}" must be a measurable quantity, not a ratio');
        ok = false;
      }
    }
    if (factor != null) {
      if (factor.unit.code != 'ratio') {
        _issue('factorFactId', 'fact "${factor.id}" must use unit "ratio" (got "${factor.unit.code}")');
        ok = false;
      } else if (factor.value <= 1 || factor.value > PlanResolver.maxGrowthFactor) {
        _issue('factorFactId', 'fact "${factor.id}" must be > 1 and ≤ ${PlanResolver.maxGrowthFactor} (got ${factor.value})');
        ok = false;
      }
    }
    if (steps != null) {
      if (steps.unit.code != 'count') {
        _issue('stepsFactId', 'fact "${steps.id}" must use unit "count" (got "${steps.unit.code}")');
        ok = false;
      } else if (steps.value != steps.value.roundToDouble() ||
          steps.value < 1 ||
          steps.value > PlanResolver.maxGrowthSteps) {
        _issue('stepsFactId', 'fact "${steps.id}" must be a whole number from 1 to ${PlanResolver.maxGrowthSteps} (got ${steps.value})');
        ok = false;
      }
    }
    if (target != null && initial != null) {
      if (!target.unit.isCompatibleWith(initial.unit)) {
        _issue('targetFactId', 'fact "${target.id}" (${target.unit.compatibilityKey}) must match '
            'the initial value\'s dimension (${initial.unit.compatibilityKey})');
        ok = false;
      } else if (target.value <= 0) {
        _issue('targetFactId', 'fact "${target.id}" must be greater than 0');
        ok = false;
      }
    }
    if (!ok) return null;

    final props = ExponentialGrowthProps(
      title: plan.title,
      caption: plan.caption,
      initial: _quantity(initial!),
      factor: factor!.value,
      factorSourceNote: factor.sourceNote,
      steps: steps!.value.toInt(),
      stepsSourceNote: steps.sourceNote,
      stepLabel: plan.stepLabel,
      defaultScale: plan.defaultScale,
      target: target == null ? null : _quantity(target),
    );
    if (!props.finalValueSi.isFinite) {
      _issue('stepsFactId', 'growth overflows: ${factor.value}^${props.steps} is too large to display');
      return null;
    }
    return props;
  }

  ComparisonBarsProps? _bars(ComparisonBarsPlan plan) {
    final refs = <(QuantityFact, String)>[];
    final bars = <BarItem>[];
    for (var i = 0; i < plan.bars.length; i++) {
      final ref = plan.bars[i];
      final path = 'bars[$i].factId';
      final f = _fact<QuantityFact>(ref.factId, path, 'quantity');
      if (f == null) continue;
      refs.add((f, path));
      bars.add(BarItem(
        displayName: ref.displayName,
        quantity: _quantity(f),
        image: ref.image == null ? null : imageCatalog[ref.image],
      ));
    }
    final unit = _sameDimension(refs, 'bars');
    if (unit == null || bars.length != plan.bars.length) return null;
    if (bars.every((b) => b.valueSi <= 0)) {
      _issue('bars', 'at least one bar must be greater than 0');
      return null;
    }
    return ComparisonBarsProps(
      title: plan.title,
      caption: plan.caption,
      orientation: plan.orientation,
      dimension: unit.dimension,
      bars: List.unmodifiable(bars),
    );
  }

  ProcessStepsProps? _steps(ProcessStepsPlan plan) {
    final steps = <ProcessStep>[];
    for (var i = 0; i < plan.stepFactIds.length; i++) {
      final f = _fact<StepFact>(plan.stepFactIds[i], 'stepFactIds[$i]', 'step');
      if (f == null) continue;
      steps.add(ProcessStep(
        factId: f.id,
        order: f.order,
        title: f.title,
        description: f.description,
        sourceNote: f.sourceNote,
      ));
    }
    if (steps.length != plan.stepFactIds.length) return null;
    steps.sort((a, b) => a.order.compareTo(b.order));
    return ProcessStepsProps(
      title: plan.title,
      caption: plan.caption,
      steps: List.unmodifiable(steps),
      autoplay: Duration(milliseconds: plan.autoplayMs),
      loop: plan.loop,
    );
  }
}
