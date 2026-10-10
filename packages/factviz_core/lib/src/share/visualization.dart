import '../facts/facts.dart';
import '../mapping/plan_resolver.dart';
import '../plan/plan.dart';
import '../templates/template_props.dart';
import '../validation/validation.dart';

/// Everything needed to render one result: the facts (for the explanation
/// and key numbers), the plan (for sharing), and the resolved props.
class Visualization {
  const Visualization._(this.facts, this.plan, this.props);

  final FactsResult facts;
  final Plan plan;
  final TemplateProps props;

  /// Resolves [plan] against [facts]. Fails if any reference is invalid.
  static ValidationResult<Visualization> build(
    FactsResult facts,
    Plan plan, {
    PlanResolver resolver = const PlanResolver(),
  }) =>
      switch (resolver.resolve(plan, facts)) {
        Valid(:final value) => Valid(Visualization._(facts, plan, value)),
        Invalid(:final issues) => Invalid(issues),
      };

  /// Facts the plan actually uses, in plan order, followed by the rest.
  List<Fact> get keyFacts {
    final used = plan.factIds.toSet();
    return [
      for (final id in plan.factIds) ?facts.byId(id),
      ...facts.facts.where((f) => !used.contains(f.id)),
    ];
  }
}
