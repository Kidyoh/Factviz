import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../common/canvas_text.dart';
import '../common/viz_paint.dart';

/// Value-vs-step chart for exponential growth on a linear or log y axis.
class GrowthChartPainter extends CustomPainter {
  GrowthChartPainter({
    required this.props,
    required this.step,
    required this.scale,
    required this.palette,
    required this.textScaler,
    required this.baseStyle,
    this.burst = 0,
  });

  final ExponentialGrowthProps props;

  /// Current (fractional) step.
  final double step;
  final AxisScale scale;
  final VizPalette palette;
  final TextScaler textScaler;

  /// Theme text style, so canvas labels use the app font.
  final TextStyle baseStyle;

  /// 0..1 progress of the celebration burst when the target is reached.
  final double burst;

  static const double _left = 72, _right = 16, _top = 16, _bottom = 28;

  TextStyle _style(double size, Color color, [FontWeight weight = FontWeight.w400]) =>
      baseStyle.copyWith(fontSize: textScaler.scale(size), color: color, fontWeight: weight);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(_left, _top, size.width - _right, size.height - _bottom);
    if (plot.width <= 0 || plot.height <= 0) return;

    final target = props.target?.valueSi;
    final yMaxValue = math.max(props.finalValueSi, target ?? 0);
    final mapper = scale == AxisScale.log
        ? _LogY(math.min(props.initial.valueSi, target ?? double.infinity), yMaxValue)
        : _LinearY(yMaxValue * 1.08);
    double xAt(double s) => plot.left + s / props.steps * plot.width;
    double yAt(double v) => plot.bottom - mapper.fraction(v) * plot.height;

    _paintGrid(canvas, plot, mapper, yAt);
    _paintXAxis(canvas, plot, xAt);
    if (target != null) _paintTarget(canvas, plot, yAt(target));

    // Curve up to the current step, with a glowing stroke and area fill.
    final samples = math.max(2, (step * 6).ceil());
    final path = Path();
    final area = Path()..moveTo(xAt(0), plot.bottom);
    for (var i = 0; i <= samples; i++) {
      final s = step * i / samples;
      final o = Offset(xAt(s), yAt(props.valueAtStepSi(s)).clamp(plot.top, plot.bottom));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      area.lineTo(o.dx, o.dy);
    }
    area
      ..lineTo(xAt(step), plot.bottom)
      ..close();
    final color = palette.seriesAt(0);
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), Cosmos.violet.withValues(alpha: 0.06)],
        ).createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(colors: [Cosmos.violet, Cosmos.cyan]).createShader(plot)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final head = Offset(xAt(step), yAt(props.valueAtStepSi(step)).clamp(plot.top, plot.bottom));
    paintComet(canvas, head, color, radius: 5);
    if (target != null && burst > 0) {
      paintBurst(canvas, head, burst, const [Cosmos.amber, Cosmos.pink, Cosmos.cyan, Colors.white]);
    }
  }

  void _paintGrid(Canvas canvas, Rect plot, _YMapper mapper, double Function(double) yAt) {
    final grid = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    final style = _style(10, palette.mutedLabel);
    for (final v in mapper.ticks()) {
      final y = yAt(v);
      if (y < plot.top - 1 || y > plot.bottom + 1) continue;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final label = layoutText(props.formatValueSi(v), style, maxWidth: _left - 8, align: TextAlign.right);
      label.paint(canvas, Offset(plot.left - 6 - label.width, y - label.height / 2));
    }
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, Paint()..color = palette.axis);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, Paint()..color = palette.axis);
  }

  void _paintXAxis(Canvas canvas, Rect plot, double Function(double) xAt) {
    final style = _style(10, palette.mutedLabel);
    final n = props.steps;
    final stride = math.max(1, (n / 6).ceil());
    for (var s = 0; s <= n; s += stride) {
      final label = layoutText('$s', style);
      label.paint(canvas, Offset(xAt(s.toDouble()) - label.width / 2, plot.bottom + 6));
    }
  }

  void _paintTarget(Canvas canvas, Rect plot, double y) {
    if (y < plot.top - 1 || y > plot.bottom + 1) return;
    canvas.drawLine(
      Offset(plot.left, y),
      Offset(plot.right, y),
      Paint()
        ..color = palette.target.withValues(alpha: 0.35)
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    final paint = Paint()
      ..color = palette.target
      ..strokeWidth = 1.5;
    const dash = 6.0;
    for (var x = plot.left; x < plot.right; x += dash * 2) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, plot.right), y), paint);
    }
    final label = layoutText(props.target!.label, _style(11, palette.target, FontWeight.w700), maxWidth: plot.width * 0.7);
    final above = y - label.height - 14 > plot.top;
    paintPill(
      canvas,
      label,
      Offset(plot.left + 14 + label.width / 2, above ? y - label.height / 2 - 10 : y + label.height / 2 + 10),
      border: palette.target.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(GrowthChartPainter old) =>
      old.step != step || old.burst != burst || old.scale != scale || old.props != props || old.palette != palette;
}

abstract class _YMapper {
  double fraction(double v);
  List<double> ticks();
}

class _LinearY implements _YMapper {
  _LinearY(this.max);
  final double max;

  @override
  double fraction(double v) => max <= 0 ? 0 : v / max;

  @override
  List<double> ticks() {
    final step = _nice(max / 4);
    return [for (var v = 0.0; v <= max; v += step) v];
  }

  static double _nice(double raw) {
    if (raw <= 0) return 1;
    final exp = (math.log(raw) / math.ln10).floor();
    final base = math.pow(10.0, exp).toDouble();
    final f = raw / base;
    return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * base;
  }
}

class _LogY implements _YMapper {
  _LogY(double min, double max)
      : lo = (math.log(min) / math.ln10).floor().toDouble(),
        hi = math.max((math.log(max) / math.ln10).ceil().toDouble(), (math.log(min) / math.ln10).floor() + 1.0);

  final double lo, hi;

  @override
  double fraction(double v) => v <= 0 ? 0 : ((math.log(v) / math.ln10) - lo) / (hi - lo);

  @override
  List<double> ticks() {
    final decades = (hi - lo).round();
    final stride = math.max(1, (decades / 5).ceil());
    return [for (var k = lo; k <= hi; k += stride) math.pow(10.0, k).toDouble()];
  }
}
