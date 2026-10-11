import 'package:factviz_core/factviz_core.dart';

import 'api_client.dart';
import 'explain_backend.dart';

enum VisualizeStage { findingFacts, choosingVisualization, rendering }

/// Runs the full pipeline: facts → plan → locally resolved visualization.
class VisualizeRepository {
  const VisualizeRepository(this._api, {this.resolver = const PlanResolver()});

  final ExplainBackend _api;
  final PlanResolver resolver;

  Future<Visualization> visualize(String query, {void Function(VisualizeStage stage)? onStage}) async {
    onStage?.call(VisualizeStage.findingFacts);
    final facts = await _api.fetchFacts(query);
    onStage?.call(VisualizeStage.choosingVisualization);
    final plan = await _api.fetchPlan(facts);
    onStage?.call(VisualizeStage.rendering);
    // The backend already resolved this plan; resolving again here means
    // the renderer never trusts anything it did not check itself.
    return switch (Visualization.build(facts, plan, resolver: resolver)) {
      Valid(:final value) => value,
      Invalid() => throw ApiException.unvisualizable,
    };
  }
}
