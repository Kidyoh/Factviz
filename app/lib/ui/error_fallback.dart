import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'logo_painter.dart';

/// Friendly failure state with retry and rephrase actions.
class ErrorFallback extends StatelessWidget {
  const ErrorFallback({super.key, required this.message, this.onRetry, required this.onRephrase, this.onOpenSettings});

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onRephrase;

  /// Set when the fix is in Settings (missing or rejected key).
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: 0.5,
          child: const SizedBox(width: 72, height: 72, child: CustomPaint(painter: LogoPainter())),
        ),
        const SizedBox(height: 18),
        Text(message, style: Txt.headline.copyWith(fontSize: 24)),
        const SizedBox(height: 10),
        Text(
          onOpenSettings != null
              ? 'It takes a minute: create a key at openrouter.ai/keys, then paste it in Settings.'
              : 'Questions about sizes, distances, history, growth or how something works tend to work best.',
          style: Txt.dek.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            if (onOpenSettings != null)
              FilledButton(onPressed: onOpenSettings, child: const Text('Open settings'))
            else
              FilledButton(onPressed: onRephrase, child: const Text('Rephrase')),
            if (onRetry != null) OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ],
    );
  }
}
