import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'cosmic/glass.dart';

/// Warning shown when the facts layer reports low confidence.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.facts});

  final FactsResult facts;

  @override
  Widget build(BuildContext context) {
    if (facts.confidence != Confidence.low) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: 'Low confidence warning',
      child: Glass(
        tint: Cosmos.amber,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Cosmos.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Low confidence. ', style: TextStyle(fontWeight: FontWeight.w700, color: Cosmos.amber)),
                  TextSpan(text: facts.confidenceNote ?? 'These figures may be inaccurate.'),
                ]),
                style: const TextStyle(color: Cosmos.text, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
