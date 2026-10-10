import 'dart:math' as math;

import '../plan/plan.dart';
import '../templates/template_props.dart';
import '../units/format.dart';
import '../units/units.dart';

/// What an annotation points at in a rendered chart.
enum AnchorKind { item, event, step, gap }

/// A data-journalism style callout ("Jupiter is 29× as wide as Mercury").
///
/// Annotations are derived arithmetic on resolved facts: ratios, spans and
/// thresholds. They never introduce new figures.
class Annotation {
  const Annotation(this.text, this.anchor, this.index, {this.index2});

  final String text;
  final AnchorKind anchor;

  /// Item / event / step index; for [AnchorKind.gap], the earlier event.
  final int index;
  final int? index2;

  Map<String, Object?> toJson() => {'text': text, 'anchor': anchor.name, 'index': index, 'index2': ?index2};

  @override
  String toString() => text;
}

/// "2.6×", "29×", "1,200×".
String formatRatio(double r) {
  if (!r.isFinite) return '∞×';
  if (r < 10) return '${_trimZero(r.toStringAsFixed(1))}×';
  if (r < 100) return '${r.round()}×';
  // Two significant figures: 1,234 → 1,200.
  final scale = math.pow(10, (math.log(r) / math.ln10).floor() - 1).toDouble();
  return '${formatNumber((r / scale).round() * scale)}×';
}

String _trimZero(String s) => s.endsWith('.0') ? s.substring(0, s.length - 2) : s;

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

List<Annotation> annotationsFor(TemplateProps props) => switch (props) {
      ScaleZoomProps p => _scale(p),
      TimelineProps p => _timeline(p),
      ExponentialGrowthProps p => _growth(p),
      ComparisonBarsProps p => _bars(p),
      ProcessStepsProps() => const [],
      NoneProps() => const [],
    };

List<Annotation> _scale(ScaleZoomProps p) {
  if (p.items.length < 2) return const [];
  final small = p.items.first, large = p.items.last;
  final last = p.items.length - 1;
  if (small.valueSi <= 0) return const [];
  final ratio = large.valueSi / small.valueSi;
  if (p.mode == ScaleMode.distance) {
    return [Annotation('${large.displayName} is ${formatRatio(ratio)} as far away as ${small.displayName}', AnchorKind.item, last)];
  }
  final text = switch (p.dimension) {
    Dimension.area => '${large.displayName} covers ${formatRatio(ratio)} the area of ${small.displayName}',
    Dimension.volume => '${large.displayName} holds ${formatRatio(ratio)} the volume of ${small.displayName}',
    _ => switch (large.shape) {
        ItemShape.circle => '${large.displayName} is ${formatRatio(ratio)} as wide as ${small.displayName}',
        ItemShape.bar => '${large.displayName} is ${formatRatio(ratio)} as long as ${small.displayName}',
        ItemShape.tower => '${large.displayName} is ${formatRatio(ratio)} as tall as ${small.displayName}',
      },
  };
  return [Annotation(text, AnchorKind.item, last)];
}

List<Annotation> _timeline(TimelineProps p) {
  final e = p.events;
  if (e.length < 2) return const [];
  final out = <Annotation>[];
  if (p.axis == TimeAxis.logYearsAgo) {
    out.add(Annotation(
      '${e.first.label}: ${formatNumber(e.first.yearsAgo.roundToDouble())} years ago',
      AnchorKind.event,
      0,
    ));
  } else {
    final span = (e.last.fractionalYear - e.first.fractionalYear).round();
    if (span >= 1) {
      out.add(Annotation('${formatNumber(span.toDouble())} years from first to last', AnchorKind.event, e.length - 1));
    }
  }
  if (e.length >= 3) {
    final gaps = [for (var i = 0; i + 1 < e.length; i++) e[i + 1].fractionalYear - e[i].fractionalYear];
    final sorted = [...gaps]..sort();
    final median = sorted[sorted.length ~/ 2];
    final maxGap = gaps.reduce(math.max);
    final i = gaps.indexOf(maxGap);
    if (maxGap >= 1 && maxGap >= 2 * median) {
      out.add(Annotation(
        'A ${formatNumber(maxGap.roundToDouble())}-year gap',
        AnchorKind.gap,
        i,
        index2: i + 1,
      ));
    }
  }
  return out;
}

List<Annotation> _growth(ExponentialGrowthProps p) {
  final out = <Annotation>[];
  final target = p.target;
  final top = math.max(p.finalValueSi, target?.valueSi ?? 0);
  // The surprise of exponential growth: almost nothing happens, then everything.
  var k = 0;
  while (k <= p.steps && p.valueAtStepSi(k) < top * 0.02) {
    k++;
  }
  if (k >= 3 && k <= p.steps) {
    out.add(Annotation(
      '${_cap(p.stepLabel)} ${k - 1}: still only ${p.formatValueSi(p.valueAtStepSi(k - 1))}',
      AnchorKind.step,
      k - 1,
    ));
  }
  final reached = p.targetStep;
  if (target != null && reached != null) {
    out.add(Annotation('${_cap(p.stepLabel)} $reached: ${target.label} reached', AnchorKind.step, reached));
  } else if (target != null) {
    final pct = (p.finalValueSi / target.valueSi * 100);
    out.add(Annotation(
      '${target.label}: ${pct < 1 ? pct.toStringAsFixed(2) : formatNumber(pct)}% of the way',
      AnchorKind.step,
      p.steps,
    ));
  }
  return out;
}

List<Annotation> _bars(ComparisonBarsProps p) {
  if (p.bars.length < 2) return const [];
  var li = 0, si = 0;
  for (var i = 1; i < p.bars.length; i++) {
    if (p.bars[i].valueSi > p.bars[li].valueSi) li = i;
    if (p.bars[i].valueSi < p.bars[si].valueSi) si = i;
  }
  final large = p.bars[li], small = p.bars[si];
  if (small.valueSi <= 0 || li == si) return const [];
  final r = formatRatio(large.valueSi / small.valueSi);
  final a = large.displayName, b = small.displayName;
  final text = switch (p.dimension) {
    Dimension.mass => '$a weighs $r as much as $b',
    // Upright bars read as heights.
    Dimension.length => p.orientation == BarOrientation.vertical ? '$a is $r as tall as $b' : '$a is $r as long as $b',
    Dimension.speed => '$a is $r as fast as $b',
    Dimension.duration => '$a lasts $r as long as $b',
    Dimension.money => '$a costs $r as much as $b',
    Dimension.area => '$a covers $r the area of $b',
    Dimension.volume => '$a holds $r the volume of $b',
    Dimension.count => '$a: $r as many as $b',
    Dimension.ratio => '$a is $r $b',
  };
  return [Annotation(text, AnchorKind.item, li)];
}
