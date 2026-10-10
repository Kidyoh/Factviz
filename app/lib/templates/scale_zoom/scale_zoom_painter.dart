import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../common/canvas_text.dart';
import '../common/viz_paint.dart';
import 'log_camera.dart';

/// Draws scale_zoom items through a [LogCamera] at the current progress:
/// lit spheres and glowing bars on a horizon, with star dust that streams
/// past as the camera zooms out.
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
  static const double _bottom = 48;

  static final List<(double, double, double, double)> _dust = () {
    final r = math.Random(11);
    return List.generate(70, (_) => (r.nextDouble(), r.nextDouble(), 0.3 + r.nextDouble() * 0.7, r.nextDouble()));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final placed = layoutScaleItems(props);
    final camera = LogCamera.forItems(placed, props.mode, Size(size.width - 2 * _pad, size.height - _bottom - 56));
    final p = progress.value;
    final worldWidth = camera.widthAt(p);
    final k = (size.width - 2 * _pad) / worldWidth;
    final baseline = size.height - _bottom;
    final focus = p.round().clamp(0, props.items.length - 1);

    _paintDust(canvas, size, worldWidth, baseline);
    _paintHorizon(canvas, size, baseline);
    if (props.mode == ScaleMode.distance) {
      _paintDistance(canvas, size, placed, k, baseline, p, focus);
    } else {
      _paintSizes(canvas, size, placed, k, baseline, p, focus);
    }
    _paintScaleBar(canvas, size, worldWidth);
  }

  double _opacity(int i, double p) => i == 0 ? 1 : (p - (i - 1)).clamp(0.0, 1.0);

  /// Star dust drifts left in proportion to log(zoom), so zooming out feels
  /// like flying backwards through space.
  void _paintDust(Canvas canvas, Size size, double worldWidth, double baseline) {
    final shift = math.log(worldWidth) / math.ln10 * 0.11;
    final paint = Paint();
    for (final (u, v, depth, tw) in _dust) {
      final x = ((u - shift * depth) % 1.0) * size.width;
      final y = v * (baseline - 8);
      paint.color = Colors.white.withValues(alpha: 0.12 + 0.35 * depth * tw);
      canvas.drawCircle(Offset(x, y), 0.5 + depth, paint);
    }
  }

  void _paintHorizon(Canvas canvas, Size size, double baseline) {
    final floor = Rect.fromLTWH(0, baseline, size.width, size.height - baseline);
    canvas.drawRect(
      floor,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Cosmos.cyan.withValues(alpha: 0.10), Colors.transparent],
        ).createShader(floor),
    );
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..shader = LinearGradient(colors: [
          Colors.transparent,
          Cosmos.cyan.withValues(alpha: 0.6),
          Cosmos.violet.withValues(alpha: 0.6),
          Colors.transparent,
        ]).createShader(Rect.fromLTWH(0, baseline - 1, size.width, 2))
        ..strokeWidth = 1.2,
    );
  }

  void _paintSizes(Canvas canvas, Size size, List<PlacedItem> placed, double k, double baseline, double p, int focus) {
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
      final color = palette.seriesAt(i);
      if (props.items[i].shape == ItemShape.circle) {
        final r = math.max(it.size * k / 2, 1.5);
        paintSphere(canvas, Offset(left + r, baseline - r), r, color, opacity: opacity);
        // Faint reflection on the floor.
        if (r > 4) {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(left + r, baseline + 3), width: r * 1.6, height: math.min(10, r * 0.25)),
            Paint()
              ..color = color.withValues(alpha: 0.25 * opacity)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
        }
      } else {
        paintGlowBar(
          canvas,
          RRect.fromRectAndRadius(rect, Radius.circular(math.min(8, math.min(w, h) / 3))),
          color,
          opacity: opacity,
          vertical: props.items[i].shape == ItemShape.tower,
        );
      }
    }
    final taken = <Rect>[];
    final order = [focus, for (var i = placed.length - 1; i >= 0; i--) if (i != focus) i];
    for (final i in order) {
      final rect = shapes[i];
      if (rect == null || rect.left > size.width) continue;
      final others = [for (final e in shapes.entries) if (e.key != i) e.value];
      _paintLabel(canvas, size, i, Offset(rect.center.dx, rect.top - 8), _opacity(i, p), [...taken, ...others],
          focused: i == focus, record: taken);
    }
  }

  void _paintDistance(Canvas canvas, Size size, List<PlacedItem> placed, double k, double baseline, double p, int focus) {
    final origin = Offset(_pad, baseline);
    final farthestVisible = placed.lastIndexWhere((it) => _opacity(placed.indexOf(it), p) > 0);
    final end = math.min(size.width, _pad + placed[math.max(0, farthestVisible)].left * k);
    paintGlowLine(canvas, origin, Offset(end, baseline), Cosmos.cyan, width: 1.6, opacity: 0.9);
    paintComet(canvas, origin, Colors.white, radius: 5);
    final originLabel = layoutText('Start', _style(11, palette.mutedLabel));
    originLabel.paint(canvas, Offset(origin.dx - 6, baseline + 10));

    final taken = <Rect>[];
    final order = [focus, for (var i = placed.length - 1; i >= 0; i--) if (i != focus) i];
    for (final i in order) {
      final opacity = _opacity(i, p);
      if (opacity <= 0) continue;
      final x = _pad + placed[i].left * k;
      if (x > size.width + 8) continue;
      final color = palette.seriesAt(i);
      paintGlowLine(canvas, Offset(x, baseline - 10), Offset(x, baseline - 34), color, width: 1.2, opacity: opacity * 0.8);
      paintSphere(canvas, Offset(x, baseline), i == focus ? 9 : 7, color, opacity: opacity);
      _paintLabel(canvas, size, i, Offset(x, baseline - 38), opacity, taken, focused: i == focus);
    }
  }

  TextStyle _style(double fontSize, Color color, {FontWeight weight = FontWeight.w500}) =>
      baseStyle.copyWith(fontSize: textScaler.scale(fontSize), color: color, fontWeight: weight);

  /// Paints a name/value pill centred above [anchor], skipping it if it
  /// would overlap anything in [taken] (unless it is the focused item).
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
    final pill = PillLabel(
      item.displayName,
      item.quantity.displayValue,
      baseStyle,
      accent: palette.seriesAt(i),
      scale: textScaler.scale(focused ? 1.08 : 0.95),
    );
    final s = pill.size;
    final top = math.max(8.0, anchor.dy - s.height);
    final left = (anchor.dx - s.width / 2).clamp(6.0, math.max(6.0, size.width - s.width - 6)).toDouble();
    final rect = Rect.fromLTWH(left, top, s.width, s.height);
    if (!focused && taken.any((r) => r.overlaps(rect.inflate(2)))) return;
    (record ?? taken).add(rect);
    pill.paint(canvas, rect.topLeft, opacity: opacity);
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
    final label = layoutText(formatQuantity(niceValue, unit), _style(11, palette.label, weight: FontWeight.w600));
    final y = size.height - 18;
    final right = size.width - _pad;
    final left = right - px;
    final paint = Paint()
      ..color = palette.mutedLabel
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    canvas.drawLine(Offset(left, y - 4), Offset(left, y + 4), paint);
    canvas.drawLine(Offset(right, y - 4), Offset(right, y + 4), paint);
    paintPill(canvas, label, Offset(left - 10 - label.width / 2 - 8, y));
  }

  @override
  bool shouldRepaint(ScaleZoomPainter old) =>
      old.props != props || old.palette != palette || old.progress != progress || old.textScaler != textScaler;
}
