import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

/// The facts behind a visualization, each with its source note.
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
        Text(hasNumbers ? 'Key numbers' : 'Sources', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < facts.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                _FactRow(fact: facts[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact});

  final Fact fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String value, String label) = switch (fact) {
      QuantityFact f => (f.displayValue, f.label),
      EventFact f => (f.displayDate, f.label),
      StepFact f => ('Step ${f.order}', f.title),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: Text(label, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            fact.sourceNote,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
