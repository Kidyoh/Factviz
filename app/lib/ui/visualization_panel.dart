import 'dart:math' as math;

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app/theme.dart';
import '../viz/viz_view.dart';
import 'confidence_badge.dart';
import 'editorial.dart';
import 'fact_card.dart';
import 'key_numbers.dart';

const _templateTags = {
  TemplateId.scaleZoom: 'To scale',
  TemplateId.timeline: 'Timeline',
  TemplateId.exponentialGrowth: 'Growth',
  TemplateId.comparisonBars: 'Comparison',
  TemplateId.processSteps: 'How it works',
  TemplateId.none: 'Answer',
};

/// A full result laid out like a newspaper graphic: kicker, headline, dek,
/// the chart, a plain-language explanation and the numbers with sources.
class VisualizationPanel extends StatelessWidget {
  const VisualizationPanel({super.key, required this.visualization, this.replayKey = 0});

  final Visualization visualization;
  final int replayKey;

  /// Side margin for text; the chart itself runs edge to edge.
  static const double gutter = 20;

  @override
  Widget build(BuildContext context) {
    final viz = visualization;
    final props = viz.props;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final chartHeight = math.max(400.0, math.min(540.0, MediaQuery.sizeOf(context).height * 0.62));

    Widget reveal(Widget child, int i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: gutter),
          child: child.animate(target: reduce ? 1 : null).fadeIn(delay: (90 * i).ms, duration: 400.ms).slideY(begin: 0.06, end: 0),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        reveal(Kicker(_templateTags[props.template]!), 0),
        const SizedBox(height: 8),
        reveal(Text(props.title, style: Txt.headline), 1),
        if (props.caption != null) ...[
          const SizedBox(height: 8),
          reveal(Text(props.caption!, style: Txt.dek), 2),
        ],
        const SizedBox(height: 16),
        if (viz.facts.confidence == Confidence.low) ...[
          reveal(ConfidenceBadge(facts: viz.facts), 2),
          const SizedBox(height: 16),
        ],
        if (props is NoneProps)
          reveal(FactCard(facts: viz.facts, reason: props.reason), 3)
        else ...[
          // Full-bleed chart between hairlines.
          Container(
            decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Palette.rule))),
            height: chartHeight,
            child: VizView(props: props, replayKey: replayKey),
          ),
          const SizedBox(height: 22),
          reveal(_Lede(text: viz.facts.explanation), 3),
        ],
        const SizedBox(height: 28),
        reveal(KeyNumbers(facts: viz.keyFacts), 4),
      ],
    );
  }
}

/// Explanation paragraph with a drop cap.
class _Lede extends StatelessWidget {
  const _Lede({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: text.substring(0, 1),
          style: const TextStyle(fontFamily: serif, fontSize: 40, height: 0.9, fontWeight: FontWeight.w600, color: Palette.accent),
        ),
        TextSpan(text: text.substring(1)),
      ]),
      style: Txt.body,
    );
  }
}
