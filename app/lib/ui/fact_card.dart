import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Plain-text answer used when no template fits (`template: none`).
class FactCard extends StatelessWidget {
  const FactCard({super.key, required this.facts, required this.reason});

  final FactsResult facts;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(facts.explanation, style: Txt.body),
        const SizedBox(height: 14),
        Text('No chart for this one: $reason', style: Txt.dek.copyWith(fontSize: 15)),
      ],
    );
  }
}
