import 'package:flutter/material.dart';

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
        Icon(Icons.auto_awesome_outlined, size: 48, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 8,
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
