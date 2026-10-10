import 'package:flutter/material.dart';

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
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        IconButton.filledTonal(
          tooltip: playing ? 'Pause' : 'Play',
          onPressed: onPlayPause,
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
        IconButton(
          tooltip: 'Next step',
          onPressed: onNext,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}
