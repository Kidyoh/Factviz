import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../state/share.dart';
import '../state/visualize_controller.dart';
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
        SharedRequest() || LibraryRequest() => null,
      };

  void _rephrase() {
    if (context.canPop()) {
      context.pop();
    } else if (widget.request is LibraryRequest) {
      context.go('/library');
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
      appBar: AppBar(
        leading: context.canPop()
            ? IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Back', onPressed: () => context.pop())
            : IconButton(icon: const Icon(Icons.home_outlined), tooltip: 'Home', onPressed: () => context.go('/')),
        title: Text(
          _query ??
              switch (widget.request) {
                LibraryRequest() => success?.visualization.facts.query ?? 'Library',
                _ => 'Shared visualization',
              },
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (success != null) ...[
            IconButton(
              tooltip: 'Replay',
              icon: const Icon(Icons.replay),
              onPressed: () => setState(() => _replay++),
            ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              onPressed: () => ref.read(shareTextProvider)(
                shareMessage(success.visualization),
                subject: success.visualization.props.title,
              ),
            ),
          ],
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 350),
          child: switch (state) {
            VisualizeLoading(:final stage) => Center(
                key: const ValueKey('loading'),
                child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: StageLoader(stage: stage)),
              ),
            VisualizeFailure(:final message, :final canRetry, :final needsKey) => Align(
                key: const ValueKey('failure'),
                alignment: const Alignment(0, -0.3),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: ErrorFallback(
                    message: message,
                    onRetry: canRetry && _query != null ? () => ref.read(provider.notifier).retry() : null,
                    onRephrase: _rephrase,
                    onOpenSettings: needsKey
                        ? () async {
                            await context.push('/settings');
                            if (mounted && await ref.read(apiKeyStoreProvider).readKey() != null) {
                              ref.read(provider.notifier).retry();
                            }
                          }
                        : null,
                  ),
                ),
              ),
            VisualizeSuccess(:final visualization) => Center(
                key: const ValueKey('success'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 40),
                    children: [
                      VisualizationPanel(visualization: visualization, replayKey: _replay),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: VisualizationPanel.gutter),
                        child: widget.request is LibraryRequest
                            ? OutlinedButton(onPressed: _rephrase, child: const Text('Back to the library'))
                            : OutlinedButton(onPressed: _rephrase, child: const Text('Ask another question')),
                      ),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text('Figures come from reference sources; check the notes above.', style: Txt.caption),
                      ),
                    ],
                  ),
                ),
              ),
          },
        ),
      ),
    );
  }
}
