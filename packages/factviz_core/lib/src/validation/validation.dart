/// A single validation problem, addressed by a JSON path such as
/// `facts[2].unit` so it can be fed back to an LLM verbatim.
class ValidationIssue {
  const ValidationIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => path.isEmpty ? message : '$path: $message';

  @override
  bool operator ==(Object other) =>
      other is ValidationIssue && other.path == path && other.message == message;

  @override
  int get hashCode => Object.hash(path, message);
}

/// Outcome of validating untrusted input.
sealed class ValidationResult<T> {
  const ValidationResult();

  bool get isValid => this is Valid<T>;

  /// The validated value, or throws [ValidationException].
  T get valueOrThrow => switch (this) {
        Valid<T>(:final value) => value,
        Invalid<T>(:final issues) => throw ValidationException(issues),
      };

  /// Issues, empty when valid.
  List<ValidationIssue> get issues => const [];
}

final class Valid<T> extends ValidationResult<T> {
  const Valid(this.value);
  final T value;
}

final class Invalid<T> extends ValidationResult<T> {
  const Invalid(this.issues);

  @override
  final List<ValidationIssue> issues;
}

class ValidationException implements Exception {
  const ValidationException(this.issues);
  final List<ValidationIssue> issues;

  @override
  String toString() => 'ValidationException:\n${formatIssues(issues)}';
}

/// Formats issues as a bullet list, the shape used in LLM retry prompts.
String formatIssues(List<ValidationIssue> issues) =>
    issues.map((i) => '- $i').join('\n');

/// Runs [body] with a fresh issue list and wraps the outcome.
///
/// The result is [Valid] only when [body] returned a value *and* recorded no
/// issues, so parsers can keep going after the first problem and report
/// everything at once.
ValidationResult<T> validate<T>(T? Function(List<ValidationIssue> issues) body) {
  final issues = <ValidationIssue>[];
  final value = body(issues);
  if (issues.isEmpty && value != null) return Valid(value);
  if (issues.isEmpty) issues.add(const ValidationIssue('', 'invalid value'));
  return Invalid(List.unmodifiable(issues));
}
