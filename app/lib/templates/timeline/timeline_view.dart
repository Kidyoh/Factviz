import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../common/canvas_text.dart';
import '../common/motion.dart';
import '../common/viz_paint.dart';
import 'timeline_layout.dart';

/// Events on an animated, horizontally scrollable time axis.
class TimelineView extends StatefulWidget {
  const TimelineView({super.key, required this.props});

  final TimelineProps props;

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView>
    with SingleTickerProviderStateMixin, EntranceAnimation {
  final _scroll = ScrollController();
  bool _follow = true;
  TimelineLayout? _layout;
  double _viewport = 0;

  static const double _cardWidth = 136;

  @override
  Duration get entranceDuration =>
      Duration(milliseconds: math.min(6000, 1200 + 280 * widget.props.events.length));

  @override
  void initState() {
    super.initState();
    entrance.addListener(_followHead);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _followHead() {
    final layout = _layout;
    if (!_follow || layout == null || !_scroll.hasClients || !entrance.isAnimating) return;
    final head = entrance.value * layout.width;
    final target = (head - _viewport * 0.65).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(target);
  }

  void _showDetails(TimelineEvent e) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.displayDate, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 4),
                Text(e.label, style: theme.textTheme.titleLarge),
                if (e.description != null) ...[
                  const SizedBox(height: 12),
                  Text(e.description!, style: theme.textTheme.bodyLarge),
                ],
                const SizedBox(height: 16),
                Text('Source: ${e.sourceNote}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.props;
    final palette = context.viz;
    return LayoutBuilder(builder: (context, constraints) {
      _viewport = constraints.maxWidth;
      final layout = TimelineLayout.compute(props, viewportWidth: constraints.maxWidth, cardWidth: _cardWidth);
      _layout = layout;
      final height = constraints.maxHeight;
      final axisY = height / 2;
      const axisGap = 22.0, levelGap = 8.0;
      final cardHeight = math.min(78.0, (axisY - axisGap - 4) / layout.levels - levelGap);
      final ticks = timelineTicks(props, layout.width);

      double cardTop(int lane) {
        final level = lane ~/ 2;
        return lane.isEven
            ? axisY - axisGap - cardHeight - level * (cardHeight + levelGap)
            : axisY + axisGap + level * (cardHeight + levelGap);
      }

      return NotificationListener<ScrollStartNotification>(
        onNotification: (n) {
          if (n.dragDetails != null) _follow = false;
          return false;
        },
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: layout.width,
            height: height,
            child: AnimatedBuilder(
              animation: entrance,
              builder: (context, _) {
                final head = entrance.value * layout.width;
                double opacityAt(double x) => ((head - x) / 80 + 1).clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _AxisPainter(
                          axisY: axisY,
                          head: head,
                          ticks: ticks,
                          xs: layout.xs,
                          connectors: [
                            for (var i = 0; i < layout.xs.length; i++)
                              (
                                layout.lanes[i].isEven ? cardTop(layout.lanes[i]) + cardHeight : cardTop(layout.lanes[i]),
                                opacityAt(layout.xs[i]),
                              ),
                          ],
                          palette: palette,
                          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                          baseStyle: Theme.of(context).textTheme.bodySmall!,
                        ),
                      ),
                    ),
                    for (var i = 0; i < props.events.length; i++)
                      Positioned(
                        left: layout.cardLefts[i],
                        top: cardTop(layout.lanes[i]),
                        width: _cardWidth,
                        height: cardHeight,
                        child: Opacity(
                          opacity: opacityAt(layout.xs[i]),
                          child: _EventCard(
                            event: props.events[i],
                            color: palette.seriesAt(i),
                            onTap: () => _showDetails(props.events[i]),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    });
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.color, required this.onTap});

  final TimelineEvent event;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${event.displayDate}: ${event.label}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 18, spreadRadius: -4)],
        ),
        child: Material(
          color: const Color(0xD90C1230),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withValues(alpha: 0.45)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: color.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.displayDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 3),
                  Flexible(
                    child: Text(
                      event.label,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, height: 1.25, color: Cosmos.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AxisPainter extends CustomPainter {
  _AxisPainter({
    required this.axisY,
    required this.head,
    required this.ticks,
    required this.xs,
    required this.connectors,
    required this.palette,
    required this.textScaler,
    required this.baseStyle,
  });

  final double axisY;
  final double head;
  final List<AxisTick> ticks;
  final List<double> xs;

  /// Card edge y and opacity per event.
  final List<(double, double)> connectors;
  final VizPalette palette;
  final TextScaler textScaler;

  /// Theme text style, so canvas labels use the app font.
  final TextStyle baseStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(TimelineLayout.pad / 2, axisY);
    final endX = math.min(head, size.width - TimelineLayout.pad / 2);
    final end = Offset(endX, axisY);

    final tickPaint = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    final style = baseStyle.copyWith(fontSize: textScaler.scale(10), color: palette.mutedLabel, fontWeight: FontWeight.w500);
    for (final t in ticks) {
      if (t.x > head) continue;
      for (var y = 0.0; y < size.height; y += 8) {
        canvas.drawLine(Offset(t.x, y), Offset(t.x, y + 3), tickPaint);
      }
      final label = layoutText(t.label, style);
      label.paint(canvas, Offset(t.x - label.width / 2, axisY + 6));
    }

    if (endX > start.dx) {
      final rect = Rect.fromPoints(start, end).inflate(4);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..shader = const LinearGradient(colors: [Cosmos.violet, Cosmos.cyan]).createShader(rect)
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..shader = const LinearGradient(colors: [Cosmos.violet, Cosmos.cyan]).createShader(rect)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < xs.length; i++) {
      final (edgeY, opacity) = connectors[i];
      if (opacity <= 0) continue;
      final color = palette.seriesAt(i);
      paintGlowLine(canvas, Offset(xs[i], axisY), Offset(xs[i], edgeY), color, width: 1.2, opacity: opacity * 0.7);
      paintSphere(canvas, Offset(xs[i], axisY), 6.5 * opacity.clamp(0.5, 1.0), color, opacity: opacity);
    }

    // The drawing head travels along the axis like a comet.
    if (head < size.width - TimelineLayout.pad / 2) paintComet(canvas, end, Cosmos.cyan, radius: 4.5);
  }

  @override
  bool shouldRepaint(_AxisPainter old) => true;
}
