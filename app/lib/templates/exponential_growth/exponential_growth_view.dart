import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../ui/cosmic/glass.dart';
import '../common/motion.dart';
import '../common/playback_controls.dart';
import 'growth_chart_painter.dart';

/// Repeated multiplication with a step counter, linear/log toggle, and an
/// optional target line (e.g. "reaches the Moon").
class ExponentialGrowthView extends StatefulWidget {
  const ExponentialGrowthView({super.key, required this.props});

  final ExponentialGrowthProps props;

  @override
  State<ExponentialGrowthView> createState() => _ExponentialGrowthViewState();
}

class _ExponentialGrowthViewState extends State<ExponentialGrowthView>
    with TickerProviderStateMixin, EntranceAnimation {
  late AxisScale _scale = widget.props.defaultScale;
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    entrance.addListener(_maybeCelebrate);
  }

  /// One spark burst (and a tap of haptics) the first time the target is
  /// reached during playback.
  void _maybeCelebrate() {
    final target = widget.props.targetStep;
    if (_celebrated || target == null || !entrance.isAnimating) return;
    if (_step.floor() >= target) {
      _celebrated = true;
      HapticFeedback.mediumImpact();
      if (!reduceMotion) _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  int get _steps => widget.props.steps;

  @override
  Duration get entranceDuration => Duration(milliseconds: (_steps * 180).clamp(3000, 10000));

  double get _step => entrance.value * _steps;

  void _playPause() {
    if (entrance.isAnimating) {
      entrance.stop();
    } else if (entrance.isCompleted) {
      entrance.forward(from: 0);
    } else {
      entrance.forward();
    }
    setState(() {});
  }

  void _jumpTo(int step) {
    entrance.stop();
    entrance.value = (step / _steps).clamp(0.0, 1.0);
    setState(() {});
  }

  String _plural(String noun, int n) => n == 1 ? noun : '${noun}s';

  @override
  Widget build(BuildContext context) {
    final props = widget.props;
    final theme = Theme.of(context);
    final palette = context.viz;
    return AnimatedBuilder(
      animation: Listenable.merge([entrance, _burst]),
      builder: (context, _) {
        final whole = _step.floor();
        final value = props.valueAtStepSi(whole);
        final targetStep = props.targetStep;
        final reached = targetStep != null && whole >= targetStep;
        final label = props.stepLabel;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${label[0].toUpperCase()}${label.substring(1)} $whole of $_steps',
                          style: theme.textTheme.labelLarge?.copyWith(color: palette.mutedLabel),
                        ),
                        Semantics(
                          liveRegion: !entrance.isAnimating,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: GradientText(
                              props.formatValueSi(value),
                              gradient: const LinearGradient(colors: [Colors.white, Cosmos.cyan]),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '×${formatNumber(props.factor)} per $label',
                          style: theme.textTheme.bodySmall?.copyWith(color: palette.mutedLabel),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<AxisScale>(
                    segments: const [
                      ButtonSegment(value: AxisScale.linear, label: Text('Linear')),
                      ButtonSegment(value: AxisScale.log, label: Text('Log')),
                    ],
                    selected: {_scale},
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onSelectionChanged: (s) => setState(() => _scale = s.first),
                  ),
                ],
              ),
            ),
            if (targetStep != null)
              // Space is reserved up front so the chart doesn't jump when the target is reached.
              AnimatedOpacity(
                opacity: reached ? 1 : 0,
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(
                    'Reaches ${props.target!.label} at $label $targetStep',
                    maxLines: 2,
                    style: theme.textTheme.bodyMedium?.copyWith(color: palette.target, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            Expanded(
              child: Semantics(
                image: true,
                label: 'Chart of ${props.title}: starts at ${props.initial.displayValue}, '
                    'multiplied by ${formatNumber(props.factor)} each $label for $_steps ${_plural(label, _steps)}, '
                    'ending at ${props.formatValueSi(props.finalValueSi)}.',
                child: CustomPaint(
                  size: Size.infinite,
                  painter: GrowthChartPainter(
                    props: props,
                    step: _step,
                    scale: _scale,
                    burst: _burst.value,
                    palette: palette,
                    textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                    baseStyle: Theme.of(context).textTheme.bodySmall!,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
              child: Row(
                children: [
                  PlaybackControls(
                    playing: entrance.isAnimating,
                    onPlayPause: _playPause,
                    onPrevious: whole > 0 ? () => _jumpTo(math.max(0, (_step.ceil()) - 1)) : null,
                    onNext: whole < _steps ? () => _jumpTo(whole + 1) : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: _step.clamp(0, _steps.toDouble()),
                      max: _steps.toDouble(),
                      divisions: _steps,
                      label: '$label $whole',
                      onChanged: (v) => _jumpTo(v.round()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
