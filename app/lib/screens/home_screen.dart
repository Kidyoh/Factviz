import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../ui/cosmic/glass.dart';
import '../ui/cosmic/orbit_mark.dart';
import '../ui/cosmic/starfield.dart';
import '../ui/example_prompts.dart';
import '../ui/search_box.dart';

/// One search box and illustrated example prompts, over a starfield.
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        actions: [
          if (kDebugMode)
            GlassIconButton(
              tooltip: 'Template gallery',
              icon: Icons.dashboard_customize_outlined,
              onPressed: () => context.push('/dev'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: CosmicBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: OrbitMark(size: 84)),
                  const SizedBox(height: 18),
                  Semantics(
                    header: true,
                    label: 'Explain It Visually',
                    child: ExcludeSemantics(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Explain it\n'),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GradientText('visually.', style: theme.textTheme.displaySmall?.copyWith(height: 1.05)),
                            ),
                          ],
                        ),
                        style: theme.textTheme.displaySmall?.copyWith(height: 1.05),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Type any concept. Get the real numbers — drawn to scale and brought to life.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: Cosmos.textMuted, height: 1.45),
                  ),
                  const SizedBox(height: 28),
                  SearchBox(controller: _controller, focusNode: _focus, onSubmit: _explain),
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      Text(
                        'EXPLORE',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Cosmos.textMuted,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ExamplePrompts(onSelected: _explain),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
