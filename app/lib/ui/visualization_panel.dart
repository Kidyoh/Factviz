import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../templates/template_view.dart';
import 'confidence_badge.dart';
import 'cosmic/glass.dart';
import 'fact_card.dart';
import 'key_numbers.dart';

const _templateTags = {
  TemplateId.scaleZoom: ('To scale', Icons.zoom_out_map_rounded),
  TemplateId.timeline: ('Timeline', Icons.timeline_rounded),
  TemplateId.exponentialGrowth: ('Growth', Icons.trending_up_rounded),
  TemplateId.comparisonBars: ('Comparison', Icons.bar_chart_rounded),
  TemplateId.processSteps: ('Process', Icons.autorenew_rounded),
  TemplateId.none: ('Answer', Icons.lightbulb_outline_rounded),
};

/// A full result: tag, title, warning badge, the animated template (or a
/// fact card), the plain-language explanation and the key numbers.
class VisualizationPanel extends StatelessWidget {
  const VisualizationPanel({super.key, required this.visualization, this.replayKey = 0});

  final Visualization visualization;
  final int replayKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viz = visualization;
    final props = viz.props;
    final palette = context.viz;
    final height = math.max(380.0, math.min(500.0, MediaQuery.sizeOf(context).height * 0.56));
    final (tag, icon) = _templateTags[props.template]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Cosmos.cyan),
            const SizedBox(width: 6),
            Text(
              tag.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(color: Cosmos.cyan, letterSpacing: 1.8, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(props.title, style: theme.textTheme.headlineMedium),
        if (props.caption != null) ...[
          const SizedBox(height: 6),
          Text(props.caption!, style: theme.textTheme.bodyLarge?.copyWith(color: Cosmos.textMuted)),
        ],
        const SizedBox(height: 16),
        ConfidenceBadge(facts: viz.facts),
        if (viz.facts.confidence == Confidence.low) const SizedBox(height: 14),
        if (props is NoneProps)
          FactCard(facts: viz.facts, reason: props.reason)
        else ...[
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Cosmos.violet.withValues(alpha: 0.18), blurRadius: 40, spreadRadius: -10)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: CustomPaint(
                foregroundPainter: const GradientBorderPainter(radius: 28),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.6, -0.9),
                      radius: 1.4,
                      colors: [palette.surfaceTop, palette.surface],
                    ),
                  ),
                  child: SizedBox(height: height, child: TemplateView(props: props, replayKey: replayKey)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Glass(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Cosmos.violet),
                    const SizedBox(width: 8),
                    Text('In plain words', style: theme.textTheme.titleSmall?.copyWith(color: Cosmos.violet, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(viz.facts.explanation, style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 26),
        KeyNumbers(facts: viz.keyFacts),
      ],
    );
  }
}
