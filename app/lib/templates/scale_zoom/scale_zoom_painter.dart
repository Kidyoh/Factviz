import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../common/canvas_text.dart';
import 'log_camera.dart';

/// Draws scale_zoom items through a [LogCamera] at the current progress.
class ScaleZoomPainter extends CustomPainter {
  ScaleZoomPainter({
    required this.props,
    required this.progress,
    required this.palette,
    required this.textScaler,
    required this.baseStyle,
  }) : super(repaint: progress);

  final ScaleZoomProps props;

  /// Camera progress in [0, items.length - 1].
  final ValueNotifier<double> progress;
  final VizPalette palette;
  final TextScaler textScaler;

  /// Theme text style, so canvas labels use the app font.
  final TextStyle baseStyle;

  static const double _pad = 20;
  static const double _bottom = 44;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final placed = layoutScaleItems(props);
    final camera = LogCamera.forItems(placed, props.mode, Size(size.width - 2 * _pad, size.height - _bottom - 48));
    final p = progress.value;
    final worldWidth = camera.widthAt(p);
    final k = (size.width - 2 * _pad) / worldWidth;
    final baseline = size.height - _bottom;
    final focus = p.round().clamp(0, props.items.length - 1);

    _paintGround(canvas, size, baseline);
    if (props.mode == ScaleMode.distance) {
      _paintDistance(canvas, size, placed, k, baseline, p, focus);
    } else {
      _paintSizes(canvas, size, placed, k, baseline, p, focus);
    }
    _paintScaleBar(canvas, size, worldWidth);
  }

  double _opacity(int i, double p) => i == 0 ? 1 : (p - (i - 1)).clamp(0.0, 1.0);

  TextStyle _style(double fontSize, Color color, {FontWeight weight = FontWeight.w500}) =>
      baseStyle.copyWith(fontSize: textScaler.scale(fontSize), color: color, fontWeight: weight);

  void _paintGround(Canvas canvas, Size size, double baseline) {
    final paint = Paint()
      ..color = palette.axis.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, baseline), Offset(size.width, baseline), paint);
  }

  void _paintSizes(Canvas canvas, Size size, List<PlacedItem> placed, double k, double baseline, double p, int focus) {
    final labelRects = <Rect>[];
    // Paint the focused item's label first so it always wins overlaps.
    final order = [focus, for (var i = placed.length - 1; i >= 0; i--) if (i != focus) i];
    final shapes = <int, Rect>{};
    for (var i = 0; i < placed.length; i++) {
      final it = placed[i];
      final opacity = _opacity(i, p);
      if (opacity <= 0) continue;
      final left = _pad + it.left * k;
      final w = math.max(it.size * k, 2.0);
      final h = math.max(it.height * k, 2.0);
      final rect = Rect.fromLTWH(left, baseline - h, w, h);
      shapes[i] = rect;
      if (rect.left > size.width) continue;
      final color = palette.seriesAt(i).withValues(alpha: opacity);
      final paint = Paint()..color = color;
      if (props.items[i].shape == ItemShape.circle) {
        final r = math.max(it.size * k / 2, 1.5);
        canvas.drawCircle(Offset(left + r, baseline - r), r, paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(math.min(6, h / 3))), paint);
      }
    }
    for (final i in order) {
      final rect = shapes[i];
      if (rect == null || rect.left > size.width) continue;
      final opacity = _opacity(i, p);
      final others = [for (final e in shapes.entries) if (e.key != i) e.value];
      _paintLabel(canvas, size, i, Offset(rect.center.dx, rect.top - 6), opacity, [...labelRects, ...others],
          focused: i == focus, record: labelRects);
    }
  }

  void _paintDistance(Canvas canvas, Size size, List<PlacedItem> placed, double k, double baseline, double p, int focus) {
    final origin = Offset(_pad, baseline);
    final line = Paint()
      ..color = palette.axis
      ..strokeWidth = 2;
    final farthestVisible = placed.lastIndexWhere((it) => _opacity(placed.indexOf(it), p) > 0);
    final end = math.min(size.width, _pad + placed[math.max(0, farthestVisible)].left * k);
    canvas.drawLine(origin, Offset(end, baseline), line);
    canvas.drawCircle(origin, 6, Paint()..color = palette.label);
    final originLabel = layoutText('Start', _style(11, palette.mutedLabel));
    originLabel.paint(canvas, Offset(origin.dx - 4, baseline + 8));

    final labelRects = <Rect>[];
    final order = [focus, for (var i = placed.length - 1; i >= 0; i--) if (i != focus) i];
    for (final i in order) {
      final opacity = _opacity(i, p);
      if (opacity <= 0) continue;
      final x = _pad + placed[i].left * k;
      if (x > size.width + 8) continue;
      final paint = Paint()..color = palette.seriesAt(i).withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, baseline), i == focus ? 8 : 6, paint);
      canvas.drawLine(
        Offset(x, baseline - 8),
        Offset(x, baseline - 28),
        Paint()
          ..color = paint.color
          ..strokeWidth = 1.5,
      );
      _paintLabel(canvas, size, i, Offset(x, baseline - 32), opacity, labelRects, focused: i == focus);
    }
  }

  /// Paints name + value centred above [anchor], skipping it if it would
  /// overlap anything in [taken] (unless it is the focused item). The drawn
  /// rect is added to [record], or to [taken] when [record] is null.
  void _paintLabel(
    Canvas canvas,
    Size size,
    int i,
    Offset anchor,
    double opacity,
    List<Rect> taken, {
    required bool focused,
    List<Rect>? record,
  }) {
    final item = props.items[i];
    final name = layoutText(item.displayName, _style(focused ? 14 : 12, palette.label.withValues(alpha: opacity), weight: FontWeight.w700), maxWidth: 160);
    final value = layoutText(item.quantity.displayValue, _style(11, palette.mutedLabel.withValues(alpha: opacity)), maxWidth: 160);
    final w = math.max(name.width, value.width);
    final h = name.height + value.height;
    var top = anchor.dy - h;
    if (top < 6) top = 6;
    final left = (anchor.dx - w / 2).clamp(4.0, math.max(4.0, size.width - w - 4)).toDouble();
    final rect = Rect.fromLTWH(left, top, w, h).inflate(3);
    if (!focused && taken.any((r) => r.overlaps(rect))) return;
    (record ?? taken).add(rect);
    name.paint(canvas, Offset(left + (w - name.width) / 2, top));
    value.paint(canvas, Offset(left + (w - value.width) / 2, top + name.height));
  }

  /// A ruler in the bottom-right corner showing a round distance in the
  /// most readable unit for the current zoom.
  void _paintScaleBar(Canvas canvas, Size size, double worldWidth) {
    // Area/volume items are drawn by their linear size, so the bar is in length.
    final dim = props.dimension.isSpatial ? Dimension.length : props.dimension;
    final unit = bestDisplayUnit(worldWidth * 0.25, dim);
    final niceValue = niceNumber(unit.fromBase(worldWidth * 0.25));
    if (niceValue <= 0) return;
    final px = unit.toBase(niceValue) / worldWidth * (size.width - 2 * _pad);
    final label = layoutText(formatQuantity(niceValue, unit), _style(11, palette.mutedLabel));
    final y = size.height - 16;
    final right = size.width - _pad;
    final left = right - px;
    final paint = Paint()
      ..color = palette.mutedLabel
      ..strokeWidth = 2;
    canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    canvas.drawLine(Offset(left, y - 4), Offset(left, y + 4), paint);
    canvas.drawLine(Offset(right, y - 4), Offset(right, y + 4), paint);
    label.paint(canvas, Offset(left - 8 - label.width, y - label.height / 2));
  }

  @override
  bool shouldRepaint(ScaleZoomPainter old) =>
      old.props != props || old.palette != palette || old.progress != progress || old.textScaler != textScaler;
}
