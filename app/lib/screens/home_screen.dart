import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder home; the search flow is wired up in a later step.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explain It Visually')),
      body: Center(
        child: kDebugMode
            ? FilledButton(onPressed: () => context.push('/dev'), child: const Text('Open template gallery'))
            : const Text('Coming soon'),
      ),
    );
  }
}
