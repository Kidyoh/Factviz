import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'editorial.dart';

/// The facts behind a visualization as a ruled table, each row with its
/// source in small type, the way print graphics credit their data.
class KeyNumbers extends StatelessWidget {
  const KeyNumbers({super.key, required this.facts});

  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();
    final hasNumbers = facts.any((f) => f is! StepFact);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionRule(hasNumbers ? 'The numbers' : 'Sources'),
        const SizedBox(height: 4),
        for (final f in facts) _FactRow(fact: f),
        if (hasNumbers)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('~ marks a typical or rounded value.', style: Txt.caption),
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
    final (String value, String label) = switch (fact) {
      QuantityFact f => (f.displayValue, f.label),
      EventFact f => (f.displayDate, f.label),
      StepFact f => ('Step ${f.order}', f.title),
    };
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.rule))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                flex: 3,
                child: Text(label, style: const TextStyle(fontFamily: serif, fontSize: 16, height: 1.3, color: Palette.ink)),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: Text(value, textAlign: TextAlign.right, style: Txt.figure.copyWith(fontSize: 17)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text('Source: ${fact.sourceNote}', style: Txt.caption),
        ],
      ),
    );
  }
}
