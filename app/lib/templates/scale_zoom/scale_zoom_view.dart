import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../common/motion.dart';
import 'scale_zoom_painter.dart';

/// Compares sizes or distances to scale, zooming out from the smallest item
/// to the largest through a log-aware camera.
class ScaleZoomView extends StatefulWidget {
  const ScaleZoomView({super.key, required this.props});

  final ScaleZoomProps props;

  @override
  State<ScaleZoomView> createState() => _ScaleZoomViewState();
}

class _ScaleZoomViewState extends State<ScaleZoomView>
    with SingleTickerProviderStateMixin, EntranceAnimation {
  final progress = ValueNotifier<double>(0);

  int get _segments => widget.props.items.length - 1;

  @override
  Duration get entranceDuration => Duration(milliseconds: 400 + 1400 * _segments);

  @override
  void initState() {
    super.initState();
    entrance.addListener(() => progress.value = entrance.value * _segments);
  }

  @override
  void dispose() {
    progress.dispose();
    super.dispose();
  }

  void _focus(int i) {
    final target = _segments == 0 ? 1.0 : i / _segments;
    if (reduceMotion) {
      entrance.value = target;
    } else {
      entrance.animateTo(target, duration: const Duration(milliseconds: 900), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.props;
    final palette = context.viz;
    final summary = props.items.map((i) => '${i.displayName}: ${i.quantity.displayValue}').join(', ');
    return Column(
      children: [
        Expanded(
          child: Semantics(
            label: '${props.title}. To-scale comparison: $summary',
            image: true,
            child: CustomPaint(
              size: Size.infinite,
              painter: ScaleZoomPainter(
                props: props,
                progress: progress,
                palette: palette,
                textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4),
                baseStyle: Theme.of(context).textTheme.bodySmall!,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, p, _) {
              final focus = p.round();
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: props.items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) => ChoiceChip(
                  label: Text(props.items[i].displayName),
                  avatar: CircleAvatar(backgroundColor: palette.seriesAt(i), radius: 6),
                  selected: i == focus,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _focus(i),
                ),
              );
            },
          ),
        ),
        if (_segments > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Icon(Icons.zoom_in_rounded, size: 20),
                Expanded(
                  child: AnimatedBuilder(
                    animation: entrance,
                    builder: (context, _) => Slider(
                      value: entrance.value,
                      semanticFormatterCallback: (v) => 'Zoom ${(v * 100).round()}%',
                      onChanged: (v) {
                        entrance.stop();
                        entrance.value = v;
                      },
                    ),
                  ),
                ),
                const Icon(Icons.zoom_out_rounded, size: 20),
              ],
            ),
          ),
      ],
    );
  }
}
