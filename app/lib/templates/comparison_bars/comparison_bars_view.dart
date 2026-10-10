import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../common/motion.dart';
import '../common/viz_paint.dart';

/// Animated side-by-side quantities with units, plus how many times the
/// largest is bigger than each of the others.
class ComparisonBarsView extends StatefulWidget {
  const ComparisonBarsView({super.key, required this.props});

  final ComparisonBarsProps props;

  @override
  State<ComparisonBarsView> createState() => _ComparisonBarsViewState();
}

class _ComparisonBarsViewState extends State<ComparisonBarsView>
    with SingleTickerProviderStateMixin, EntranceAnimation {
  @override
  Duration get entranceDuration => Duration(milliseconds: 700 + 160 * widget.props.bars.length);

  /// Staggered 0..1 growth for bar [i].
  double _grow(int i) {
    final n = widget.props.bars.length;
    final start = n <= 1 ? 0.0 : 0.35 * i / (n - 1);
    final t = ((entrance.value - start) / 0.65).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  /// The value counting up as its bar grows; exact once fully grown.
  String _countUp(ResolvedQuantity q, double t) {
    if (t >= 1) return q.displayValue;
    final v = q.value * t;
    final shown = q.value == q.value.roundToDouble() ? v.roundToDouble() : v;
    return formatQuantity(shown, q.unit, approximate: q.approximate);
  }

  String? _ratioText(BarItem bar) {
    final props = widget.props;
    final largest = props.bars.reduce((a, b) => a.valueSi >= b.valueSi ? a : b);
    if (identical(bar, largest) || bar.valueSi <= 0) return null;
    final ratio = largest.valueSi / bar.valueSi;
    if (ratio < 1.05) return 'about the same as ${largest.displayName}';
    return '${largest.displayName} is ${formatNumber(ratio)}× this';
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.props;
    return AnimatedBuilder(
      animation: entrance,
      builder: (context, _) => props.orientation == BarOrientation.horizontal
          ? _horizontal(context, props)
          : _vertical(context, props),
    );
  }

  Widget _horizontal(BuildContext context, ComparisonBarsProps props) {
    final theme = Theme.of(context);
    final palette = context.viz;
    final max = props.maxSi;
    return LayoutBuilder(builder: (context, constraints) {
      // Thicker bars when there is room, so few bars still fill the canvas.
      final perRow = constraints.maxHeight / props.bars.length;
      final thickness = (perRow - 64).clamp(18.0, 44.0);
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              for (var i = 0; i < props.bars.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                _horizontalRow(theme, palette, props.bars[i], i, max, thickness),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _horizontalRow(ThemeData theme, VizPalette palette, BarItem bar, int i, double max, double thickness) {
    final fraction = max <= 0 ? 0.0 : bar.valueSi / max;
    final ratio = _ratioText(bar);
    return Semantics(
      label: '${bar.displayName}: ${bar.quantity.displayValue}${ratio == null ? '' : '. $ratio'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(bar.displayName, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Opacity(
                opacity: _grow(i),
                child: Text(
                  _countUp(bar.quantity, _grow(i)),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.seriesAt(i),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Bar(
            fraction: fraction * _grow(i),
            color: palette.seriesAt(i),
            track: palette.grid,
            thickness: thickness,
            axis: Axis.horizontal,
            shimmer: _grow(i),
          ),
          if (ratio != null) ...[
            const SizedBox(height: 4),
            Opacity(
              opacity: _grow(i),
              child: Text(ratio, style: theme.textTheme.bodySmall?.copyWith(color: palette.mutedLabel)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vertical(BuildContext context, ComparisonBarsProps props) {
    final theme = Theme.of(context);
    final palette = context.viz;
    final max = props.maxSi;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < props.bars.length; i++)
            Expanded(
              child: Semantics(
                label: '${props.bars[i].displayName}: ${props.bars[i].quantity.displayValue}',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Opacity(
                        opacity: _grow(i),
                        child: Text(
                          _countUp(props.bars[i].quantity, _grow(i)),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _Bar(
                          fraction: (max <= 0 ? 0.0 : props.bars[i].valueSi / max) * _grow(i),
                          color: palette.seriesAt(i),
                          track: palette.grid,
                          thickness: math.min(56, 220 / props.bars.length),
                          axis: Axis.vertical,
                          shimmer: _grow(i),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        props.bars[i].displayName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    required this.track,
    required this.thickness,
    required this.axis,
    this.shimmer = 1,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double thickness;
  final Axis axis;

  /// Growth progress 0..1; a light band sweeps along the bar while < 1.
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    return SizedBox(
      width: horizontal ? double.infinity : thickness,
      height: horizontal ? thickness : double.infinity,
      child: CustomPaint(
        painter: _BarPainter(
          // Non-zero values never vanish completely, even next to huge ones.
          fraction: fraction > 0 ? math.max(fraction, 0.004) : 0.0,
          color: color,
          track: track,
          horizontal: horizontal,
          shimmer: shimmer,
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.horizontal,
    required this.shimmer,
  });

  final double fraction;
  final Color color;
  final Color track;
  final bool horizontal;
  final double shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular((horizontal ? size.height : size.width) / 2.6);
    final full = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(full, radius), Paint()..color = track);
    if (fraction <= 0) return;
    final bar = horizontal
        ? Rect.fromLTWH(0, 0, size.width * fraction, size.height)
        : Rect.fromLTWH(0, size.height * (1 - fraction), size.width, size.height * fraction);
    final rrect = RRect.fromRectAndRadius(bar, radius);
    paintGlowBar(canvas, rrect, color, vertical: !horizontal);
    if (shimmer < 1) {
      canvas.save();
      canvas.clipRRect(rrect);
      final band = horizontal ? bar.width * 0.35 : bar.height * 0.35;
      final pos = horizontal
          ? Rect.fromLTWH(bar.left - band + (bar.width + band) * shimmer, bar.top, band, bar.height)
          : Rect.fromLTWH(bar.left, bar.bottom - (bar.height + band) * shimmer, bar.width, band);
      canvas.drawRect(
        pos,
        Paint()
          ..shader = LinearGradient(
            begin: horizontal ? Alignment.centerLeft : Alignment.bottomCenter,
            end: horizontal ? Alignment.centerRight : Alignment.topCenter,
            colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
          ).createShader(pos),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fraction != fraction || old.shimmer != shimmer || old.color != color || old.horizontal != horizontal;
}
