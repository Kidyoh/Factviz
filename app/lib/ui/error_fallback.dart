import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'cosmic/orbit_mark.dart';

/// Friendly failure state with retry and rephrase actions.
class ErrorFallback extends StatelessWidget {
  const ErrorFallback({super.key, required this.message, this.onRetry, required this.onRephrase});

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onRephrase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Opacity(opacity: 0.55, child: OrbitMark(size: 96, animate: false)),
        const SizedBox(height: 22),
        Text(message, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Try a question about sizes, distances, history, growth or how something works.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Cosmos.textMuted),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            if (onRetry != null)
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            FilledButton.icon(onPressed: onRephrase, icon: const Icon(Icons.edit_rounded), label: const Text('Rephrase')),
          ],
        ),
      ],
    );
  }
}
