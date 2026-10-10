import 'package:flutter/material.dart';

import '../data/visualize_repository.dart';

/// Shows progress through "Finding facts" → "Choosing visualization" →
/// "Rendering".
class StageLoader extends StatelessWidget {
  const StageLoader({super.key, required this.stage});

  final VisualizeStage stage;

  static const labels = {
    VisualizeStage.findingFacts: 'Finding facts',
    VisualizeStage.choosingVisualization: 'Choosing visualization',
    VisualizeStage.rendering: 'Rendering',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      label: '${labels[stage]}…',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in VisualizeStage.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 28,
                      child: switch (s.index.compareTo(stage.index)) {
                        < 0 => Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
                        0 => const Padding(padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 3)),
                        _ => Icon(Icons.radio_button_unchecked_rounded, color: theme.colorScheme.outlineVariant),
                      },
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        labels[s]!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: s.index > stage.index ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                          fontWeight: s == stage ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
