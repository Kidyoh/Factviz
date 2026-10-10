import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Editor's-note style warning when the facts layer reports low confidence.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.facts});

  final FactsResult facts;

  @override
  Widget build(BuildContext context) {
    if (facts.confidence != Confidence.low) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: 'Low confidence warning',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(
          color: Palette.warnBg,
          border: Border(left: BorderSide(color: Palette.warn, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LOW CONFIDENCE', style: Txt.kicker.copyWith(color: Palette.warn)),
            const SizedBox(height: 4),
            Text(
              facts.confidenceNote ?? 'These figures may be inaccurate.',
              style: const TextStyle(fontFamily: serif, fontSize: 15, height: 1.4, color: Palette.ink),
            ),
          ],
        ),
      ),
    );
  }
}
