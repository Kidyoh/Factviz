import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'cosmic/glass.dart';

/// The facts behind a visualization as stat tiles, each with its source.
class KeyNumbers extends StatelessWidget {
  const KeyNumbers({super.key, required this.facts});

  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (facts.isEmpty) return const SizedBox.shrink();
    final hasNumbers = facts.any((f) => f is! StepFact);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(hasNumbers ? 'Key numbers' : 'Sources'),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          const gap = 10.0;
          final half = (c.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < facts.length; i++)
                SizedBox(
                  // Long values (dates, "4.5 billion years ago") get the full row.
                  width: _valueOf(facts[i]).length > 14 ? c.maxWidth : half,
                  child: _StatTile(fact: facts[i], accent: context.viz.seriesAt(i)),
                ),
            ],
          );
        }),
        const SizedBox(height: 4),
        if (hasNumbers)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '~ marks typical or rounded values.',
              style: theme.textTheme.bodySmall?.copyWith(color: Cosmos.textFaint),
            ),
          ),
      ],
    );
  }
}

String _valueOf(Fact fact) => switch (fact) {
      QuantityFact f => f.displayValue,
      EventFact f => f.displayDate,
      StepFact f => 'Step ${f.order}',
    };

String _labelOf(Fact fact) => switch (fact) {
      QuantityFact f => f.label,
      EventFact f => f.label,
      StepFact f => f.title,
    };

class _StatTile extends StatelessWidget {
  const _StatTile({required this.fact, required this.accent});

  final Fact fact;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Glass(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _valueOf(fact),
            style: theme.textTheme.titleLarge?.copyWith(color: accent, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(_labelOf(fact), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.verified_outlined, size: 13, color: Cosmos.textFaint),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  fact.sourceNote,
                  style: theme.textTheme.bodySmall?.copyWith(color: Cosmos.textMuted, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Uppercase section heading with a hairline rule.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Cosmos.textMuted,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08))),
      ],
    );
  }
}
