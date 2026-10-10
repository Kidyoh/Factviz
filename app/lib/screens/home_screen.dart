import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/example_prompts.dart';
import '../ui/search_box.dart';

/// One search box and example prompts.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _explain(String query) {
    _focus.unfocus();
    _controller.text = query;
    context.push(Uri(path: '/explain', queryParameters: {'q': query}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Template gallery',
              icon: const Icon(Icons.dashboard_customize_outlined),
              onPressed: () => context.push('/dev'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Icon(Icons.auto_graph_rounded, size: 44, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Explain It Visually',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Type any concept and get the real numbers, drawn to scale and animated.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                SearchBox(controller: _controller, focusNode: _focus, onSubmit: _explain),
                const SizedBox(height: 28),
                Text('Try one of these', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                ExamplePrompts(onSelected: _explain),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
