import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../templates/template_view.dart';
import 'confidence_badge.dart';
import 'fact_card.dart';
import 'key_numbers.dart';

/// A full result: title, warning badge, the animated template (or a fact
/// card), the plain-language explanation and the key numbers with sources.
class VisualizationPanel extends StatelessWidget {
  const VisualizationPanel({super.key, required this.visualization, this.replayKey = 0});

  final Visualization visualization;
  final int replayKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viz = visualization;
    final props = viz.props;
    final height = math.max(360.0, math.min(480.0, MediaQuery.sizeOf(context).height * 0.55));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(props.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        if (props.caption != null) ...[
          const SizedBox(height: 4),
          Text(props.caption!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 12),
        ConfidenceBadge(facts: viz.facts),
        if (viz.facts.confidence == Confidence.low) const SizedBox(height: 12),
        if (props is NoneProps)
          FactCard(facts: viz.facts, reason: props.reason)
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: context.viz.surface,
              child: SizedBox(height: height, child: TemplateView(props: props, replayKey: replayKey)),
            ),
          ),
          const SizedBox(height: 20),
          Text('In plain words', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(viz.facts.explanation, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 20),
        KeyNumbers(facts: viz.keyFacts),
      ],
    );
  }
}
