import '../facts/facts.dart';
import '../mapping/plan_resolver.dart';
import '../plan/plan.dart';
import '../share/visualization.dart';
import '../validation/json_reader.dart';
import '../validation/validation.dart';

final _slug = RegExp(r'^[a-z0-9_]{1,60}$');

/// A ready-made visualization bundled with the app: facts with source notes
/// and a plan, checked by exactly the same validators and resolver as a live
/// answer from the model.
class LibraryEntry {
  const LibraryEntry({required this.id, required this.category, required this.visualization});

  final String id;
  final String category;
  final Visualization visualization;

  String get query => visualization.facts.query;
  String get title => visualization.plan.title;
  TemplateId get template => visualization.plan.template;
}

/// One shelf of the library, e.g. "Space".
class LibraryCategory {
  const LibraryCategory({required this.id, required this.title, required this.entries});

  final String id;
  final String title;
  final List<LibraryEntry> entries;

  /// Parses and resolves a category file. Any invalid entry fails the
  /// whole category, with the entry's index in each issue path.
  static ValidationResult<LibraryCategory> fromJson(Object? json, {PlanResolver resolver = const PlanResolver()}) =>
      validate((issues) {
        final r = JsonReader.of(json, issues);
        if (r == null) return null;
        final id = r.string('category', pattern: _slug, patternHint: 'slug');
        final title = r.string('title', maxLength: 40);
        final raw = r.has('entries') ? (json! as Map)['entries'] : null;
        if (raw is! List) {
          r.issue('must be a list', key: 'entries');
          return null;
        }
        final entries = <LibraryEntry>[];
        final ids = <String>{};
        for (var i = 0; i < raw.length; i++) {
          final e = raw[i];
          final path = 'entries[$i]';
          if (e is! Map) {
            issues.add(ValidationIssue(path, 'must be an object'));
            continue;
          }
          final entryId = e['id'];
          if (entryId is! String || !_slug.hasMatch(entryId)) {
            issues.add(ValidationIssue('$path.id', 'must be a slug'));
            continue;
          }
          if (!ids.add(entryId)) issues.add(ValidationIssue('$path.id', 'duplicate id "$entryId"'));
          final facts = FactsResult.fromJson(e['facts']);
          final plan = Plan.fromJson(e['plan']);
          String at(String part, String sub) => sub.isEmpty ? '$path.$part' : '$path.$part.$sub';
          for (final issue in facts.issues) {
            issues.add(ValidationIssue(at('facts', issue.path), issue.message));
          }
          for (final issue in plan.issues) {
            issues.add(ValidationIssue(at('plan', issue.path), issue.message));
          }
          if (facts is! Valid<FactsResult> || plan is! Valid<Plan>) continue;
          switch (Visualization.build(facts.value, plan.value, resolver: resolver)) {
            case Valid(:final value):
              entries.add(LibraryEntry(id: entryId, category: id ?? '', visualization: value));
            case Invalid(issues: final found):
              for (final issue in found) {
                issues.add(ValidationIssue(issue.path.isEmpty ? '$path.plan' : '$path.plan.${issue.path}', issue.message));
              }
          }
        }
        if (id == null || title == null) return null;
        return LibraryCategory(id: id, title: title, entries: List.unmodifiable(entries));
      });
}
