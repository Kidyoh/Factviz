import 'dart:async';

import 'package:factviz_core/factviz_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/api_key_store.dart';
import '../data/explain_backend.dart';
import '../data/on_device_backend.dart';
import '../data/visualize_repository.dart';

/// What a result screen is showing: a fresh question or a shared link.
sealed class ResultRequest {
  const ResultRequest();
}

final class QueryRequest extends ResultRequest {
  const QueryRequest(this.query);
  final String query;

  @override
  bool operator ==(Object other) => other is QueryRequest && other.query == query;

  @override
  int get hashCode => query.hashCode;
}

final class SharedRequest extends ResultRequest {
  const SharedRequest(this.payload);
  final String payload;

  @override
  bool operator ==(Object other) => other is SharedRequest && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;
}

sealed class VisualizeState {
  const VisualizeState();
}

final class VisualizeLoading extends VisualizeState {
  const VisualizeLoading(this.stage);
  final VisualizeStage stage;
}

final class VisualizeSuccess extends VisualizeState {
  const VisualizeSuccess(this.visualization);
  final Visualization visualization;
}

final class VisualizeFailure extends VisualizeState {
  const VisualizeFailure(this.message, {this.canRetry = true, this.needsKey = false});
  final String message;
  final bool canRetry;

  /// The user has to add or fix their OpenRouter key in Settings.
  final bool needsKey;
}

final apiKeyStoreProvider = Provider<ApiKeyStore>((ref) => SecureApiKeyStore());

/// Verifies an OpenRouter key; overridable in tests.
final keyCheckerProvider = Provider<Future<KeyCheck> Function(String key)>((ref) => checkOpenRouterKey);

/// Whether a key is stored. Refresh with `ref.invalidate` after Settings.
final hasApiKeyProvider = FutureProvider<bool>((ref) async => (await ref.watch(apiKeyStoreProvider).readKey()) != null);

/// True when the app was built to use an API server.
const bool usesServer = apiBaseUrl != '';

/// The server when one is configured at build time, otherwise the on-device
/// pipeline with the user's key.
final explainBackendProvider = Provider<ExplainBackend>((ref) {
  final ExplainBackend backend =
      usesServer ? FactvizApiClient() : OnDeviceBackend(keys: ref.watch(apiKeyStoreProvider));
  ref.onDispose(backend.close);
  return backend;
});

final visualizeRepositoryProvider =
    Provider<VisualizeRepository>((ref) => VisualizeRepository(ref.watch(explainBackendProvider)));

/// One controller per result screen; disposed when the screen is popped.
final visualizeControllerProvider = NotifierProvider.autoDispose
    .family<VisualizeController, VisualizeState, ResultRequest>(VisualizeController.new);

class VisualizeController extends Notifier<VisualizeState> {
  VisualizeController(this.request);

  /// How long the "Rendering" stage stays visible before the result appears.
  static Duration renderHold = const Duration(milliseconds: 400);

  final ResultRequest request;
  int _run = 0;

  @override
  VisualizeState build() {
    switch (request) {
      case SharedRequest(:final payload):
        // Shared links re-render from the validated payload with no LLM call.
        return switch (ShareCodec.decode(payload)) {
          Valid(:final value) => VisualizeSuccess(value),
          Invalid() => const VisualizeFailure(
              "This share link is damaged or out of date, so it can't be shown.",
              canRetry: false,
            ),
        };
      case QueryRequest(:final query):
        scheduleMicrotask(() => _explain(query));
        return const VisualizeLoading(VisualizeStage.findingFacts);
    }
  }

  /// Runs the query again after a failure.
  void retry() {
    if (request case QueryRequest(:final query)) {
      state = const VisualizeLoading(VisualizeStage.findingFacts);
      _explain(query);
    }
  }

  Future<void> _explain(String query) async {
    final run = ++_run;
    bool current() => ref.mounted && run == _run;
    try {
      final viz = await ref.read(visualizeRepositoryProvider).visualize(
        query,
        onStage: (stage) {
          if (current()) state = VisualizeLoading(stage);
        },
      );
      await Future<void>.delayed(renderHold);
      if (current()) state = VisualizeSuccess(viz);
    } on ApiException catch (e) {
      if (current()) {
        state = VisualizeFailure(e.message, canRetry: e.canRetry, needsKey: e.kind == ApiErrorKind.needsKey);
      }
    } catch (_) {
      if (current()) state = VisualizeFailure(ApiException.unvisualizable.message);
    }
  }
}
