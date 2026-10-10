import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/visualize_repository.dart';
import 'cosmic/glass.dart';
import 'cosmic/orbit_mark.dart';

/// Orbital loader with the pipeline stages: "Finding facts" →
/// "Choosing visualization" → "Rendering".
class StageLoader extends StatelessWidget {
  const StageLoader({super.key, required this.stage});

  final VisualizeStage stage;

  static const labels = {
    VisualizeStage.findingFacts: 'Finding facts',
    VisualizeStage.choosingVisualization: 'Choosing visualization',
    VisualizeStage.rendering: 'Rendering',
  };

  static const hints = {
    VisualizeStage.findingFacts: 'Looking up trusted figures and their sources',
    VisualizeStage.choosingVisualization: 'Picking the best way to show it',
    VisualizeStage.rendering: 'Drawing everything to scale',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      liveRegion: true,
      label: '${labels[stage]}…',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OrbitMark(size: 132, speed: 2),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
              child: Column(
                key: ValueKey(stage),
                children: [
                  GradientText(labels[stage]!, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(hints[stage]!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: Cosmos.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Glass(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in VisualizeStage.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 22,
                            child: switch (s.index.compareTo(stage.index)) {
                              < 0 => const DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [Cosmos.cyan, Cosmos.violet]),
                                  ),
                                  child: Icon(Icons.check_rounded, size: 15, color: Cosmos.void0),
                                ),
                              0 => const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Cosmos.cyan),
                                ),
                              _ => DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                                  ),
                                ),
                            },
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              labels[s]!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: s.index > stage.index ? Cosmos.textFaint : Cosmos.text,
                                fontWeight: s == stage ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
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
