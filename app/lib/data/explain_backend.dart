import 'package:factviz_core/factviz_core.dart';

/// Where facts and plans come from: the API server, or the on-device
/// pipeline with the user's own key. Both validate their output.
///
/// Failures are reported as `ApiException`s with user-facing messages.
abstract interface class ExplainBackend {
  Future<FactsResult> fetchFacts(String query);
  Future<Plan> fetchPlan(FactsResult facts);
  void close();
}
