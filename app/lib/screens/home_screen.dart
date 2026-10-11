import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../state/visualize_controller.dart';
import '../templates/common/motion.dart';
import '../ui/editorial.dart';
import '../ui/logo_painter.dart';
import '../ui/example_prompts.dart';
import '../ui/search_box.dart';

/// Masthead, one question field and an index of examples.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                // Masthead.
                Row(
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      // Animated once on launch; the static mark when motion is off.
                      child: ambientMotionOf(context)
                          ? Lottie.asset('assets/lottie/logo.json', repeat: false)
                          : const CustomPaint(painter: LogoPainter()),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'EXPLAIN IT VISUALLY',
                        style: TextStyle(fontFamily: sans, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.2, color: Palette.ink),
                      ),
                    ),
                    if (!usesServer)
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.key_outlined, size: 20),
                        onPressed: () => context.push('/settings'),
                      ),
                    if (showGallery)
                      IconButton(
                        tooltip: 'Template gallery',
                        icon: const Icon(Icons.grid_view_outlined, size: 20),
                        onPressed: () => context.push('/dev'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(height: 2, color: Palette.ink),
                const SizedBox(height: 3),
                Container(height: 1, color: Palette.ink),
                const SizedBox(height: 36),
                Semantics(
                  header: true,
                  child: const Text('What would you like to see?', style: TextStyle(
                    fontFamily: serif,
                    fontSize: 38,
                    height: 1.08,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                    color: Palette.ink,
                  )),
                ).animate(target: reduce ? 1 : null).fadeIn(duration: 450.ms).slideY(begin: 0.08, end: 0),
                const SizedBox(height: 12),
                Text(
                  'Ask about any size, distance, date or process. We look up the real figures and draw them to scale.',
                  style: Txt.dek,
                ).animate(target: reduce ? 1 : null).fadeIn(delay: 120.ms, duration: 450.ms),
                const SizedBox(height: 28),
                SearchBox(controller: _controller, focusNode: _focus, onSubmit: _explain),
                if (!usesServer && ref.watch(hasApiKeyProvider).value == false) ...[
                  const SizedBox(height: 18),
                  _KeyNudge(onTap: () => context.push('/settings')),
                ],
                const SizedBox(height: 44),
                const SectionRule('Try one of these'),
                const SizedBox(height: 2),
                ExamplePrompts(onSelected: _explain),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown until an OpenRouter key is saved.
class _KeyNudge extends StatelessWidget {
  const _KeyNudge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: const BoxDecoration(
            color: Palette.warnBg,
            border: Border(left: BorderSide(color: Palette.warn, width: 3)),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  'First, add your OpenRouter key so the app can look up facts.',
                  style: TextStyle(fontFamily: serif, fontSize: 15, height: 1.35, color: Palette.ink),
                ),
              ),
              SizedBox(width: 8),
              Text('Add key', style: TextStyle(fontFamily: sans, fontWeight: FontWeight.w700, fontSize: 13, color: Palette.ink)),
              Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
