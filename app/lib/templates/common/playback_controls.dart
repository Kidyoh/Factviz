import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Previous / play-pause / next buttons shared by stepped templates.
class PlaybackControls extends StatelessWidget {
  const PlaybackControls({
    super.key,
    required this.playing,
    required this.onPlayPause,
    this.onPrevious,
    this.onNext,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous step',
          onPressed: onPrevious,
          color: Cosmos.text,
          disabledColor: Cosmos.textFaint,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Cosmos.cyan, Cosmos.violet]),
            boxShadow: [BoxShadow(color: Cosmos.cyan.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: -2)],
          ),
          child: IconButton(
            tooltip: playing ? 'Pause' : 'Play',
            onPressed: onPlayPause,
            color: Cosmos.void0,
            icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
        ),
        IconButton(
          tooltip: 'Next step',
          onPressed: onNext,
          color: Cosmos.text,
          disabledColor: Cosmos.textFaint,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}
