import 'package:factviz_core/factviz_core.dart';
import 'package:flutter/material.dart';

/// Warning shown when the facts layer reports low confidence.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.facts});

  final FactsResult facts;

  @override
  Widget build(BuildContext context) {
    if (facts.confidence != Confidence.low) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Low confidence warning',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Low confidence. ', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: facts.confidenceNote ?? 'These figures may be inaccurate.'),
                ]),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
