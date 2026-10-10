import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../app/theme.dart';
import '../data/visualize_repository.dart';
import '../templates/common/motion.dart';

/// Lottie chart animation with the pipeline stages: "Finding facts" →
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
    VisualizeStage.findingFacts: 'Looking up reference figures and where they come from.',
    VisualizeStage.choosingVisualization: 'Deciding how best to draw it.',
    VisualizeStage.rendering: 'Putting everything to scale.',
  };

  @override
  Widget build(BuildContext context) {
    final animate = ambientMotionOf(context);
    return Semantics(
      liveRegion: true,
      label: '${labels[stage]}…',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 240,
              height: 150,
              child: Lottie.asset('assets/lottie/loader.json', animate: animate, repeat: true, frameRate: FrameRate.max),
            ),
            const SizedBox(height: 18),
            for (final s in VisualizeStage.values) _StageRow(stage: s, current: stage),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: reduceMotionOf(context) ? Duration.zero : const Duration(milliseconds: 250),
              child: Text(hints[stage]!, key: ValueKey(stage), style: Txt.dek.copyWith(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.current});

  final VisualizeStage stage;
  final VisualizeStage current;

  @override
  Widget build(BuildContext context) {
    final order = stage.index.compareTo(current.index);
    final color = order > 0 ? Palette.ink3 : Palette.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            child: order < 0
                ? const Icon(Icons.check, size: 16, color: Palette.ink)
                : Text(
                    '${stage.index + 1}',
                    style: TextStyle(fontFamily: sans, fontSize: 13, fontWeight: FontWeight.w700, color: order == 0 ? Palette.accent : color),
                  ),
          ),
          Flexible(
            child: Text(
              StageLoader.labels[stage]!,
              style: TextStyle(
                fontFamily: serif,
                fontSize: 19,
                fontWeight: order == 0 ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ),
          if (order == 0) ...[
            const SizedBox(width: 6),
            const Text('…', style: TextStyle(fontFamily: serif, fontSize: 19, color: Palette.accent)),
          ],
        ],
      ),
    );
  }
}
