import 'package:factviz_core/factviz_core.dart';

import '../llm/llm_client.dart';
import '../llm/prompts/facts_prompt.dart';
import '../llm/prompts/planner_prompt.dart';
import 'validated_call.dart';

typedef PipelineLogger = void Function(String message);

/// Outcome of one pipeline step.
sealed class PipelineResult<T> {
  const PipelineResult();
}

final class PipelineOk<T> extends PipelineResult<T> {
  const PipelineOk(this.value, this.attempts);
  final T value;

  /// LLM requests made (0 when no model call was needed).
  final int attempts;
}

enum RejectionKind {
  /// The input was invalid (e.g. a query that is too short).
  badRequest,

  /// The model could not produce valid output after a retry.
  unvisualizable,
}

final class PipelineRejected<T> extends PipelineResult<T> {
  const PipelineRejected(this.kind, this.message, {this.issues = const []});
  final RejectionKind kind;
  final String message;
  final List<ValidationIssue> issues;
}

/// The facts → planner pipeline, independent of transport. The HTTP server
/// and the app's on-device mode both run exactly this code, so prompts,
/// validation and the retry-once policy are identical everywhere.
///
/// [LlmException]s from the provider are not caught; callers map them.
class ExplainPipeline {
  ExplainPipeline({
    required this.llm,
    required this.factsModel,
    required this.plannerModel,
    this.resolver = const PlanResolver(),
    PipelineLogger? log,
  }) : _log = log ?? ((_) {});

  final LlmClient llm;
  final String factsModel;
  final String plannerModel;
  final PlanResolver resolver;
  final PipelineLogger _log;

  static const int minQueryLength = 3;
  static const int maxQueryLength = 300;
  static const String unvisualizableMessage = "Couldn't visualize this one, try rephrasing.";

  /// Trims and collapses whitespace; null if the length is out of range.
  static String? normalizeQuery(String raw) {
    final q = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return q.length < minQueryLength || q.length > maxQueryLength ? null : q;
  }

  Future<PipelineResult<FactsResult>> facts(String rawQuery) async {
    final query = normalizeQuery(rawQuery);
    if (query == null) {
      return const PipelineRejected(
        RejectionKind.badRequest,
        'Type a question between $minQueryLength and $maxQueryLength characters.',
      );
    }
    final outcome = await validatedCall(
      llm: llm,
      request: buildFactsRequest(model: factsModel, query: query),
      validate: (json) {
        // The echoed query is always the user's own text.
        if (json is Map<String, dynamic>) json['query'] = query;
        return FactsResult.fromJson(json);
      },
    );
    switch (outcome) {
      case CallSucceeded(:final value, :final attempts):
        _log('facts ok attempts=$attempts facts=${value.facts.length} confidence=${value.confidence.name}');
        return PipelineOk(value, attempts);
      case CallFailedValidation(:final issues, :final attempts):
        _log('facts invalid after $attempts attempts:\n${formatIssues(issues)}');
        return PipelineRejected(RejectionKind.unvisualizable, unvisualizableMessage, issues: issues);
    }
  }

  Future<PipelineResult<Plan>> plan(FactsResult facts) async {
    if (facts.facts.isEmpty) {
      return PipelineOk(NonePlan(title: facts.topic, reason: 'There are not enough reliable facts to draw this.'), 0);
    }
    final outcome = await validatedCall<Plan>(
      llm: llm,
      request: buildPlannerRequest(model: plannerModel, facts: facts),
      validate: (json) => switch (Plan.fromJson(json)) {
        Invalid(:final issues) => Invalid(issues),
        Valid(value: final plan) => switch (resolver.resolve(plan, facts)) {
            Invalid(:final issues) => Invalid(issues),
            Valid() => Valid(plan),
          },
      },
    );
    switch (outcome) {
      case CallSucceeded(:final value, :final attempts):
        _log('plan ok attempts=$attempts template=${value.template.wire}');
        return PipelineOk(value, attempts);
      case CallFailedValidation(:final issues, :final attempts):
        _log('plan invalid after $attempts attempts:\n${formatIssues(issues)}');
        return PipelineRejected(RejectionKind.unvisualizable, unvisualizableMessage, issues: issues);
    }
  }
}
