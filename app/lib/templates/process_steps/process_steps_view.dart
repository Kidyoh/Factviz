import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme.dart';
import '../common/motion.dart';
import '../common/playback_controls.dart';
import '../common/viz_paint.dart';
import '../../ui/cosmic/glass.dart';

/// Sequential stages that auto-play, with play/pause/step controls. Cyclic
/// processes are drawn as a ring; linear ones as a row of numbered stops.
class ProcessStepsView extends StatefulWidget {
  const ProcessStepsView({super.key, required this.props});

  final ProcessStepsProps props;

  @override
  State<ProcessStepsView> createState() => _ProcessStepsViewState();
}

class _ProcessStepsViewState extends State<ProcessStepsView> with SingleTickerProviderStateMixin {
  late final AnimationController _timer = AnimationController(vsync: this, duration: widget.props.autoplay)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _advance();
    });
  int _index = 0;
  bool _playing = false;
  bool _started = false;

  int get _last => widget.props.steps.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduced motion: no autoplay, the user steps through manually.
    if (!reduceMotionOf(context)) _play();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  void _advance() {
    setState(() {
      if (_index < _last) {
        _index++;
      } else if (widget.props.loop) {
        _index = 0;
      } else {
        _playing = false;
        return;
      }
      if (_playing) _timer.forward(from: 0);
    });
  }

  void _play() {
    setState(() {
      if (_index == _last && !widget.props.loop) _index = 0;
      _playing = true;
    });
    _timer.forward(from: 0);
  }

  void _pause() {
    _timer.stop();
    setState(() => _playing = false);
  }

  void _goTo(int i) {
    setState(() => _index = i.clamp(0, _last));
    if (_playing) {
      _timer.forward(from: 0);
    } else {
      _timer.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.props;
    final reduce = reduceMotionOf(context);
    final ring = props.loop && props.steps.length <= 8;
    final progressBar = AnimatedBuilder(
      animation: _timer,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LinearProgressIndicator(
          value: _playing ? _timer.value : 0,
          minHeight: 3,
          borderRadius: BorderRadius.circular(2),
          semanticsLabel: 'Time until next step',
        ),
      ),
    );
    final controls = Center(
      child: PlaybackControls(
        playing: _playing,
        onPlayPause: _playing ? _pause : _play,
        onPrevious: _index > 0 || props.loop ? () => _goTo(_index > 0 ? _index - 1 : _last) : null,
        onNext: _index < _last || props.loop ? () => _goTo(_index < _last ? _index + 1 : 0) : null,
      ),
    );
    if (!ring) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Stepper(steps: props.steps, index: _index, onTap: _goTo, reduceMotion: reduce),
          ),
          progressBar,
          controls,
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final diagramHeight = math.min(constraints.maxHeight * 0.48, constraints.maxWidth * 0.7);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: diagramHeight,
              child: AnimatedBuilder(
                animation: _timer,
                builder: (context, _) =>
                    _Ring(steps: props.steps, index: _index, progress: _playing ? _timer.value : 0, onTap: _goTo),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: AnimatedSwitcher(
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _StepCard(
                    key: ValueKey(_index),
                    step: props.steps[_index],
                    total: props.steps.length,
                    color: context.viz.seriesAt(_index),
                  ),
                ),
              ),
            ),
            progressBar,
            controls,
          ],
        );
      },
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({super.key, required this.step, required this.total, required this.color});

  final ProcessStep step;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: SingleChildScrollView(
        child: Glass(
          tint: color,
          radius: 20,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step ${step.order} of $total',
                style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(step.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(step.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.45)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.step, required this.state, required this.color, required this.onTap});

  final ProcessStep step;

  /// -1 done, 0 current, 1 upcoming.
  final int state;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = state == 0;
    return Semantics(
      button: true,
      selected: current,
      label: 'Step ${step.order}: ${step.title}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: current ? 40 : 32,
          height: current ? 40 : 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: state <= 0
                ? RadialGradient(
                    center: const Alignment(-0.35, -0.4),
                    colors: [lighten(color, 0.22), color, darken(color, 0.3)],
                  )
                : null,
            color: state <= 0 ? null : const Color(0xFF0B1030),
            border: Border.all(color: color.withValues(alpha: state <= 0 ? 0.9 : 0.6), width: 1.6),
            boxShadow: [
              if (current) BoxShadow(color: color.withValues(alpha: 0.65), blurRadius: 22, spreadRadius: 1),
              if (state < 0) BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10),
            ],
          ),
          child: Text(
            '${step.order}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: state <= 0 ? Cosmos.void0 : color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.steps, required this.index, required this.progress, required this.onTap});

  final List<ProcessStep> steps;
  final int index;
  final double progress;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.viz;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final center = Offset(c.maxWidth / 2, c.maxHeight / 2);
        final radius = math.max(10.0, math.min(c.maxWidth, c.maxHeight) / 2 - 26);
        Offset at(int i) {
          final a = -math.pi / 2 + 2 * math.pi * i / steps.length;
          return center + Offset(math.cos(a), math.sin(a)) * radius;
        }

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RingPainter(
                  count: steps.length,
                  index: index,
                  progress: progress,
                  center: center,
                  radius: radius,
                  track: Colors.white.withValues(alpha: 0.08),
                  active: palette.seriesAt(index),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: radius * 1.2,
                  child: Text(
                    steps[index].title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: theme.textTheme.titleSmall?.copyWith(color: palette.mutedLabel),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < steps.length; i++)
              Positioned(
                left: at(i).dx - 20,
                top: at(i).dy - 20,
                width: 40,
                height: 40,
                child: Center(
                  child: _Node(
                    step: steps[i],
                    state: i < index ? -1 : (i == index ? 0 : 1),
                    color: palette.seriesAt(i),
                    onTap: () => onTap(i),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.count,
    required this.index,
    required this.progress,
    required this.center,
    required this.radius,
    required this.track,
    required this.active,
  });

  final int count, index;
  final double progress, radius;
  final Offset center;
  final Color track, active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final seg = 2 * math.pi / count;
    // Completed part of the cycle so far, plus the live segment.
    final sweep = seg * (index + progress);
    if (sweep > 0) {
      final shader = SweepGradient(
        transform: const GradientRotation(-math.pi / 2),
        colors: const [Cosmos.violet, Cosmos.cyan, Cosmos.pink, Cosmos.violet],
      ).createShader(rect);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
      final a = -math.pi / 2 + sweep;
      paintComet(canvas, center + Offset(math.cos(a), math.sin(a)) * radius, active, radius: 3.5);
    }
    // Direction arrows midway between nodes.
    final arrow = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i < count; i++) {
      final a = -math.pi / 2 + seg * (i + 0.5);
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      final dir = Offset(-math.sin(a), math.cos(a));
      final normal = Offset(math.cos(a), math.sin(a));
      final path = Path()
        ..moveTo((p + dir * 5).dx, (p + dir * 5).dy)
        ..lineTo((p - dir * 3 + normal * 4).dx, (p - dir * 3 + normal * 4).dy)
        ..lineTo((p - dir * 3 - normal * 4).dx, (p - dir * 3 - normal * 4).dy)
        ..close();
      canvas.drawPath(path, arrow);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.index != index || old.progress != progress || old.radius != radius || old.active != active;
}

/// Vertical list of all steps; the current one is expanded with its
/// description and scrolled into view.
class _Stepper extends StatefulWidget {
  const _Stepper({required this.steps, required this.index, required this.onTap, required this.reduceMotion});

  final List<ProcessStep> steps;
  final int index;
  final ValueChanged<int> onTap;
  final bool reduceMotion;

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  late final List<GlobalKey> _keys = [for (final _ in widget.steps) GlobalKey()];
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Stepper old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Scroll only this list (Scrollable.ensureVisible would also scroll the page).
      final box = _keys[widget.index].currentContext?.findRenderObject();
      if (box == null || !mounted || !_scroll.hasClients) return;
      final target = RenderAbstractViewport.of(
        box,
      ).getOffsetToReveal(box, 0.2).offset.clamp(0.0, _scroll.position.maxScrollExtent);
      if (widget.reduceMotion) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.viz;
    final steps = widget.steps;
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              key: _keys[i],
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 40,
                    child: Column(
                      children: [
                        _Node(
                          step: steps[i],
                          state: i < widget.index ? -1 : (i == widget.index ? 0 : 1),
                          color: palette.seriesAt(i),
                          onTap: () => widget.onTap(i),
                        ),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 3,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: i < widget.index
                                    ? LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [palette.seriesAt(i), palette.seriesAt(i + 1)],
                                      )
                                    : null,
                                color: i < widget.index ? null : palette.grid,
                                boxShadow: i < widget.index
                                    ? [BoxShadow(color: palette.seriesAt(i).withValues(alpha: 0.5), blurRadius: 6)]
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: i == widget.index
                                ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
                                : theme.textTheme.bodyLarge?.copyWith(color: palette.mutedLabel),
                          ),
                          AnimatedSwitcher(
                            duration: widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
                            child: i == widget.index
                                ? Padding(
                                    key: ValueKey(i),
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(steps[i].description, style: theme.textTheme.bodyMedium),
                                    ),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
