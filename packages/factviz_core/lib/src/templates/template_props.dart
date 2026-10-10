import 'dart:math' as math;

import '../images/image_catalog.dart';
import '../plan/plan.dart';
import '../units/format.dart';
import '../units/units.dart';

/// Typed, validated input for one render template. Produced only by
/// [PlanResolver]; every number here traces back to a fact.
sealed class TemplateProps {
  const TemplateProps({required this.title, this.caption});

  final String title;
  final String? caption;

  TemplateId get template;
}

/// A quantity resolved from a fact, carried with its provenance.
class ResolvedQuantity {
  const ResolvedQuantity({
    required this.factId,
    required this.label,
    required this.value,
    required this.unit,
    required this.approximate,
    required this.sourceNote,
  });

  final String factId;
  final String label;
  final double value;
  final Unit unit;
  final bool approximate;
  final String sourceNote;

  double get valueSi => unit.toBase(value);
  String get displayValue => formatQuantity(value, unit, approximate: approximate);
}

// ---------------------------------------------------------------------------
// scale_zoom

class ScaleItem {
  const ScaleItem({required this.displayName, required this.shape, required this.quantity, this.image});

  final String displayName;
  final ItemShape shape;
  final ResolvedQuantity quantity;
  final ImageAsset? image;

  double get valueSi => quantity.valueSi;
}

final class ScaleZoomProps extends TemplateProps {
  const ScaleZoomProps({
    required super.title,
    super.caption,
    required this.mode,
    required this.dimension,
    required this.items,
  });

  final ScaleMode mode;
  final Dimension dimension;

  /// Sorted smallest → largest, so the camera can zoom out item by item.
  final List<ScaleItem> items;

  @override
  TemplateId get template => TemplateId.scaleZoom;

  double get minSi => items.first.valueSi;
  double get maxSi => items.last.valueSi;

  /// Orders of magnitude between smallest and largest item.
  double get log10Range => math.log(maxSi / minSi) / math.ln10;
}

// ---------------------------------------------------------------------------
// timeline

class TimelineEvent {
  const TimelineEvent({
    required this.factId,
    required this.label,
    required this.displayDate,
    required this.fractionalYear,
    required this.yearsAgo,
    required this.sourceNote,
    this.description,
  });

  final String factId;
  final String label;
  final String displayDate;
  final double fractionalYear;

  /// Years before the reference year, clamped to at least 1 for log axes.
  final double yearsAgo;
  final String sourceNote;
  final String? description;
}

final class TimelineProps extends TemplateProps {
  const TimelineProps({
    required super.title,
    super.caption,
    required this.axis,
    required this.referenceYear,
    required this.events,
  });

  final TimeAxis axis;
  final int referenceYear;

  /// Sorted oldest → newest.
  final List<TimelineEvent> events;

  @override
  TemplateId get template => TemplateId.timeline;

  /// Normalised 0..1 position of [event] on the axis.
  double positionOf(TimelineEvent event) {
    if (events.length < 2) return 0;
    switch (axis) {
      case TimeAxis.linear:
        final start = events.first.fractionalYear;
        final span = events.last.fractionalYear - start;
        return span == 0 ? 0 : (event.fractionalYear - start) / span;
      case TimeAxis.logYearsAgo:
        final oldest = math.log(events.first.yearsAgo);
        final newest = math.log(events.last.yearsAgo);
        final span = oldest - newest;
        return span == 0 ? 0 : (oldest - math.log(event.yearsAgo)) / span;
    }
  }
}

// ---------------------------------------------------------------------------
// exponential_growth

final class ExponentialGrowthProps extends TemplateProps {
  const ExponentialGrowthProps({
    required super.title,
    super.caption,
    required this.initial,
    required this.factor,
    required this.factorSourceNote,
    required this.steps,
    required this.stepsSourceNote,
    required this.stepLabel,
    required this.defaultScale,
    this.target,
  });

  final ResolvedQuantity initial;
  final double factor;
  final String factorSourceNote;
  final int steps;
  final String stepsSourceNote;
  final String stepLabel;
  final AxisScale defaultScale;
  final ResolvedQuantity? target;

  @override
  TemplateId get template => TemplateId.exponentialGrowth;

  Dimension get dimension => initial.unit.dimension;

  /// Base-unit value after [step] multiplications.
  double valueAtStepSi(num step) => initial.valueSi * math.pow(factor, step);

  double get finalValueSi => valueAtStepSi(steps);

  /// First step at which the value reaches [target], or null if never within
  /// [steps].
  int? get targetStep {
    final t = target;
    if (t == null) return null;
    if (initial.valueSi >= t.valueSi) return 0;
    final n = (math.log(t.valueSi / initial.valueSi) / math.log(factor)).ceil();
    return n <= steps ? n : null;
  }

  String formatValueSi(double si) => dimension == Dimension.count || dimension == Dimension.money
      ? formatQuantity(si, initial.unit)
      : formatSi(si, dimension, fallback: initial.unit);
}

// ---------------------------------------------------------------------------
// comparison_bars

class BarItem {
  const BarItem({required this.displayName, required this.quantity, this.image});

  final String displayName;
  final ResolvedQuantity quantity;
  final ImageAsset? image;

  double get valueSi => quantity.valueSi;
}

final class ComparisonBarsProps extends TemplateProps {
  const ComparisonBarsProps({
    required super.title,
    super.caption,
    required this.orientation,
    required this.dimension,
    required this.bars,
  });

  final BarOrientation orientation;
  final Dimension dimension;

  /// In the planner's order.
  final List<BarItem> bars;

  @override
  TemplateId get template => TemplateId.comparisonBars;

  double get maxSi => bars.map((b) => b.valueSi).reduce(math.max);
  double get minSi => bars.map((b) => b.valueSi).reduce(math.min);
}

// ---------------------------------------------------------------------------
// process_steps

class ProcessStep {
  const ProcessStep({
    required this.factId,
    required this.order,
    required this.title,
    required this.description,
    required this.sourceNote,
  });

  final String factId;
  final int order;
  final String title;
  final String description;
  final String sourceNote;
}

final class ProcessStepsProps extends TemplateProps {
  const ProcessStepsProps({
    required super.title,
    super.caption,
    required this.steps,
    required this.autoplay,
    required this.loop,
  });

  /// Sorted by step order.
  final List<ProcessStep> steps;
  final Duration autoplay;
  final bool loop;

  @override
  TemplateId get template => TemplateId.processSteps;
}

// ---------------------------------------------------------------------------
// none

final class NoneProps extends TemplateProps {
  const NoneProps({required super.title, super.caption, required this.reason});

  final String reason;

  @override
  TemplateId get template => TemplateId.none;
}
