import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import 'comparison_bars/comparison_bars_view.dart';
import 'exponential_growth/exponential_growth_view.dart';
import 'process_steps/process_steps_view.dart';
import 'scale_zoom/scale_zoom_view.dart';
import 'timeline/timeline_view.dart';

/// Renders validated [TemplateProps] with the matching hand-built template.
///
/// Changing [replayKey] recreates the template, restarting its animation.
class TemplateView extends StatelessWidget {
  const TemplateView({super.key, required this.props, this.replayKey = 0});

  final TemplateProps props;
  final int replayKey;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey(replayKey);
    return switch (props) {
      ScaleZoomProps p => ScaleZoomView(key: key, props: p),
      TimelineProps p => TimelineView(key: key, props: p),
      ExponentialGrowthProps p => ExponentialGrowthView(key: key, props: p),
      ComparisonBarsProps p => ComparisonBarsView(key: key, props: p),
      ProcessStepsProps p => ProcessStepsView(key: key, props: p),
      NoneProps p => _NoTemplate(props: p),
    };
  }
}

class _NoTemplate extends StatelessWidget {
  const _NoTemplate({required this.props});

  final NoneProps props;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(props.reason, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
