import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      appBar: AppBar(
        leading: context.canPop() ? null : IconButton(icon: const Icon(Icons.home_rounded), tooltip: 'Home', onPressed: () => context.go('/')),
        title: Text(_query ?? 'Shared visualization', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (success != null) ...[
            IconButton(
              tooltip: 'Replay',
              icon: const Icon(Icons.replay_rounded),
              onPressed: () => setState(() => _replay++),
            ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_rounded),
              onPressed: () => ref.read(shareTextProvider)(
                shareMessage(success.visualization),
                subject: success.visualization.props.title,
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch (state) {
          VisualizeLoading(:final stage) => Center(
              child: Padding(padding: const EdgeInsets.all(24), child: StageLoader(stage: stage)),
            ),
          VisualizeFailure(:final message, :final canRetry) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorFallback(
                  message: message,
                  onRetry: canRetry && _query != null ? () => ref.read(provider.notifier).retry() : null,
                  onRephrase: _rephrase,
                ),
              ),
            ),
          VisualizeSuccess(:final visualization) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    VisualizationPanel(visualization: visualization, replayKey: _replay),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _rephrase,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Ask another question'),
                    ),
                  ],
                ),
              ),
            ),
        },
      ),
    );
  }
}
