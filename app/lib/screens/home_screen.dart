import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../templates/common/motion.dart';
import '../ui/editorial.dart';
import '../ui/logo_painter.dart';
import '../ui/example_prompts.dart';
import '../ui/search_box.dart';

/// Masthead, one question field and an index of examples.
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
