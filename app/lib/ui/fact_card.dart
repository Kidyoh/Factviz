import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'cosmic/glass.dart';

/// Plain-text answer used when no template fits (`template: none`).
class FactCard extends StatelessWidget {
  const FactCard({super.key, required this.facts, required this.reason});

  final FactsResult facts;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Glass(
      tint: Cosmos.violet,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Cosmos.cyan),
              const SizedBox(width: 10),
              Expanded(child: Text(facts.topic, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 14),
          Text(facts.explanation, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          const SizedBox(height: 14),
          Text(
            'No visualization: $reason',
            style: theme.textTheme.bodySmall?.copyWith(color: Cosmos.textMuted),
          ),
        ],
      ),
    );
  }
}
