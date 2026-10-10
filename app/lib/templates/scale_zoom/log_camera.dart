import 'dart:math' as math;
import 'dart:ui' show Size, lerpDouble;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/animation.dart' show Curves;

/// World-space placement of one item, in base units along one axis.
class PlacedItem {
  const PlacedItem({required this.left, required this.size, required this.height});

  /// Left edge (size mode) or position from the origin (distance mode).
  final double left;

  /// Horizontal extent on screen.
  final double size;

  /// Vertical extent, used to keep tall items on screen.
  final double height;

  double get right => left + size;
}

/// Converts a spatial quantity to a linear size so areas and volumes can be
/// drawn as shapes whose *area* or *volume* is to scale.
double linearSize(double valueSi, Dimension dimension) => switch (dimension) {
      Dimension.area => math.sqrt(valueSi),
      Dimension.volume => math.pow(valueSi, 1 / 3).toDouble(),
      _ => valueSi,
    };

/// Lays out items in world space.
///
/// Size mode: shapes stand side by side on a baseline, smallest first, so
/// each zoom-out step reveals the next item to the right.
/// Distance mode: markers sit at their distance from a shared origin.
List<PlacedItem> layoutScaleItems(ScaleZoomProps props) {
  final placed = <PlacedItem>[];
  if (props.mode == ScaleMode.distance) {
    for (final item in props.items) {
      final d = linearSize(item.valueSi, props.dimension);
      placed.add(PlacedItem(left: d, size: 0, height: 0));
    }
    return placed;
  }
  var cursor = 0.0;
  for (final item in props.items) {
    final s = linearSize(item.valueSi, props.dimension);
    final (w, h) = switch (item.shape) {
      ItemShape.circle => (s, s),
      ItemShape.bar => (s, s * 0.3),
      ItemShape.tower => (s * 0.3, s),
    };
    placed.add(PlacedItem(left: cursor, size: w, height: h));
    cursor += w + s * 0.3;
  }
  return placed;
}

/// A camera that zooms between per-item "stops" (visible world widths),
/// interpolating in log space so zooming across many orders of magnitude
/// feels uniform.
class LogCamera {
  LogCamera(List<double> stops)
      : assert(stops.isNotEmpty),
        stops = List.unmodifiable(stops);

  /// Visible world width when item `i` is in focus. Non-decreasing.
  final List<double> stops;

  /// Builds stops so that item `i` and everything before it fit on screen.
  factory LogCamera.forItems(List<PlacedItem> items, ScaleMode mode, Size viewport) {
    final aspect = viewport.width / math.max(1, viewport.height);
    final stops = <double>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      double w;
      if (mode == ScaleMode.distance) {
        w = it.left * (i == 0 ? 1.6 : 1.15);
      } else if (i == 0) {
        w = math.max(it.size / 0.4, it.height * aspect / 0.6);
      } else {
        w = math.max(it.right * 1.06, it.height * aspect / 0.7);
      }
      if (stops.isNotEmpty) w = math.max(w, stops.last);
      stops.add(w);
    }
    return LogCamera(stops);
  }

  int get length => stops.length;

  double get maxProgress => (stops.length - 1).toDouble();

  /// Visible world width at [progress] ∈ [0, length-1].
  double widthAt(double progress) {
    if (stops.length == 1) return stops.first;
    final p = progress.clamp(0.0, maxProgress);
    final i = p.floor().clamp(0, stops.length - 2);
    final t = Curves.easeInOutCubic.transform(p - i);
    final a = math.log(stops[i]);
    final b = math.log(stops[i + 1]);
    return math.exp(lerpDouble(a, b, t)!);
  }
}

/// A "nice" round number (1, 2 or 5 × 10ⁿ) close to [value].
double niceNumber(double value) {
  if (value <= 0 || !value.isFinite) return 0;
  final exp = (math.log(value) / math.ln10).floor();
  final base = math.pow(10.0, exp).toDouble();
  final f = value / base;
  final nice = f < 1.5 ? 1 : (f < 3.5 ? 2 : (f < 7.5 ? 5 : 10));
  return nice * base;
}
