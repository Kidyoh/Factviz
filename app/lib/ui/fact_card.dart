import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

/// Plain-text answer used when no template fits (`template: none`).
class FactCard extends StatelessWidget {
  const FactCard({super.key, required this.facts, required this.reason});

  final FactsResult facts;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(facts.topic, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 12),
            Text(facts.explanation, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Text(
              'No visualization: $reason',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
