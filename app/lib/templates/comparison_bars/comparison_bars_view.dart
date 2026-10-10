import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../common/motion.dart';

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
                child: Text(bar.quantity.displayValue, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
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
                          props.bars[i].quantity.displayValue,
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
  });

  final double fraction;
  final Color color;
  final Color track;
  final double thickness;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(thickness / 3);
    // Non-zero values never vanish completely, even next to huge ones.
    final visible = fraction > 0 ? math.max(fraction, 0.004) : 0.0;
    final horizontal = axis == Axis.horizontal;
    return Container(
      width: horizontal ? double.infinity : thickness,
      height: horizontal ? thickness : double.infinity,
      decoration: BoxDecoration(color: track, borderRadius: radius),
      alignment: horizontal ? Alignment.centerLeft : Alignment.bottomCenter,
      child: FractionallySizedBox(
        widthFactor: horizontal ? visible : 1,
        heightFactor: horizontal ? 1 : visible,
        child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: radius)),
      ),
    );
  }
}
