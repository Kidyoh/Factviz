import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';

/// Horizontal placement of timeline events and their cards.
class TimelineLayout {
  const TimelineLayout({
    required this.width,
    required this.xs,
    required this.cardLefts,
    required this.lanes,
    required this.levels,
  });

  /// Total scrollable width.
  final double width;

  /// Axis x of each event (chronological order).
  final List<double> xs;

  /// Left edge of each event's card.
  final List<double> cardLefts;

  /// Lane per event: even lanes sit above the axis, odd lanes below;
  /// `lane ~/ 2` is the distance from the axis.
  final List<int> lanes;

  /// Number of levels used on the busiest side.
  final int levels;

  static const double pad = 28;

  /// Widens the axis until every card fits in [maxLevels] levels per side
  /// without overlapping, so dense clusters stay readable.
  static TimelineLayout compute(
    TimelineProps props, {
    required double viewportWidth,
    double cardWidth = 136,
    double gap = 8,
    int maxLevels = 2,
  }) {
    final n = props.events.length;
    var width = math.max(viewportWidth, n * cardWidth * 0.62 + 2 * pad);
    late List<double> xs, lefts;
    late List<int> lanes;
    for (var attempt = 0; attempt < 10; attempt++) {
      xs = [for (final e in props.events) pad + props.positionOf(e) * (width - 2 * pad)];
      lefts = [for (final x in xs) (x - cardWidth / 2).clamp(0.0, width - cardWidth)];
      final laneCount = maxLevels * 2;
      final laneRight = List<double>.filled(laneCount, -double.infinity);
      lanes = List<int>.filled(n, 0);
      var overflow = false;
      for (var i = 0; i < n; i++) {
        var placed = false;
        for (var l = 0; l < laneCount; l++) {
          if (laneRight[l] + gap <= lefts[i]) {
            lanes[i] = l;
            laneRight[l] = lefts[i] + cardWidth;
            placed = true;
            break;
          }
        }
        if (!placed) {
          overflow = true;
          // Fall back to the least-crowded lane; used only if we stop widening.
          var best = 0;
          for (var l = 1; l < laneCount; l++) {
            if (laneRight[l] < laneRight[best]) best = l;
          }
          lanes[i] = best;
          laneRight[best] = lefts[i] + cardWidth;
        }
      }
      if (!overflow) break;
      width *= 1.35;
    }
    final levels = lanes.isEmpty ? 1 : lanes.map((l) => l ~/ 2 + 1).reduce(math.max);
    return TimelineLayout(width: width, xs: xs, cardLefts: lefts, lanes: lanes, levels: levels);
  }
}

class AxisTick {
  const AxisTick(this.x, this.label);
  final double x;
  final String label;
}

/// Axis ticks at "nice" intervals, at least [minSpacing] pixels apart.
List<AxisTick> timelineTicks(TimelineProps props, double width, {double minSpacing = 84}) {
  final events = props.events;
  if (events.length < 2) return const [];
  const pad = TimelineLayout.pad;
  final usable = width - 2 * pad;
  final ticks = <AxisTick>[];

  switch (props.axis) {
    case TimeAxis.linear:
      final start = events.first.fractionalYear;
      final end = events.last.fractionalYear;
      final span = end - start;
      if (span <= 0) return const [];
      final pxPerYear = usable / span;
      final step = _niceStep(minSpacing / pxPerYear);
      for (var y = (start / step).ceil() * step; y <= end; y += step) {
        ticks.add(AxisTick(pad + (y - start) * pxPerYear, _yearLabel(y)));
      }
    case TimeAxis.logYearsAgo:
      final oldest = math.log(events.first.yearsAgo);
      final newest = math.log(events.last.yearsAgo);
      final span = oldest - newest;
      if (span <= 0) return const [];
      var lastX = -double.infinity;
      final kMin = (newest / math.ln10).ceil();
      final kMax = (oldest / math.ln10).floor();
      for (var k = kMax; k >= kMin; k--) {
        final x = pad + (oldest - k * math.ln10) / span * usable;
        // Log labels ("10 million yrs ago") are wider than years.
        if (x - lastX < minSpacing * 1.45) continue;
        lastX = x;
        ticks.add(AxisTick(x, '${formatNumber(math.pow(10.0, k).toDouble())} yrs ago'));
      }
  }
  return ticks;
}

double _niceStep(double raw) {
  if (raw <= 1) return 1;
  final exp = (math.log(raw) / math.ln10).floor();
  final base = math.pow(10.0, exp).toDouble();
  for (final m in const [1, 2, 2.5, 5, 10]) {
    if (m * base >= raw) return m * base;
  }
  return 10 * base;
}

String _yearLabel(double y) {
  final year = y.round();
  if (year < -9999) return '${formatNumber(-year.toDouble())} BCE';
  if (year < 0) return '${-year} BCE';
  return '$year';
}
