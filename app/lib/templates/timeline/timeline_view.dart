import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../common/canvas_text.dart';
import '../common/motion.dart';
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
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 4))),
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.displayDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    event.label,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
                  ),
                ),
              ],
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
    final axis = Paint()
      ..color = palette.axis
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(TimelineLayout.pad / 2, axisY), Offset(math.min(head, size.width - TimelineLayout.pad / 2), axisY), axis);

    final tickPaint = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    final style = baseStyle.copyWith(fontSize: textScaler.scale(10), color: palette.mutedLabel);
    for (final t in ticks) {
      if (t.x > head) continue;
      canvas.drawLine(Offset(t.x, 0), Offset(t.x, size.height), tickPaint);
      final label = layoutText(t.label, style);
      label.paint(canvas, Offset(t.x - label.width / 2, axisY + 4));
    }

    for (var i = 0; i < xs.length; i++) {
      final (edgeY, opacity) = connectors[i];
      if (opacity <= 0) continue;
      final color = palette.seriesAt(i).withValues(alpha: opacity);
      canvas.drawLine(
        Offset(xs[i], axisY),
        Offset(xs[i], edgeY),
        Paint()
          ..color = color.withValues(alpha: opacity * 0.6)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(Offset(xs[i], axisY), 6 * opacity.clamp(0.5, 1.0), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) => true;
}
