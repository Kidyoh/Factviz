import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/share.dart';
import '../state/visualize_controller.dart';
import '../ui/cosmic/glass.dart';
import '../ui/cosmic/starfield.dart';
import '../ui/error_fallback.dart';
import '../ui/stage_loader.dart';
import '../ui/visualization_panel.dart';

/// Shows loading stages, the visualization, or a friendly fallback.
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.request});

  final ResultRequest request;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  int _replay = 0;

  String? get _query => switch (widget.request) {
        QueryRequest(:final query) => query,
        SharedRequest() => null,
      };

  void _rephrase() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Uri(path: '/', queryParameters: {'q': ?_query}).toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = visualizeControllerProvider(widget.request);
    final state = ref.watch(provider);
    final success = state is VisualizeSuccess ? state : null;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leadingWidth: 64,
        leading: Center(
          child: context.canPop()
              ? GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => context.pop())
              : GlassIconButton(icon: Icons.home_rounded, tooltip: 'Home', onPressed: () => context.go('/')),
        ),
        title: Text(_query ?? 'Shared visualization', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (success != null) ...[
            GlassIconButton(
              tooltip: 'Replay',
              icon: Icons.replay_rounded,
              onPressed: () => setState(() => _replay++),
            ),
            GlassIconButton(
              tooltip: 'Share',
              icon: Icons.ios_share_rounded,
              onPressed: () => ref.read(shareTextProvider)(
                shareMessage(success.visualization),
                subject: success.visualization.props.title,
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: CosmicBackground(
        intensity: 0.8,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(animation), child: child),
            ),
            child: switch (state) {
              VisualizeLoading(:final stage) => Center(
                  key: const ValueKey('loading'),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: StageLoader(stage: stage),
                  ),
                ),
              VisualizeFailure(:final message, :final canRetry) => Center(
                  key: const ValueKey('failure'),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: ErrorFallback(
                      message: message,
                      onRetry: canRetry && _query != null ? () => ref.read(provider.notifier).retry() : null,
                      onRephrase: _rephrase,
                    ),
                  ),
                ),
              VisualizeSuccess(:final visualization) => Center(
                  key: const ValueKey('success'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                      children: [
                        VisualizationPanel(visualization: visualization, replayKey: _replay),
                        const SizedBox(height: 28),
                        OutlinedButton.icon(
                          onPressed: _rephrase,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Ask another question'),
                        ),
                      ],
                    ),
                  ),
                ),
            },
          ),
        ),
      ),
    );
  }
}
